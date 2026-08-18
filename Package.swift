// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RealmStorage",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "RealmStorage",
            targets: ["RealmStorage"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/realm/realm-swift.git",
            .upToNextMajor(from: "20.0.5")
        )
    ],
    targets: [
        .target(
            name: "RealmStorage",
            dependencies: [
                .product(name: "RealmSwift", package: "realm-swift")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "RealmStorageTests",
            dependencies: ["RealmStorage"],
            resources: [
                .copy("Fixtures")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
