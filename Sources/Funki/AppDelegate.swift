import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let monitor = ConnectivityMonitor(settings: .load())
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    private let statusLine = NSMenuItem()
    private let pauseItem = NSMenuItem(title: "", action: #selector(togglePause), keyEquivalent: "")
    private let settingsItem = NSMenuItem(title: "Settings…", action: #selector(editSettings), keyEquivalent: ",")
    private let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The bundle's Info.plist says the same. Setting it here keeps Funki out
        // of the Dock when the executable runs without its bundle, too.
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu = makeEditMenu()

        for item in [pauseItem, settingsItem, loginItem] { item.target = self }
        let menu = NSMenu()
        menu.delegate = self
        menu.items = [
            statusLine,
            .separator(),
            pauseItem,
            .separator(),
            settingsItem,
            loginItem,
            .separator(),
            NSMenuItem(title: "Quit Funki", action: #selector(NSApplication.terminate), keyEquivalent: "q"),
        ]
        statusItem.menu = menu

        monitor.onChange = { [weak self] in self?.show($0) }
        show(monitor.status)
        monitor.start()
    }

    // MARK: - Display

    private func show(_ status: Status) {
        let title = status.title
        statusLine.title = title
        pauseItem.title = status == .paused ? "Resume" : "Pause"

        guard let button = statusItem.button else { return }
        button.image = status.icon
        button.image?.accessibilityDescription = title
        button.toolTip = title
        // Dims the icon while Funki has nothing to say about the connection.
        button.appearsDisabled = status == .checking || status == .paused
    }

    func menuWillOpen(_ menu: NSMenu) {
        // A dash instead of a checkmark while macOS waits for the user's approval.
        loginItem.state = switch SMAppService.mainApp.status {
        case .enabled: .on
        case .requiresApproval: .mixed
        default: .off
        }
        // Whoever opens the menu wants to know the status as of now.
        monitor.checkNow()
    }

    // MARK: - Actions

    @objc private func togglePause() {
        if monitor.status == .paused {
            monitor.start()
        } else {
            monitor.pause()
        }
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        var failure: Error?
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            failure = error
        }

        if service.status == .requiresApproval {
            // macOS holds the login item back until the user allows it, and
            // registering again fails for as long as it does. Only the user can
            // change that, so take them to where they can.
            SMAppService.openSystemSettingsLoginItems()
        } else if let failure {
            NSApp.activate()
            NSAlert(error: failure).runModal()
        }
    }

    @objc private func editSettings() {
        guard let settings = SettingsDialog().run(editing: monitor.settings) else { return }
        settings.save()
        monitor.settings = settings
    }

    /// Funki has no menu bar of its own, but the standard editing shortcuts are
    /// dispatched through the main menu. Without this, ⌘V wouldn't work in the
    /// settings dialog.
    private func makeEditMenu() -> NSMenu {
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll), keyEquivalent: "a")

        let item = NSMenuItem()
        item.submenu = edit
        let menu = NSMenu()
        menu.addItem(item)
        return menu
    }
}

@MainActor
private extension Status {
    var title: String {
        switch self {
        case .checking: "Checking…"
        case .online: "Online"
        case .paused: "Paused"
        case .offline(.noNetwork): "Offline – No Network"
        case .offline(.noResponse): "Offline – No Response"
        case .offline(.unexpectedResponse(let status)): "Offline – Unexpected Response (HTTP \(status))"
        }
    }

    var icon: NSImage? {
        switch self {
        case .checking, .online, .paused: Icon.connected
        case .offline: Icon.disconnected
        }
    }
}

/// The menu bar icons, created once and reused for every status change.
@MainActor
private enum Icon {
    /// A template image, so it follows the menu bar's appearance.
    static let connected = NSImage(
        systemSymbolName: "antenna.radiowaves.left.and.right",
        accessibilityDescription: nil
    )

    /// Red on purpose: being offline is the one state worth drawing attention to.
    static let disconnected = NSImage(
        systemSymbolName: "antenna.radiowaves.left.and.right.slash",
        accessibilityDescription: nil
    )?.withSymbolConfiguration(.init(paletteColors: [.systemRed]))
}
