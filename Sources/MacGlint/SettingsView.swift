import SwiftUI
import ServiceManagement
import MacGlintCore

struct SettingsView: View {
    @ObservedObject var store: AppStore
    @State private var editing: AlertRule?
    @State private var newRule = false
    @State private var clearConfirm = false
    @State private var exceptionSearch = ""
    @State private var showExceptions = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                section("Оформление") {
                    Picker("Тема", selection: $store.prefs.appearance) {
                        Text("Как в macOS").tag(Appearance.system); Text("Светлая").tag(Appearance.light); Text("Тёмная").tag(Appearance.dark)
                    }.pickerStyle(.segmented)
                    HStack { Text("В строке меню").font(.callout); Spacer(); Toggle("CPU", isOn: $store.prefs.menuCPU); Toggle("Память", isOn: $store.prefs.menuMemory); Toggle("Сеть", isOn: $store.prefs.menuNetwork) }.toggleStyle(.checkbox)
                }
                section("Уведомления") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) { Text("Системные уведомления"); SmallLabel(text: store.notificationStatus) }
                        Spacer()
                        if store.notificationStatus == "Разрешены" { Toggle("Показывать", isOn: $store.prefs.notifications).toggleStyle(.switch) }
                        else if store.notificationsDenied {
                            Button("Настройки macOS…") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") { NSWorkspace.shared.open(url) }
                            }
                        } else { Button("Разрешить…") { store.requestNotifications() } }
                    }
                    if let until = store.prefs.pauseUntil, until > Date() {
                        HStack { Text("Пауза до " + until.formatted(date: .omitted, time: .shortened)).foregroundStyle(.orange); Spacer(); Button("Возобновить") { store.resumeAlerts() } }
                    } else { Button("Не беспокоить 1 час") { store.pauseAlerts() } }
                    SmallLabel(text: "События записываются локально даже без разрешения на системные уведомления. Во время паузы правила не срабатывают.")
                }
                section("Личные правила") {
                    ForEach(store.prefs.rules) { rule in
                        HStack {
                            Toggle(rule.name, isOn: Binding(get: { rule.enabled }, set: { enabled in
                                if let i = store.prefs.rules.firstIndex(where: { $0.id == rule.id }) { store.prefs.rules[i].enabled = enabled; store.savePreferences() }
                            })).labelsHidden().toggleStyle(.switch).controlSize(.small)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(rule.name).fontWeight(.medium)
                                SmallLabel(text: "\(rule.metric.title) \(rule.metric == .diskFreeGB ? "<" : "≥") \(rule.threshold.formatted()) · \(Int(rule.duration)) с · " + (rule.appKey == nil ? "весь Mac" : "приложение"))
                            }
                            Spacer()
                            if let until = store.ruleMutedUntil(rule.id) {
                                Button("Пауза до " + until.formatted(date: .omitted, time: .shortened) + " · возобновить") { store.resumeRule(rule.id) }.font(.caption)
                            }
                            Button("Изменить") { editing = rule }
                            Button { store.prefs.rules.removeAll { $0.id == rule.id }; store.savePreferences() } label: { Image(systemName: "trash") }.buttonStyle(.plain).help("Удалить правило").accessibilityLabel("Удалить правило «" + rule.name + "»")
                        }.padding(.vertical, 3)
                    }
                    Button { newRule = true } label: { Label("Добавить правило", systemImage: "plus") }
                }
                section("Исключения приложений") {
                    SmallLabel(text: "Исключение отключает личные правила для приложения. Общие правила Mac продолжают работать.")
                    DisclosureGroup("Выбрать приложения · исключено \(store.prefs.excludedApps.count)", isExpanded: $showExceptions) {
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
                section("Приложение и данные") {
                    Toggle("Запускать при входе в macOS", isOn: Binding(get: { launchAtLogin }, set: { value in
                        do { if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
                        catch { store.error = error.localizedDescription }
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }))
                    Button("Очистить историю…") { clearConfirm = true }
                    SmallLabel(text: "MacGlint 0.3.0 · локальная предварительная сборка\nСоздано для себя с помощью ИИ. История и настройки хранятся на Mac.\nИнтеграция с вкладками Safari и автоматическое обновление пока не реализованы.")
                    Link("Проект на GitHub", destination: URL(string: "https://github.com/greenpandorik/macglint")!)
                }
            }.padding(.horizontal, 24).padding(.bottom, 20)
        }
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
        VStack(alignment: .leading, spacing: 12) { Text(title).font(.system(size: 14, weight: .semibold)); content() }.frame(maxWidth: .infinity, alignment: .leading)
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
