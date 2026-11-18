// Program: aegis-runelite-ios - WorldPoint.swift
// Programmer: Ethan-da-Tech-Wizard (written with Claude, an AI assistant)
// Last Modified: 2026-11-18
// Purpose: World coordinate model with plane, Chebyshev distance and conversion to local scene coordinates.

// ==============================================================================
// Overview: Grid Coordinate Systems:
// ==============================================================================
// In computer science and game development, virtual worlds are modeled using
// spatial coordinate grids.
//
// Old School RuneScape World Coordinate System:
// - Global Grid (X, Y): The entire game world (Gielinor) is laid out on a vast
//   discrete 2D integer grid. For example, Lumbridge Castle courtyard sits around
//   tile (3222, 3218), while Varrock center sits around (3212, 3422).
// - Plane Layer (Z / Elevation): Discrete height layers numbered 0 through 3.
//   Plane 0 represents the ground floor. Plane 1 is the 2nd story of a building
//   or rooftop agility route. Planes 2 and 3 represent higher towers.
//
// Distance Metrics:
// 1. Chebyshev Distance (`distanceTo`):
//    `max(abs(x1 - x2), abs(y1 - y2))`
//    In grid-based games with 8-directional movement (orthogonal + diagonal),
//    moving diagonally costs the same 1 step as moving orthogonally. Therefore,
//    Chebyshev distance accurately represents the true number of game steps/turns
//    a player needs to reach a tile or engage in melee combat.
// 2. Euclidean Distance (`distanceSquaredTo`):
//    Straight-line Pythagorean distance `dx^2 + dy^2`. Used for radius checks.
// ==============================================================================

import Foundation

/// Represents a three-dimensional world coordinate tile in the OSRS universe.
public struct WorldPoint: Hashable, Codable, Sendable, CustomStringConvertible {
    /// World coordinate X (Global Gielinor grid: 1152 ... 3904)
    public let x: Int
    /// World coordinate Y (Global Gielinor grid: 2496 ... 4160)
    public let y: Int
    /// Plane / Elevation layer (clamped to 0 ... 3)
    public let plane: Int

    /// Initialize a WorldPoint with given grid coordinates and optional elevation plane.
    ///
    /// - Parameters:
    ///   - x: Global X coordinate.
    ///   - y: Global Y coordinate.
    ///   - plane: Elevation plane (clamped to 0...3). Defaults to 0 (ground level).
    public init(x: Int, y: Int, plane: Int = 0) {
        self.x = x
        self.y = y
        self.plane = max(0, min(3, plane))
    }

    /// Human-readable textual representation for debugging and logging.
    public var description: String {
        return "WorldPoint(\(x), \(y), plane: \(plane))"
    }

    /// Chebyshev / Chessboard distance to another world point on the same plane.
    ///
    /// - Parameter other: Target WorldPoint.
    /// - Returns: Number of tile steps, or Int.max if points are on different planes.
    public func distanceTo(_ other: WorldPoint) -> Int {
        // Different elevation planes cannot be reached via 2D walking
        guard self.plane == other.plane else { return Int.max }
        // Diagonal steps cost 1 unit: take the maximum of horizontal and vertical deltas
        return max(abs(self.x - other.x), abs(self.y - other.y))
    }

    /// Euclidean distance squared for efficient threshold comparisons without square root.
    ///
    /// - Parameter other: Target WorldPoint.
    /// - Returns: Squared Euclidean distance (dx^2 + dy^2).
    public func distanceSquaredTo(_ other: WorldPoint) -> Double {
        guard self.plane == other.plane else { return Double.infinity }
        let dx = Double(self.x - other.x)
        let dy = Double(self.y - other.y)
        return dx * dx + dy * dy
    }

    /// Returns a new WorldPoint offset by delta coordinates.
    ///
    /// - Parameters:
    ///   - dx: Delta X tiles.
    ///   - dy: Delta Y tiles.
    ///   - dPlane: Delta elevation planes.
    /// - Returns: Offset WorldPoint instance.
    public func offset(dx: Int, dy: Int, dPlane: Int = 0) -> WorldPoint {
        return WorldPoint(x: self.x + dx, y: self.y + dy, plane: self.plane + dPlane)
    }

    /// Convert to local scene chunk coordinates relative to base tile.
    ///
    /// - Parameters:
    ///   - baseX: Bottom-left world X tile of the loaded 104x104 scene.
    ///   - baseY: Bottom-left world Y tile of the loaded 104x104 scene.
    /// - Returns: LocalPoint fine coordinates, or nil if outside loaded scene bounds.
    public func toLocalPoint(baseX: Int, baseY: Int) -> LocalPoint? {
        // Convert tile offset to fine units (128 fine units per tile; +64 centers on tile)
        let sceneX = (self.x - baseX) * 128 + 64
        let sceneY = (self.y - baseY) * 128 + 64

        // Validate within 104x104 loaded scene region (104 * 128 = 13,312 units)
        guard sceneX >= 0 && sceneX < 104 * 128 && sceneY >= 0 && sceneY < 104 * 128 else {
            return nil
        }
        return LocalPoint(x: sceneX, y: sceneY)
    }
}
