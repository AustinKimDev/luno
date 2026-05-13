// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Luno",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "LunoEngineCore", targets: ["LunoEngineCore"]),
        .executable(name: "Luno", targets: ["LunoApp"])
    ],
    targets: [
        .target(name: "LunoEngineCore"),
        .executableTarget(
            name: "LunoApp",
            dependencies: ["LunoEngineCore"],
            resources: [
                .copy("Resources/SamplePackages")
            ]
        ),
        .testTarget(name: "LunoEngineCoreTests", dependencies: ["LunoEngineCore"])
    ]
)
