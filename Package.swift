// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Morning",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Morning", targets: ["MorningFolder"])
    ],
    targets: [
        .executableTarget(
            name: "MorningFolder",
            dependencies: ["MorningNarration"],
            path: "Sources/MorningFolder",
            exclude: [
                "App/Info.plist",
                "App/Assets"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "MorningNarration",
            path: "Sources/MorningNarration"
        ),
        .executableTarget(
            name: "NarrationRegression",
            dependencies: ["MorningNarration"],
            path: "Tests/NarrationRegression"
        )
    ]
)
