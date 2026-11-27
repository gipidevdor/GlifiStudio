// swift-tools-version: 6.4
// SPDX-License-Identifier: BSD-3-Clause

import PackageDescription

let package = Package(
    name: "GlifiCore",
    platforms: [
        .macOS("27.0"),
        .iOS("27.0"),
    ],
    products: [
        .library(name: "GlifiCore", targets: ["GlifiCore"]),
        .library(name: "GlifiKit", targets: ["GlifiKit"]),
        .executable(name: "GlifiCLI", targets: ["GlifiCLI"]),
        .executable(name: "GlifiRecoveryHarness", targets: ["GlifiRecoveryHarness"]),
        .executable(name: "GlifiBenchmark", targets: ["GlifiBenchmark"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/cucumberswift/CucumberSwift.git", exact: "6.9.0", traits: [])
    ],
    targets: [
        .target(
            name: "GlifiCore",
            cSettings: [.define("ACCELERATE_NEW_LAPACK")],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .target(name: "GlifiKit", dependencies: ["GlifiCore"]),
        .executableTarget(name: "GlifiCLI", dependencies: ["GlifiKit"]),
        .executableTarget(name: "GlifiRecoveryHarness", dependencies: ["GlifiCore"]),
        .executableTarget(name: "GlifiBenchmark", dependencies: ["GlifiCore"]),
        .target(
            name: "GlifiBenchmarkTestSupport",
            path: "Tests/GlifiBenchmarkTestSupport"
        ),
        .testTarget(
            name: "GlifiCoreTests", dependencies: ["GlifiCore", "GlifiBenchmarkTestSupport"]),
        .testTarget(
            name: "GlifiKitTests", dependencies: ["GlifiKit", "GlifiBenchmarkTestSupport"]),
        .testTarget(
            name: "GlifiBDDTests",
            dependencies: [
                "GlifiKit",
                .product(name: "CucumberSwiftTesting", package: "CucumberSwift"),
            ],
            exclude: ["Features"],
            plugins: [
                .plugin(name: "CucumberSwiftTestingPlugin", package: "CucumberSwift")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
