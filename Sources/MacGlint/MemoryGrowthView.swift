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
            Text("Изменение за последние 10 минут. Рост не обязательно означает утечку.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            TextField("Найти приложение или группу", text: $search).textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if growth.isEmpty {
                        QuietEmptyState(
                            title: search.isEmpty ? (!store.growthHasComparison ? "Собираем данные" : "Заметного роста нет") : "Ничего не найдено",
                            message: search.isEmpty ? "Сравнение доступно после минуты непрерывных измерений. После сна или перезапуска отсчёт начинается заново." : "Попробуйте другое название приложения.")
                    }
                    ForEach(growth) { item in
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 12) {
                                AppIcon(key: item.id)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                                    Text((Double(item.before) / 1e6).formatted(.number.precision(.fractionLength(0))) + " МБ → " + (Double(item.after) / 1e6).formatted(.number.precision(.fractionLength(0))) + " МБ")
                                        .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                                    if item.compositionChanged {
                                        Text("Состав процессов менялся").font(.caption).foregroundStyle(.secondary)
                                            .help("Часть роста может быть связана с появлением новых процессов.")
                                    }
                                }
                                Spacer(minLength: 8)
                                VStack(alignment: .trailing, spacing: 5) {
                                    Text("+" + Format.bytes(item.increase)).font(.system(size: 14, weight: .medium)).monospacedDigit()
                                    Text("за " + String(format: "%.1f", item.elapsed / 60) + " мин").font(.caption).foregroundStyle(.secondary)
                                }
                                .help(item.since.formatted(date: .omitted, time: .standard) + " — " + item.until.formatted(date: .omitted, time: .standard))
                                Button { store.openHistoricalProcess(item.process) } label: { Image(systemName: "arrow.up.right.square") }
                                    .buttonStyle(.borderless).disabled(!store.isLive(item.process))
                                    .help("Открыть текущий процесс").accessibilityLabel("Показать процесс «" + item.name + "»")
                            }.padding(.vertical, 12).padding(.horizontal, 4)
                            Divider()
                        }
                    }
                }
            }
            SmallLabel(text: "От 1 МБ · только текущий сеанс")
        }.padding(.horizontal, 24).padding(.bottom, 14)
    }
}
