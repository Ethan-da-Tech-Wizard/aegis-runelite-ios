// swift-tools-version: 5.9
// ==============================================================================
// Program: Package.swift
// Programmer: Ethan-da-Tech-Wizard
// Last Modified: November 18, 2026
// Purpose: Swift Package Manager (SPM) Manifest for RuneLiteMobile.
//          Configures the build targets, platforms (iOS 16+), library products
//          (RuneLiteCore), and executable targets (RuneLiteMobile).
// ==============================================================================

// ==============================================================================
// Architecture Overview & Swift Package Manager:
// ==============================================================================
// The Swift Package Manager (SPM) is Apple's official tool for managing the
// distribution of Swift code. It is integrated directly with the Swift build
// system to automate downloading, compiling, and linking dependencies.
//
// Manifest Structure:
// - `platforms`: Specifies minimum deployment target (.iOS(.v16)).
// - `products`: Defines the vendor outputs (RuneLiteCore library and executable).
// - `targets`: Defines modules composed of source files with exclusions
//   for platform-specific entry points (UIKit AppDelegate/SceneDelegate).
// ==============================================================================

import PackageDescription

let package = Package(
    name: "RuneLiteMobile",
    // Minimum deployment target is iOS 16.
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
            // RuneLiteCore compiles the whole Sources/ tree except the UIKit entry points and the C/Objective-C injection stubs,
            // which cannot be built as part of a plain Swift package target.
            dependencies: [],
            path: "Sources",
            exclude: [
                "App/AppDelegate.swift",
                "App/SceneDelegate.swift",
                "Injection/DylibEntry.c",
                "Injection/MetalHook.m"
            ]
        ),
        // The app executable is built only from Sources/App and links against RuneLiteCore.
        .executableTarget(
            name: "RuneLiteMobile",
            dependencies: ["RuneLiteCore"],
            path: "Sources/App"
        )
    ]
)
