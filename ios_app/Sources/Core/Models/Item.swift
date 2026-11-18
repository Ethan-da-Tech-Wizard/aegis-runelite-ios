//
//  Item.swift
//  RuneLiteMobile
//
//  Created for iOS Standalone RuneLite Client Architecture.
//  Copyright © 2026 TWU LLC. All rights reserved.
//

import Foundation

/// Value tier classification for Ground Items plugin
public enum ItemValueTier: String, Codable, Sendable {
    case hidden
    case low       // < 10,000 GP
    case medium    // 10,000 ... 100,000 GP
    case high      // 100,000 ... 1,000,000 GP
    case insane    // > 1,000,000 GP

    public var hexColor: String {
        switch self {
        case .hidden: return "#808080"
        case .low:    return "#FFFFFF"
        case .medium: return "#99FF99"
        case .high:   return "#FFA500"
        case .insane: return "#FF69B4"
        }
    }
}

/// Represents an item dropped on the ground or in inventory
public struct Item: Hashable, Codable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let quantity: Int
    public let gePrice: Int
    public let haPrice: Int
    public let worldPoint: WorldPoint?
    public let spawnTick: Int

    public init(
        id: Int,
        name: String,
        quantity: Int = 1,
        gePrice: Int = 0,
        haPrice: Int = 0,
        worldPoint: WorldPoint? = nil,
        spawnTick: Int = 0
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.gePrice = gePrice
        self.haPrice = haPrice
        self.worldPoint = worldPoint
        self.spawnTick = spawnTick
    }

    /// Total Grand Exchange value
    public var totalGeValue: Int {
        return gePrice * quantity
    }

    /// Total High Alchemy value
    public var totalHaValue: Int {
        return haPrice * quantity
    }

    /// Determine value tier
    public var valueTier: ItemValueTier {
        let val = max(totalGeValue, totalHaValue)
        if val >= 1_000_000 {
            return .insane
        } else if val >= 100_000 {
            return .high
        } else if val >= 10_000 {
            return .medium
        } else {
            return .low
        }
    }
}
