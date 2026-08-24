// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ContainerGUI",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    targets: [
        .target(
            name: "ExceptionCatcher",
            path: "ExceptionCatcher"
        ),
        .executableTarget(
            name: "ContainerGUI",
            dependencies: ["ExceptionCatcher"],
            path: "ContainerGUI",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
