// ==============================================================================
// Program: AppDelegate.swift
// Programmer: Ethan-da-Tech-Wizard
// Last Modified: November 18, 2026
// Purpose: Primary Application Lifecycle Delegate for RuneLite Mobile iOS.
//          Handles initial application launch configuration, Jagex OAuth2 PKCE
//          deep-link URL scheme routing, and multi-window scene configurations.
// ==============================================================================

// ==============================================================================
// Architecture Overview & Mobile Application Lifecycle:
// ==============================================================================
// In iOS development (Swift / UIKit), the `UIApplicationDelegate` acts as the
// central controller for OS-level events. When an application launches, enters
// the background, or receives an external deep-link URL from the system browser,
// iOS invokes delegate callbacks on `AppDelegate`.
//
// Key Responsibilities:
// 1. App Launch: Initializes subsystems when `didFinishLaunchingWithOptions` fires.
// 2. OAuth Deep-Link Dispatch: When Jagex's web authentication flow redirects to
//    `runelite-mobile://oauth-callback?code=...`, the OS routes the URL here.
// 3. Scene Management: Coordinates window scenes for iOS 13+ multi-window support.
// ==============================================================================

import UIKit

// @main marks this class as the process entry point; UIKit creates it and calls the delegate methods below.
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    // The primary user interface window for the application (legacy / single-window support)
    // Unused when scenes are active (SceneDelegate owns the real window); kept for pre-scene compatibility.
    var window: UIWindow?

    /// Called by iOS when the application process finishes launching and is ready to run.
    ///
    /// - Parameters:
    ///   - application: The singleton `UIApplication` instance of the running app.
    ///   - launchOptions: A dictionary containing reasons why the app was launched (e.g. notifications, deep links).
    /// - Returns: Bool indicating whether the application successfully handled the launch request.
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Step 1: Log startup banner to console for developer diagnostics
        // Diagnostics go to the console only (no logging framework).
        print("🚀 [RuneLiteMobile] Application launched successfully.")
        // Step 2: Return true indicating application initialization succeeded
        return true
    }

    /// Handles incoming custom URL scheme deep links (e.g., OAuth authentication redirects).
    ///
    /// - Parameters:
    ///   - app: The singleton `UIApplication` instance.
    ///   - url: The deep-link URL opened by an external application or Safari web session.
    ///   - options: Dictionary of open-URL options (e.g., source application identifier).
    /// - Returns: Bool indicating if the application recognized and handled the URL.
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        // Step 1: Log incoming deep link URL string
        print("🔗 [RuneLiteMobile] Received deep link callback: \(url.absoluteString)")

        // NOTE: as written this method only logs the URL and returns true; it does not forward the code anywhere.
        // ASWebAuthenticationSession (see JagexOAuthManager) normally delivers the callback itself, so this path is a fallback.
        // Step 2: In PKCE OAuth2 flow, the authorization code returned in `url` is
        // extracted and passed to JagexOAuthManager to exchange for an access token.
        return true
    }

    // MARK: - UISceneSession Lifecycle

    /// Configures new window scenes when an iOS 13+ scene session is requested.
    ///
    /// - Parameters:
    ///   - application: The singleton `UIApplication` instance.
    ///   - connectingSceneSession: The scene session being created or reconnected.
    ///   - options: Connection options specifying the context for the scene request.
    /// - Returns: A UISceneConfiguration object describing how to initialize the scene.
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Direct UIKit to use the "Default Configuration" declared in Info.plist
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
