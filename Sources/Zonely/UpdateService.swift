import Foundation
import ZonelyCore

/// Checks GitHub Releases for a newer version.
///
/// Zonely only reports the new version and links to its release page. It does
/// not replace itself: the app is not code signed yet, so an in-place update
/// could not be verified and would lose the Accessibility permission.
final class UpdateService {
    enum UpdateError: LocalizedError {
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case let .requestFailed(message):
                return "Could not check for Zonely updates: \(message)"
            }
        }
    }

    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/feuvan/Zonely/releases/latest")!

    let currentVersion: SemanticVersion
    private let session: URLSession

    init(
        currentVersion: SemanticVersion = UpdateService.installedVersion(),
        session: URLSession = .shared
    ) {
        self.currentVersion = currentVersion
        self.session = session
    }

    func checkForUpdate() async throws -> AvailableUpdate? {
        var request = URLRequest(url: Self.latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Zonely/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw UpdateError.requestFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateError.requestFailed("GitHub returned an invalid response.")
        }
        guard httpResponse.statusCode == 200 else {
            throw UpdateError.requestFailed("GitHub returned HTTP \(httpResponse.statusCode).")
        }

        return try ReleaseCheck.availableUpdate(fromLatestRelease: data, currentVersion: currentVersion)
    }

    static func installedVersion() -> SemanticVersion {
        if let value = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           let version = SemanticVersion(value) {
            return version
        }
        // Development builds run outside an app bundle and have no version.
        return SemanticVersion("0.0.0")!
    }
}
