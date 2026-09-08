// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Zonely",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Zonely", targets: ["Zonely"])
    ],
    targets: [
        .target(
            name: "ZonelyCore",
            path: "Sources/ZonelyCore"
        ),
        .executableTarget(
            name: "Zonely",
            dependencies: ["ZonelyCore"],
            path: "Sources/Zonely"
        ),
        .testTarget(
            name: "ZonelyCoreTests",
            dependencies: ["ZonelyCore"],
            path: "Tests/ZonelyCoreTests"
        )
    ]
)
