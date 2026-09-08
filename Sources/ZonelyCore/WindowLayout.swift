import CoreGraphics
import Foundation

public enum WindowRegion: String, CaseIterable, Sendable {
    case leftHalf
    case rightHalf
    case fullScreen
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    public var title: String {
        switch self {
        case .leftHalf:
            return "Left Half"
        case .rightHalf:
            return "Right Half"
        case .fullScreen:
            return "Full Screen"
        case .topLeft:
            return "Top Left Quarter"
        case .topRight:
            return "Top Right Quarter"
        case .bottomLeft:
            return "Bottom Left Quarter"
        case .bottomRight:
            return "Bottom Right Quarter"
        }
    }
}

public struct WindowCoordinateConverter: Sendable {
    public init() {}

    /// Converts an AppKit screen rect (origin at the bottom-left) to the
    /// Accessibility screen rect (origin at the top-left).
    public func accessibilityFrame(for appKitFrame: CGRect, in screenFrame: CGRect) -> CGRect {
        CGRect(
            x: appKitFrame.minX,
            y: screenFrame.maxY - appKitFrame.maxY,
            width: appKitFrame.width,
            height: appKitFrame.height
        )
    }
}

public struct WindowLayout: Sendable {
    public init() {}

    public func frame(for region: WindowRegion, in visibleFrame: CGRect) -> CGRect {
        let halfWidth = visibleFrame.width / 2
        let halfHeight = visibleFrame.height / 2

        switch region {
        case .leftHalf:
            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: halfWidth,
                height: visibleFrame.height
            )
        case .rightHalf:
            return CGRect(
                x: visibleFrame.minX + halfWidth,
                y: visibleFrame.minY,
                width: halfWidth,
                height: visibleFrame.height
            )
        case .fullScreen:
            return visibleFrame
        case .topLeft:
            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY + halfHeight,
                width: halfWidth,
                height: halfHeight
            )
        case .topRight:
            return CGRect(
                x: visibleFrame.minX + halfWidth,
                y: visibleFrame.minY + halfHeight,
                width: halfWidth,
                height: halfHeight
            )
        case .bottomLeft:
            return CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: halfWidth,
                height: halfHeight
            )
        case .bottomRight:
            return CGRect(
                x: visibleFrame.minX + halfWidth,
                y: visibleFrame.minY,
                width: halfWidth,
                height: halfHeight
            )
        }
    }

    public func region(containing point: CGPoint, in visibleFrame: CGRect) -> WindowRegion? {
        guard visibleFrame.contains(point) else { return nil }

        let normalizedX = (point.x - visibleFrame.minX) / visibleFrame.width
        let normalizedY = (point.y - visibleFrame.minY) / visibleFrame.height
        let isLeftEdge = normalizedX < 0.25
        let isRightEdge = normalizedX >= 0.75
        let isTopEdge = normalizedY >= 0.75
        let isBottomEdge = normalizedY < 0.25

        if isLeftEdge && isTopEdge {
            return .topLeft
        }
        if isRightEdge && isTopEdge {
            return .topRight
        }
        if isLeftEdge && isBottomEdge {
            return .bottomLeft
        }
        if isRightEdge && isBottomEdge {
            return .bottomRight
        }
        if isLeftEdge {
            return .leftHalf
        }
        if isRightEdge {
            return .rightHalf
        }
        if isTopEdge {
            return .fullScreen
        }

        return nil
    }
}
