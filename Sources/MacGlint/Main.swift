import AppKit
import SwiftUI
import UserNotifications

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
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var panel: GlintPanel!
    private var store: AppStore!
    private var notificationDelegate: NotificationDelegate!
    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        store = AppStore()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform.path", accessibilityDescription: "MacGlint")
            button.imagePosition = .imageLeading
            button.target = self; button.action = #selector(toggle)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        panel = GlintPanel(contentRect: NSRect(x: 0, y: 0, width: 410, height: 650), styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        panel.title = "MacGlint"; panel.titleVisibility = .hidden; panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true; panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false; panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.contentView = NSHostingView(rootView: RootView(store: store))
        panel.delegate = self
        store.onLayout = { [weak self] in self?.layout() }
        store.onMenuUpdate = { [weak self] in self?.statusItem.button?.title = " " + (self?.store.menuTitle ?? "") }
        store.onReveal = { [weak self] in self?.show() }
        notificationDelegate = NotificationDelegate { [weak self] id in
            guard let self, let event = self.store.events.first(where: { $0.id.uuidString == id }) else { return }
            self.store.showEvent(event)
        }
        UNUserNotificationCenter.current().delegate = notificationDelegate
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(woke), name: NSWorkspace.didWakeNotification, object: nil)
        store.start()
        show()
    }
    private func installMainMenu() {
        let menu = NSMenu()
        let application = NSMenuItem(); let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Завершить MacGlint", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        application.submenu = appMenu; menu.addItem(application)
        let edit = NSMenuItem(); let editMenu = NSMenu(title: "Правка")
        for (title, selector, key) in [("Отменить", "undo:", "z"), ("Вырезать", "cut:", "x"), ("Копировать", "copy:", "c"), ("Вставить", "paste:", "v"), ("Выделить всё", "selectAll:", "a")] {
            editMenu.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key)
        }
        edit.submenu = editMenu; menu.addItem(edit); NSApp.mainMenu = menu
    }
    @objc private func woke() { store.handleWake() }
    @objc private func toggle() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "Открыть MacGlint", action: #selector(reveal), keyEquivalent: "").target = self
            menu.addItem(withTitle: "Завершить MacGlint", action: #selector(quit), keyEquivalent: "q").target = self
            statusItem.menu = menu; statusItem.button?.performClick(nil); statusItem.menu = nil
        } else if panel.isVisible { panel.orderOut(nil); store.panelVisible = false } else { show() }
    }
    @objc private func reveal() { show() }
    @objc private func quit() { NSApp.terminate(nil) }
    private func show() {
        layout(); NSApp.activate(ignoringOtherApps: true); panel.makeKeyAndOrderFront(nil)
        store.panelVisible = true; store.tick(force: true)
    }
    private func layout() {
        let width: CGFloat = store.expanded ? 800 : 410
        let height: CGFloat = store.expanded ? 740 : 650
        let screen = statusItem.button?.window?.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let anchor = statusItem.button?.window?.frame.maxX ?? visible.maxX
        let x = max(visible.minX + 10, min(anchor - width, visible.maxX - width - 10))
        let y = max(visible.minY, visible.maxY - height - 8)
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true, animate: panel.isVisible)
        panel.level = store.pinned ? .floating : .normal
    }
    func windowDidResignKey(_ notification: Notification) {
        guard !store.pinned, panel.attachedSheet == nil, NSApp.modalWindow == nil else { return }
        panel.orderOut(nil); store.panelVisible = false
    }
    func applicationWillTerminate(_ notification: Notification) { store.stop() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { show(); return true }
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
