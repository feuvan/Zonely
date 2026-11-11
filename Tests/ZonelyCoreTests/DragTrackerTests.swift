import CoreGraphics
import XCTest
@testable import ZonelyCore

final class DragTrackerTests: XCTestCase {
    private let frame = CGRect(x: 100, y: 100, width: 800, height: 600)
    private let pointer = CGPoint(x: 400, y: 110)

    private func startedTracker() -> DragTracker {
        var tracker = DragTracker(maximumPendingTravel: 64)
        tracker.begin(windowFrame: frame, pointer: pointer)
        return tracker
    }

    func testStartsIdleAndBecomesPending() {
        XCTAssertEqual(DragTracker().state, .idle)
        XCTAssertEqual(startedTracker().state, .pending)
    }

    func testWindowThatFollowsThePointerIsMoving() {
        var tracker = startedTracker()
        tracker.update(
            windowFrame: frame.offsetBy(dx: 12, dy: 5),
            pointer: CGPoint(x: 412, y: 115)
        )
        XCTAssertEqual(tracker.state, .moving)
    }

    func testResizeFromTheBottomRightCancels() {
        var tracker = startedTracker()
        tracker.update(
            windowFrame: CGRect(x: 100, y: 100, width: 820, height: 600),
            pointer: CGPoint(x: 420, y: 110)
        )
        XCTAssertEqual(tracker.state, .cancelled)
    }

    func testResizeFromTheTopLeftCancelsEvenThoughTheOriginMoves() {
        var tracker = startedTracker()
        tracker.update(
            windowFrame: CGRect(x: 90, y: 90, width: 810, height: 610),
            pointer: CGPoint(x: 390, y: 100)
        )
        XCTAssertEqual(tracker.state, .cancelled)
    }

    func testStaysPendingWhileThePointerHasBarelyMoved() {
        var tracker = startedTracker()
        tracker.update(windowFrame: frame, pointer: CGPoint(x: 430, y: 110))
        XCTAssertEqual(tracker.state, .pending)
    }

    func testDraggingSomethingElseOverAWindowCancels() {
        var tracker = startedTracker()
        tracker.update(windowFrame: frame, pointer: CGPoint(x: 500, y: 110))
        XCTAssertEqual(tracker.state, .cancelled)
    }

    func testCancelledDragIgnoresLaterMovement() {
        var tracker = startedTracker()
        tracker.cancel()
        tracker.update(windowFrame: frame.offsetBy(dx: 50, dy: 0), pointer: pointer)
        XCTAssertEqual(tracker.state, .cancelled)
    }

    func testMovingDragIgnoresLaterUpdates() {
        var tracker = startedTracker()
        tracker.update(windowFrame: frame.offsetBy(dx: 12, dy: 0), pointer: pointer)
        tracker.update(
            windowFrame: CGRect(x: 0, y: 0, width: 10, height: 10),
            pointer: CGPoint(x: 9000, y: 9000)
        )
        XCTAssertEqual(tracker.state, .moving)
    }

    func testResetReturnsToIdle() {
        var tracker = startedTracker()
        tracker.cancel()
        tracker.reset()
        XCTAssertEqual(tracker.state, .idle)
    }
}
