import Foundation

public enum WindowRegion: CaseIterable, Sendable {
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

public extension CGRect {
    /// Like `contains(_:)`, but also accepts points on the max edges. The
    /// pointer can rest exactly on the top or right edge of a screen.
    func containsInclusive(_ point: CGPoint) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }
}

/// Converts between AppKit global coordinates (origin at the bottom-left of
/// the primary screen, y up) and Accessibility/Quartz global coordinates
/// (origin at the top-left of the primary screen, y down).
///
/// Both systems share the primary screen as their reference, so the flip
/// always uses the primary screen height, whichever screen the rect is on.
public struct ScreenCoordinates: Sendable {
    public let primaryScreenHeight: CGFloat

    public init(primaryScreenHeight: CGFloat) {
        self.primaryScreenHeight = primaryScreenHeight
    }

    public func accessibilityFrame(for appKitFrame: CGRect) -> CGRect {
        flipped(appKitFrame)
    }

    public func appKitFrame(for accessibilityFrame: CGRect) -> CGRect {
        flipped(accessibilityFrame)
    }

    private func flipped(_ frame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX,
            y: primaryScreenHeight - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }
}

public struct WindowLayout: Sendable {
    /// How close to a screen edge the pointer must be to select a region.
    public let edgeThreshold: CGFloat
    /// How far along an edge, measured from a corner, selects the quarter
    /// region instead of the half or full screen region.
    public let cornerLength: CGFloat

    public init(edgeThreshold: CGFloat = 10, cornerLength: CGFloat = 120) {
        self.edgeThreshold = edgeThreshold
        self.cornerLength = cornerLength
    }

    /// The frame of `region` inside a screen's visible frame. AppKit coordinates.
    public func frame(for region: WindowRegion, in visibleFrame: CGRect) -> CGRect {
        let halfWidth = visibleFrame.width / 2
        let halfHeight = visibleFrame.height / 2
        let midX = visibleFrame.minX + halfWidth
        let midY = visibleFrame.minY + halfHeight

        switch region {
        case .leftHalf:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: halfWidth, height: visibleFrame.height)
        case .rightHalf:
            return CGRect(x: midX, y: visibleFrame.minY, width: halfWidth, height: visibleFrame.height)
        case .fullScreen:
            return visibleFrame
        case .topLeft:
            return CGRect(x: visibleFrame.minX, y: midY, width: halfWidth, height: halfHeight)
        case .topRight:
            return CGRect(x: midX, y: midY, width: halfWidth, height: halfHeight)
        case .bottomLeft:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY, width: halfWidth, height: halfHeight)
        case .bottomRight:
            return CGRect(x: midX, y: visibleFrame.minY, width: halfWidth, height: halfHeight)
        }
    }

    /// The region selected by a pointer resting against an edge of the screen.
    ///
    /// Uses the full screen frame, not the visible frame, so that dragging
    /// into the menu bar or the Dock still counts as reaching the edge.
    /// AppKit coordinates. The bottom edge away from the corners selects
    /// nothing, because that is where the Dock usually sits.
    public func region(at point: CGPoint, in screenFrame: CGRect) -> WindowRegion? {
        guard screenFrame.containsInclusive(point) else { return nil }

        let fromLeft = point.x - screenFrame.minX
        let fromRight = screenFrame.maxX - point.x
        let fromBottom = point.y - screenFrame.minY
        let fromTop = screenFrame.maxY - point.y

        let atLeft = fromLeft <= edgeThreshold
        let atRight = fromRight <= edgeThreshold
        let atBottom = fromBottom <= edgeThreshold
        let atTop = fromTop <= edgeThreshold
        guard atLeft || atRight || atBottom || atTop else { return nil }

        let inLeftCorner = fromLeft <= cornerLength
        let inRightCorner = fromRight <= cornerLength
        let inBottomCorner = fromBottom <= cornerLength
        let inTopCorner = fromTop <= cornerLength

        if (atLeft && inTopCorner) || (atTop && inLeftCorner) {
            return .topLeft
        }
        if (atRight && inTopCorner) || (atTop && inRightCorner) {
            return .topRight
        }
        if (atLeft && inBottomCorner) || (atBottom && inLeftCorner) {
            return .bottomLeft
        }
        if (atRight && inBottomCorner) || (atBottom && inRightCorner) {
            return .bottomRight
        }
        if atLeft {
            return .leftHalf
        }
        if atRight {
            return .rightHalf
        }
        if atTop {
            return .fullScreen
        }
        return nil
    }
}
