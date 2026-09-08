import AppKit
import ApplicationServices
import Foundation
import ZonelyCore

final class WindowService {
    enum ServiceError: LocalizedError {
        case accessibilityPermissionRequired
        case noFocusedWindow
        case unsupportedPosition
        case unsupportedSize
        case operationFailed(String)

        var errorDescription: String? {
            switch self {
            case .accessibilityPermissionRequired:
                return "Zonely needs Accessibility permission to control windows."
            case .noFocusedWindow:
                return "No controllable window was found in the selected application."
            case .unsupportedPosition:
                return "The selected window does not expose a readable position."
            case .unsupportedSize:
                return "The selected window does not expose a readable size."
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

    func apply(_ region: WindowRegion, to application: NSRunningApplication, on screen: NSScreen? = nil) throws {
        guard Self.isTrusted else {
            throw ServiceError.accessibilityPermissionRequired
        }

        let window = try focusedWindow(for: application)
        let targetScreen = screen ?? screenContainingMouse() ?? NSScreen.main
        guard let targetScreen else {
            throw ServiceError.operationFailed("find the target screen")
        }

        let targetFrame = layout.frame(for: region, in: targetScreen.visibleFrame)
        try setFrame(targetFrame, of: window)
    }

    func focusedWindow(for application: NSRunningApplication) throws -> AXUIElement {
        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedWindowAttribute as CFString,
            &value
        )

        guard error == .success, let window = value else {
            throw ServiceError.noFocusedWindow
        }

        return window as! AXUIElement
    }

    func frame(of window: AXUIElement) throws -> CGRect {
        let origin = try pointAttribute(kAXPositionAttribute, of: window, error: .unsupportedPosition)
        let size = try sizeAttribute(kAXSizeAttribute, of: window, error: .unsupportedSize)
        return CGRect(origin: origin, size: size)
    }

    func setFrame(_ frame: CGRect, of window: AXUIElement) throws {
        var origin = frame.origin
        guard let position = AXValueCreate(.cgPoint, &origin) else {
            throw ServiceError.operationFailed("create the window position")
        }

        let positionError = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            position
        )
        guard positionError == .success else {
            throw ServiceError.operationFailed("move the window")
        }

        var size = frame.size
        guard let axSize = AXValueCreate(.cgSize, &size) else {
            throw ServiceError.operationFailed("create the window size")
        }

        let sizeError = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            axSize
        )
        guard sizeError == .success else {
            throw ServiceError.operationFailed("resize the window")
        }
    }

    private func sizeAttribute(
        _ attribute: String,
        of window: AXUIElement,
        error serviceError: ServiceError
    ) throws -> CGSize {
        var value: CFTypeRef?
        let copyError = AXUIElementCopyAttributeValue(window, attribute as CFString, &value)
        guard copyError == .success, let value else {
            throw serviceError
        }
        let axValue = value as! AXValue

        var size = CGSize.zero
        guard AXValueGetType(axValue) == .cgSize,
              AXValueGetValue(axValue, .cgSize, &size) else {
            throw serviceError
        }
        return size
    }

    private func pointAttribute(
        _ attribute: String,
        of window: AXUIElement,
        error serviceError: ServiceError
    ) throws -> CGPoint {
        var value: CFTypeRef?
        let copyError = AXUIElementCopyAttributeValue(window, attribute as CFString, &value)
        guard copyError == .success, let value else {
            throw serviceError
        }
        let axValue = value as! AXValue

        var point = CGPoint.zero
        guard AXValueGetType(axValue) == .cgPoint,
              AXValueGetValue(axValue, .cgPoint, &point) else {
            throw serviceError
        }
        return point
    }

    private func screenContainingMouse() -> NSScreen? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(location) }
    }
}
