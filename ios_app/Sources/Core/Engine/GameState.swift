//
//  GameState.swift
//  RuneLiteMobile
//
//  Created for iOS Standalone RuneLite Client Architecture.
//  Copyright © 2026 TWU LLC. All rights reserved.
//

import Foundation
import CoreGraphics

/// Observable game state snapshot updated by the native engine hook or local simulation
public final class GameState: ObservableObject {
    public static let shared = GameState()

    // Base coordinates for the 104x104 scene
    @Published public var baseTileX: Int = 3200
    @Published public var baseTileY: Int = 3200
    @Published public var currentPlane: Int = 0

    // Local Player & Destination
    @Published public var localPlayer: PlayerActor = PlayerActor(name: "Ethan")
    @Published public var destinationTile: WorldPoint? = nil
    @Published public var hoverTile: WorldPoint? = nil

    // Camera parameters
    @Published public var cameraX: Int = 6656
    @Published public var cameraY: Int = 6656
    @Published public var cameraZ: Int = 1000
    @Published public var cameraPitch: Int = 128
    @Published public var cameraYaw: Int = 512
    @Published public var cameraZoom: Int = 512

    // Viewport bounds
    @Published public var viewportSize: CGSize = CGSize(width: 844, height: 390)

    // Dynamic ground items
    @Published public var groundItems: [Item] = []

    // Skills & Experience
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

    // Current game tick
    @Published public var currentTick: Int = 0

    // Ground elevation array [104][104]
    public var tileHeights: [[Int]] = Array(repeating: Array(repeating: 0, count: 104), count: 104)

    private init() {}

    /// Get tile height in fine units at a specific scene coordinate
    public func getTileHeight(sceneX: Int, sceneY: Int) -> Int {
        guard sceneX >= 0 && sceneX < 104 && sceneY >= 0 && sceneY < 104 else {
            return 0
        }
        return tileHeights[sceneX][sceneY]
    }

    /// Process a new game tick from the engine
    public func onTick() {
        currentTick += 1
        EventBus.shared.publish(GameTickEvent(tickCount: currentTick))
    }

    /// Update experience for a skill and fire event
    public func addExperience(skillName: String, amount: Int) {
        guard var current = skills[skillName] else { return }
        current.xp += amount
        // Simple OSRS level calculation
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
