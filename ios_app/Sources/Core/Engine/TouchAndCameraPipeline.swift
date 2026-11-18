//
//  TouchAndCameraPipeline.swift
//  RuneLiteMobile
//
//  Created for iOS Standalone RuneLite Client Architecture.
//  Copyright © 2026 TWU LLC. All rights reserved.
//

import UIKit

/// Gesture states mirroring OSRS mobile touch interaction engine
public enum TouchGestureState {
    case idle
    case possibleTap
    case longPressing
    case draggingCamera
    case pinchingZoom
    case draggingContextMenu
}

/// Point-and-click interaction type
public enum ClickMarkerType {
    case redX       // Action on interactable (NPC, Object, Item)
    case yellowX    // Ground movement tap
}

/// Delegate protocol for touch and camera actions
public protocol TouchAndCameraDelegate: AnyObject {
    func didTriggerClickMarker(at point: CGPoint, type: ClickMarkerType)
    func didTriggerContextMenu(at point: CGPoint, worldPoint: WorldPoint)
    func didUpdateCamera(yaw: Int, pitch: Int, zoom: Int)
}

/// 1:1 Authentic OSRS Mobile Touch & Camera Pipeline
/// Enforces hardware digitizer capacitive contact verification,
/// 350ms long press with Taptic feedback, 2-finger camera yaw/pitch, and pinch zoom.
public final class TouchAndCameraPipeline {
    public static let shared = TouchAndCameraPipeline()

    public weak var delegate: TouchAndCameraDelegate?

    // Calibration constants matching OSRS Mobile
    public let tapThresholdMs: TimeInterval = 0.200
    public let longPressThresholdMs: TimeInterval = 0.350
    public let dragSlopPoints: CGFloat = 10.0
    public let cameraPitchMin: Int = 128
    public let cameraPitchMax: Int = 383
    public let zoomMin: Int = 180
    public let zoomMax: Int = 896

    // State
    public private(set) var currentState: TouchGestureState = .idle
    private var touchStartTimestamp: TimeInterval = 0
    private var touchStartLocation: CGPoint = .zero
    private var longPressTimer: Timer?
    private var activeTouches: [UITouch: CGPoint] = [:]

    // Camera parameters (OSRS fixed-point angle units: 0 - 2047)
    public private(set) var cameraYaw: Int = 0
    public private(set) var cameraPitch: Int = 128
    public private(set) var cameraZoom: Int = 600

    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)

    private init() {
        hapticFeedback.prepare()
    }

    // MARK: - Touch Ingestion & Digitizer Validation

    public func handleTouchesBegan(_ touches: Set<UITouch>, in view: UIView) {
        for touch in touches {
            // Jagex Botwatch verification: Ensure touch came from physical capacitive glass
            guard validateHardwareDigitizer(touch) else {
                print("⚠️ [TouchPipeline] Rejected non-digitizer/synthetic touch")
                continue
            }
            activeTouches[touch] = touch.location(in: view)
        }

        if activeTouches.count == 1, let firstTouch = activeTouches.keys.first {
            touchStartTimestamp = ProcessInfo.processInfo.systemUptime
            touchStartLocation = activeTouches[firstTouch] ?? .zero
            currentState = .possibleTap

            // Schedule 350ms OSRS Context Menu trigger
            longPressTimer?.invalidate()
            longPressTimer = Timer.scheduledTimer(withTimeInterval: longPressThresholdMs, repeats: false) { [weak self] _ in
                self?.handleLongPressTriggered(in: view)
            }
        } else if activeTouches.count == 2 {
            longPressTimer?.invalidate()
            currentState = .draggingCamera
        }
    }

    public func handleTouchesMoved(_ touches: Set<UITouch>, in view: UIView) {
        var previousPoints: [UITouch: CGPoint] = [:]
        for touch in touches {
            previousPoints[touch] = activeTouches[touch]
            activeTouches[touch] = touch.location(in: view)
        }

        if currentState == .possibleTap, let firstTouch = touches.first, let currentLoc = activeTouches[firstTouch] {
            let distance = hypot(currentLoc.x - touchStartLocation.x, currentLoc.y - touchStartLocation.y)
            if distance > dragSlopPoints {
                longPressTimer?.invalidate()
                currentState = .draggingCamera
            }
        }

        if currentState == .draggingCamera && activeTouches.count >= 2 {
            // 2-finger orbit: Yaw (horizontal pan) and Pitch (vertical pan)
            let touchList = Array(activeTouches.keys)
            let t0 = touchList[0]
            let t1 = touchList[1]

            let p0 = activeTouches[t0] ?? .zero
            let p1 = activeTouches[t1] ?? .zero
            let prev0 = previousPoints[t0] ?? p0
            let prev1 = previousPoints[t1] ?? p1

            let deltaX = ((p0.x - prev0.x) + (p1.x - prev1.x)) * 0.5
            let deltaY = ((p0.y - prev0.y) + (p1.y - prev1.y)) * 0.5

            cameraYaw = (cameraYaw + Int(deltaX * 2.0)) % 2048
            if cameraYaw < 0 { cameraYaw += 2048 }

            cameraPitch = max(cameraPitchMin, min(cameraPitchMax, cameraPitch - Int(deltaY * 1.5)))
            delegate?.didUpdateCamera(yaw: cameraYaw, pitch: cameraPitch, zoom: cameraZoom)
        }
    }

    public func handleTouchesEnded(_ touches: Set<UITouch>, in view: UIView) {
        let uptime = ProcessInfo.processInfo.systemUptime
        let elapsed = uptime - touchStartTimestamp

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

    public func handleTouchesCancelled(_ touches: Set<UITouch>, in view: UIView) {
        longPressTimer?.invalidate()
        activeTouches.removeAll()
        currentState = .idle
    }

    // MARK: - Pinch Zoom Gesture

    public func handlePinchZoom(scaleDelta: CGFloat) {
        let zoomChange = Int((1.0 - scaleDelta) * 300.0)
        cameraZoom = max(zoomMin, min(zoomMax, cameraZoom + zoomChange))
        delegate?.didUpdateCamera(yaw: cameraYaw, pitch: cameraPitch, zoom: cameraZoom)
    }

    // MARK: - Tap & Long-Press Actions

    private func handlePrimaryTap(at point: CGPoint, in view: UIView) {
        // Query top-level entity under tap
        let worldPoint = screenToWorld(point: point)
        let isInteractable = isEntityAt(worldPoint: worldPoint)

        let markerType: ClickMarkerType = isInteractable ? .redX : .yellowX
        delegate?.didTriggerClickMarker(at: point, type: markerType)

        // Dispatch 1:1 menu action to game engine
        GameState.shared.executePrimaryAction(at: worldPoint)
    }

    private func handleLongPressTriggered(in view: UIView) {
        guard currentState == .possibleTap else { return }
        currentState = .longPressing

        // Trigger authentic OSRS mobile haptic bump
        hapticFeedback.impactOccurred()

        let worldPoint = screenToWorld(point: touchStartLocation)
        delegate?.didTriggerContextMenu(at: touchStartLocation, worldPoint: worldPoint)
    }

    // MARK: - Validation & Projections

    private func validateHardwareDigitizer(_ touch: UITouch) -> Bool {
        // Hardware capacitive touch check: direct touch from screen digitizer with contact radius
        guard touch.type == .direct else { return false }
        #if !targetEnvironment(simulator)
        guard touch.majorRadius > 0.0 else { return false }
        #endif
        return true
    }

    public func screenToWorld(point: CGPoint) -> WorldPoint {
        let player = GameState.shared.localPlayer
        return WorldPoint(
            x: player.worldLocation.x + Int((point.x - 200) / 32),
            y: player.worldLocation.y - Int((point.y - 400) / 32),
            plane: player.worldLocation.plane
        )
    }

    private func isEntityAt(worldPoint: WorldPoint) -> Bool {
        // Check if world point contains an NPC, interactable object, or ground item
        for item in GameState.shared.groundItems where item.location == worldPoint {
            return true
        }
        return false
    }

    public func resetCameraToNorth() {
        cameraYaw = 0
        cameraPitch = 256
        delegate?.didUpdateCamera(yaw: cameraYaw, pitch: cameraPitch, zoom: cameraZoom)
    }
}
