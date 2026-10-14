import SwiftUI
import AppKit
import UserNotifications
import MacGlintCore
import MacGlintSystem

struct CPUPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}
enum DetailTab: String, CaseIterable { case processes = "Процессы", history = "История", settings = "Настройки" }
@MainActor final class AppStore: ObservableObject {
    @Published var snapshot = MetricSnapshot()
    @Published var processes: [ProcessSample] = []
    @Published var recent: [MetricSnapshot] = []
    @Published var events: [AlertEvent] = []
    @Published var prefs = Preferences.load(from: .standard)
    @Published var pinned = false
    @Published var tab: DetailTab = .processes
    @Published var search = ""
    @Published var sortMemory = false
    @Published var onlyMine = true
    @Published var selected: ProcessSample?
    @Published var expandedGroups: Set<String> = []
    @Published var error: String?
    @Published var notice: String?
    @Published var notificationStatus = "Не запрошены"
    @Published var notificationsDenied = false
    @Published var focusedEvent: AlertEvent?
    var onPinChange: (() -> Void)?
    var onOpenFull: (() -> Void)?
    var onOpenMini: (() -> Void)?
    var onCloseMini: (() -> Void)?
    var canNavigate: (() -> Bool)?
    var onMenuUpdate: (() -> Void)?
    var panelVisible = false
    private let sampler = SamplingService()
    private let engine = AlertEngine()
    private let history: HistoryStore
    private var timer: Timer?
    private var sampling = false
    private var generation = 0
    private var lastSample = Date.distantPast
    private var lastHistory = Date.distantPast
    private var lastSave = Date.distantPast
    private var traces: [ProcessIdentity: [CPUPoint]] = [:]

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MacGlint")
        history = HistoryStore(url: support.appendingPathComponent("history.json"))
        recent = history.snapshots; events = history.events
        notice = history.loadWarning
    }
    func start() {
        refreshNotificationStatus()
        tick(force: true)
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }
    func stop() { timer?.invalidate(); try? history.save() }
    func tick(force: Bool = false) {
        guard !sampling, force || panelVisible || Date().timeIntervalSince(lastSample) >= 5 else { return }
        sampling = true
        let ticket = generation
        Task { [self] in
            let reading = await sampler.sample()
            guard ticket == generation else { return }
            apply(reading)
        }
    }
    func handleWake() {
        generation += 1; sampling = true
        engine.resetPending(); traces = [:]
        Task {
            await sampler.reset()
            sampling = false
            tick(force: true)
        }
    }
    var topCPUGroup: ProcessGroup? {
        ProcessGrouping.groups(processes.filter { $0.identity.uid == geteuid() })
            .filter { $0.cpu != nil }.max { ($0.cpu ?? 0) < ($1.cpu ?? 0) }
    }
    private func apply(_ reading: SystemReading) {
        sampling = false; lastSample = Date()
        snapshot = reading.snapshot; processes = reading.processes
        let now = snapshot.date
        let alive = Set(processes.map(\.identity))
        traces = traces.filter { alive.contains($0.key) }
        for process in processes {
            guard let cpu = process.cpu else { continue }
            var points = traces[process.identity] ?? []
            points.append(CPUPoint(date: now, value: cpu))
            points.removeAll { now.timeIntervalSince($0.date) > 120 }
            traces[process.identity] = points
        }
        if let selected, let live = processes.first(where: { $0.identity == selected.identity }) { self.selected = live }
        let paused = prefs.pauseUntil.map { $0 > now } ?? false
        let fired = engine.evaluate(snapshot: snapshot, processes: processes, rules: prefs.rules,
            excludedApps: prefs.excludedApps, paused: paused, uptime: ProcessInfo.processInfo.systemUptime)
        history.addEvents(fired)
        if now.timeIntervalSince(lastHistory) >= 10 {
            history.append(snapshot); recent = history.snapshots; lastHistory = now
        }
        if !fired.isEmpty { events = history.events; fired.forEach(deliver) }
        if now.timeIntervalSince(lastSave) >= 60 || !fired.isEmpty {
            do { try history.save(); lastSave = now } catch { notice = "Не удалось сохранить историю: \(error.localizedDescription)" }
            events = history.events
        }
        onMenuUpdate?()
    }
    var groups: [ProcessGroup] {
        let input = processes.filter { !onlyMine || $0.identity.uid == geteuid() }
        return ProcessGrouping.groups(input, sortByMemory: sortMemory).filter { group in
            search.isEmpty || group.name.localizedCaseInsensitiveContains(search) || group.processes.contains {
                $0.name.localizedCaseInsensitiveContains(search) || String($0.identity.pid).contains(search)
            }
        }.sorted {
            let a = sortMemory ? Double($0.memoryBytes ?? 0) : ($0.cpu ?? -1)
            let b = sortMemory ? Double($1.memoryBytes ?? 0) : ($1.cpu ?? -1)
            return a == b ? $0.id < $1.id : a > b
        }
    }
    var appChoices: [(key: String, name: String)] {
        ProcessGrouping.groups(processes.filter { $0.identity.uid == geteuid() })
            .filter { $0.id.hasSuffix(".app") }
            .sorted { $0.name < $1.name }.map { ($0.id, $0.name) }
    }
    var pressureText: String {
        switch snapshot.pressure { case 0: return "Памяти достаточно"; case 1: return "Память под нагрузкой"; case 2: return "Памяти не хватает"; default: return "Давление на память недоступно" }
    }
    var stateText: String {
        if (snapshot.pressure ?? 0) > 0 { return pressureText }
        guard let cpu = snapshot.cpu else { return "Собираем показатели…" }
        return cpu >= 85 ? "Высокая нагрузка" : cpu >= 50 ? "Mac занят работой" : "Нагрузка невысокая"
    }
    var stateColor: Color { (snapshot.pressure ?? 0) > 0 || (snapshot.cpu ?? 0) >= 85 ? .orange : .green }
    var theme: ColorScheme? { prefs.appearance == .system ? nil : prefs.appearance == .dark ? .dark : .light }
    var menuTitle: String {
        var parts: [String] = []
        if prefs.menuCPU { parts.append(Format.percent(snapshot.cpu)) }
        if prefs.menuMemory { parts.append(Format.bytes(snapshot.memoryUsed)) }
        if prefs.menuNetwork { parts.append("↓ " + Format.rate(snapshot.download)) }
        return parts.joined(separator: "  ")
    }
    func savePreferences() { prefs.save(to: .standard); onMenuUpdate?() }
    func expand(_ tab: DetailTab = .processes, memory: Bool = false) {
        guard canNavigate?() != false else { onOpenFull?(); return }
        self.tab = tab; sortMemory = memory; onOpenFull?()
    }
    func togglePin() { pinned.toggle(); onPinChange?() }
    func choose(_ process: ProcessSample) { selected = process }
    var selectedIsLive: Bool { selected.map { s in processes.contains { $0.identity == s.identity } } ?? false }
    var mayTerminate: Bool {
        guard let p = selected else { return false }
        return selectedIsLive && p.identity.uid == geteuid() && p.identity.pid > 1 && p.identity.pid != getpid()
    }
    func selectedTrace() -> [CPUPoint] { selected.flatMap { traces[$0.identity] } ?? [] }
    func terminateSelected(force: Bool) {
        guard let process = selected, mayTerminate else { return }
        let alert = NSAlert()
        alert.messageText = force ? "Принудительно завершить «\(process.name)»?" : "Завершить «\(process.name)»?"
        alert.informativeText = "PID \(process.identity.pid). " + (force ? "Несохранённые данные могут быть потеряны. Связанные страницы и приложения могут перестать работать." : "Будет отправлен запрос завершения. Для отдельного процесса сохранение данных не гарантируется.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Отмена"); alert.addButton(withTitle: force ? "Завершить принудительно" : "Завершить")
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        do {
            guard ProcessController.identity(for: process.identity.pid) == process.identity else { throw ProcessControlError.unavailable }
            if !force, let app = NSRunningApplication(processIdentifier: process.identity.pid) {
                guard app.terminate() else { throw ProcessControlError.refused(EPERM) }
            } else { try ProcessController.terminate(identity: process.identity, force: force) }
            notice = "Запрос завершения отправлен: \(process.name)"
            tick(force: true)
        } catch { self.error = error.localizedDescription }
    }
    func clearHistory() {
        do { try history.clear(); recent = []; events = []; focusedEvent = nil } catch { self.error = error.localizedDescription }
    }
    func pauseAlerts() { prefs.pauseUntil = Date().addingTimeInterval(3600); savePreferences() }
    func resumeAlerts() { prefs.pauseUntil = nil; savePreferences() }
    func showEvent(_ event: AlertEvent) {
        focusedEvent = event; expand(.history)
    }
    func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            Task { @MainActor in
                self?.prefs.notifications = granted; self?.savePreferences(); self?.refreshNotificationStatus()
                if let error { self?.error = error.localizedDescription }
            }
        }
    }
    func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.notificationsDenied = settings.authorizationStatus == .denied
                switch settings.authorizationStatus {
                case .authorized, .provisional: self?.notificationStatus = "Разрешены"
                case .denied: self?.notificationStatus = "Запрещены в настройках macOS"
                default: self?.notificationStatus = "Не запрошены"
                }
            }
        }
    }
    private func deliver(_ event: AlertEvent) {
        guard prefs.notifications else { return }
        let content = UNMutableNotificationContent(); content.title = event.title; content.body = event.detail
        content.userInfo = ["eventID": event.id.uuidString]
        let request = UNNotificationRequest(identifier: event.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error { Task { @MainActor in self?.notice = "Уведомление не доставлено: \(error.localizedDescription)" } }
        }
    }
}
