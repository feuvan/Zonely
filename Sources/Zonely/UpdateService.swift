import AppKit
import CryptoKit
import Foundation
import ZonelyCore

struct AvailableUpdate: Sendable {
    let version: SemanticVersion
    let tagName: String
    let releaseURL: URL
    let notes: String
    let downloadURL: URL
    let checksumURL: URL?
}

final class UpdateService {
    private struct GitHubRelease: Decodable {
        let tagName: String
        let htmlURL: URL
        let body: String?
        let draft: Bool
        let prerelease: Bool
        let assets: [ReleaseAsset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case body
            case draft
            case prerelease
            case assets
        }
    }

    private struct ReleaseAsset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    enum UpdateError: LocalizedError {
        case invalidRelease(String)
        case requestFailed(String)
        case unavailableOutsideAppBundle
        case unsupportedArchive
        case installationFailed(String)

        var errorDescription: String? {
            switch self {
            case let .invalidRelease(message):
                return "The latest Zonely release is invalid: \(message)"
            case let .requestFailed(message):
                return "Could not check for Zonely updates: \(message)"
            case .unavailableOutsideAppBundle:
                return "Updates can only be installed when Zonely is running from a .app bundle."
            case .unsupportedArchive:
                return "The downloaded release does not contain a valid Zonely.app."
            case let .installationFailed(message):
                return "Could not install the Zonely update: \(message)"
            }
        }
    }

    static let repository = "feuvan/Zonely"
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

        let release: GitHubRelease
        do {
            release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        } catch {
            throw UpdateError.requestFailed("Could not parse the GitHub Release response.")
        }

        guard !release.draft, !release.prerelease else { return nil }
        guard let version = SemanticVersion(release.tagName) else {
            throw UpdateError.invalidRelease("tag \(release.tagName) is not semantic versioning.")
        }
        guard version > currentVersion else { return nil }

        let architecture = ProcessInfo.processInfo.machineArchitecture
        let acceptedNames = [
            "Zonely-\(release.tagName)-macos-\(architecture).zip",
            "Zonely-\(version)-macos-\(architecture).zip",
            "Zonely-\(release.tagName)-macos.zip",
            "Zonely-\(version)-macos.zip"
        ]
        guard let archive = release.assets.first(where: { acceptedNames.contains($0.name) }) else {
            return nil
        }

        let checksumURL = release.assets.first {
            $0.name == "\(archive.name).sha256"
        }?.browserDownloadURL

        return AvailableUpdate(
            version: version,
            tagName: release.tagName,
            releaseURL: release.htmlURL,
            notes: release.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            downloadURL: archive.browserDownloadURL,
            checksumURL: checksumURL
        )
    }

    /// Downloads and stages an update. The caller terminates the app after this returns successfully.
    func downloadAndScheduleInstall(_ update: AvailableUpdate) async throws {
        guard update.version > currentVersion else {
            throw UpdateError.invalidRelease("the available version is not newer than the installed version.")
        }

        let currentAppURL = Bundle.main.bundleURL.standardizedFileURL
        guard currentAppURL.pathExtension == "app" else {
            throw UpdateError.unavailableOutsideAppBundle
        }
        guard FileManager.default.isWritableFile(atPath: currentAppURL.deletingLastPathComponent().path) else {
            throw UpdateError.installationFailed("the folder containing Zonely.app is not writable.")
        }

        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("Zonely-update-\(UUID().uuidString)", isDirectory: true)
        let archiveURL = temporaryRoot.appendingPathComponent("update.zip")
        let extractionURL = temporaryRoot.appendingPathComponent("extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: archiveURL)
        }

        do {
            let archiveData = try await downloadData(from: update.downloadURL)
            try archiveData.write(to: archiveURL, options: .atomic)

            if let checksumURL = update.checksumURL {
                let checksumData = try await downloadData(from: checksumURL)
                try verifyChecksum(of: archiveData, using: checksumData)
            }

            try FileManager.default.createDirectory(at: extractionURL, withIntermediateDirectories: true)
            try runDittoExtract(archiveURL: archiveURL, destinationURL: extractionURL)

            guard let replacementAppURL = findAppBundle(in: extractionURL) else {
                throw UpdateError.unsupportedArchive
            }

            try scheduleReplacement(
                currentAppURL: currentAppURL,
                replacementAppURL: replacementAppURL,
                temporaryRoot: temporaryRoot
            )
        } catch let error as UpdateError {
            throw error
        } catch {
            throw UpdateError.installationFailed(error.localizedDescription)
        }
    }

    static func installedVersion() -> SemanticVersion {
        if let value = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           let version = SemanticVersion(value) {
            return version
        }
        return SemanticVersion("0.1.0")!
    }

    private func downloadData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Zonely/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw UpdateError.installationFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw UpdateError.installationFailed("download returned HTTP \(statusCode).")
        }
        return data
    }

    private func verifyChecksum(of data: Data, using checksumData: Data) throws {
        guard let checksumText = String(data: checksumData, encoding: .utf8),
              let expected = checksumText.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" }).first,
              expected.count == 64 else {
            throw UpdateError.installationFailed("the SHA-256 checksum file is invalid.")
        }

        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actual.caseInsensitiveCompare(String(expected)) == .orderedSame else {
            throw UpdateError.installationFailed("the downloaded archive failed its SHA-256 check.")
        }
    }

    private func runDittoExtract(archiveURL: URL, destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archiveURL.path, destinationURL.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UpdateError.installationFailed("could not extract the downloaded archive.")
        }
    }

    private func findAppBundle(in directoryURL: URL) -> URL? {
        let directURL = directoryURL.appendingPathComponent("Zonely.app", isDirectory: true)
        if FileManager.default.fileExists(atPath: directURL.path) {
            return directURL
        }

        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let url as URL in enumerator where url.lastPathComponent == "Zonely.app" {
            return url
        }
        return nil
    }

    private func scheduleReplacement(
        currentAppURL: URL,
        replacementAppURL: URL,
        temporaryRoot: URL
    ) throws {
        let scriptURL = temporaryRoot.appendingPathComponent("install-update.zsh")
        let script = """
        #!/bin/zsh
        set -euo pipefail

        old_app="$1"
        new_app="$2"
        process_id="$3"
        temporary_root="$4"

        for _ in {1..60}; do
            if ! kill -0 "$process_id" 2>/dev/null; then
                break
            fi
            /bin/sleep 1
        done

        /bin/rm -rf "$old_app"
        /bin/mv "$new_app" "$old_app"
        /usr/bin/open "$old_app"
        /bin/rm -f "$0"
        /bin/rm -rf "$temporary_root"
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: scriptURL.path
        )

        let installer = Process()
        installer.executableURL = URL(fileURLWithPath: "/bin/zsh")
        installer.arguments = [
            scriptURL.path,
            currentAppURL.path,
            replacementAppURL.path,
            String(ProcessInfo.processInfo.processIdentifier),
            temporaryRoot.path
        ]
        installer.currentDirectoryURL = temporaryRoot
        try installer.run()
    }
}

private extension ProcessInfo {
    var machineArchitecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return processInfo.environment["HOSTTYPE"] ?? "unknown"
        #endif
    }
}
