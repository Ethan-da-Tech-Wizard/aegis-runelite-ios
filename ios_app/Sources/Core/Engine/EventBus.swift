// Program: aegis-runelite-ios - EventBus.swift
// Programmer: Ethan-da-Tech-Wizard (written with Claude, an AI assistant)
// Last Modified: 2026-11-18
// Purpose: Publish-subscribe event bus and typed event definitions used to decouple the engine from plugins.

// ==============================================================================
// Overview: Publish-Subscribe (Pub/Sub) Pattern:
// ==============================================================================
// In software design patterns, the "Observer" or "Publish-Subscribe" pattern
// establishes a one-to-many dependency between objects.
//
// Why We Use an EventBus:
// - Without an EventBus, the game engine would need direct hardcoded references
//   to every single plugin (Ground Items, Agility, XP Tracker, Tile Indicators, etc.).
//   This causes "tight coupling" — modifying or removing one plugin can break
//   the entire game engine.
// - With an EventBus, components are "loosely coupled":
//   1. Publishers: The engine simply fires `EventBus.shared.publish(GameTickEvent(tickCount: 42))`.
//   2. Subscribers: Any plugin interested in tick events calls `subscribe()`.
//   3. Thread-Safety: An internal `NSLock` guarantees that subscribing, unsubscribing,
//      and event publishing do not cause multithreaded race conditions or crashes.
// ==============================================================================

import Foundation

// MARK: - Event Definitions

/// Fired every 600ms when the Old School RuneScape engine tick increments.
public struct GameTickEvent: Sendable {
    public let tickCount: Int
    /// Creates the event with the current game tick number.
    public init(tickCount: Int) {
        self.tickCount = tickCount
    }
}

/// Fired every screen redraw frame with the delta elapsed time in seconds.
public struct ClientTickEvent: Sendable {
    public let deltaTime: TimeInterval
    /// Creates the event with the seconds elapsed since the previous frame.
    public init(deltaTime: TimeInterval) {
        self.deltaTime = deltaTime
    }
}

/// Fired whenever a player earns experience or levels up a skill.
public struct StatChangedEvent: Sendable {
    public let skillName: String
    public let currentLevel: Int
    public let experience: Int
    public let xpGained: Int

    /// Creates the event from the skill name, its new level and total experience, and the experience just gained.
    public init(skillName: String, currentLevel: Int, experience: Int, xpGained: Int) {
        self.skillName = skillName
        self.currentLevel = currentLevel
        self.experience = experience
        self.xpGained = xpGained
    }
}

/// Fired when an item appears on the ground.
public struct ItemSpawnedEvent: Sendable {
    public let item: Item
    /// Creates the event for the given item.
    public init(item: Item) {
        self.item = item
    }
}

/// Fired when an item is picked up or despawns from the ground.
public struct ItemDespawnedEvent: Sendable {
    public let item: Item
    /// Creates the event for the given item.
    public init(item: Item) {
        self.item = item
    }
}

/// Fired when a right-click or tap context menu entry is registered.
public struct MenuEntryAddedEvent: Sendable {
    public let option: String
    public let target: String
    public let identifier: Int
    public let opcode: Int
    public var isConsumed: Bool

    /// Creates the event describing one menu entry; plugins may mark it consumed.
    public init(option: String, target: String, identifier: Int, opcode: Int, isConsumed: Bool = false) {
        self.option = option
        self.target = target
        self.identifier = identifier
        self.opcode = opcode
        self.isConsumed = isConsumed
    }
}

/// Fired when a player character changes animations (e.g. idle to mining, casting, or running).
public struct PlayerAnimationChangedEvent: Sendable {
    public let player: PlayerActor
    public let oldAnimation: Int
    public let newAnimation: Int

    /// Creates the event with the player and its previous and new animation ids.
    public init(player: PlayerActor, oldAnimation: Int, newAnimation: Int) {
        self.player = player
        self.oldAnimation = oldAnimation
        self.newAnimation = newAnimation
    }
}

// MARK: - EventBus Implementation

/// Thread-safe publish-subscribe message broker.
public final class EventBus {
    /// Shared singleton instance.
    public static let shared = EventBus()

    private let lock = NSLock()
    private var subscribers: [ObjectIdentifier: [(Any) -> Void]] = [:]

    // Private so the shared singleton is the only instance.
    private init() {}

    /// Subscribe an observer to a specific event type.
    ///
    /// - Parameters:
    ///   - observer: The subscribing object instance (used as lifecycle key).
    ///   - eventType: The type of event to listen for (e.g. GameTickEvent.self).
    ///   - handler: Closure invoked when a matching event is published.
    public func subscribe<T>(_ observer: AnyObject, eventType: T.Type, handler: @escaping (T) -> Void) {
        lock.lock()
        defer { lock.unlock() }

        // Use ObjectIdentifier as a unique key for the observer instance
        let id = ObjectIdentifier(observer)
        // Wrap closure with type-casting check
        let wrapper: (Any) -> Void = { event in
            if let typedEvent = event as? T {
                handler(typedEvent)
            }
        }

        if subscribers[id] != nil {
            subscribers[id]?.append(wrapper)
        } else {
            subscribers[id] = [wrapper]
        }
    }

    /// Unsubscribe an observer from all events (typically called in plugin deinit or shutDown).
    ///
    /// - Parameter observer: The object to remove from the subscriber dictionary.
    public func unsubscribe(_ observer: AnyObject) {
        lock.lock()
        defer { lock.unlock() }
        let id = ObjectIdentifier(observer)
        subscribers.removeValue(forKey: id)
    }

    /// Publish an event to all subscribed listeners.
    ///
    /// - Parameter event: The event instance being broadcast.
    public func publish<T>(_ event: T) {
        lock.lock()
        // Extract snapshot of handlers to prevent deadlocks during callback execution
        let handlers = subscribers.values.flatMap { $0 }
        lock.unlock()

        // Dispatch event to each listener
        for handler in handlers {
            handler(event)
        }
    }
}
