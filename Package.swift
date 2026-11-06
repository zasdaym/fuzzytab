// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FuzzyTab",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "FuzzyTabCore"),
        .executableTarget(name: "FuzzyTab", dependencies: ["FuzzyTabCore"]),
        .testTarget(name: "FuzzyTabCoreTests", dependencies: ["FuzzyTabCore"]),
    ],
    swiftLanguageModes: [.v5]
)
