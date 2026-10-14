import SwiftUI
import MacGlintCore

struct MemoryGrowthView: View {
    @ObservedObject var store: AppStore
    @State private var search = ""
    private var growth: [MemoryGrowth] {
        store.memoryGrowth.filter { $0.increase >= 1_000_000 && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Что изменилось за последние 10 минут").font(.headline)
            Text("Сравниваем память приложений и групп процессов текущего пользователя. Рост сам по себе не означает утечку памяти.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            TextField("Найти приложение или группу", text: $search).textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if growth.isEmpty {
                        ContentUnavailableView(search.isEmpty ? (!store.growthHasComparison ? "Собираем сравнение" : "Рост пока не обнаружен") : "Ничего не найдено",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text("Для сравнения нужна минимум минута непрерывных измерений. После сна, перезапуска или пропуска данных отсчёт начинается заново."))
                    }
                    ForEach(growth) { item in
                        VStack(alignment: .leading, spacing: 9) {
                            HStack(spacing: 10) {
                                AppIcon(key: item.id)
                                Text(item.name).font(.headline).lineLimit(1)
                                Spacer()
                                Text("+" + Format.bytes(item.increase)).font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(.orange)
                            }
                            HStack {
                                Text((Double(item.before) / 1e6).formatted(.number.precision(.fractionLength(0))) + " МБ → " + (Double(item.after) / 1e6).formatted(.number.precision(.fractionLength(0))) + " МБ").monospacedDigit()
                                Spacer()
                                Text("за " + String(format: "%.1f", item.elapsed / 60) + " мин").foregroundStyle(.secondary)
                            }.font(.callout)
                            HStack {
                                Text(item.since.formatted(date: .omitted, time: .standard) + " — " + item.until.formatted(date: .omitted, time: .standard)).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Button("Показать процесс") { store.openHistoricalProcess(item.process) }.disabled(!store.isLive(item.process))
                            }
                            if item.compositionChanged {
                                Label("Состав процессов менялся — часть роста может быть связана с новыми процессами.", systemImage: "info.circle")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(14).background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            SmallLabel(text: "Изменения от 1 МБ · обновляется с измерениями · сравнение только в текущем сеансе")
        }.padding(.horizontal, 24).padding(.bottom, 14)
    }
}
