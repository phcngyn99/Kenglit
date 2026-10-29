// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Kenglish",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "KenglishCore", targets: ["KenglishCore"]),
        .executable(name: "KenglishCoreChecks", targets: ["KenglishCoreChecks"]),
        .executable(name: "Kenglish", targets: ["KenglishApp"]),
    ],
    targets: [
        .target(name: "KenglishCore"),
        .executableTarget(
            name: "KenglishCoreChecks",
            dependencies: ["KenglishCore"]
        ),
        .executableTarget(
            name: "KenglishApp",
            dependencies: ["KenglishCore"],
            path: "Sources/KenglishApp",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ]
)
