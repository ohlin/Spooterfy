// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Spooterfy",
    platforms: [.macOS(.v26)],
    dependencies: [
        // Vendored subset of Google's Material Color Utilities; see its README.
        .package(path: "Packages/MaterialColorUtilities"),
    ],
    targets: [
        .executableTarget(
            name: "Spooterfy",
            dependencies: ["MaterialColorUtilities"],
            path: "Sources/Spooterfy",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
