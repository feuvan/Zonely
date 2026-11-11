import AppKit
import Foundation

/// Remembers the most recently active application other than Zonely, so that
/// menu commands act on the application the user was working in.
final class TargetApplicationTracker {
    private(set) var application: NSRunningApplication?

    private var activationObserver: NSObjectProtocol?
    private let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier

    init() {
        if let current = NSWorkspace.shared.frontmostApplication,
           current.processIdentifier != ownProcessIdentifier {
            application = current
        }

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
}
