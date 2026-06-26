// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HeadInClouds",
    platforms: [
        .iOS(.v16),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "HeadInCloudsCore",
            targets: ["HeadInCloudsCore"]
        ),
        .executable(
            name: "HeadInCloudsCoreChecks",
            targets: ["HeadInCloudsCoreChecks"]
        )
    ],
    targets: [
        .target(
            name: "HeadInCloudsCore"
        ),
        .executableTarget(
            name: "HeadInCloudsCoreChecks",
            dependencies: ["HeadInCloudsCore"]
        )
    ]
)
