// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftAST",
    products: [
        .executable(name: "swift-ast", targets: ["SwiftAST"]),
        .library(name: "SwiftASTCore", type: .dynamic, targets: ["SwiftASTCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-package-manager.git", from: "0.3.0"),
    ],
    targets: [
        .target(
            name: "SwiftAST",
            dependencies: ["SwiftASTCore", "Utility"]),
        .target(
            name: "SwiftASTCore",
            dependencies: ["Utility"]
        ),
        .testTarget(
            name: "SwiftASTTests",
            dependencies: ["SwiftASTCore"]),
    ]
)
