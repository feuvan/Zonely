import AppKit
import Foundation
import ZonelyCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let windowService = WindowService()
    private let targetApplicationTracker = TargetApplicationTracker()
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        dragMonitor.start()
        startPermissionRefresh()
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
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.rebuildMenu()
        }
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

        let settingsItem = menu.addItem(
            withTitle: "Open Accessibility Settings…",
            action: #selector(openAccessibilitySettings(_:)),
            keyEquivalent: ""
        )
        settingsItem.target = self

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

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
