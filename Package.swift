// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PanteaoClient",
    products: [
        .library(name: "PanteaoClient", targets: ["PanteaoClient"]),
    ],
    targets: [
        .target(name: "PanteaoClient", dependencies: [], path: "sdk/swift/Sources/PanteaoClient"),
    ]
)
