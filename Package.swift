// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "islo",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "islo", path: "Sources/islo")
    ]
)
