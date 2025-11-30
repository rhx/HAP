// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "HAP",
    platforms: [
        .macOS(.v11),
    ],
    products: [
        .library(name: "HAP", targets: ["HAP"]),
        .executable(name: "hap-demo", targets: ["HAPDemo"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Bouke/SRP.git", from: "3.2.0"),
        .package(url: "https://github.com/crossroadlabs/Regex.git", from: "1.1.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.13.0"),
        .package(url: "https://github.com/apple/swift-log.git", Version("0.0.0") ..< Version("2.0.0")),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "1.1.0"),
        .package(url: "https://github.com/rhx/NetService.git", branch: "main"),
    ],
    targets: [
        .target(name: "CQRCode", exclude: ["LICENSE.txt"]),
        .target(name: "COperatingSystem", exclude: ["LICENSE"]),
        .target(name: "VaporHTTP",
                dependencies: [
                    .product(name: "NIO", package: "swift-nio"),
                    .product(name: "NIOHTTP1", package: "swift-nio"),
                    .product(name: "NIOFoundationCompat", package: "swift-nio"),
                    "COperatingSystem",
                ],
                exclude: ["LICENSE"]),
        .target(name: "HAP",
                dependencies: [
                    "SRP",
                    .product(name: "Logging", package: "swift-log"),
                    "Regex",
                    "CQRCode",
                    "VaporHTTP",
                    .product(name: "Crypto", package: "swift-crypto"),
                    .product(name: "NetService", package: "NetService", condition: .when(platforms: [.linux]))
                ],
                exclude: ["Base/Predefined/README"]),
        .executableTarget(name: "HAPDemo",
                          dependencies: [
                            "HAP",
                            .product(name: "Logging", package: "swift-log")
                          ]),
        .testTarget(name: "HAPTests", dependencies: ["HAP"]),
    ]
)

#if os(macOS)
    package.products.append(.executable(name: "hap-update", targets: ["HAPInspector"]))
    package.targets.append(.executableTarget(name: "HAPInspector"))
#endif
