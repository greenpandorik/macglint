import AppKit
import SwiftUI
import UserNotifications
import MacGlintCore

@main enum MacGlintMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}
final class GlintPanel: NSPanel {
    var dismiss: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { dismiss?() }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var mini: GlintPanel!
    private var full: NSWindow!
    private var store: AppStore!
    private var notificationDelegate: NotificationDelegate!
    private var outsideMonitor: Any?
    private var localMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        store = AppStore()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "MacGlint"
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform.path", accessibilityDescription: "MacGlint")
            button.image?.isTemplate = true
            button.imagePosition = .imageLeading
            button.toolTip = "MacGlint — открыть мини-панель"
            button.setAccessibilityLabel("MacGlint — мини-панель")
            button.target = self; button.action = #selector(toggle)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        mini = GlintPanel(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        mini.title = "MacGlint — мини-панель"
        mini.isOpaque = false; mini.backgroundColor = .clear; mini.hasShadow = true
        mini.isReleasedWhenClosed = false; mini.hidesOnDeactivate = false
        mini.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        mini.contentView = NSHostingView(rootView: RootView(store: store, compact: true))
        mini.delegate = self; mini.dismiss = { [weak self] in self?.hideMini() }

        full = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 700), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        full.title = "MacGlint"; full.isReleasedWhenClosed = false
        full.contentMinSize = NSSize(width: 800, height: 560)
        full.contentView = NSHostingView(rootView: RootView(store: store, compact: false))
        full.delegate = self
        full.center(); full.setFrameAutosaveName("MacGlintDetails")

        store.onOpenFull = { [weak self] in self?.showFull() }
        store.onOpenMini = { [weak self] in self?.showMini() }
        store.onCloseMini = { [weak self] in self?.hideMini() }
        store.canNavigate = { [weak self] in self?.full.attachedSheet == nil }
        store.onPinChange = { [weak self] in self?.full.level = self?.store.pinned == true ? .floating : .normal }
        store.onMenuUpdate = { [weak self] in
            guard let self else { return }
            let title = self.store.menuTitle
            self.statusItem.button?.title = title.isEmpty ? "" : " " + title
        }
        notificationDelegate = NotificationDelegate { [weak self] id in
            guard let self, let event = self.store.events.first(where: { $0.id.uuidString == id }) else { return }
            self.store.showEvent(event)
        }
        UNUserNotificationCenter.current().delegate = notificationDelegate
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(woke), name: NSWorkspace.didWakeNotification, object: nil)
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.hideMini() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self, event.window !== self.mini, event.window !== self.statusItem.button?.window { self.hideMini() }
            return event
        }
        store.start(); showMini()
    }
    private func installMainMenu() {
        let menu = NSMenu()
        let application = NSMenuItem(); let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Открыть полное окно", action: #selector(reveal), keyEquivalent: "1").target = self
        appMenu.addItem(withTitle: "Мини-панель", action: #selector(revealMini), keyEquivalent: "0").target = self
        appMenu.addItem(withTitle: "Настройки…", action: #selector(settings), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Завершить MacGlint", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        application.submenu = appMenu; menu.addItem(application)
        let edit = NSMenuItem(); let editMenu = NSMenu(title: "Правка")
        for (title, selector, key) in [("Отменить", "undo:", "z"), ("Вырезать", "cut:", "x"), ("Копировать", "copy:", "c"), ("Вставить", "paste:", "v"), ("Выделить всё", "selectAll:", "a")] {
            editMenu.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key)
        }
        edit.submenu = editMenu; menu.addItem(edit)
        let window = NSMenuItem(); let windowMenu = NSMenu(title: "Окно")
        windowMenu.addItem(withTitle: "Закрыть окно", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Свернуть в Dock", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.submenu = windowMenu; menu.addItem(window); NSApp.mainMenu = menu
    }
    @objc private func woke() { store.handleWake() }
    @objc private func toggle() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            hideMini()
            let menu = NSMenu()
            menu.addItem(withTitle: "Мини-панель", action: #selector(revealMini), keyEquivalent: "").target = self
            menu.addItem(withTitle: "Открыть полное окно", action: #selector(reveal), keyEquivalent: "").target = self
            menu.addItem(withTitle: "Настройки…", action: #selector(settings), keyEquivalent: "").target = self
            menu.addItem(.separator())
            menu.addItem(withTitle: "Завершить MacGlint", action: #selector(quit), keyEquivalent: "").target = self
            statusItem.menu = menu; statusItem.button?.performClick(nil); statusItem.menu = nil
        } else if mini.isVisible { hideMini() } else { showMini() }
    }
    @objc private func reveal() { showFull() }
    @objc private func revealMini() { showMini() }
    @objc private func settings() { store.expand(.settings) }
    @objc private func quit() { NSApp.terminate(nil) }
    private func showMini() {
        guard full.attachedSheet == nil else { showFull(); return }
        let screen = statusItem.button?.window?.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let anchor = statusItem.button?.window?.frame.maxX ?? visible.maxX
        mini.setFrame(PanelPlacement.frame(visibleScreen: visible, anchorX: anchor), display: true)
        mini.level = .popUpMenu
        NSApp.activate(ignoringOtherApps: true); mini.makeKeyAndOrderFront(nil)
        updateVisibility(); store.tick(force: true)
    }
    private func hideMini() {
        guard mini?.isVisible == true else { return }
        mini.orderOut(nil); updateVisibility()
    }
    private func showFull() {
        hideMini()
        NSApp.setActivationPolicy(.regular)
        if full.isMiniaturized { full.deminiaturize(nil) }
        full.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        updateVisibility(); store.refreshNotificationStatus(); store.tick(force: true)
    }
    private func updateVisibility() { store.panelVisible = mini.isVisible || (full.isVisible && !full.isMiniaturized) }
    func windowDidResignKey(_ notification: Notification) {
        if notification.object as? NSWindow === mini { hideMini() }
    }
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === full {
            store.panelVisible = mini.isVisible
            NSApp.setActivationPolicy(.accessory)
        }
    }
    func windowDidMiniaturize(_ notification: Notification) { updateVisibility() }
    func windowDidDeminiaturize(_ notification: Notification) { updateVisibility() }
    func applicationWillTerminate(_ notification: Notification) {
        if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        store.stop()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showFull(); return true }
}
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    let open: @MainActor (String) -> Void
    init(open: @escaping @MainActor (String) -> Void) { self.open = open }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) { completionHandler([.banner, .list]) }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let id = response.notification.request.content.userInfo["eventID"] as? String { Task { @MainActor in open(id) } }
        completionHandler()
    }
}
