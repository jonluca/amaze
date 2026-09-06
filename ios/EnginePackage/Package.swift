// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PrismRollEngine",
    platforms: [.macOS(.v13)],
    products: [.library(name: "PrismRoll", targets: ["PrismRoll"])],
    targets: [
        .target(name: "PrismRoll"),
        .testTarget(name: "PrismRollTests", dependencies: ["PrismRoll"])
    ]
)
