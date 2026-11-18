// Program: aegis-runelite-ios - LocalPoint.swift
// Programmer: Ethan-da-Tech-Wizard (written with Claude, an AI assistant)
// Last Modified: 2026-11-18
// Purpose: Sub-tile coordinate model for positions inside the 104x104 local scene.

// ==============================================================================
// Overview: Fixed-Point Sub-Tile Coordinates:
// ==============================================================================
// In computer graphics and physics engines, entities move smoothly across tiles
// rather than teleporting instantly from one integer tile to the next.
//
// Fixed-Point Scaling in OSRS:
// - The loaded game region consists of a 104x104 grid of tiles.
// - Rather than using floating-point numbers (which can introduce rounding errors
//   and non-deterministic physics across different CPU architectures), OSRS subdivides
//   each tile into 128 discrete integer "fine units".
// - Total scene size: 104 * 128 = 13,312 fine units.
// - Tile Center: To place an actor or object in the exact center of a tile,
//   we add half a tile width: `(tileIndex * 128) + 64`.
// ==============================================================================

import Foundation

/// Represents a fine-grained 2D coordinate inside the 104x104 local scene chunk.
/// Each tile is 128x128 fine units (center is at +64, +64).
public struct LocalPoint: Hashable, Codable, Sendable, CustomStringConvertible {
    /// Fine local coordinate X (0 ... 13312)
    public let x: Int
    /// Fine local coordinate Y (0 ... 13312)
    public let y: Int

    /// Initialize with fine unit coordinates.
    ///
    /// - Parameters:
    ///   - x: Fine horizontal unit coordinate.
    ///   - y: Fine vertical unit coordinate.
    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    /// Tile X in scene coordinates (0 ... 103).
    /// Computed by dividing fine units by 128 (integer division / right-shift by 7).
    public var sceneX: Int {
        return x / 128
    }

    /// Tile Y in scene coordinates (0 ... 103).
    public var sceneY: Int {
        return y / 128
    }

    /// Human-readable description.
    public var description: String {
        return "LocalPoint(sceneX: \(sceneX), sceneY: \(sceneY), fine: (\(x), \(y)))"
    }

    /// Creates a LocalPoint centered on a given scene tile.
    ///
    /// - Parameters:
    ///   - sceneX: Scene tile X (0...103).
    ///   - sceneY: Scene tile Y (0...103).
    /// - Returns: LocalPoint positioned at the exact center of the tile.
    public static func fromSceneTile(sceneX: Int, sceneY: Int) -> LocalPoint {
        return LocalPoint(x: sceneX * 128 + 64, y: sceneY * 128 + 64)
    }

    /// Returns distance to another local point in fine units using Pythagorean theorem.
    ///
    /// - Parameter other: Target LocalPoint.
    /// - Returns: Euclidean distance in fine units.
    public func distanceTo(_ other: LocalPoint) -> Double {
        let dx = Double(self.x - other.x)
        let dy = Double(self.y - other.y)
        return sqrt(dx * dx + dy * dy)
    }
}
