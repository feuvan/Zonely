import XCTest
@testable import ZonelyCore

final class SemanticVersionTests: XCTestCase {
    func testComparesReleaseVersionsWithVPrefix() {
        XCTAssertTrue(SemanticVersion("v0.1.1")! > SemanticVersion("0.1.0")!)
        XCTAssertFalse(SemanticVersion("0.1.0")! > SemanticVersion("v0.1.0")!)
        XCTAssertTrue(SemanticVersion("1.0.0")! > SemanticVersion("0.9.9")!)
        XCTAssertTrue(SemanticVersion("0.10.0")! > SemanticVersion("0.9.0")!)
    }

    func testDescriptionOmitsThePrefix() {
        XCTAssertEqual(SemanticVersion(" v1.2.3\n")?.description, "1.2.3")
    }

    func testRejectsInvalidVersions() {
        XCTAssertNil(SemanticVersion("1.2"))
        XCTAssertNil(SemanticVersion("1.2.3.4"))
        XCTAssertNil(SemanticVersion("release-1.2.3"))
        XCTAssertNil(SemanticVersion("1.2.3-beta.1"))
        XCTAssertNil(SemanticVersion("1..3"))
        XCTAssertNil(SemanticVersion(""))
    }
}

final class ReleaseCheckTests: XCTestCase {
    private func release(tag: String, body: String? = "Notes\n") -> Data {
        var object: [String: Any] = [
            "tag_name": tag,
            "html_url": "https://github.com/feuvan/Zonely/releases/tag/\(tag)",
            "draft": false,
            "prerelease": false,
            "assets": [String]()
        ]
        if let body {
            object["body"] = body
        }
        return try! JSONSerialization.data(withJSONObject: object)
    }

    func testReturnsANewerRelease() throws {
        let update = try ReleaseCheck.availableUpdate(
            fromLatestRelease: release(tag: "v0.2.0"),
            currentVersion: SemanticVersion("0.1.2")!
        )
        XCTAssertEqual(update?.version, SemanticVersion("0.2.0"))
        XCTAssertEqual(
            update?.releaseURL,
            URL(string: "https://github.com/feuvan/Zonely/releases/tag/v0.2.0")
        )
        XCTAssertEqual(update?.notes, "Notes")
    }

    func testReturnsNilForTheInstalledOrAnOlderRelease() throws {
        let current = SemanticVersion("0.1.2")!
        XCTAssertNil(try ReleaseCheck.availableUpdate(fromLatestRelease: release(tag: "v0.1.2"), currentVersion: current))
        XCTAssertNil(try ReleaseCheck.availableUpdate(fromLatestRelease: release(tag: "v0.1.1"), currentVersion: current))
    }

    func testMissingNotesBecomeEmpty() throws {
        let update = try ReleaseCheck.availableUpdate(
            fromLatestRelease: release(tag: "v0.2.0", body: nil),
            currentVersion: SemanticVersion("0.1.2")!
        )
        XCTAssertEqual(update?.notes, "")
    }

    func testRejectsATagThatIsNotAVersion() {
        XCTAssertThrowsError(
            try ReleaseCheck.availableUpdate(
                fromLatestRelease: release(tag: "nightly"),
                currentVersion: SemanticVersion("0.1.2")!
            )
        ) { error in
            XCTAssertEqual(error as? ReleaseCheckError, .invalidTag("nightly"))
        }
    }

    func testRejectsAnUnreadableResponse() {
        XCTAssertThrowsError(
            try ReleaseCheck.availableUpdate(
                fromLatestRelease: Data("{\"message\":\"Not Found\"}".utf8),
                currentVersion: SemanticVersion("0.1.2")!
            )
        ) { error in
            XCTAssertEqual(error as? ReleaseCheckError, .unreadableResponse)
        }
    }
}
