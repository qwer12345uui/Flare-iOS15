// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SwiftUIBackports",
    platforms: [
        .iOS(.v15),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "SwiftUIBackports",
            targets: ["SwiftUIBackports"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftUIBackports",
            path: "Sources/SwiftUIBackports"
        ),
    ]
)
