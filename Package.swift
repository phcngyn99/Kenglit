// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Kenglit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "KenglitCore", targets: ["KenglitCore"]),
        .executable(name: "KenglitCoreChecks", targets: ["KenglitCoreChecks"]),
        .executable(name: "Kenglit", targets: ["KenglitApp"]),
    ],
    targets: [
        .target(name: "KenglitCore"),
        .executableTarget(
            name: "KenglitCoreChecks",
            dependencies: ["KenglitCore"]
        ),
        .executableTarget(
            name: "KenglitApp",
            dependencies: ["KenglitCore"],
            path: "Sources/KenglitApp",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ]
)
