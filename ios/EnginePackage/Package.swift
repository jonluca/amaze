// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PrismRollEngine",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "PrismRoll", targets: ["PrismRoll"]),
        .executable(name: "MazeOptimalityBenchmark", targets: ["MazeOptimalityBenchmark"])
    ],
    dependencies: [.package(path: "../Packages/PrismOptimizer")],
    targets: [
        .target(name: "PrismRoll", dependencies: [
            .product(name: "CPrismOptimizer", package: "PrismOptimizer")
        ]),
        .executableTarget(name: "MazeOptimalityBenchmark", dependencies: [
            .product(name: "CPrismOptimizer", package: "PrismOptimizer")
        ]),
        .testTarget(name: "PrismRollTests", dependencies: ["PrismRoll"])
    ]
)
