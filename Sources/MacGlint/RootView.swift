import SwiftUI
import MacGlintCore

struct RootView: View {
    @ObservedObject var store: AppStore
    let compact: Bool
    var body: some View {
        Group {
            if compact { miniContent }
            else { fullContent }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: compact ? 14 : 0))
        .preferredColorScheme(store.theme)
        .tint(.blue)
        .onChange(of: store.prefs.appearance) { _, _ in if !compact { store.savePreferences() } }
        .alert("Не удалось выполнить действие", isPresented: Binding(get: { !compact && store.error != nil }, set: { if !$0 && !compact { store.error = nil } })) {
            Button("Понятно") { store.error = nil }
        } message: { Text(store.error ?? "") }
    }
    private var miniContent: some View {
        VStack(spacing: 0) {
            HStack {
                Label("MacGlint", systemImage: "waveform.path").font(.system(size: 17, weight: .semibold))
                Spacer()
                Button { store.expand(.settings) } label: { Image(systemName: "gearshape") }
                    .help("Открыть настройки").accessibilityLabel("Открыть настройки")
                Button { store.onCloseMini?() } label: { Image(systemName: "xmark") }
                    .help("Закрыть мини-панель · Esc").accessibilityLabel("Закрыть мини-панель")
            }.buttonStyle(.plain).padding(.horizontal, 20).padding(.top, 18)
            HStack {
                Circle().fill(store.stateColor).frame(width: 6, height: 6)
                Text(store.stateText).font(.callout)
                Spacer()
            }.padding(.horizontal, 20).padding(.top, 9).padding(.bottom, 14)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Button { store.search = ""; store.expand() } label: {
                        HStack {
                            MetricTile(icon: "cpu", title: "Процессор", value: Format.percent(store.snapshot.cpu), subtitle: "Мощность всего Mac")
                            Sparkline(values: store.recent.suffix(24).compactMap(\.cpu)).frame(width: 95, height: 35)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 14)
                    }.buttonStyle(.plain)
                    Divider()
                    Button { store.search = ""; store.expand(memory: true) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("Память", systemImage: "memorychip").font(.callout).foregroundStyle(.secondary)
                                Spacer()
                                Text(Format.bytes(store.snapshot.memoryUsed)).font(.headline).monospacedDigit()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                            ProgressView(value: min(1, Double(store.snapshot.memoryUsed ?? 0) / max(1, Double(store.snapshot.memoryTotal))))
                                .tint((store.snapshot.pressure ?? 0) > 0 ? .orange : .blue)
                                .accessibilityHidden(true)
                            Text(store.pressureText + " · из " + Format.bytes(store.snapshot.memoryTotal)).font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 14)
                    }.buttonStyle(.plain)
                    Divider()
                    HStack(alignment: .top) {
                        MetricTile(icon: "network", title: "Сеть", value: "↓ " + Format.rate(store.snapshot.download), subtitle: "↑ " + Format.rate(store.snapshot.upload))
                        MetricTile(icon: "battery.75percent", title: "Батарея", value: Format.percent(store.snapshot.battery), subtitle: store.snapshot.charging ? "От сети" : "От аккумулятора")
                    }.padding(.vertical, 14)
                    Divider()
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Больше всего CPU").font(.caption).foregroundStyle(.secondary)
                        if let top = store.topCPUGroup {
                            Button {
                                store.search = ""; store.onlyMine = true; store.expand()
                                if let p = top.processes.first { store.choose(p); store.expandedGroups.insert(top.id) }
                            } label: {
                                HStack { AppIcon(key: top.id); Text(top.name).lineLimit(1); Spacer(); Text(Format.percent(top.cpu)).monospacedDigit(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary) }
                            }.buttonStyle(.plain)
                        } else { Text("Собираем данные процессов…").font(.callout).foregroundStyle(.secondary) }
                    }.padding(.vertical, 13)
                    Label("Свободно " + Format.bytes(store.snapshot.diskFree), systemImage: "internaldrive").font(.caption).foregroundStyle(.secondary).padding(.bottom, 12)
                }.padding(.horizontal, 20)
            }
            Divider()
            HStack {
                Button { store.expand() } label: { Label("Открыть полное окно", systemImage: "arrow.up.right.square") }
                    .buttonStyle(.borderedProminent).controlSize(.regular)
                Spacer()
                Menu {
                    Button("История нагрузки") { store.expand(.history) }
                    Button("Настройки…") { store.expand(.settings) }
                    Divider()
                    Button("Завершить MacGlint") { NSApplication.shared.terminate(nil) }
                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 24).help("Действия MacGlint")
            }.padding(16)
        }
    }
    private var fullContent: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Label("MacGlint", systemImage: "waveform.path").font(.system(size: 19, weight: .semibold)).padding(.vertical, 18).padding(.horizontal, 12)
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Button { store.tab = tab } label: {
                        Label(tab.rawValue, systemImage: icon(tab))
                            .font(.system(size: 13, weight: store.tab == tab ? .semibold : .regular))
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.vertical, 10)
                            .background(store.tab == tab ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain).accessibilityAddTraits(store.tab == tab ? .isSelected : [])
                }
                Spacer()
                Text("Мониторинг продолжается\nпосле закрытия окна.").font(.caption).foregroundStyle(.secondary).padding(12)
                Button { store.onOpenMini?() } label: { Label("Мини-панель", systemImage: "menubar.rectangle") }.padding(12)
            }.padding(.horizontal, 10).padding(.bottom, 8).frame(width: 174)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(store.tab.rawValue).font(.system(size: 24, weight: .semibold))
                        Label(store.stateText, systemImage: "circle.fill").font(.caption).foregroundStyle(store.stateColor)
                    }
                    Spacer()
                    Toggle(isOn: Binding(get: { store.pinned }, set: { _ in store.togglePin() })) {
                        Label("Поверх окон", systemImage: "pin")
                    }.toggleStyle(.button).help("Оставлять полное окно поверх других приложений")
                }.padding(24)
                if store.tab != .settings {
                    HStack(alignment: .top, spacing: 18) {
                        MetricTile(icon: "cpu", title: "Процессор", value: Format.percent(store.snapshot.cpu), subtitle: "Весь Mac")
                        MetricTile(icon: "memorychip", title: "Память", value: Format.bytes(store.snapshot.memoryUsed), subtitle: "из " + Format.bytes(store.snapshot.memoryTotal))
                        MetricTile(icon: "network", title: "Сеть ↓", value: Format.rate(store.snapshot.download), subtitle: "↑ " + Format.rate(store.snapshot.upload))
                        MetricTile(icon: "internaldrive", title: "Свободно", value: Format.bytes(store.snapshot.diskFree), subtitle: "На системном диске")
                    }.padding(.horizontal, 24).padding(.bottom, 22)
                }
                Group {
                    switch store.tab {
                    case .processes: ProcessView(store: store)
                    case .history: HistoryView(store: store)
                    case .settings: SettingsView(store: store)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                if let notice = store.notice {
                    HStack {
                        Text(notice).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button { store.notice = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("Скрыть сообщение")
                    }.padding(.horizontal, 24).padding(.vertical, 8)
                }
                Divider()
                HStack {
                    Circle().fill(store.stateColor).frame(width: 5, height: 5)
                    Text(store.processes.isEmpty ? "Подключаемся к macOS…" : "Обновлено " + store.snapshot.date.formatted(date: .omitted, time: .standard))
                    Spacer()
                    Text("Данные остаются на Mac")
                }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 24).padding(.vertical, 10)
            }
        }
    }
    private func icon(_ tab: DetailTab) -> String {
        switch tab { case .processes: return "list.bullet.rectangle"; case .history: return "chart.xyaxis.line"; case .settings: return "gearshape" }
    }
}
