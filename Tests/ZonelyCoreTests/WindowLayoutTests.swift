import XCTest
@testable import ZonelyCore

final class WindowLayoutTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    private let layout = WindowLayout(edgeThreshold: 10, cornerLength: 120)

    func testSplitsScreenIntoEqualHalves() {
        XCTAssertEqual(
            layout.frame(for: .leftHalf, in: screen),
            CGRect(x: 0, y: 0, width: 960, height: 1080)
        )
        XCTAssertEqual(
            layout.frame(for: .rightHalf, in: screen),
            CGRect(x: 960, y: 0, width: 960, height: 1080)
        )
        XCTAssertEqual(layout.frame(for: .fullScreen, in: screen), screen)
    }

    func testCreatesFourQuarterFrames() {
        XCTAssertEqual(
            layout.frame(for: .topLeft, in: screen),
            CGRect(x: 0, y: 540, width: 960, height: 540)
        )
        XCTAssertEqual(
            layout.frame(for: .topRight, in: screen),
            CGRect(x: 960, y: 540, width: 960, height: 540)
        )
        XCTAssertEqual(
            layout.frame(for: .bottomLeft, in: screen),
            CGRect(x: 0, y: 0, width: 960, height: 540)
        )
        XCTAssertEqual(
            layout.frame(for: .bottomRight, in: screen),
            CGRect(x: 960, y: 0, width: 960, height: 540)
        )
    }

    func testFramesFollowAnOffsetVisibleFrame() {
        let visibleFrame = CGRect(x: 1920, y: 100, width: 1000, height: 800)
        XCTAssertEqual(
            layout.frame(for: .topRight, in: visibleFrame),
            CGRect(x: 2420, y: 500, width: 500, height: 400)
        )
    }

    func testEdgesSelectHalvesAndFullScreen() {
        XCTAssertEqual(layout.region(at: CGPoint(x: 0, y: 540), in: screen), .leftHalf)
        XCTAssertEqual(layout.region(at: CGPoint(x: 10, y: 540), in: screen), .leftHalf)
        XCTAssertEqual(layout.region(at: CGPoint(x: 1915, y: 540), in: screen), .rightHalf)
        XCTAssertEqual(layout.region(at: CGPoint(x: 960, y: 1075), in: screen), .fullScreen)
    }

    func testPointerOnTheMaxEdgesStillCounts() {
        XCTAssertEqual(layout.region(at: CGPoint(x: 960, y: 1080), in: screen), .fullScreen)
        XCTAssertEqual(layout.region(at: CGPoint(x: 1920, y: 540), in: screen), .rightHalf)
    }

    func testCornersSelectQuartersFromEitherEdge() {
        XCTAssertEqual(layout.region(at: CGPoint(x: 5, y: 1000), in: screen), .topLeft)
        XCTAssertEqual(layout.region(at: CGPoint(x: 100, y: 1078), in: screen), .topLeft)
        XCTAssertEqual(layout.region(at: CGPoint(x: 1918, y: 1000), in: screen), .topRight)
        XCTAssertEqual(layout.region(at: CGPoint(x: 1850, y: 1078), in: screen), .topRight)
        XCTAssertEqual(layout.region(at: CGPoint(x: 5, y: 100), in: screen), .bottomLeft)
        XCTAssertEqual(layout.region(at: CGPoint(x: 100, y: 2), in: screen), .bottomLeft)
        XCTAssertEqual(layout.region(at: CGPoint(x: 1918, y: 100), in: screen), .bottomRight)
        XCTAssertEqual(layout.region(at: CGPoint(x: 1850, y: 2), in: screen), .bottomRight)
    }

    func testInteriorAndBottomEdgeSelectNothing() {
        XCTAssertNil(layout.region(at: CGPoint(x: 960, y: 540), in: screen))
        XCTAssertNil(layout.region(at: CGPoint(x: 11, y: 540), in: screen))
        // A window whose title bar sits near the top must not be maximized
        // just because the pointer is in the upper part of the screen.
        XCTAssertNil(layout.region(at: CGPoint(x: 960, y: 1000), in: screen))
        XCTAssertNil(layout.region(at: CGPoint(x: 960, y: 0), in: screen))
    }

    func testReturnsNilOutsideScreen() {
        XCTAssertNil(layout.region(at: CGPoint(x: -1, y: 540), in: screen))
        XCTAssertNil(layout.region(at: CGPoint(x: 960, y: 1081), in: screen))
    }

    func testRegionsOnASecondaryScreen() {
        let secondary = CGRect(x: 1920, y: -200, width: 2560, height: 1440)
        XCTAssertEqual(layout.region(at: CGPoint(x: 1922, y: 500), in: secondary), .leftHalf)
        XCTAssertEqual(layout.region(at: CGPoint(x: 3000, y: 1238), in: secondary), .fullScreen)
        XCTAssertEqual(layout.region(at: CGPoint(x: 4478, y: -150), in: secondary), .bottomRight)
    }
}

final class ScreenCoordinatesTests: XCTestCase {
    private let layout = WindowLayout()
    /// Primary screen is 1920x1080 at the AppKit origin.
    private let coordinates = ScreenCoordinates(primaryScreenHeight: 1080)

    func testConvertsOnThePrimaryScreen() {
        let visibleFrame = CGRect(x: 0, y: 25, width: 1920, height: 1030)

        XCTAssertEqual(
            coordinates.accessibilityFrame(for: layout.frame(for: .topLeft, in: visibleFrame)),
            CGRect(x: 0, y: 25, width: 960, height: 515)
        )
        XCTAssertEqual(
            coordinates.accessibilityFrame(for: layout.frame(for: .bottomRight, in: visibleFrame)),
            CGRect(x: 960, y: 540, width: 960, height: 515)
        )
    }

    func testConvertsOnATallerScreenToTheRight() {
        // Bottom-aligned with the primary screen, so its top is 360pt above.
        let visibleFrame = CGRect(x: 1920, y: 0, width: 2560, height: 1415)

        XCTAssertEqual(
            coordinates.accessibilityFrame(for: layout.frame(for: .fullScreen, in: visibleFrame)),
            CGRect(x: 1920, y: -335, width: 2560, height: 1415)
        )
    }

    func testConvertsOnAScreenAboveThePrimary() {
        let visibleFrame = CGRect(x: 0, y: 1080, width: 1920, height: 1055)

        XCTAssertEqual(
            coordinates.accessibilityFrame(for: layout.frame(for: .fullScreen, in: visibleFrame)),
            CGRect(x: 0, y: -1055, width: 1920, height: 1055)
        )
    }

    func testConvertsOnAScreenBelowAndLeftOfThePrimary() {
        let visibleFrame = CGRect(x: -1440, y: -900, width: 1440, height: 875)

        XCTAssertEqual(
            coordinates.accessibilityFrame(for: layout.frame(for: .leftHalf, in: visibleFrame)),
            CGRect(x: -1440, y: 1105, width: 720, height: 875)
        )
    }

    func testConversionRoundTrips() {
        let frame = CGRect(x: 1920, y: -335, width: 800, height: 600)
        XCTAssertEqual(
            coordinates.accessibilityFrame(for: coordinates.appKitFrame(for: frame)),
            frame
        )
    }
}
