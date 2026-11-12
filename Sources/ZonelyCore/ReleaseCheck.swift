import Foundation

public struct AvailableUpdate: Equatable, Sendable {
    public let version: SemanticVersion
    public let releaseURL: URL
    public let notes: String
}

public enum ReleaseCheckError: LocalizedError, Equatable {
    case unreadableResponse
    case invalidTag(String)

    public var errorDescription: String? {
        switch self {
        case .unreadableResponse:
            return "Could not read the GitHub Release response."
        case let .invalidTag(tag):
            return "The latest release tag \(tag) is not a version number."
        }
    }
}

public enum ReleaseCheck {
    private struct Release: Decodable {
        let tagName: String
        let htmlURL: URL
        let body: String?

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case body
        }
    }

    /// Reads a GitHub "latest release" response and returns the release if it
    /// is newer than `currentVersion`.
    public static func availableUpdate(
        fromLatestRelease data: Data,
        currentVersion: SemanticVersion
    ) throws -> AvailableUpdate? {
        guard let release = try? JSONDecoder().decode(Release.self, from: data) else {
            throw ReleaseCheckError.unreadableResponse
        }
        guard let version = SemanticVersion(release.tagName) else {
            throw ReleaseCheckError.invalidTag(release.tagName)
        }
        guard version > currentVersion else { return nil }

        return AvailableUpdate(
            version: version,
            releaseURL: release.htmlURL,
            notes: release.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
    }
}
