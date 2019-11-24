// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SSH",
    products: [
        .library(
            name: "SSH",
            targets: ["SSH"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Lavmint/spm-libssh.git", .branch("master"))
    ],
    targets: [
        .target(
            name: "SSH",
            dependencies: ["libssh"]),
        .testTarget(
            name: "SSHTests",
            dependencies: ["SSH"]),
    ]
)
