// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PanteaoClientSwift",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PanteaoClientSwift",
            path: "."
        )
    ]
)
