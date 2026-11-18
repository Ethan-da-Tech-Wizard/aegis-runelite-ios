// ==============================================================================
// Program: GameState.swift
// Programmer: Ethan-da-Tech-Wizard
// Last Modified: November 18, 2026
// Purpose: Central Game Engine State Model and Tick Event Driver for OSRS.
//          Maintains the 104x104 scene tile base, local player status, camera
//          parameters, ground items, skill experience tables, and 600ms tick dispatch.
// ==============================================================================

// ==============================================================================
// Overview: Game Engine Architecture:
// ==============================================================================
// In video game programming, the "Game State" represents the complete snapshot
// of everything currently existing and happening in the game world.
//
// Key Subsystems Managed by GameState:
// 1. Scene Origin (`baseTileX`, `baseTileY`):
//    The 104x104 local area chunk loaded in memory has its bottom-left corner
//    anchored at global coordinates (baseTileX, baseTileY).
// 2. 600ms Engine Tick Heartbeat (`onTick`):
//    Every 600 milliseconds, the engine increments `currentTick` and publishes
//    a `GameTickEvent` to all registered plugins via `EventBus`.
// 3. Experience & Level Curves (`calculateLevel`):
//    OSRS uses an exponential formula to calculate skill levels from experience:
//    Points accumulated per level: `lvl + 300 * 2^(lvl / 7)`.
//    Level threshold = `points / 4`.
//    This mathematical curve ensures that level 92 is the halfway mark to 99!
// ==============================================================================

import Foundation
import CoreGraphics

/// Observable game state snapshot updated by the native engine hook or local simulation.
public final class GameState: ObservableObject {
    /// Shared singleton instance accessible by overlays, plugins, and the camera pipeline.
    public static let shared = GameState()

    // Base coordinates for the 104x104 scene
    @Published public var baseTileX: Int = 3200
    @Published public var baseTileY: Int = 3200
    @Published public var currentPlane: Int = 0

    // Local Player & Destination Tile
    @Published public var localPlayer: PlayerActor = PlayerActor(name: "Ethan")
    @Published public var destinationTile: WorldPoint? = nil
    @Published public var hoverTile: WorldPoint? = nil

    // Camera parameters (Pitch 128...383, Yaw 0...2047, Zoom 180...896)
    @Published public var cameraX: Int = 6656
    @Published public var cameraY: Int = 6656
    @Published public var cameraZ: Int = 1000
    @Published public var cameraPitch: Int = 128
    @Published public var cameraYaw: Int = 512
    @Published public var cameraZoom: Int = 512

    // Viewport bounds matching mobile screen
    @Published public var viewportSize: CGSize = CGSize(width: 844, height: 390)

    // Dynamic ground items collection
    @Published public var groundItems: [Item] = []

    // Skills & Experience dictionary mapping skill names to current level and XP
    @Published public var skills: [String: (level: Int, xp: Int)] = [
        "Attack": (99, 13_034_431),
        "Strength": (99, 13_034_431),
        "Defence": (99, 13_034_431),
        "Hitpoints": (99, 13_034_431),
        "Prayer": (99, 13_034_431),
        "Magic": (99, 13_034_431),
        "Ranged": (99, 13_034_431),
        "Mining": (85, 3_258_594),
        "Woodcutting": (90, 5_346_332),
        "Fishing": (80, 1_986_068)
    ]

    // Current game tick counter
    @Published public var currentTick: Int = 0

    /// Convenience alias matching tickCount naming convention
    public var tickCount: Int {
        return currentTick
    }

    // Ground elevation 2D array [104][104]
    public var tileHeights: [[Int]] = Array(repeating: Array(repeating: 0, count: 104), count: 104)

    private init() {}

    /// Get tile height in fine units at a specific scene coordinate.
    ///
    /// - Parameters:
    ///   - sceneX: Scene tile X (0...103).
    ///   - sceneY: Scene tile Y (0...103).
    /// - Returns: Height integer in fine units (or 0 if out of bounds).
    public func getTileHeight(sceneX: Int, sceneY: Int) -> Int {
        guard sceneX >= 0 && sceneX < 104 && sceneY >= 0 && sceneY < 104 else {
            return 0
        }
        return tileHeights[sceneX][sceneY]
    }

    /// Process a new 600ms game tick from the engine and notify plugins.
    public func onTick() {
        currentTick += 1
        EventBus.shared.publish(GameTickEvent(tickCount: currentTick))
    }

    /// Execute primary tap action at target world coordinate (walk to tile or interact).
    ///
    /// - Parameter worldPoint: The target WorldPoint tapped on screen.
    public func executePrimaryAction(at worldPoint: WorldPoint) {
        destinationTile = worldPoint
    }

    /// Update experience for a skill and fire StatChangedEvent.
    ///
    /// - Parameters:
    ///   - skillName: Name of the skill (e.g., "Attack", "Woodcutting").
    ///   - amount: Amount of XP points gained.
    public func addExperience(skillName: String, amount: Int) {
        guard var current = skills[skillName] else { return }
        current.xp += amount
        // Calculate new level from updated experience points
        let newLevel = calculateLevel(xp: current.xp)
        current.level = newLevel
        skills[skillName] = current

        EventBus.shared.publish(StatChangedEvent(
            skillName: skillName,
            currentLevel: newLevel,
            experience: current.xp,
            xpGained: amount
        ))
    }

    /// Calculate OSRS skill level (1 to 99) using the official mathematical formula.
    ///
    /// - Parameter xp: Accumulated experience points.
    /// - Returns: Calculated level from 1 to 99.
    private func calculateLevel(xp: Int) -> Int {
        var points = 0
        for lvl in 1...99 {
            points += Int(floor(Double(lvl) + 300.0 * pow(2.0, Double(lvl) / 7.0)))
            let threshold = points / 4
            if xp < threshold {
                return lvl
            }
        }
        return 99
    }
}
