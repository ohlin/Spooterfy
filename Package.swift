// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Spooterfy",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Spooterfy",
            path: "Sources/Spooterfy",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
