// ==============================================================================
// Program: Item.swift
// Programmer: Ethan-da-Tech-Wizard
// Course: CIS 156 / Advanced Systems
// Last Modified: November 18, 2026
// Purpose: Item & Loot Value Tier Model for RuneLite Mobile iOS.
//          Models ground and inventory items, computes Grand Exchange and High
//          Alchemy valuations, and categorizes items into visual color tiers
//          for high-visibility HUD rendering.
// ==============================================================================

// ==============================================================================
// CIS 156 Educational Overview & Domain Data Modeling:
// ==============================================================================
// In video game economy modeling, items carry distinct identifiers, quantities,
// and market valuations.
//
// Ground Items Value Tiering:
// - Players need immediate visual cues to distinguish between high-value loot
//   (e.g., Twisted Bow, Abyssal Whip) and low-value junk (e.g., Bones, Ashes).
// - ItemValueTier divides items into color-coded categories:
//   * Hidden: Non-notable items (< customizable threshold or ignored).
//   * Low (< 10k GP): White text (#FFFFFF).
//   * Medium (10k...100k GP): Light Green text (#99FF99).
//   * High (100k...1M GP): Orange text (#FFA500).
//   * Insane (> 1M GP): Pink text (#FF69B4).
// ==============================================================================

import Foundation

/// Value tier classification for Ground Items plugin.
public enum ItemValueTier: String, Codable, Sendable {
    case hidden
    case low       // < 10,000 GP
    case medium    // 10,000 ... 100,000 GP
    case high      // 100,000 ... 1,000,000 GP
    case insane    // > 1,000,000 GP

    /// Hexadecimal RGB color string used by Metal and Web canvas overlay renderers.
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

/// Represents an item dropped on the ground or in inventory.
public struct Item: Hashable, Codable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let quantity: Int
    public let gePrice: Int
    public let haPrice: Int
    public let worldPoint: WorldPoint?
    public let spawnTick: Int

    /// Convenience accessor returning non-optional location for plugins.
    public var location: WorldPoint {
        return worldPoint ?? WorldPoint(x: 0, y: 0, plane: 0)
    }

    /// Initialize an Item model with pricing and optional location.
    ///
    /// - Parameters:
    ///   - id: Unique OSRS item ID (e.g., 4151 for Abyssal Whip).
    ///   - name: Plain-English item display name.
    ///   - quantity: Stack quantity (default: 1).
    ///   - gePrice: Individual item Grand Exchange market price in gold coins (GP).
    ///   - haPrice: Individual item High Alchemy magic price in gold coins (GP).
    ///   - worldPoint: World tile where the item is sitting on the ground (or nil for inventory).
    ///   - spawnTick: The engine game tick during which the item was dropped.
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

    /// Total Grand Exchange value computed as unit price times stack quantity.
    public var totalGeValue: Int {
        return gePrice * quantity
    }

    /// Total High Alchemy value computed as unit price times stack quantity.
    public var totalHaValue: Int {
        return haPrice * quantity
    }

    /// Determine value tier based on the higher of GE price or High Alchemy price.
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
