// ==============================================================================
// Program: EventBus.swift
// Programmer: Ethan-da-Tech-Wizard
// Last Modified: November 18, 2026
// Purpose: Decoupled Publish-Subscribe Event Dispatch Bus for RuneLite Mobile iOS.
//          Enables game loop, network daemon, and touch pipeline to broadcast
//          typed events (ticks, stat changes, item spawns, menu entries) to
//          active plugins without tight coupling.
// ==============================================================================

// ==============================================================================
// Architecture Overview & Publish-Subscribe (Pub/Sub) Pattern:
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
// Event payloads are small immutable value types (Sendable) so handlers on any thread can read them safely.
public struct GameTickEvent: Sendable {
    public let tickCount: Int
    public init(tickCount: Int) {
        self.tickCount = tickCount
    }
}

/// Fired every screen redraw frame with the delta elapsed time in seconds.
public struct ClientTickEvent: Sendable {
    public let deltaTime: TimeInterval
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
    public init(item: Item) {
        self.item = item
    }
}

/// Fired when an item is picked up or despawns from the ground.
public struct ItemDespawnedEvent: Sendable {
    public let item: Item
    public init(item: Item) {
        self.item = item
    }
}

/// Fired when a right-click or tap context menu entry is registered.
// isConsumed is a var so a handler could mark the entry handled, but publish() passes the event BY VALUE to every handler,
// so a change made by one handler is not visible to the others or to the publisher.
public struct MenuEntryAddedEvent: Sendable {
    public let option: String
    public let target: String
    public let identifier: Int
    public let opcode: Int
    public var isConsumed: Bool

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
    // Handlers are stored type-erased as (Any) -> Void, keyed by observer identity; one observer may hold several handlers.
    private var subscribers: [ObjectIdentifier: [(Any) -> Void]] = [:]

    private init() {}

    /// Subscribe an observer to a specific event type.
    ///
    /// - Parameters:
    ///   - observer: The subscribing object instance (used as lifecycle key).
    ///   - eventType: The type of event to listen for (e.g. GameTickEvent.self).
    ///   - handler: Closure invoked when a matching event is published.
    // Each handler is wrapped in a closure that downcasts to T, so a handler only runs for events of its own type.
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

        // Append to the observer's existing list or start a new one.
        if subscribers[id] != nil {
            subscribers[id]?.append(wrapper)
        } else {
            subscribers[id] = [wrapper]
        }
    }

    /// Unsubscribe an observer from all events (typically called in plugin deinit or shutDown).
    ///
    /// - Parameter observer: The object to remove from the subscriber dictionary.
    // Removes ALL handlers registered by this observer; there is no per-event-type unsubscribe.
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
        // Copy under the lock, call outside it: a handler may itself subscribe or publish without deadlocking.
        // Every handler for every event type is invoked on the publisher's thread, and each one filters by type.
        // Extract snapshot of handlers to prevent deadlocks during callback execution
        let handlers = subscribers.values.flatMap { $0 }
        lock.unlock()

        // Dispatch event to each listener
        for handler in handlers {
            handler(event)
        }
    }
}
