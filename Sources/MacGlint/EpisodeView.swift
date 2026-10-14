import SwiftUI
import MacGlintCore

struct EpisodeView: View {
    @ObservedObject var store: AppStore
    let snapshot: MetricSnapshot
    let episode: Episode?
    @State private var memory = false
    private var apps: [AppObservation] {
        (episode?.apps ?? []).sorted {
            let a = memory ? $0.memoryBytes.map(Double.init) ?? -1 : $0.cpu ?? -1
            let b = memory ? $1.memoryBytes.map(Double.init) ?? -1 : $1.cpu ?? -1
            return a == b ? $0.id < $1.id : a > b
        }
    }
    private var pressure: String {
        switch snapshot.pressure { case 0: return "норма"; case 1: return "повышенное"; case 2: return "критическое"; default: return "нет данных" }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Состояние в " + snapshot.date.formatted(date: .omitted, time: .standard)).font(.headline)
            Text("CPU " + Format.percent(snapshot.cpu) + " · Память " + Format.bytes(snapshot.memoryUsed) + " · Давление: " + pressure)
                .font(.callout).monospacedDigit().fixedSize(horizontal: false, vertical: true)
            if let episode {
                HStack {
                    Text("Активные приложения и процессы").font(.subheadline.weight(.medium))
                    Spacer()
                    Picker("Порядок", selection: $memory) { Text("CPU").tag(false); Text("Память").tag(true) }
                        .labelsHidden().pickerStyle(.segmented).frame(width: 150)
                }
                SmallLabel(text: "Срез в " + episode.id.formatted(date: .omitted, time: .standard) + " · топ-3 по CPU и памяти, только текущий пользователь")
                if apps.isEmpty { Text("Данные приложений в этом срезе недоступны.").foregroundStyle(.secondary) }
                ForEach(apps) { app in
                    HStack(spacing: 10) {
                        AppIcon(key: app.id)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(app.name).lineLimit(1)
                            Text("Процессов: \(app.processCount)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Text(Format.percent(app.cpu)).monospacedDigit().frame(width: 50, alignment: .trailing)
                        Text(Format.bytes(app.memoryBytes)).monospacedDigit().frame(width: 75, alignment: .trailing)
                        Button { store.openHistoricalProcess(app.representative) } label: { Image(systemName: "arrow.up.right.square") }
                            .disabled(!store.isLive(app.representative))
                            .help(store.isLive(app.representative) ? "Открыть текущие сведения о процессе" : "Сохранённый процесс уже завершён или перезапущен")
                            .accessibilityLabel("Открыть процесс «" + app.name + "» сейчас")
                    }.padding(.vertical, 4)
                }
                SmallLabel(text: "Это измерения в выбранный момент, а не доказательство причины торможения. Переход открывает текущий процесс, если он ещё существует.")
            } else {
                Label("Для этого момента нет подробностей приложений. Они записываются начиная с версии 0.3.0 примерно раз в 30 секунд.", systemImage: "info.circle")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
    }
}
struct AlertCardView: View {
    @ObservedObject var store: AppStore
    let event: AlertEvent
    private var hasRule: Bool { store.prefs.rules.contains { $0.id == event.ruleID } }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: "bell.badge").foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 5) {
                    Text(event.title).font(.headline)
                    Text(event.detail).font(.callout)
                    Text(event.date.formatted(date: .abbreviated, time: .standard)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            if let rule = event.ruleSnapshot {
                SmallLabel(text: "Условие при срабатывании: " + rule.metric.title + (rule.metric == .diskFreeGB ? " < " : " ≥ ") + rule.threshold.formatted() + " · " + Int(rule.duration).formatted() + " с")
            }
            ViewThatFits(in: .horizontal) {
                HStack { actions }
                VStack(alignment: .leading, spacing: 8) { actions }
            }
            if !hasRule { SmallLabel(text: "Правило удалено. Событие осталось в истории.") }
            if let process = event.process {
                SmallLabel(text: "В момент события: " + process.name + " · PID \(process.identity.pid)" + (store.isLive(process.identity) ? "" : " · уже завершён или перезапущен"))
            }
            if let context = event.context {
                EpisodeView(store: store, snapshot: context.snapshot, episode: context)
            } else {
                SmallLabel(text: "У этого события нет сохранённого среза приложений. Можно выбрать соседний момент на графике.")
            }
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }
    @ViewBuilder private var actions: some View {
        if let process = event.process {
            Button("Показать процесс") { store.openHistoricalProcess(process.identity) }.disabled(!store.isLive(process.identity))
        }
        Button("Изменить правило") { store.editRule(for: event) }.disabled(!hasRule)
        if let until = store.ruleMutedUntil(event.ruleID) {
            Button("Возобновить правило") { store.resumeRule(event.ruleID) }
            Text("Пауза до " + until.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(.secondary)
        } else {
            Button("Это правило — на паузу 1 час") { store.muteRule(event.ruleID) }.disabled(!hasRule)
        }
    }
}
