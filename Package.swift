// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HWFengNiao",
    dependencies: [
        .package(name: "Rainbow", url: "https://github.com/onevcat/Rainbow.git", from: "3.1.1"),
        .package(name: "CommandLineKit", url: "https://github.com/benoit-pereira-da-silva/CommandLine.git", from: "4.0.0"),
        .package(name: "PathKit", url: "https://github.com/kylef/PathKit.git", from: "0.9.0"),
        .package(name: "Spectre", url: "https://github.com/kylef/Spectre.git", from: "0.9.2"),
        .package(name: "Nimble", url: "https://github.com/Quick/Nimble.git", from: "9.0.0"),
        .package(name: "Quick", url: "https://github.com/Quick/Quick.git", from: "3.1.2")
    ],
    targets: [
        .target(name: "HWFengNiaoKit", dependencies: ["Rainbow","PathKit"]),
        .target(name: "HWFengNiao", dependencies: ["CommandLineKit","HWFengNiaoKit"]),
        .testTarget(name: "HWFengNiaoTests",dependencies: ["HWFengNiaoKit","Spectre"] , exclude: ["Tests/Fixtures"])
    ]
)
