//
//  EventBus.swift
//  RuneLiteMobile
//
//  Created for iOS Standalone RuneLite Client Architecture.
//  Copyright © 2026 TWU LLC. All rights reserved.
//

import Foundation

// MARK: - Event Definitions

public struct GameTickEvent: Sendable {
    public let tickCount: Int
    public init(tickCount: Int) {
        self.tickCount = tickCount
    }
}

public struct ClientTickEvent: Sendable {
    public let deltaTime: TimeInterval
    public init(deltaTime: TimeInterval) {
        self.deltaTime = deltaTime
    }
}

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

public struct ItemSpawnedEvent: Sendable {
    public let item: Item
    public init(item: Item) {
        self.item = item
    }
}

public struct ItemDespawnedEvent: Sendable {
    public let item: Item
    public init(item: Item) {
        self.item = item
    }
}

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

public final class EventBus {
    public static let shared = EventBus()

    private let lock = NSLock()
    private var subscribers: [ObjectIdentifier: [(Any) -> Void]] = [:]

    private init() {}

    /// Subscribe an observer to a specific event type
    public func subscribe<T>(_ observer: AnyObject, eventType: T.Type, handler: @escaping (T) -> Void) {
        lock.lock()
        defer { lock.unlock() }

        let id = ObjectIdentifier(observer)
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

    /// Unsubscribe an observer from all events
    public func unsubscribe(_ observer: AnyObject) {
        lock.lock()
        defer { lock.unlock() }
        let id = ObjectIdentifier(observer)
        subscribers.removeValue(forKey: id)
    }

    /// Publish an event to all subscribed listeners
    public func publish<T>(_ event: T) {
        lock.lock()
        let handlers = subscribers.values.flatMap { $0 }
        lock.unlock()

        for handler in handlers {
            handler(event)
        }
    }
}
