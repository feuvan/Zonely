import AppKit
import ApplicationServices
import Foundation
import ZonelyCore

extension NSScreen {
    /// The screen that contains a point in AppKit global coordinates.
    static func containing(_ point: CGPoint) -> NSScreen? {
        screens.first { $0.frame.containsInclusive(point) }
    }
}

final class WindowService {
    enum ServiceError: LocalizedError {
        case accessibilityPermissionRequired
        case noFocusedWindow
        case fullScreenWindow
        case operationFailed(String)

        var errorDescription: String? {
            switch self {
            case .accessibilityPermissionRequired:
                return "Zonely needs Accessibility permission to control windows."
            case .noFocusedWindow:
                return "No controllable window was found in the selected application."
            case .fullScreenWindow:
                return "The window is in full screen. Exit full screen, then try again."
            case let .operationFailed(operation):
                return "Could not update the window while trying to \(operation)."
            }
        }
    }

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private let layout = WindowLayout()
    private let systemWideElement = AXUIElementCreateSystemWide()
    private let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier

    init() {
        // Applies to every Accessibility request this process makes, so an
        // unresponsive application cannot stall Zonely for long.
        _ = AXUIElementSetMessagingTimeout(systemWideElement, 0.5)
    }

    /// Moves the application's focused window to `region` on the screen the
    /// window is currently on.
    func apply(_ region: WindowRegion, to application: NSRunningApplication) throws {
        guard Self.isTrusted else {
            throw ServiceError.accessibilityPermissionRequired
        }

        let window = try focusedWindow(for: application)
        guard let screen = screen(showing: window) ?? NSScreen.main else {
            throw ServiceError.operationFailed("find the target screen")
        }
        try setFrame(layout.frame(for: region, in: screen.visibleFrame), of: window)
    }

    func focusedWindow(for application: NSRunningApplication) throws -> AXUIElement {
        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        guard let window = elementAttribute(kAXFocusedWindowAttribute, of: applicationElement) else {
            throw ServiceError.noFocusedWindow
        }
        return window
    }

    /// The window of another application under a point in Accessibility
    /// (top-left origin) global coordinates.
    func window(at point: CGPoint) -> AXUIElement? {
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(
            systemWideElement,
            Float(point.x),
            Float(point.y),
            &hit
        ) == .success, let element = hit else {
            return nil
        }

        var processIdentifier: pid_t = 0
        guard AXUIElementGetPid(element, &processIdentifier) == .success,
              processIdentifier != ownProcessIdentifier else {
            return nil
        }

        if stringAttribute(kAXRoleAttribute, of: element) == kAXWindowRole {
            return element
        }
        return elementAttribute(kAXWindowAttribute, of: element)
    }

    /// The window frame in Accessibility (top-left origin) global coordinates.
    func frame(of window: AXUIElement) -> CGRect? {
        guard let origin = valueAttribute(kAXPositionAttribute, of: window, as: .cgPoint, initial: CGPoint.zero),
              let size = valueAttribute(kAXSizeAttribute, of: window, as: .cgSize, initial: CGSize.zero) else {
            return nil
        }
        return CGRect(origin: origin, size: size)
    }

    /// Moves and resizes a window to a frame in AppKit global coordinates.
    /// A window that cannot be resized is only moved.
    func setFrame(_ appKitFrame: CGRect, of window: AXUIElement) throws {
        guard let primaryScreen = NSScreen.screens.first else {
            throw ServiceError.operationFailed("find the primary screen")
        }
        if boolAttribute("AXFullScreen", of: window) == true {
            throw ServiceError.fullScreenWindow
        }

        let target = ScreenCoordinates(primaryScreenHeight: primaryScreen.frame.height)
            .accessibilityFrame(for: appKitFrame)
        let isResizable = isSettable(kAXSizeAttribute, of: window)

        // Size, then position, then size again: an application clamps a new
        // size to the screen the window is on at that moment, so a single
        // resize can come out wrong when the window changes screens.
        if isResizable {
            _ = setValue(target.size, type: .cgSize, for: kAXSizeAttribute, of: window)
        }
        guard setValue(target.origin, type: .cgPoint, for: kAXPositionAttribute, of: window) else {
            throw ServiceError.operationFailed("move the window")
        }
        if isResizable {
            guard setValue(target.size, type: .cgSize, for: kAXSizeAttribute, of: window) else {
                throw ServiceError.operationFailed("resize the window")
            }
        }
    }

    private func screen(showing window: AXUIElement) -> NSScreen? {
        guard let primaryScreen = NSScreen.screens.first,
              let accessibilityFrame = frame(of: window) else {
            return nil
        }
        let appKitFrame = ScreenCoordinates(primaryScreenHeight: primaryScreen.frame.height)
            .appKitFrame(for: accessibilityFrame)
        return NSScreen.containing(CGPoint(x: appKitFrame.midX, y: appKitFrame.midY))
    }

    // MARK: - Accessibility attribute helpers

    private func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private func elementAttribute(_ name: String, of element: AXUIElement) -> AXUIElement? {
        guard let value = attribute(name, of: element),
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
    }

    private func stringAttribute(_ name: String, of element: AXUIElement) -> String? {
        attribute(name, of: element) as? String
    }

    private func boolAttribute(_ name: String, of element: AXUIElement) -> Bool? {
        attribute(name, of: element) as? Bool
    }

    private func valueAttribute<Value>(
        _ name: String,
        of element: AXUIElement,
        as type: AXValueType,
        initial: Value
    ) -> Value? {
        guard let value = attribute(name, of: element),
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        var result = initial
        guard AXValueGetValue(value as! AXValue, type, &result) else {
            return nil
        }
        return result
    }

    private func isSettable(_ name: String, of element: AXUIElement) -> Bool {
        var settable: DarwinBoolean = false
        return AXUIElementIsAttributeSettable(element, name as CFString, &settable) == .success
            && settable.boolValue
    }

    private func setValue<Value>(
        _ value: Value,
        type: AXValueType,
        for name: String,
        of element: AXUIElement
    ) -> Bool {
        var value = value
        guard let axValue = AXValueCreate(type, &value) else {
            return false
        }
        return AXUIElementSetAttributeValue(element, name as CFString, axValue) == .success
    }
}
