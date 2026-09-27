// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Readmate",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Readmate", path: "Sources/Readmate")
    ]
)
