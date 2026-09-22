// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SafeAwake",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SafeAwake", targets: ["SafeAwake"]),
        .library(name: "SafeAwakeCore", targets: ["SafeAwakeCore"])
    ],
    targets: [
        .target(
            name: "SafeAwakeCore",
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .executableTarget(
            name: "SafeAwake",
            dependencies: ["SafeAwakeCore"]
        ),
        .testTarget(
            name: "SafeAwakeCoreTests",
            dependencies: ["SafeAwakeCore"]
        )
    ]
)
