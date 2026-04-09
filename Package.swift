// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SpadesOffline",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "SpadesCore", targets: ["SpadesCore"]),
        .executable(name: "SpadesOfflineApp", targets: ["SpadesOfflineApp"])
    ],
    targets: [
        .target(name: "SpadesCore"),
        .executableTarget(name: "SpadesOfflineApp", dependencies: ["SpadesCore"]),
        .testTarget(name: "SpadesCoreTests", dependencies: ["SpadesCore"])
    ]
)
