// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PocketTTSClone",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PocketTTSClone",
            targets: ["PocketTTSClone"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PocketTTSClone",
            dependencies: [],
            path: "PocketTTSClone",
            resources: [
                .process("Resources"),
                .process("Assets.xcassets")
            ],
            cSettings: [
                .headerSearchPath("Bridging")
            ],
            linkerSettings: [
                .linkedLibrary("c++"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("UIKit")
            ]
        )
    ]
)
