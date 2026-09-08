import AppKit
import Foundation
import ServiceManagement

enum LaunchAtLoginService {
    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    static var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    static var isEnabled: Bool {
        status == .enabled
    }

    static var needsApproval: Bool {
        status == .requiresApproval
    }

    static func enable() throws {
        try SMAppService.mainApp.register()
    }

    static func disable() throws {
        try SMAppService.mainApp.unregister()
    }

    static func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
