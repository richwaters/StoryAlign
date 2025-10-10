
// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "StoryAlign",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "StoryAlignCore",
            targets: ["StoryAlignCore"]
        ),
        .executable(
            name: "storyalign",
            targets: ["StoryAlignCli"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git",       from: "0.9.12"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git",            from: "2.6.0"),
    ],
    targets: [
        .target(
            name: "StoryAlignCore",
            dependencies: [
                "ZIPFoundation",
                "SwiftSoup",
                "WhisperFramework",
            ],
            swiftSettings: [
                .enableExperimentalFeature("Extern")
            ],
            linkerSettings: [
                .linkedFramework("CoreML"),
                .linkedFramework("CoreAudio"),
            ]
        ),

        .executableTarget(
            name: "StoryAlignCli",
            dependencies: [
                "StoryAlignCore",
            ],

        ),

        .testTarget(
            name: "StoryAlignTests",
            dependencies: [
                "StoryAlignCore"
            ],
        ),
        .testTarget(
            name: "StoryAlignCliTests",
            dependencies: [
                "StoryAlignCore"
            ],
            path : "Tests/StoryAlignCliTests",
            exclude: [
                "StoryAlignCli/StoryAlignMain.swift"
            ],
            sources: [
                "."
            ],
        ),

        .binaryTarget(
            name: "WhisperFramework",
            url: "https://github.com/richwaters/whisper.cpp/releases/download/v1.7.6-static-xcframework/whisper-v1.7.6.xcframework.static.zip",
            checksum: "77ee20de9c837fd66e555fa1bb3658c6889cfeee86cd5a101a1b141f6e97c4c9"
        ),
        
        .executableTarget(
            name: "smilcheck",
            dependencies: [
                "ZIPFoundation",
                "SwiftSoup"
            ],
            path:"Sources/smilcheck",

        ),
        
    ]
)
