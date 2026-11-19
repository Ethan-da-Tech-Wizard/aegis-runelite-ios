// ==============================================================================
// Program: OverlayViewController.swift
// Programmer: Ethan-da-Tech-Wizard
// Last Modified: November 18, 2026
// Purpose: Primary UIViewController for RuneLite Mobile iOS.
//          Hosts the transparent MTKView with 120Hz ProMotion support, floating
//          HUD controls (Settings gear, rotating North compass), pinch-to-zoom
//          recognizer, click animation markers (red X / yellow X), and 350ms
//          long-press right-click context menu presentation.
// ==============================================================================

// ==============================================================================
// Architecture Overview & Mobile View Controller Architecture:
// ==============================================================================
// In UIKit application architecture, a `UIViewController` coordinates
// user input events, subviews, hardware rendering layers, and modal transitions.
//
// Key Subsystems in this View Controller:
// 1. Transparent Metal Layer (`MTKView`):
//    The Metal view is layered over the screen with `isOpaque = false` and
//    `isUserInteractionEnabled = false`. This allows touches to pass directly
//    through to the view controller while the GPU draws overlays on top at up
//    to 120 FPS on ProMotion hardware.
// 2. Click Marker Animations:
//    - Red X: Action on an interactable entity (monster attack, tree chop, door open).
//    - Yellow X: Pure tile ground movement tap.
//    - Animates a rotating, expanding square that fades out over 350ms.
// 3. Rotating Compass:
//    The North compass button rotates dynamically according to camera yaw:
//    `angle = (yaw / 2048.0) * 2 * pi`. Tapping it resets camera to North.
// 4. Jagex 1:1 Compliance Verification:
//    Every touch event entering `touchesBegan` is passed to
//    `JagexComplianceEngine.shared.validateTouchEvent(touch)`.
// ==============================================================================

import UIKit
import MetalKit
import SwiftUI

/// Main container view controller hosting the game view, 1:1 touch interaction engine,
/// and transparent Metal overlay with 120Hz ProMotion support.
public final class OverlayViewController: UIViewController, TouchAndCameraDelegate {
    private var metalView: MTKView!
    private var settingsButton: UIButton!
    private var compassButton: UIButton!
    // Everything here runs against simulated state: a 0.6 s timer drives GameState instead of a real game connection.
    private var simulatedTickTimer: Timer?
    private var activeContextMenu: UIView?

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        // Required for the two-finger camera gesture.
        view.isMultipleTouchEnabled = true

        // Initialize user interface and hardware rendering subsystems
        setupMetalOverlay()
        setupFloatingControls()
        setupPinchGesture()
        registerDefaultPlugins()
        startSimulatedTelemetry()

        // Bind touch and camera delegate
        TouchAndCameraPipeline.shared.delegate = self
    }

    /// Configures the transparent MTKView for ProMotion 120Hz/60Hz rendering.
    private func setupMetalOverlay() {
        guard let device = MetalOverlayRenderer.shared.device else {
            print("❌ [OverlayViewController] Metal device unavailable")
            return
        }

        metalView = MTKView(frame: view.bounds, device: device)
        metalView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        metalView.delegate = MetalOverlayRenderer.shared
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        metalView.isOpaque = false
        metalView.backgroundColor = .clear

        // Enable 120Hz ProMotion when supported by iPhone hardware
        // ProMotion devices render at 120 Hz, others at 60.
        if UIScreen.main.maximumFramesPerSecond >= 120 {
            metalView.preferredFramesPerSecond = 120
        } else {
            metalView.preferredFramesPerSecond = 60
        }

        // The Metal layer is draw-only; touches reach this controller's touchesBegan/Moved/Ended overrides.
        metalView.isUserInteractionEnabled = false // Passes touches to container view controller
        view.addSubview(metalView)
    }

    /// Sets up floating circular buttons for settings and camera compass.
    private func setupFloatingControls() {
        // Read during viewDidLoad, when safe-area insets may still be zero; the max(44, ...) keeps buttons below the status bar regardless.
        let safeArea = view.safeAreaInsets

        // Settings Button (Gear icon)
        settingsButton = UIButton(type: .system)
        settingsButton.frame = CGRect(x: 20, y: max(44, safeArea.top + 10), width: 44, height: 44)
        settingsButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        settingsButton.layer.cornerRadius = 22
        settingsButton.setImage(UIImage(systemName: "gearshape.fill"), for: .normal)
        settingsButton.tintColor = .white
        settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        view.addSubview(settingsButton)

        // Compass Button (Tap to face North)
        compassButton = UIButton(type: .system)
        compassButton.frame = CGRect(x: 74, y: max(44, safeArea.top + 10), width: 44, height: 44)
        compassButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        compassButton.layer.cornerRadius = 22
        compassButton.setImage(UIImage(systemName: "location.north.fill"), for: .normal)
        compassButton.tintColor = .systemRed
        compassButton.addTarget(self, action: #selector(resetCameraNorth), for: .touchUpInside)
        view.addSubview(compassButton)
    }

    /// Attaches 2-finger pinch gesture recognizer for camera zooming.
    private func setupPinchGesture() {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        if recognizer.state == .changed {
            TouchAndCameraPipeline.shared.handlePinchZoom(scaleDelta: recognizer.scale)
            // Reset after each change so each callback delivers an incremental scale, matching handlePinchZoom's delta use.
            recognizer.scale = 1.0
        }
    }

    /// Registers the default suite of native mobile plugins.
    // The five bundled native plugins; their saved enabled state is restored by PluginManager.register.
    private func registerDefaultPlugins() {
        let pm = PluginManager.shared
        pm.register(plugin: TileIndicatorsPlugin())
        pm.register(plugin: GroundItemsPlugin())
        pm.register(plugin: XpTrackerPlugin())
        pm.register(plugin: IdleNotifierPlugin())
        pm.register(plugin: MenuEntrySwapperPlugin())
    }

    /// Starts 600ms tick timer driving the OSRS simulation loop.
    private func startSimulatedTelemetry() {
        // Stand-in for the game's 600 ms tick. Also steps the JavaScript plugins through SandboxedRuntime.
        simulatedTickTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
            GameState.shared.onTick()
            // Dispatch tick to sandboxed plugins
            SandboxedRuntime.shared.dispatchGameTick(tick: GameState.shared.tickCount)
        }
    }

    /// Opens the SwiftUI Plugin Settings modal view.
    @objc private func openSettings() {
        let settingsView = PluginSettingsView()
        let hostingController = UIHostingController(rootView: settingsView)
        present(hostingController, animated: true)
    }

    /// Resets camera orientation to North.
    @objc private func resetCameraNorth() {
        TouchAndCameraPipeline.shared.resetCameraToNorth()
    }

    // MARK: - Touch Handling (1:1 Jagex Touch Compliance + OSRS Mobile Gestures)

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        dismissContextMenu()
        for touch in touches {
            // Result is ignored on purpose: a failed check is logged by the engine, and in release builds a critical violation aborts the app.
            _ = JagexComplianceEngine.shared.validateTouchEvent(touch)
        }
        TouchAndCameraPipeline.shared.handleTouchesBegan(touches, in: view)
        super.touchesBegan(touches, with: event)
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        TouchAndCameraPipeline.shared.handleTouchesMoved(touches, in: view)
        super.touchesMoved(touches, with: event)
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        TouchAndCameraPipeline.shared.handleTouchesEnded(touches, in: view)
        super.touchesEnded(touches, with: event)
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        TouchAndCameraPipeline.shared.handleTouchesCancelled(touches, in: view)
        super.touchesCancelled(touches, with: event)
    }

    // MARK: - TouchAndCameraDelegate Implementations

    public func didTriggerClickMarker(at point: CGPoint, type: ClickMarkerType) {
        showClickAnimation(at: point, color: type == .redX ? .red : .yellow)
    }

    public func didTriggerContextMenu(at point: CGPoint, worldPoint: WorldPoint) {
        showContextMenu(at: point, worldPoint: worldPoint)
    }

    // Rotate the compass opposite to the camera yaw so the red arrow keeps pointing north.
    public func didUpdateCamera(yaw: Int, pitch: Int, zoom: Int) {
        // Update compass icon rotation based on camera yaw
        let angleRadians = Double(yaw) / 2048.0 * (2.0 * .pi)
        compassButton.transform = CGAffineTransform(rotationAngle: CGFloat(-angleRadians))
    }

    // MARK: - Visual Click Markers & Context Menu Presentation

    /// Renders the classic OSRS crosshair click marker animation.
    private func showClickAnimation(at point: CGPoint, color: UIColor) {
        // Rotated 45 degrees so the bordered square reads as an 'X'-style click marker; it fades and grows, then removes itself.
        let marker = UIView(frame: CGRect(x: point.x - 12, y: point.y - 12, width: 24, height: 24))
        marker.layer.borderColor = color.cgColor
        marker.layer.borderWidth = 3.0
        marker.layer.cornerRadius = 4.0
        marker.alpha = 1.0
        marker.transform = CGAffineTransform(rotationAngle: .pi / 4)
        view.addSubview(marker)

        UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseOut, animations: {
            marker.alpha = 0.0
            marker.transform = CGAffineTransform(scaleX: 1.6, y: 1.6).rotated(by: .pi / 4)
        }) { _ in
            marker.removeFromSuperview()
        }
    }

    /// Presents authentic OSRS right-click context menu at finger location.
    private func showContextMenu(at point: CGPoint, worldPoint: WorldPoint) {
        dismissContextMenu()

        let menu = UIView()
        menu.backgroundColor = UIColor(white: 0.1, alpha: 0.95)
        menu.layer.cornerRadius = 8
        menu.layer.borderWidth = 1.0
        menu.layer.borderColor = UIColor.systemGray.cgColor
        menu.clipsToBounds = true

        let titleLabel = UILabel(frame: CGRect(x: 12, y: 8, width: 180, height: 20))
        titleLabel.text = "Choose Option"
        titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .systemYellow
        menu.addSubview(titleLabel)

        // 'Walk here' only dismisses the menu; it does not move the player yet.
        let walkButton = UIButton(type: .system)
        walkButton.frame = CGRect(x: 12, y: 32, width: 180, height: 30)
        walkButton.contentHorizontalAlignment = .leading
        walkButton.setTitle("Walk here", for: .normal)
        walkButton.setTitleColor(.white, for: .normal)
        walkButton.addTarget(self, action: #selector(dismissContextMenu), for: .touchUpInside)
        menu.addSubview(walkButton)

        let cancelBtn = UIButton(type: .system)
        cancelBtn.frame = CGRect(x: 12, y: 64, width: 180, height: 30)
        cancelBtn.contentHorizontalAlignment = .leading
        cancelBtn.setTitle("Cancel", for: .normal)
        cancelBtn.setTitleColor(.lightGray, for: .normal)
        cancelBtn.addTarget(self, action: #selector(dismissContextMenu), for: .touchUpInside)
        menu.addSubview(cancelBtn)

        // Clamp the menu inside the view bounds with a margin.
        let menuX = min(max(10, point.x - 20), view.bounds.width - 210)
        let menuY = min(max(60, point.y - 40), view.bounds.height - 110)
        menu.frame = CGRect(x: menuX, y: menuY, width: 200, height: 100)

        view.addSubview(menu)
        activeContextMenu = menu
    }

    /// Dismisses any active context menu on screen.
    @objc private func dismissContextMenu() {
        activeContextMenu?.removeFromSuperview()
        activeContextMenu = nil
    }
}
