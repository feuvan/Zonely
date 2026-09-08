import AppKit
import Foundation

final class TargetApplicationTracker {
    private(set) var application: NSRunningApplication?

    private var activationObserver: NSObjectProtocol?
    private let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier

    init() {
        captureCurrentApplication()
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  application.processIdentifier != self.ownProcessIdentifier else {
                return
            }
            self.application = application
        }
    }

    deinit {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
    }

    func captureCurrentApplication() {
        guard let current = NSWorkspace.shared.frontmostApplication,
              current.processIdentifier != ownProcessIdentifier else {
            return
        }
        application = current
    }
}
