// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Codetalker",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Codetalker",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation")
            ]
        )
    ]
)
