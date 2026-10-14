import SwiftUI
import MacGlintCore

struct RootView: View {
    @ObservedObject var store: AppStore
    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 18)
            if store.expanded {
                HStack(alignment: .top, spacing: 25) {
                    MetricTile(icon: "cpu", title: "Процессор", value: Format.percent(store.snapshot.cpu), subtitle: "Весь Mac")
                    MetricTile(icon: "memorychip", title: "Память", value: Format.bytes(store.snapshot.memoryUsed), subtitle: "из \(Format.bytes(store.snapshot.memoryTotal))")
                    MetricTile(icon: "network", title: "Сеть ↓", value: Format.rate(store.snapshot.download), subtitle: "↑ " + Format.rate(store.snapshot.upload))
                    MetricTile(icon: "battery.75percent", title: "Батарея", value: Format.percent(store.snapshot.battery), subtitle: store.snapshot.charging ? "От сети" : "От аккумулятора")
                }.padding(20).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14)).padding(.horizontal, 24)
                Picker("Раздел", selection: $store.tab) {
                    ForEach(DetailTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).padding(.horizontal, 24).padding(.vertical, 16)
                Group {
                    switch store.tab {
                    case .processes: ProcessView(store: store)
                    case .history: HistoryView(store: store)
                    case .settings: SettingsView(store: store)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else { compact }
            if let notice = store.notice {
                HStack { Text(notice).font(.caption).foregroundStyle(.secondary).lineLimit(2); Spacer(); Button { store.notice = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain) }
                    .padding(.horizontal, 24).padding(.vertical, 8)
            }
            Divider().padding(.horizontal, 24)
            HStack {
                Button(store.expanded ? "Свернуть" : "Подробнее") { store.expanded ? store.collapse() : store.expand() }.buttonStyle(.plain).foregroundStyle(.blue)
                Spacer()
                Circle().fill(store.stateColor).frame(width: 5, height: 5)
                Text(store.processes.isEmpty ? "Подключаемся к macOS" : "Обновлено " + store.snapshot.date.formatted(date: .omitted, time: .standard)).font(.system(size: 10)).foregroundStyle(.secondary)
                Menu { Button("Завершить MacGlint") { NSApplication.shared.terminate(nil) } } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 20)
            }.padding(.horizontal, 24).padding(.vertical, 16)
        }
        .frame(width: store.expanded ? 800 : 410, height: store.expanded ? 740 : 650)
        .background(.regularMaterial)
        .preferredColorScheme(store.theme)
        .tint(.blue)
        .onChange(of: store.prefs.appearance) { _, _ in store.savePreferences() }
        .alert("Не удалось выполнить действие", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
            Button("Понятно") { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path").foregroundStyle(.blue).font(.system(size: 19, weight: .medium))
                    Text("MacGlint").font(.system(size: 25, weight: .semibold))
                }
                Label(store.stateText, systemImage: "circle.fill").font(.system(size: 11, weight: .medium)).foregroundStyle(store.stateColor)
            }
            Spacer()
            Button { store.togglePin() } label: { Image(systemName: store.pinned ? "pin.fill" : "pin") }.help(store.pinned ? "Открепить окно" : "Закрепить окно").accessibilityLabel(store.pinned ? "Открепить окно" : "Закрепить окно").foregroundStyle(store.pinned ? .blue : .secondary)
            Button { store.expand(.settings) } label: { Image(systemName: "gearshape") }.help("Настройки").accessibilityLabel("Настройки")
        }.buttonStyle(.plain).font(.system(size: 16))
    }
    private var compact: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { store.expand() } label: {
                HStack {
                    MetricTile(icon: "cpu", title: "Процессор", value: Format.percent(store.snapshot.cpu), subtitle: "Доля общей мощности Mac")
                    Sparkline(values: store.recent.suffix(24).compactMap(\.cpu)).frame(width: 130, height: 35)
                }.padding(.vertical, 19)
            }.buttonStyle(.plain)
            Divider()
            Button { store.expand(memory: true) } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack { MetricTile(icon: "memorychip", title: "Память", value: Format.bytes(store.snapshot.memoryUsed)); Spacer(); Text("из " + Format.bytes(store.snapshot.memoryTotal)).foregroundStyle(.secondary) }
                    ProgressView(value: min(1, Double(store.snapshot.memoryUsed ?? 0) / max(1, Double(store.snapshot.memoryTotal)))).tint((store.snapshot.pressure ?? 0) > 0 ? .orange : .blue)
                    SmallLabel(text: store.pressureText)
                }.padding(.vertical, 19)
            }.buttonStyle(.plain)
            Divider()
            HStack { MetricTile(icon: "network", title: "Сеть", value: "↓ " + Format.rate(store.snapshot.download), subtitle: "↑ " + Format.rate(store.snapshot.upload)); MetricTile(icon: "battery.75percent", title: "Батарея", value: Format.percent(store.snapshot.battery), subtitle: store.snapshot.charging ? "От сети" : "От аккумулятора") }.padding(.vertical, 19)
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                SmallLabel(text: "БОЛЬШЕ ВСЕГО CPU")
                if let top = store.topCPUGroup {
                    Button { store.search = ""; store.onlyMine = true; store.expand(); if let p = top.processes.first { store.choose(p); store.expandedGroups.insert(top.id) } } label: {
                        HStack { AppIcon(key: top.id); Text(top.name).lineLimit(1); Spacer(); Text(Format.percent(top.cpu)).monospacedDigit(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }
                    }.buttonStyle(.plain)
                } else { SmallLabel(text: "Ожидаем первый снимок процессов…") }
            }.padding(.vertical, 17)
            HStack { Image(systemName: "internaldrive"); Text("Свободно " + Format.bytes(store.snapshot.diskFree)); Spacer() }.font(.system(size: 11)).foregroundStyle(.secondary).padding(.bottom, 15)
            Spacer(minLength: 0)
        }.padding(.horizontal, 24)
    }
}
