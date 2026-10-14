import SwiftUI
import ServiceManagement
import MacGlintCore

struct SettingsView: View {
    @ObservedObject var store: AppStore
    private enum Pane: String, CaseIterable { case general = "Основные", alerts = "Уведомления", about = "О приложении" }
    @State private var pane: Pane = .general
    @State private var editing: AlertRule?
    @State private var newRule = false
    @State private var clearConfirm = false
    @State private var exceptionSearch = ""
    @State private var showExceptions = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Picker("Раздел настроек", selection: $pane) {
                ForEach(Pane.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).labelsHidden().fixedSize(horizontal: true, vertical: false)
            ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if pane == .general {
                section("Оформление") {
                    HStack {
                        Text("Тема").frame(width: 130, alignment: .leading)
                        Picker("Тема", selection: $store.prefs.appearance) {
                            Text("Системная").tag(Appearance.system); Text("Светлая").tag(Appearance.light); Text("Тёмная").tag(Appearance.dark)
                        }.pickerStyle(.segmented).labelsHidden().fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 0)
                    }
                    HStack {
                        Text("В строке меню").frame(width: 130, alignment: .leading)
                        Toggle("CPU", isOn: $store.prefs.menuCPU)
                        Toggle("Память", isOn: $store.prefs.menuMemory)
                        Toggle("Сеть", isOn: $store.prefs.menuNetwork)
                        Spacer(minLength: 0)
                    }.toggleStyle(.checkbox)
                }
                section("Запуск и хранение") {
                    Toggle("Запускать при входе в macOS", isOn: Binding(get: { launchAtLogin }, set: { value in
                        do { if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
                        catch { store.error = error.localizedDescription }
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    })).toggleStyle(.checkbox)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("История нагрузки")
                            SmallLabel(text: "Хранится на этом Mac за последние 24 часа.")
                        }
                        Spacer()
                        Button("Очистить…") { clearConfirm = true }
                    }
                }
                }
                if pane == .alerts {
                section("Уведомления") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) { Text("Системные уведомления"); if store.notificationStatus != "Разрешены" { SmallLabel(text: store.notificationStatus) } }
                        Spacer()
                        if store.notificationStatus == "Разрешены" { Toggle("Системные уведомления", isOn: $store.prefs.notifications).labelsHidden().toggleStyle(.switch).controlSize(.small) }
                        else if store.notificationsDenied {
                            Button("Настройки macOS…") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") { NSWorkspace.shared.open(url) }
                            }
                        } else { Button("Разрешить…") { store.requestNotifications() } }
                    }
                    if let until = store.prefs.pauseUntil, until > Date() {
                        HStack { Text("Пауза до " + until.formatted(date: .omitted, time: .shortened)).foregroundStyle(.orange); Spacer(); Button("Возобновить") { store.resumeAlerts() } }
                    } else { Button("Не беспокоить 1 час") { store.pauseAlerts() } }
                    SmallLabel(text: "Без уведомлений события сохраняются в истории. Пауза временно отключает правила.")
                }
                section("Правила") {
                    VStack(spacing: 0) {
                    ForEach(store.prefs.rules) { rule in
                        HStack {
                            Toggle(rule.name, isOn: Binding(get: { rule.enabled }, set: { enabled in
                                if let i = store.prefs.rules.firstIndex(where: { $0.id == rule.id }) { store.prefs.rules[i].enabled = enabled; store.savePreferences() }
                            })).labelsHidden().toggleStyle(.switch).controlSize(.small)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(rule.name)
                                SmallLabel(text: "\(rule.metric.title) \(rule.metric == .diskFreeGB ? "<" : "≥") \(rule.threshold.formatted()) · \(Int(rule.duration)) с · " + (rule.appKey == nil ? "весь Mac" : "приложение"))
                            }
                            Spacer()
                            if let until = store.ruleMutedUntil(rule.id) {
                                Button("Пауза до " + until.formatted(date: .omitted, time: .shortened) + " · возобновить") { store.resumeRule(rule.id) }.font(.caption)
                            }
                            Button { editing = rule } label: { Image(systemName: "slider.horizontal.3") }
                                .buttonStyle(.borderless).help("Изменить правило").accessibilityLabel("Изменить правило «" + rule.name + "»")
                            Button { store.prefs.rules.removeAll { $0.id == rule.id }; store.savePreferences() } label: { Image(systemName: "trash") }.buttonStyle(.plain).help("Удалить правило").accessibilityLabel("Удалить правило «" + rule.name + "»")
                        }.padding(.vertical, 10)
                        Divider()
                    }
                    }
                    Button { newRule = true } label: { Label("Добавить правило", systemImage: "plus") }
                }
                section("Исключения") {
                    SmallLabel(text: "Не применять правила к выбранным приложениям. Правила для всего Mac остаются включены.")
                    DisclosureGroup("Приложения · \(store.prefs.excludedApps.count)", isExpanded: $showExceptions) {
                        TextField("Найти приложение", text: $exceptionSearch).textFieldStyle(.roundedBorder).padding(.top, 8)
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 10) {
                                ForEach(exceptionChoices, id: \.key) { app in
                                    Toggle(app.name, isOn: Binding(get: { store.prefs.excludedApps.contains(app.key) }, set: {
                                        if $0 { store.prefs.excludedApps.insert(app.key) } else { store.prefs.excludedApps.remove(app.key) }
                                        store.savePreferences()
                                    })).toggleStyle(.checkbox)
                                }
                                if exceptionChoices.isEmpty { Text("Приложения не найдены").foregroundStyle(.secondary) }
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                        }.frame(height: 180)
                    }
                    if !store.prefs.excludedApps.isEmpty { Button("Сбросить все исключения") { store.prefs.excludedApps = []; store.savePreferences() } }
                }
                }
                if pane == .about {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            Image(nsImage: NSApplication.shared.applicationIconImage).resizable().frame(width: 48, height: 48)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("MacGlint").font(.title3.weight(.semibold))
                                Text("Версия 0.4.0 · предварительная сборка").font(.callout).foregroundStyle(.secondary)
                            }
                        }
                        Text("Сделано для себя с помощью ИИ. Открытый проект для тех, кому нужен простой монитор Mac.")
                            .font(.callout).fixedSize(horizontal: false, vertical: true)
                        Link("Проект на GitHub ↗", destination: URL(string: "https://github.com/greenpandorik/macglint")!)
                        Divider()
                        Text("История и настройки остаются на вашем Mac.").font(.callout)
                        SmallLabel(text: "Сопоставление вкладок Safari и автоматическое обновление пока недоступны.")
                    }
                }
            }.frame(maxWidth: 560, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 20)
            }
        }.padding(.horizontal, 24)
        .onAppear { openRequestedRule() }
        .onChange(of: store.requestedRuleID) { _, _ in openRequestedRule() }
        .onChange(of: store.prefs.menuCPU) { _, _ in store.savePreferences() }
        .onChange(of: store.prefs.menuMemory) { _, _ in store.savePreferences() }
        .onChange(of: store.prefs.menuNetwork) { _, _ in store.savePreferences() }
        .onChange(of: store.prefs.notifications) { _, _ in store.savePreferences() }
        .sheet(item: $editing) { rule in RuleEditor(rule: rule, apps: store.appChoices) { updated in
            if let index = store.prefs.rules.firstIndex(where: { $0.id == updated.id }) { store.prefs.rules[index] = updated; store.savePreferences() }
        } }
        .sheet(isPresented: $newRule) { RuleEditor(rule: AlertRule(name: "Моё правило", metric: .cpu, threshold: 80), apps: store.appChoices) { store.prefs.rules.append($0); store.savePreferences() } }
        .confirmationDialog("Удалить историю нагрузки и событий?", isPresented: $clearConfirm) { Button("Очистить", role: .destructive) { store.clearHistory() } }
    }
    private func openRequestedRule() {
        guard let id = store.requestedRuleID else { return }
        pane = .alerts
        editing = store.prefs.rules.first { $0.id == id }
        store.requestedRuleID = nil
    }
    private var exceptionChoices: [(key: String, name: String)] {
        var choices = Dictionary(uniqueKeysWithValues: store.appChoices.map { ($0.key, $0.name) })
        for key in store.prefs.excludedApps where choices[key] == nil {
            choices[key] = URL(fileURLWithPath: key).deletingPathExtension().lastPathComponent + " (не запущено)"
        }
        return choices.map { (key: $0.key, name: $0.value) }
            .filter { exceptionSearch.isEmpty || $0.name.localizedCaseInsensitiveContains(exceptionSearch) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) { Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary); content() }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct RuleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: RuleDraft
    let apps: [(key: String, name: String)]
    var save: (AlertRule) -> Void
    init(rule: AlertRule, apps: [(key: String, name: String)], save: @escaping (AlertRule) -> Void) {
        _draft = State(initialValue: RuleDraft(rule: rule)); self.apps = apps; self.save = save
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Правило уведомления").font(.title2.weight(.semibold))
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Название") { TextField("Название", text: $draft.rule.name).labelsHidden().frame(width: 230) }
                Picker("Для кого", selection: Binding(get: { draft.rule.appKey ?? "" }, set: { draft.setAppKey($0.isEmpty ? nil : $0) })) {
                    Text("Весь Mac").tag("")
                    ForEach(apps, id: \.key) { Text($0.name).tag($0.key) }
                    if let key = draft.rule.appKey, !apps.contains(where: { $0.key == key }) { Text("Сохранённое приложение").tag(key) }
                }
                Picker("Показатель", selection: $draft.rule.metric) { ForEach(draft.availableMetrics, id: \.self) { Text($0.title).tag($0) } }
                LabeledContent(draft.rule.metric == .diskFreeGB ? "Меньше чем" : "Не меньше чем") { TextField("Порог", text: $draft.threshold).labelsHidden().frame(width: 150) }
                LabeledContent("Длительность, с") { TextField("Длительность, с", text: $draft.duration).labelsHidden().frame(width: 150) }
                LabeledContent("Повтор не чаще, с") { TextField("Повтор не чаще, с", text: $draft.cooldown).labelsHidden().frame(width: 150) }
            }.textFieldStyle(.roundedBorder).frame(maxWidth: .infinity)
            Text("Уведомить, если порог держится указанное время. CPU — доля мощности всего Mac. Давление: 1 — повышенное, 2 — критическое. Память и диск — в ГБ.")
                .font(.caption).foregroundStyle(.secondary)
            if let message = draft.validationMessage {
                Label(message, systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button("Отмена") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Сохранить") { if let rule = draft.build() { save(rule); dismiss() } }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(draft.build() == nil)
            }
        }.padding(24).frame(width: 460)
    }
}
