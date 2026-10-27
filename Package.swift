// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DisplayVibrance",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DisplayVibrance",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ColorSync"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
