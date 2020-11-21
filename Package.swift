// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RealmStorage",
    products: [
        .library(
            name: "RealmStorage",
            targets: ["RealmStorage"]
        ),
        .library(
            name: "PredicateFlow",
            targets: ["PredicateFlow"]
        )
    ],
    dependencies: [
        .package(
            name: "Realm",
            url: "https://github.com/realm/realm-cocoa.git",
            from: "10.0.0"
        ),
        .package(
            name: "Sourcery",
            url: "https://github.com/krzysztofzablocki/Sourcery.git",
            from: "1.0.0"
        ),
        .package(
            name: "KeychainSwift",
            url: "https://github.com/evgenyneu/keychain-swift.git",
            from: "19.0.0"
        )
    ],
    targets: [
        .target(
            name: "PredicateFlow",
            dependencies: [
                .product(
                    name: "Realm",
                    package: "Realm"
                ),
                .product(
                    name: "RealmSwift",
                    package: "Realm"
                )
            ]
        ),
        .target(
            name: "RealmStorage",
            dependencies: [
                "PredicateFlow",
                .product(
                    name: "Realm",
                    package: "Realm"
                ),
                .product(
                    name: "RealmSwift",
                    package: "Realm"
                ),
                .product(
                    name: "KeychainSwift",
                    package: "KeychainSwift"
                )
            ]
        ),
        .testTarget(
            name: "RealmStorageTests",
            dependencies: [
                "RealmStorage",
                .product(
                    name: "Realm",
                    package: "Realm"
                ),
                .product(
                    name: "RealmSwift",
                    package: "Realm"
                )
            ]
        )
    ]
)
