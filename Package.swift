// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "auc-native",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AUCNative", targets: ["AUCNativeApp"]),
        .library(name: "AUCNativeCore", targets: ["AUCNativeCore"])
    ],
    targets: [
        .target(
            name: "AUCNativeCore",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .executableTarget(
            name: "AUCNativeApp",
            dependencies: ["AUCNativeCore"],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ]
        ),
        .testTarget(
            name: "AUCNativeCoreTests",
            dependencies: ["AUCNativeCore"]
        )
    ]
)
