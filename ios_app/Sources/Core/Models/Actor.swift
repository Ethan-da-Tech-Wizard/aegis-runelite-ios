//
//  Actor.swift
//  RuneLiteMobile
//
//  Created for iOS Standalone RuneLite Client Architecture.
//  Copyright © 2026 TWU LLC. All rights reserved.
//

import Foundation

/// Base protocol for dynamic entities (Players and NPCs)
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

/// Player character representation
public final class PlayerActor: Actor {
    public let name: String
    public var combatLevel: Int
    public var worldPoint: WorldPoint
    public var localPoint: LocalPoint
    public var currentAnimation: Int
    public var healthRatio: Int
    public var healthScale: Int
    public var isInteracting: Bool

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

/// NPC representation
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
