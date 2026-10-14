import SwiftUI
import Charts
import MacGlintCore

struct HistoryView: View {
    @ObservedObject var store: AppStore
    @State private var window: Double = 3600
    @State private var metric = "CPU"
    private let metrics = ["CPU", "Память", "Давление", "Сеть", "Диск"]
    private var samples: [MetricSnapshot] {
        let end = store.focusedEvent?.date.addingTimeInterval(window / 2) ?? Date()
        return store.recent.filter { $0.date >= end.addingTimeInterval(-window) && $0.date <= end }
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
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Picker("Показатель", selection: $metric) { ForEach(metrics, id: \.self) { Text($0).tag($0) } }.frame(width: 180)
                Spacer()
                Picker("Период", selection: $window) { Text("15 мин").tag(900.0); Text("1 час").tag(3600.0); Text("24 часа").tag(86400.0) }.pickerStyle(.segmented).labelsHidden().frame(width: 240)
            }
            HStack { Text(metric).font(.headline); SmallLabel(text: unit); Spacer(); if store.focusedEvent != nil { Button("К текущему времени") { store.focusedEvent = nil } } }
            if samples.isEmpty {
                ContentUnavailableView("История ещё собирается", systemImage: "chart.xyaxis.line", description: Text("Новые точки сохраняются каждые 10 секунд. Данные хранятся на этом Mac до 24 часов.")).frame(height: 170)
            } else {
                Chart {
                    ForEach(plotPoints) { s in
                        LineMark(x: .value("Время", s.date), y: .value(metric, s.value), series: .value("Отрезок", s.segment))
                            .foregroundStyle(.blue).lineStyle(StrokeStyle(lineWidth: 1.7))
                    }
                    ForEach(visibleEvents) { event in
                        RuleMark(x: .value("Событие", event.date)).foregroundStyle(.orange.opacity(0.6)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    }
                }.chartYAxis { AxisMarks(position: .leading) }.frame(height: 170)
            }
            if let event = store.focusedEvent {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title).font(.headline)
                    Text(event.detail).font(.caption)
                    if let process = event.process { Text("В момент события: \(process.name), PID \(process.identity.pid)").font(.caption).foregroundStyle(.secondary) }
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
            Divider()
            HStack { Text("События").font(.headline); Spacer(); Text("\(store.events.count) за 24 часа").font(.caption).foregroundStyle(.secondary) }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if store.events.isEmpty { Text("Пока всё спокойно. Здесь появятся сработавшие правила.").font(.callout).foregroundStyle(.secondary).padding(.vertical, 16) }
                    ForEach(store.events.reversed()) { event in
                        Button { store.focusedEvent = event } label: {
                            HStack(alignment: .top) {
                                Image(systemName: "bell.badge").foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 3) { Text(event.title).fontWeight(.medium); Text(event.detail).font(.caption).foregroundStyle(.secondary) }
                                Spacer(); Text(event.date.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                            }.padding(10).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                    }
                }
            }
            SmallLabel(text: "Локальная история · 24 часа · промежутки без измерений не означают нулевую нагрузку")
        }.padding(.horizontal, 24).padding(.bottom, 14)
            .onAppear { selectEventMetric() }
            .onChange(of: store.focusedEvent?.id) { _, _ in selectEventMetric() }
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
