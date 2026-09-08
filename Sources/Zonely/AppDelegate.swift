import AppKit
import Foundation
import ZonelyCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let repositoryURL = URL(string: "https://github.com/feuvan/Zonely")!

    private let windowService = WindowService()
    private let targetApplicationTracker = TargetApplicationTracker()
    private let updateService = UpdateService()
    private lazy var dragMonitor: DragMonitor = {
        let monitor = DragMonitor(
            windowService: windowService,
            targetApplicationTracker: targetApplicationTracker
        )
        monitor.onError = { [weak self] message in
            self?.showError(title: "Could Not Position Window", message: message)
        }
        return monitor
    }()

    private var statusItem: NSStatusItem?
    private var permissionTimer: Timer?
    private var isPaused = false
    private var isCheckingForUpdates = false
    private var isInstallingUpdate = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        dragMonitor.start()
        startPermissionRefresh()
        scheduleAutomaticUpdateCheck()
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
    }

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
        statusItem = item
        rebuildMenu()
    }

    private func startPermissionRefresh() {
        let timer = Timer(
            timeInterval: 2,
            target: self,
            selector: #selector(refreshPermission(_:)),
            userInfo: nil,
            repeats: true
        )
        permissionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    @objc private func refreshPermission(_ timer: Timer) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        guard let statusItem else { return }

        let menu = NSMenu()
        let titleItem = menu.addItem(withTitle: "Zonely", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false

        let permissionItem = menu.addItem(
            withTitle: permissionStatusTitle,
            action: #selector(requestPermission(_:)),
            keyEquivalent: ""
        )
        permissionItem.target = self

        let layoutItem = menu.addItem(withTitle: "Test Layout", action: nil, keyEquivalent: "")
        let layoutMenu = NSMenu()
        for region in WindowRegion.allCases {
            let item = layoutMenu.addItem(
                withTitle: region.title,
                action: #selector(applyRegion(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = region
        }
        menu.setSubmenu(layoutMenu, for: layoutItem)

        menu.addItem(.separator())

        let pauseItem = menu.addItem(
            withTitle: isPaused ? "Resume Zonely" : "Pause Zonely",
            action: #selector(togglePause(_:)),
            keyEquivalent: ""
        )
        pauseItem.target = self

        let launchAtLoginItem = menu.addItem(
            withTitle: launchAtLoginTitle,
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginItem.state = launchAtLoginState
        launchAtLoginItem.isEnabled = LaunchAtLoginService.isAvailable

        let settingsItem = menu.addItem(
            withTitle: "Open Accessibility Settings…",
            action: #selector(openAccessibilitySettings(_:)),
            keyEquivalent: ""
        )
        settingsItem.target = self

        let updateItem = menu.addItem(
            withTitle: "Check for Updates…",
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updateItem.target = self

        let repositoryItem = menu.addItem(
            withTitle: "Open GitHub Repository…",
            action: #selector(openRepository(_:)),
            keyEquivalent: ""
        )
        repositoryItem.target = self

        menu.addItem(.separator())

        let quitItem = menu.addItem(
            withTitle: "Quit Zonely",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self

        statusItem.menu = menu
    }

    private var permissionStatusTitle: String {
        WindowService.isTrusted ? "Accessibility: Ready" : "Accessibility: Required"
    }

    @objc private func requestPermission(_ sender: Any?) {
        WindowService.requestAccessibilityPermission()
        WindowService.openAccessibilitySettings()
    }

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

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        guard LaunchAtLoginService.isAvailable else {
            showError(
                title: "App Bundle Required",
                message: "Launch at Login can be configured after launching Zonely from a .app bundle."
            )
            return
        }

        do {
            if LaunchAtLoginService.isEnabled {
                try LaunchAtLoginService.disable()
            } else if LaunchAtLoginService.needsApproval {
                LaunchAtLoginService.openSettings()
            } else {
                try LaunchAtLoginService.enable()
            }
            rebuildMenu()

            if LaunchAtLoginService.needsApproval {
                LaunchAtLoginService.openSettings()
                showInfo(
                    title: "Approval Required",
                    message: "Enable Zonely under System Settings → General → Login Items."
                )
            }
        } catch {
            showError(title: "Could Not Update Login Item", message: error.localizedDescription)
        }
    }

    @objc private func openAccessibilitySettings(_ sender: Any?) {
        WindowService.openAccessibilitySettings()
    }

    @objc private func togglePause(_ sender: Any?) {
        isPaused.toggle()
        dragMonitor.isEnabled = !isPaused
        if isPaused {
            dragMonitor.stop()
        } else {
            dragMonitor.start()
        }
        rebuildMenu()
    }

    @objc private func checkForUpdates(_ sender: Any?) {
        beginUpdateCheck(showNoUpdate: true)
    }

    @objc private func openRepository(_ sender: Any?) {
        NSWorkspace.shared.open(Self.repositoryURL)
    }

    private func scheduleAutomaticUpdateCheck() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.beginUpdateCheck(showNoUpdate: false)
        }
    }

    private func beginUpdateCheck(showNoUpdate: Bool) {
        guard !isCheckingForUpdates, !isInstallingUpdate else { return }
        isCheckingForUpdates = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let update = try await updateService.checkForUpdate()
                isCheckingForUpdates = false
                if let update {
                    presentUpdate(update)
                } else if showNoUpdate {
                    showInfo(
                        title: "Zonely Is Up to Date",
                        message: "You are running Zonely \(updateService.currentVersion)."
                    )
                }
            } catch {
                isCheckingForUpdates = false
                if showNoUpdate {
                    showError(title: "Update Check Failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func presentUpdate(_ update: AvailableUpdate) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Zonely \(update.version) Is Available"
        let notes = update.notes.isEmpty ? "A new version of Zonely is ready to install." : update.notes
        alert.informativeText = "\(notes)\n\nInstalled: \(updateService.currentVersion)"
        alert.addButton(withTitle: "Install Update")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            installUpdate(update)
        }
    }

    private func installUpdate(_ update: AvailableUpdate) {
        guard !isInstallingUpdate else { return }
        isInstallingUpdate = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await updateService.downloadAndScheduleInstall(update)
                isInstallingUpdate = false
                NSApp.terminate(nil)
            } catch {
                isInstallingUpdate = false
                showError(title: "Update Installation Failed", message: error.localizedDescription)
            }
        }
    }

    @objc private func applyRegion(_ sender: NSMenuItem) {
        guard !isPaused,
              let region = sender.representedObject as? WindowRegion else {
            return
        }

        guard WindowService.isTrusted else {
            showError(
                title: "Accessibility Permission Required",
                message: "Enable Zonely in System Settings → Privacy & Security → Accessibility, then try again."
            )
            return
        }

        guard let application = targetApplicationTracker.application else {
            showError(
                title: "No Target Application",
                message: "Activate the application whose window you want to position, then try again."
            )
            return
        }

        do {
            try windowService.apply(region, to: application)
        } catch {
            showError(title: "Could Not Position Window", message: error.localizedDescription)
        }
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func showInfo(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
