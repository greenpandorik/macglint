import SwiftUI
import Charts
import MacGlintCore

struct HistoryView: View {
    @ObservedObject var store: AppStore
    @State private var window: Double = 3600
    @State private var metric = "CPU"
    @State private var navigation = HistoryNavigation()
    private let metrics = ["CPU", "Память", "Давление", "Сеть", "Диск"]
    private var samples: [MetricSnapshot] {
        let range = navigation.range(now: Date(), duration: window)
        return store.recent.filter { range.contains($0.date) }
    }
    private var visibleEvents: [AlertEvent] {
        guard let first = samples.first, let last = samples.last else { return [] }
        return store.events.filter { $0.date >= first.date && $0.date <= last.date }
    }
    private struct PlotPoint: Identifiable {
        let date: Date
        let value: Double
        let segment: Int
        var id: Date { date }
    }
    private var plotPoints: [PlotPoint] {
        var segment = 0
        var previous: Date?
        return samples.compactMap { sample in
            guard let v = value(sample) else { segment += 1; previous = nil; return nil }
            if let previous, sample.date.timeIntervalSince(previous) > 30 { segment += 1 }
            previous = sample.date
            return PlotPoint(date: sample.date, value: v, segment: segment)
        }
    }
    private func value(_ s: MetricSnapshot) -> Double? {
        switch metric {
        case "Память": return s.memoryUsed.map { Double($0) / 1e9 }
        case "Давление": return s.pressure.map(Double.init)
        case "Диск": return s.diskFree.map { Double($0) / 1e9 }
        case "Сеть": return s.download.map { $0 / 1e6 }
        default: return s.cpu
        }
    }
    private var unit: String { metric == "CPU" ? "%" : (metric == "Память" || metric == "Диск") ? "ГБ" : metric == "Сеть" ? "МБ/с ↓" : "0 норма · 1 повышенное · 2 критическое" }
    private var selectedSnapshot: MetricSnapshot? {
        guard let selectedDate = navigation.selectedDate, let closest = samples.min(by: { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }),
              abs(closest.date.timeIntervalSince(selectedDate)) <= 18 else { return nil }
        return closest
    }
    var body: some View {
        ScrollViewReader { reader in
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Color.clear.frame(height: 0).id("history-top")
                HStack {
                    Picker("Показатель", selection: $metric) { ForEach(metrics, id: \.self) { Text($0).tag($0) } }.frame(width: 180)
                    Spacer()
                    Picker("Период", selection: $window) { Text("15 мин").tag(900.0); Text("1 час").tag(3600.0); Text("24 часа").tag(86400.0) }.pickerStyle(.segmented).labelsHidden().frame(width: 240)
                }
                HStack {
                    Text(metric).font(.headline); SmallLabel(text: unit); Spacer()
                    if store.focusedEvent != nil || navigation.selectedDate != nil {
                        Button("К текущему времени") { store.focusedEvent = nil; navigation.goLive() }
                    }
                }
                historyChart
                HStack {
                    SmallLabel(text: "Нажмите на график, чтобы посмотреть этот момент")
                    Spacer()
                    Button { stepSelection(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Предыдущий срез")
                        .disabled(samples.isEmpty)
                    Button("Последний срез") { store.focusedEvent = nil; navigation.goLive(); if let date = store.recent.last?.date { navigation.selectMoment(date) } }.disabled(store.recent.isEmpty)
                    Button { stepSelection(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Следующий срез")
                        .disabled(samples.isEmpty)
                }
                if let event = store.focusedEvent {
                    AlertCardView(store: store, event: event)
                } else if let selected = selectedSnapshot {
                    EpisodeView(store: store, snapshot: selected, episode: Episode.nearest(to: selected.date, in: store.episodes))
                } else if navigation.selectedDate != nil {
                    Label("В этот момент измерений нет: Mac мог спать или мониторинг был выключен.", systemImage: "moon.zzz")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Divider()
                HStack { Text("События").font(.headline); Spacer(); Text("\(store.events.count) за 24 часа").font(.caption).foregroundStyle(.secondary) }
                LazyVStack(alignment: .leading, spacing: 0) {
                    if store.events.isEmpty { Text("Пока всё спокойно. Здесь появятся сработавшие правила.").font(.callout).foregroundStyle(.secondary).padding(.vertical, 16) }
                    ForEach(store.events.reversed()) { event in
                        Button { store.showEvent(event) } label: {
                            HStack(alignment: .top) {
                                Image(systemName: "bell.badge").foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 3) { Text(event.title).fontWeight(.medium); Text(event.detail).font(.caption).foregroundStyle(.secondary) }
                                Spacer(); Text(event.date.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }.padding(12).background(store.focusedEvent?.id == event.id ? Color.primary.opacity(0.06) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain).accessibilityAddTraits(store.focusedEvent?.id == event.id ? .isSelected : [])
                        Divider()
                    }
                }
                SmallLabel(text: "История за 24 часа · система ≈ 10 с, приложения ≈ 30 с · пропуски не означают нулевую нагрузку")
            }.padding(.horizontal, 24).padding(.bottom, 14)
        }
        .onAppear { if let event = store.focusedEvent { navigation.focusEvent(at: event.date) }; selectEventMetric() }
        .onChange(of: store.focusedEvent?.id) { _, id in
            if id != nil {
                if let event = store.focusedEvent { navigation.focusEvent(at: event.date) }; selectEventMetric()
                reader.scrollTo("history-top", anchor: .top)
            }
        }
        .onChange(of: window) { _, _ in navigation.selectedDate = nil }
        }
    }
    @ViewBuilder private var historyChart: some View {
        if samples.isEmpty {
            QuietEmptyState(title: "История ещё собирается", message: "Новые точки появляются примерно каждые 10 секунд. История хранится на Mac за последние сутки.").frame(height: 170)
        } else {
            Chart {
                ForEach(plotPoints) { s in
                    LineMark(x: .value("Время", s.date), y: .value(metric, s.value), series: .value("Отрезок", s.segment))
                        .foregroundStyle(.blue).lineStyle(StrokeStyle(lineWidth: 1.7))
                }
                ForEach(visibleEvents) { event in
                    RuleMark(x: .value("Событие", event.date)).foregroundStyle(.orange.opacity(0.6)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                }
                if let focus = navigation.selectedDate ?? store.focusedEvent?.date {
                    RuleMark(x: .value("Выбранный момент", focus)).foregroundStyle(.primary.opacity(0.6))
                }
            }.chartXScale(range: .plotDimension(padding: 16))
                .chartYAxis { AxisMarks(position: .leading) }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisGridLine(); AxisValueLabel(format: .dateTime.hour().minute()) } }
                .frame(height: 170)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle()).gesture(
                            DragGesture(minimumDistance: 0).onChanged { value in
                                guard let plot = proxy.plotFrame else { return }
                                let frame = geometry[plot]
                                let x = min(max(0, value.location.x - frame.minX), frame.width)
                                guard let date: Date = proxy.value(atX: x) else { return }
                                store.focusedEvent = nil; navigation.selectMoment(date)
                            }
                        )
                    }
                }
        }
    }
    private func stepSelection(_ direction: Int) {
        let ordered = samples
        guard !ordered.isEmpty else { return }
        let target = navigation.selectedDate ?? store.focusedEvent?.date ?? ordered.last!.date
        let date = direction < 0 ? ordered.last(where: { $0.date < target })?.date : ordered.first(where: { $0.date > target })?.date
        store.focusedEvent = nil; navigation.selectMoment(date ?? target)
    }
    private func selectEventMetric() {
        guard let event = store.focusedEvent else { return }
        switch event.metric {
        case .cpu: metric = "CPU"
        case .memoryGB: metric = "Память"
        case .pressure: metric = "Давление"
        case .diskFreeGB: metric = "Диск"
        }
    }
}
