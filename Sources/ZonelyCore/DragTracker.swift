import CoreGraphics
import Foundation

/// Decides whether a mouse drag is really moving a window.
///
/// A drag counts as a window move once the window under the pointer has
/// changed position while keeping its size. A size change means the user is
/// resizing; a pointer that travels far while the window stays put means the
/// user is dragging something else (text, a tab, a file).
public struct DragTracker: Sendable {
    public enum State: Equatable, Sendable {
        /// No drag is being followed.
        case idle
        /// A drag started over a window, which has not moved yet.
        case pending
        /// The window is confirmed to be following the pointer.
        case moving
        /// This drag is not a window move. Ignored until the next `reset()`.
        case cancelled
    }

    public private(set) var state: State = .idle

    /// Pointer travel, in points, after which a drag over a window that has
    /// not moved is given up on.
    public let maximumPendingTravel: CGFloat

    private var initialFrame = CGRect.zero
    private var initialPointer = CGPoint.zero

    public init(maximumPendingTravel: CGFloat = 64) {
        self.maximumPendingTravel = maximumPendingTravel
    }

    /// Starts following a drag over a window with the given frame.
    public mutating func begin(windowFrame: CGRect, pointer: CGPoint) {
        initialFrame = windowFrame
        initialPointer = pointer
        state = .pending
    }

    /// Feeds the window's current frame while the drag is pending.
    /// Window frame and pointer must use the same coordinate space as `begin`.
    public mutating func update(windowFrame: CGRect, pointer: CGPoint) {
        guard state == .pending else { return }

        let sizeChanged = abs(windowFrame.width - initialFrame.width) >= 1
            || abs(windowFrame.height - initialFrame.height) >= 1
        if sizeChanged {
            state = .cancelled
            return
        }

        let originMoved = abs(windowFrame.minX - initialFrame.minX) >= 1
            || abs(windowFrame.minY - initialFrame.minY) >= 1
        if originMoved {
            state = .moving
            return
        }

        let travel = hypot(pointer.x - initialPointer.x, pointer.y - initialPointer.y)
        if travel > maximumPendingTravel {
            state = .cancelled
        }
    }

    /// Stops following this drag until the next `reset()`.
    public mutating func cancel() {
        state = .cancelled
    }

    /// Call when the mouse button goes down or up.
    public mutating func reset() {
        state = .idle
    }
}
