// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BlinkBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "BlinkBarCore", targets: ["BlinkBarCore"]),
        .executable(name: "BlinkBar", targets: ["BlinkBar"])
    ],
    targets: [
        .target(
            name: "BlinkBarCore",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .executableTarget(
            name: "BlinkBar",
            dependencies: ["BlinkBarCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "BlinkBarCoreTests",
            dependencies: ["BlinkBarCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
