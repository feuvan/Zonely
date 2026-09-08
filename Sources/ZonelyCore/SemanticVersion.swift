import Foundation

public struct SemanticVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prerelease: [String]

    public init?(_ rawValue: String) {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.first == "v" || value.first == "V" {
            value.removeFirst()
        }

        let withoutBuildMetadata = value.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false)[0]
        let versionParts = withoutBuildMetadata.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let numbers = versionParts[0].split(separator: ".", omittingEmptySubsequences: false)
        guard numbers.count == 3,
              numbers.allSatisfy({ $0.allSatisfy { $0.isNumber } }),
              let major = Int(numbers[0]),
              let minor = Int(numbers[1]),
              let patch = Int(numbers[2]) else {
            return nil
        }

        let prerelease = versionParts.count == 2
            ? versionParts[1].split(separator: ".", omittingEmptySubsequences: false).map(String.init)
            : []
        guard prerelease.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" } }) else {
            return nil
        }

        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prerelease
    }

    public var description: String {
        var value = "\(major).\(minor).\(patch)"
        if !prerelease.isEmpty {
            value += "-" + prerelease.joined(separator: ".")
        }
        return value
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        return comparePrerelease(lhs.prerelease, rhs.prerelease) == .orderedAscending
    }

    private static func comparePrerelease(_ lhs: [String], _ rhs: [String]) -> ComparisonResult {
        if lhs.isEmpty && rhs.isEmpty { return .orderedSame }
        if lhs.isEmpty { return .orderedDescending }
        if rhs.isEmpty { return .orderedAscending }

        for (left, right) in zip(lhs, rhs) {
            if left == right { continue }

            let leftNumber = Int(left)
            let rightNumber = Int(right)
            if let leftNumber, let rightNumber {
                return leftNumber < rightNumber ? .orderedAscending : .orderedDescending
            }
            if leftNumber != nil { return .orderedAscending }
            if rightNumber != nil { return .orderedDescending }
            return left < right ? .orderedAscending : .orderedDescending
        }

        if lhs.count == rhs.count { return .orderedSame }
        return lhs.count < rhs.count ? .orderedAscending : .orderedDescending
    }
}
