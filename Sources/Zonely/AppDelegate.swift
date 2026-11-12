import AppKit
import Foundation
import ZonelyCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let repositoryURL = URL(string: "https://github.com/feuvan/Zonely")!

    private let windowService = WindowService()
    private let targetApplicationTracker = TargetApplicationTracker()
    private let updateService = UpdateService()
    private lazy var dragMonitor: DragMonitor = DragMonitor(windowService: windowService)

    private var statusItem: NSStatusItem?
    private var isCheckingForUpdates = false
    private var availableUpdate: AvailableUpdate?
    private var lastSnapError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()

        dragMonitor.onSnapResult = { [weak self] error in
            self?.lastSnapError = error?.localizedDescription
        }
        dragMonitor.start()

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.checkForUpdates(userInitiated: false)
        }
    }

    // MARK: - Menu

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = NSImage(
            systemSymbolName: "rectangle.split.2x1",
            accessibilityDescription: "Zonely"
        ) {
            image.isTemplate = true
            item.button?.image = image
        } else {
            item.button?.title = "Z"
        }
        item.button?.toolTip = "Zonely"

        // The menu is filled in `menuNeedsUpdate` each time it opens, so its
        // state is always current without polling.
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === statusItem?.menu else { return }
        menu.removeAllItems()

        addItem("Zonely \(updateService.currentVersion)", to: menu)
        addItem(
            WindowService.isTrusted ? "Accessibility: Ready" : "Accessibility: Required",
            action: #selector(requestPermission(_:)),
            to: menu
        )
        if let lastSnapError {
            addItem("Last snap failed: \(lastSnapError)", to: menu)
        }
        if let availableUpdate {
            addItem(
                "Zonely \(availableUpdate.version) Is Available…",
                action: #selector(openAvailableUpdate(_:)),
                to: menu
            )
        }

        menu.addItem(.separator())

        let layoutMenu = NSMenu()
        for region in WindowRegion.allCases {
            let item = addItem(region.title, action: #selector(applyRegion(_:)), to: layoutMenu)
            item.representedObject = region
        }
        let layoutItem = addItem("Move Focused Window", to: menu)
        menu.setSubmenu(layoutMenu, for: layoutItem)

        addItem(
            dragMonitor.isRunning ? "Pause Drag Snapping" : "Resume Drag Snapping",
            action: #selector(togglePause(_:)),
            to: menu
        )

        let launchAtLoginItem = addItem(
            launchAtLoginTitle,
            action: #selector(toggleLaunchAtLogin(_:)),
            to: menu
        )
        launchAtLoginItem.state = launchAtLoginState

        menu.addItem(.separator())

        addItem("Open Accessibility Settings…", action: #selector(openAccessibilitySettings(_:)), to: menu)
        addItem("Check for Updates…", action: #selector(checkForUpdatesFromMenu(_:)), to: menu)
        addItem("Open GitHub Repository…", action: #selector(openRepository(_:)), to: menu)

        menu.addItem(.separator())

        addItem("Quit Zonely", action: #selector(quit(_:)), key: "q", to: menu)
    }

    /// Adds an item that targets this object. An item without an action is
    /// shown disabled, as a label.
    @discardableResult
    private func addItem(
        _ title: String,
        action: Selector? = nil,
        key: String = "",
        to menu: NSMenu
    ) -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - Accessibility permission

    @objc private func requestPermission(_ sender: Any?) {
        WindowService.requestAccessibilityPermission()
        WindowService.openAccessibilitySettings()
    }

    @objc private func openAccessibilitySettings(_ sender: Any?) {
        WindowService.openAccessibilitySettings()
    }

    // MARK: - Launch at login

    private var launchAtLoginTitle: String {
        if !LaunchAtLoginService.isAvailable {
            return "Launch at Login (App Bundle Required)"
        }
        if LaunchAtLoginService.needsApproval {
            return "Launch at Login (Approval Required)"
        }
        return "Launch at Login"
    }

    private var launchAtLoginState: NSControl.StateValue {
        if LaunchAtLoginService.isEnabled {
            return .on
        }
        if LaunchAtLoginService.needsApproval {
            return .mixed
        }
        return .off
    }

    @objc private func toggleLaunchAtLogin(_ sender: Any?) {
        guard LaunchAtLoginService.isAvailable else {
            showAlert(
                .warning,
                title: "App Bundle Required",
                message: "Launch at Login can be configured after launching Zonely from a .app bundle."
            )
            return
        }

        do {
            if LaunchAtLoginService.isEnabled {
                try LaunchAtLoginService.disable()
            } else if !LaunchAtLoginService.needsApproval {
                try LaunchAtLoginService.enable()
            }

            if LaunchAtLoginService.needsApproval {
                LaunchAtLoginService.openSettings()
                showAlert(
                    .informational,
                    title: "Approval Required",
                    message: "Enable Zonely under System Settings → General → Login Items."
                )
            }
        } catch {
            showAlert(.warning, title: "Could Not Update Login Item", message: error.localizedDescription)
        }
    }

    // MARK: - Window layout

    @objc private func togglePause(_ sender: Any?) {
        if dragMonitor.isRunning {
            dragMonitor.stop()
        } else {
            dragMonitor.start()
        }
    }

    @objc private func applyRegion(_ sender: NSMenuItem) {
        guard let region = sender.representedObject as? WindowRegion else { return }

        guard WindowService.isTrusted else {
            showAlert(
                .warning,
                title: "Accessibility Permission Required",
                message: "Enable Zonely in System Settings → Privacy & Security → Accessibility, then try again."
            )
            return
        }

        guard let application = targetApplicationTracker.application else {
            showAlert(
                .warning,
                title: "No Target Application",
                message: "Activate the application whose window you want to position, then try again."
            )
            return
        }

        do {
            try windowService.apply(region, to: application)
        } catch {
            showAlert(.warning, title: "Could Not Position Window", message: error.localizedDescription)
        }
    }

    // MARK: - Updates

    @objc private func checkForUpdatesFromMenu(_ sender: Any?) {
        checkForUpdates(userInitiated: true)
    }

    @objc private func openAvailableUpdate(_ sender: Any?) {
        guard let availableUpdate else { return }
        NSWorkspace.shared.open(availableUpdate.releaseURL)
    }

    @objc private func openRepository(_ sender: Any?) {
        NSWorkspace.shared.open(Self.repositoryURL)
    }

    /// An automatic check only records the update for the menu. A check the
    /// user asked for also reports the outcome in an alert.
    private func checkForUpdates(userInitiated: Bool) {
        guard !isCheckingForUpdates else { return }
        isCheckingForUpdates = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isCheckingForUpdates = false }

            do {
                availableUpdate = try await updateService.checkForUpdate()
                guard userInitiated else { return }

                if let availableUpdate {
                    presentUpdate(availableUpdate)
                } else {
                    showAlert(
                        .informational,
                        title: "Zonely Is Up to Date",
                        message: "You are running Zonely \(updateService.currentVersion)."
                    )
                }
            } catch {
                if userInitiated {
                    showAlert(.warning, title: "Update Check Failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func presentUpdate(_ update: AvailableUpdate) {
        let notes = update.notes.isEmpty ? "A new version of Zonely is available to download." : update.notes
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Zonely \(update.version) Is Available"
        alert.informativeText = "\(notes)\n\nInstalled: \(updateService.currentVersion)"
        alert.addButton(withTitle: "View Release")
        alert.addButton(withTitle: "Later")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(update.releaseURL)
        }
    }

    // MARK: - Alerts

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func showAlert(_ style: NSAlert.Style, title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")

        // Zonely has no Dock icon, so bring the alert in front of other apps.
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
