// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Blueprints",
    platforms: [
        .macOS(.v15), .iOS(.v17),
    ],
    products: [
        .library(
            name: "Blueprints",
            targets: [
                "Handlebars"
            ]),
        .executable(
            name: "blue",
            targets: ["blue"]),
    ],
    dependencies: [
//        .package(path: "/Users/jason/dev/workshop/ThirdParty/swift-html"),
//        .package(url: "https://github.com/coenttb/pointfree-html.git", from: "2.0.0"),
//        .package(url: "https://github.com/pointfreeco/swift-html", from: "0.5.0"),
//        .package(url: "https://github.com/coenttb/swift-html.git", from: "0.3.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Handlebars"),
        .testTarget(
            name: "HandlebarsTests",
            dependencies: [
                "Handlebars",
                "blue",
            ]
        ),
        .executableTarget(
            name: "blue",
            dependencies: [
                "Handlebars",
//                .product(name: "HTML", package: "swift-html"),
//                .product(name: "Html", package: "swift-html"),
            ]
        ),
    ]
)
