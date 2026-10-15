// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Spooterfy",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Spooterfy",
            path: "Sources/Spooterfy",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
