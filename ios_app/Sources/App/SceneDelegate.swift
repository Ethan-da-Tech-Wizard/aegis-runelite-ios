// ==============================================================================
// Program: SceneDelegate.swift
// Programmer: Ethan-da-Tech-Wizard
// Last Modified: November 18, 2026
// Purpose: Window Scene Lifecycle Delegate for RuneLite Mobile iOS.
//          Configures the primary UIWindow, instantiates the root
//          OverlayViewController, attaches Metal rendering views, and activates
//          the window on screen.
// ==============================================================================

// ==============================================================================
// Overview: iOS Scene Architecture:
// ==============================================================================
// In iOS 13 and later, Apple separated process lifecycle (`AppDelegate`) from
// user interface lifecycle (`SceneDelegate`). This enables iPadOS devices to
// run multiple side-by-side split-screen windows of the same app simultaneously.
//
// Lifecycle Flow:
// 1. `scene(_:willConnectTo:options:)`: The OS provides a `UIWindowScene`.
// 2. A new `UIWindow` is allocated and bound to that scene.
// 3. The `OverlayViewController` (which contains our Metal game canvas and HUD)
//    is assigned as `window.rootViewController`.
// 4. `window.makeKeyAndVisible()` presents the interface to the user.
// ==============================================================================

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    // Reference to the main window displayed on the physical device screen
    var window: UIWindow?

    /// Called when a scene is being added to the app, connecting it to the UIWindow.
    ///
    /// - Parameters:
    ///   - scene: The abstract UIScene object managed by the operating system.
    ///   - session: The UISceneSession tracking persistent configuration state.
    ///   - connectionOptions: Additional options supplied when connecting the scene.
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // Step 1: Safely downcast the generic UIScene into a UIWindowScene
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // Step 2: Allocate the UIWindow bound to the device screen's window scene
        let window = UIWindow(windowScene: windowScene)

        // Step 3: Instantiate the root overlay view controller (manages Metal & HUD)
        let rootVC = OverlayViewController()
        window.rootViewController = rootVC

        // Step 4: Retain the window in our class property
        self.window = window

        // Step 5: Make the window key and visible to present graphics to the user
        window.makeKeyAndVisible()
    }
}
