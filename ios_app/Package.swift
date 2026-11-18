// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RuneLiteMobile",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "RuneLiteCore",
            targets: ["RuneLiteCore"]
        ),
        .executable(
            name: "RuneLiteMobile",
            targets: ["RuneLiteMobile"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "RuneLiteCore",
            dependencies: [],
            path: "Sources",
            exclude: ["App/AppDelegate.swift", "App/SceneDelegate.swift", "Injection/DylibEntry.c", "Injection/MetalHook.m"]
        ),
        .executableTarget(
            name: "RuneLiteMobile",
            dependencies: ["RuneLiteCore"],
            path: "Sources/App"
        )
    ]
)
