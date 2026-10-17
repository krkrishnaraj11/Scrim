// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Scrim",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Scrim",
            path: "Sources/Scrim"
        )
    ]
)
