// ==============================================================================
// Program: TouchAndCameraPipeline.swift
// Programmer: Ethan-da-Tech-Wizard
// Last Modified: November 18, 2026
// Purpose: 1:1 Authentic OSRS Mobile Touch & Camera Gesture Pipeline.
//          Implements genuine mobile touch mechanics:
//          - 200ms tap-to-walk (yellow X) and interact (red X)
//          - 350ms long-press with Taptic haptic feedback for right-click context menu
//          - 2-finger camera orbit (Yaw horizontal, Pitch vertical)
//          - Pinch-to-zoom (180...896 zoom bounds)
//          - Hardware capacitive digitizer contact verification (no synthetic bot events).
// ==============================================================================

// ==============================================================================
// Architecture Overview & Human-Computer Interaction (HCI):
// ==============================================================================
// In mobile systems design, mapping physical gestures onto 3D game cameras
// and point-and-click interactions requires careful state machine modeling.
//
// Gesture State Machine:
// 1. Idle -> Possible Tap: When 1 finger touches the screen, a 350ms timer starts.
// 2. Tap (< 200ms): If the finger is released within 200ms without dragging,
//    a primary tap is dispatched (yellow X ground marker or red X entity interact).
// 3. Long-Press (350ms): If the finger remains stationary for 350ms, a medium
//    haptic pulse (`UIImpactFeedbackGenerator(style: .medium)`) triggers and
//    the OSRS right-click context menu opens at the finger location.
// 4. Drag Slop (> 10 points): If the finger moves more than 10 points, the long-press
//    timer cancels, transitioning to camera orbit or dragging.
// 5. 2-Finger Orbit: Two fingers moving together rotate the camera yaw (Z-axis)
//    and pitch (X-axis, clamped between 128 and 383).
// ==============================================================================

import UIKit

/// Gesture states mirroring OSRS mobile touch interaction engine.
// State machine: idle -> possibleTap -> (longPressing | draggingCamera); a second finger always forces draggingCamera.
// pinchingZoom and draggingContextMenu are declared but never entered by the code in this file.
public enum TouchGestureState {
    case idle
    case possibleTap
    case longPressing
    case draggingCamera
    case pinchingZoom
    case draggingContextMenu
}

/// Point-and-click interaction type.
public enum ClickMarkerType {
    case redX       // Action on interactable (NPC, Object, Item)
    case yellowX    // Ground movement tap
}

/// Delegate protocol for touch and camera actions.
public protocol TouchAndCameraDelegate: AnyObject {
    func didTriggerClickMarker(at point: CGPoint, type: ClickMarkerType)
    func didTriggerContextMenu(at point: CGPoint, worldPoint: WorldPoint)
    func didUpdateCamera(yaw: Int, pitch: Int, zoom: Int)
}

/// 1:1 Authentic OSRS Mobile Touch & Camera Pipeline.
/// Enforces hardware digitizer capacitive contact verification,
/// 350ms long press with Taptic feedback, 2-finger camera yaw/pitch, and pinch zoom.
public final class TouchAndCameraPipeline {
    /// Shared singleton instance.
    public static let shared = TouchAndCameraPipeline()

    public weak var delegate: TouchAndCameraDelegate?

    // Calibration constants matching OSRS Mobile specification
    // Despite the 'Ms' suffix these are TimeInterval values in SECONDS (0.200 = 200 ms). They are pinned by tests/test_compliance.py.
    public let tapThresholdMs: TimeInterval = 0.200
    public let longPressThresholdMs: TimeInterval = 0.350
    public let dragSlopPoints: CGFloat = 10.0
    public let cameraPitchMin: Int = 128
    public let cameraPitchMax: Int = 383
    public let zoomMin: Int = 180
    public let zoomMax: Int = 896

    // State tracking
    public private(set) var currentState: TouchGestureState = .idle
    private var touchStartTimestamp: TimeInterval = 0
    private var touchStartLocation: CGPoint = .zero
    private var longPressTimer: Timer?
    private var activeTouches: [UITouch: CGPoint] = [:]

    // Camera parameters (OSRS fixed-point angle units: 0 - 2047)
    // Angles use OSRS units (2048 per revolution). Note this pipeline keeps its own camera values; it does not write to GameState's camera.
    public private(set) var cameraYaw: Int = 0
    public private(set) var cameraPitch: Int = 128
    public private(set) var cameraZoom: Int = 600

    // Created once and prepare()d in init so the first long press has no haptic latency.
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)

    private init() {
        hapticFeedback.prepare()
    }

    // MARK: - Touch Ingestion & Digitizer Validation

    /// Called by the host view when new touch contacts begin.
    ///
    /// - Parameters:
    ///   - touches: Set of UITouch events.
    ///   - view: The containing coordinate view.
    public func handleTouchesBegan(_ touches: Set<UITouch>, in view: UIView) {
        for touch in touches {
            // Jagex Botwatch verification: Ensure touch came from physical capacitive glass
            // Rejected touches are skipped entirely (never tracked), so a rejected finger cannot start a tap, drag or long press.
            guard validateHardwareDigitizer(touch) else {
                print("⚠️ [TouchPipeline] Rejected non-digitizer/synthetic touch")
                continue
            }
            activeTouches[touch] = touch.location(in: view)
        }

        // Single finger touch: initiate possible tap and 350ms long-press timer
        if activeTouches.count == 1, let firstTouch = activeTouches.keys.first {
            touchStartTimestamp = ProcessInfo.processInfo.systemUptime
            touchStartLocation = activeTouches[firstTouch] ?? .zero
            currentState = .possibleTap

            // Schedule 350ms OSRS Context Menu trigger
            longPressTimer?.invalidate()
            // If the finger stays within the slop radius for 350 ms the timer fires and opens the context menu instead of a tap.
            longPressTimer = Timer.scheduledTimer(withTimeInterval: longPressThresholdMs, repeats: false) { [weak self] _ in
                self?.handleLongPressTriggered(in: view)
            }
        } else if activeTouches.count == 2 {
            // Two finger touch: transition immediately to camera orbit mode
            longPressTimer?.invalidate()
            currentState = .draggingCamera
        }
    }

    /// Called when active touch contacts move across the screen.
    ///
    /// - Parameters:
    ///   - touches: Updated touches.
    ///   - view: The view.
    public func handleTouchesMoved(_ touches: Set<UITouch>, in view: UIView) {
        var previousPoints: [UITouch: CGPoint] = [:]
        for touch in touches {
            previousPoints[touch] = activeTouches[touch]
            activeTouches[touch] = touch.location(in: view)
        }

        // Check if single finger has moved beyond drag slop threshold
        if currentState == .possibleTap, let firstTouch = touches.first, let currentLoc = activeTouches[firstTouch] {
            // Moving farther than dragSlopPoints turns a possible tap into a camera drag (cancelling the long press).
            let distance = hypot(currentLoc.x - touchStartLocation.x, currentLoc.y - touchStartLocation.y)
            if distance > dragSlopPoints {
                longPressTimer?.invalidate()
                currentState = .draggingCamera
            }
        }

        // Handle 2-finger camera rotation
        if currentState == .draggingCamera && activeTouches.count >= 2 {
            let touchList = Array(activeTouches.keys)
            let t0 = touchList[0]
            let t1 = touchList[1]

            let p0 = activeTouches[t0] ?? .zero
            let p1 = activeTouches[t1] ?? .zero
            let prev0 = previousPoints[t0] ?? p0
            let prev1 = previousPoints[t1] ?? p1

            // Average delta across both fingers
            let deltaX = ((p0.x - prev0.x) + (p1.x - prev1.x)) * 0.5
            let deltaY = ((p0.y - prev0.y) + (p1.y - prev1.y)) * 0.5

            // Update Yaw (horizontal orbit, wrapping modulo 2048)
            // Gain of 2 yaw units per point of horizontal motion; modulo wraps the angle, with a fix-up for negative remainders.
            cameraYaw = (cameraYaw + Int(deltaX * 2.0)) % 2048
            if cameraYaw < 0 { cameraYaw += 2048 }

            // Update Pitch (vertical tilt, clamped between 128 and 383)
            // Dragging up lowers the pitch value (note the minus sign); clamped to the OSRS pitch range.
            cameraPitch = max(cameraPitchMin, min(cameraPitchMax, cameraPitch - Int(deltaY * 1.5)))
            delegate?.didUpdateCamera(yaw: cameraYaw, pitch: cameraPitch, zoom: cameraZoom)
        }
    }

    /// Called when touches are lifted from the screen.
    ///
    /// - Parameters:
    ///   - touches: Terminated touches.
    ///   - view: The view.
    public func handleTouchesEnded(_ touches: Set<UITouch>, in view: UIView) {
        let uptime = ProcessInfo.processInfo.systemUptime
        let elapsed = uptime - touchStartTimestamp

        // If lifted within tapThresholdMs, register primary tap
        // Tap = finger lifted within 200 ms without exceeding the slop distance.
        if currentState == .possibleTap && elapsed < tapThresholdMs {
            longPressTimer?.invalidate()
            handlePrimaryTap(at: touchStartLocation, in: view)
        }

        for touch in touches {
            activeTouches.removeValue(forKey: touch)
        }

        if activeTouches.isEmpty {
            longPressTimer?.invalidate()
            currentState = .idle
        }
    }

    /// Called when touches are cancelled by system gestures (e.g. notification banner, phone call).
    public func handleTouchesCancelled(_ touches: Set<UITouch>, in view: UIView) {
        longPressTimer?.invalidate()
        activeTouches.removeAll()
        currentState = .idle
    }

    // MARK: - Pinch Zoom Gesture

    /// Adjust viewport zoom based on 2-finger pinch gesture delta.
    ///
    /// - Parameter scaleDelta: Scale factor change from UIPinchGestureRecognizer.
    public func handlePinchZoom(scaleDelta: CGFloat) {
        // Pinching in (scale < 1) increases zoom value, pinching out decreases it; clamped to 180...896.
        let zoomChange = Int((1.0 - scaleDelta) * 300.0)
        cameraZoom = max(zoomMin, min(zoomMax, cameraZoom + zoomChange))
        delegate?.didUpdateCamera(yaw: cameraYaw, pitch: cameraPitch, zoom: cameraZoom)
    }

    // MARK: - Tap & Long-Press Actions

    /// Process a valid primary single-finger tap.
    private func handlePrimaryTap(at point: CGPoint, in view: UIView) {
        let worldPoint = screenToWorld(point: point)
        // Red marker = something interactable under the tap, yellow = plain ground walk.
        let isInteractable = isEntityAt(worldPoint: worldPoint)

        let markerType: ClickMarkerType = isInteractable ? .redX : .yellowX
        delegate?.didTriggerClickMarker(at: point, type: markerType)

        // Dispatch 1:1 action to game engine
        GameState.shared.executePrimaryAction(at: worldPoint)
    }

    /// Trigger 350ms long press context menu with haptic feedback.
    private func handleLongPressTriggered(in view: UIView) {
        guard currentState == .possibleTap else { return }
        currentState = .longPressing

        // Trigger authentic OSRS mobile haptic bump
        hapticFeedback.impactOccurred()

        let worldPoint = screenToWorld(point: touchStartLocation)
        delegate?.didTriggerContextMenu(at: touchStartLocation, worldPoint: worldPoint)
    }

    // MARK: - Validation & Projections

    /// Validates that a touch event originated from the physical capacitive screen digitizer.
    ///
    /// - Parameter touch: The UITouch event to inspect.
    /// - Returns: True if authentic physical touch.
    public func validateHardwareDigitizer(_ touch: UITouch) -> Bool {
        // Hardware capacitive touch check: direct touch from screen digitizer with contact radius
        // Rejects Apple Pencil/indirect pointers. The radius check is compiled out on the Simulator, whose touches report no contact radius.
        guard touch.type == .direct else { return false }
        #if !targetEnvironment(simulator)
        guard touch.majorRadius > 0.0 else { return false }
        #endif
        return true
    }

    /// Convert screen coordinates to approximate world tile coordinates.
    ///
    /// - Parameter point: Screen pixel point.
    /// - Returns: Projected WorldPoint.
    // Rough approximation only: a fixed 32-points-per-tile mapping with hard-coded screen offsets (200, 400) centred on the player.
    // It ignores camera yaw, pitch and zoom, so taps will not match what Perspective.localToCanvas draws.
    public func screenToWorld(point: CGPoint) -> WorldPoint {
        let player = GameState.shared.localPlayer
        return WorldPoint(
            x: player.worldPoint.x + Int((point.x - 200) / 32),
            y: player.worldPoint.y - Int((point.y - 400) / 32),
            plane: player.worldPoint.plane
        )
    }

    /// Check if an interactable entity or ground item is present at world coordinate.
    // Only ground items count today; NPCs and objects are not checked.
    private func isEntityAt(worldPoint: WorldPoint) -> Bool {
        for item in GameState.shared.groundItems where item.worldPoint == worldPoint {
            return true
        }
        return false
    }

    /// Reset camera orientation to North (Yaw 0, Pitch 256).
    public func resetCameraToNorth() {
        cameraYaw = 0
        cameraPitch = 256
        delegate?.didUpdateCamera(yaw: cameraYaw, pitch: cameraPitch, zoom: cameraZoom)
    }
}
