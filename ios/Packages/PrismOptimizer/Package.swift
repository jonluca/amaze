// swift-tools-version: 6.0
import PackageDescription

// Build the reviewed source subset on each destination; no downloaded binaries.
let includePaths = [
    "include", "include/interfaces", "include/io", "include/io/filereaderlp",
    "include/ipm", "include/ipm/ipx", "include/ipm/basiclu", "include/lp_data",
    "include/mip", "include/model", "include/parallel", "include/pdlp",
    "include/pdlp/cupdlp", "include/pdlp/hipdlp", "include/presolve",
    "include/qpsolver", "include/simplex", "include/test_kkt", "include/util",
    "include/ipm/hipo", "include/ipm/hipo/auxiliary",
    "include/ipm/hipo/factorhighs", "include/ipm/hipo/ipm"
]

let package = Package(
    name: "PrismOptimizer",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "CPrismOptimizer", type: .static, targets: ["CPrismOptimizer"])],
    targets: [
        .target(
            name: "CHighs",
            sources: ["src"],
            publicHeadersPath: "include",
            cSettings: includePaths.map { .headerSearchPath($0) },
            cxxSettings: includePaths.map { .headerSearchPath($0) } + [
                .define("HIGHS_EXTRAS_VERSION", to: "\"1.15.1\""),
                .define("LIBHIGHS_STATIC_DEFINE")
            ]
        ),
        .target(
            name: "CPrismOptimizer",
            dependencies: ["CHighs"],
            publicHeadersPath: "include"
        )
    ],
    cxxLanguageStandard: .cxx17
)
