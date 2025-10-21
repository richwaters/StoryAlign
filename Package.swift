
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
        url: "https://codeberg.org/richwaters/whisper.cpp-static-binaries/releases/download/v1.8.2-static-xcframework/whisper-v1.8.2.xcframework.static.zip",
        checksum: "a8b3947d4b2b63d90fca71613aa0369180a68f80859318eacb66bc80b8daffe1"
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
