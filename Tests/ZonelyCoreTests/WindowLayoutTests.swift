import XCTest
@testable import ZonelyCore

final class WindowLayoutTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    private let layout = WindowLayout()

    func testSplitsScreenIntoEqualHalves() {
        XCTAssertEqual(
            layout.frame(for: .leftHalf, in: screen),
            CGRect(x: 0, y: 0, width: 960, height: 1080)
        )
        XCTAssertEqual(
            layout.frame(for: .rightHalf, in: screen),
            CGRect(x: 960, y: 0, width: 960, height: 1080)
        )
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

    func testMapsPointsToRegions() {
        XCTAssertEqual(
            layout.region(containing: CGPoint(x: 100, y: 900), in: screen),
            .topLeft
        )
        XCTAssertEqual(
            layout.region(containing: CGPoint(x: 1800, y: 900), in: screen),
            .topRight
        )
        XCTAssertEqual(
            layout.region(containing: CGPoint(x: 100, y: 100), in: screen),
            .bottomLeft
        )
        XCTAssertEqual(
            layout.region(containing: CGPoint(x: 1800, y: 100), in: screen),
            .bottomRight
        )
        XCTAssertEqual(
            layout.region(containing: CGPoint(x: 100, y: 540), in: screen),
            .leftHalf
        )
        XCTAssertEqual(
            layout.region(containing: CGPoint(x: 1800, y: 540), in: screen),
            .rightHalf
        )
        XCTAssertEqual(
            layout.region(containing: CGPoint(x: 960, y: 900), in: screen),
            .fullScreen
        )
    }

    func testConvertsAppKitFrameToAccessibilityCoordinates() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let visibleFrame = CGRect(x: 0, y: 25, width: 1920, height: 1030)
        let converter = WindowCoordinateConverter()

        XCTAssertEqual(
            converter.accessibilityFrame(
                for: layout.frame(for: .topLeft, in: visibleFrame),
                in: screenFrame
            ),
            CGRect(x: 0, y: 25, width: 960, height: 515)
        )
        XCTAssertEqual(
            converter.accessibilityFrame(
                for: layout.frame(for: .bottomRight, in: visibleFrame),
                in: screenFrame
            ),
            CGRect(x: 960, y: 540, width: 960, height: 515)
        )
    }

    func testReturnsNilOutsideVisibleFrame() {
        XCTAssertNil(layout.region(containing: CGPoint(x: -1, y: 100), in: screen))
        XCTAssertNil(layout.region(containing: CGPoint(x: 960, y: 100), in: screen))
    }
}
