
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
            url: "https://github.com/richwaters/whisper.cpp/releases/download/v1.7.5-static-xcframework/whisper-v1.75.xcframework.static.zip",
            checksum: "139d7d61fc1a6ece5ffbfb811e147479883873dac4b3786856fea22050845e9c"
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
