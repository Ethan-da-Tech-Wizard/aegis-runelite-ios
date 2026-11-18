// ==============================================================================
// Program: Actor.swift
// Programmer: Ethan-da-Tech-Wizard
// Last Modified: November 18, 2026
// Purpose: Dynamic Game Entity Protocol & Concrete Models (Player & NPC) for OSRS.
//          Defines polymorphic protocols for combat entities, position tracking,
//          health bar calculations, animation states, and entity interactions.
// ==============================================================================

// ==============================================================================
// Overview: Object-Oriented Polymorphism:
// ==============================================================================
// In object-oriented programming, polymorphism allows code to interact
// with diverse entity types through a unified interface.
//
// Protocol-Oriented Architecture:
// In OSRS, both human player characters (`PlayerActor`) and computer-controlled
// monsters (`NpcActor`) share common attributes:
// - A coordinate location (`worldPoint` and `localPoint`).
// - A combat level indicating combat difficulty (e.g. Level 3 to Level 126 for players,
//   up to Level 1000+ for bosses).
// - Health ratio and scale for hitpoint bar rendering (`healthRatio / healthScale`).
// - An active animation ID (e.g., weapon swinging, spellcasting, woodcutting).
// By declaring the `protocol Actor: AnyObject`, plugins like NPC Indicators,
// Combat Level overlays, and Health Bars can process any entity uniformly.
// ==============================================================================

import Foundation

/// Base protocol defining standard properties for dynamic game entities (Players and NPCs).
public protocol Actor: AnyObject {
    var name: String { get }
    var combatLevel: Int { get }
    var worldPoint: WorldPoint { get }
    var localPoint: LocalPoint { get }
    var currentAnimation: Int { get }
    var healthRatio: Int { get }
    var healthScale: Int { get }
    var isInteracting: Bool { get }
}

/// Concrete model representing another human player character in the game world.
public final class PlayerActor: Actor {
    public let name: String
    public var combatLevel: Int
    public var worldPoint: WorldPoint
    public var localPoint: LocalPoint
    public var currentAnimation: Int
    public var healthRatio: Int
    public var healthScale: Int
    public var isInteracting: Bool

    /// Convenience alias for world coordinate tile.
    public var worldLocation: WorldPoint {
        get { return worldPoint }
        set { worldPoint = newValue }
    }

    /// Convenience alias for active animation ID.
    public var animationId: Int {
        return currentAnimation
    }

    /// Initialize a PlayerActor entity.
    ///
    /// - Parameters:
    ///   - name: Player username / display name.
    ///   - combatLevel: Combat level (3...126).
    ///   - worldPoint: World coordinate tile.
    ///   - localPoint: Sub-tile fine local coordinate.
    ///   - currentAnimation: Active animation index (-1 for idle).
    ///   - healthRatio: Current remaining health units.
    ///   - healthScale: Maximum health scale units.
    ///   - isInteracting: True if engaged in combat or dialog.
    public init(
        name: String,
        combatLevel: Int = 3,
        worldPoint: WorldPoint = WorldPoint(x: 3200, y: 3200, plane: 0),
        localPoint: LocalPoint = LocalPoint(x: 6656, y: 6656),
        currentAnimation: Int = -1,
        healthRatio: Int = 30,
        healthScale: Int = 30,
        isInteracting: Bool = false
    ) {
        self.name = name
        self.combatLevel = combatLevel
        self.worldPoint = worldPoint
        self.localPoint = localPoint
        self.currentAnimation = currentAnimation
        self.healthRatio = healthRatio
        self.healthScale = healthScale
        self.isInteracting = isInteracting
    }
}

/// Concrete model representing a Non-Player Character (monster, merchant, boss).
public final class NpcActor: Actor {
    public let id: Int
    public let name: String
    public var combatLevel: Int
    public var worldPoint: WorldPoint
    public var localPoint: LocalPoint
    public var currentAnimation: Int
    public var healthRatio: Int
    public var healthScale: Int
    public var isInteracting: Bool

    /// Convenience alias for world coordinate tile.
    public var worldLocation: WorldPoint {
        get { return worldPoint }
        set { worldPoint = newValue }
    }

    /// Convenience alias for active animation ID.
    public var animationId: Int {
        return currentAnimation
    }

    /// Initialize an NpcActor entity.
    ///
    /// - Parameters:
    ///   - id: Unique NPC type ID (e.g. 2042 for Zulrah).
    ///   - name: NPC name.
    ///   - combatLevel: NPC combat level.
    ///   - worldPoint: World tile location.
    ///   - localPoint: Fine local coordinate.
    ///   - currentAnimation: Active animation ID (-1 for idle).
    ///   - healthRatio: Current remaining health.
    ///   - healthScale: Total health scale.
    ///   - isInteracting: True if interacting with an actor.
    public init(
        id: Int,
        name: String,
        combatLevel: Int = 1,
        worldPoint: WorldPoint,
        localPoint: LocalPoint,
        currentAnimation: Int = -1,
        healthRatio: Int = 10,
        healthScale: Int = 10,
        isInteracting: Bool = false
    ) {
        self.id = id
        self.name = name
        self.combatLevel = combatLevel
        self.worldPoint = worldPoint
        self.localPoint = localPoint
        self.currentAnimation = currentAnimation
        self.healthRatio = healthRatio
        self.healthScale = healthScale
        self.isInteracting = isInteracting
    }
}
