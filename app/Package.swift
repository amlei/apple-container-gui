// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ContainerGUI",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing", from: "6.3.2")
    ],
    targets: [
        .target(
            name: "ExceptionCatcher",
            path: "ExceptionCatcher"
        ),
        .target(
            name: "ContainerGUI",
            dependencies: ["ExceptionCatcher"],
            path: "ContainerGUI",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "ContainerApp",
            dependencies: ["ContainerGUI"],
            path: "ContainerApp",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ContainerGUITests",
            dependencies: [
                "ContainerGUI",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/ContainerGUITests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
