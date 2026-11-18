//
//  WorldPoint.swift
//  RuneLiteMobile
//
//  Created for iOS Standalone RuneLite Client Architecture.
//  Copyright © 2026 TWU LLC. All rights reserved.
//

import Foundation

/// Represents a three-dimensional world coordinate tile in the OSRS universe.
public struct WorldPoint: Hashable, Codable, Sendable, CustomStringConvertible {
    /// World coordinate X (Global Gielinor grid: 1152 ... 3904)
    public let x: Int
    /// World coordinate Y (Global Gielinor grid: 2496 ... 4160)
    public let y: Int
    /// Plane / Elevation layer (0 ... 3)
    public let plane: Int

    public init(x: Int, y: Int, plane: Int = 0) {
        self.x = x
        self.y = y
        self.plane = max(0, min(3, plane))
    }

    public var description: String {
        return "WorldPoint(\(x), \(y), plane: \(plane))"
    }

    /// Chebyshev / Manhattan distance to another world point on the same plane
    public func distanceTo(_ other: WorldPoint) -> Int {
        guard self.plane == other.plane else { return Int.max }
        return max(abs(self.x - other.x), abs(self.y - other.y))
    }

    /// Euclidean distance squared for efficient threshold comparisons
    public func distanceSquaredTo(_ other: WorldPoint) -> Double {
        guard self.plane == other.plane else { return Double.infinity }
        let dx = Double(self.x - other.x)
        let dy = Double(self.y - other.y)
        return dx * dx + dy * dy
    }

    /// Returns a new WorldPoint offset by delta coordinates
    public func offset(dx: Int, dy: Int, dPlane: Int = 0) -> WorldPoint {
        return WorldPoint(x: self.x + dx, y: self.y + dy, plane: self.plane + dPlane)
    }

    /// Convert to local scene chunk coordinates relative to base tile
    public func toLocalPoint(baseX: Int, baseY: Int) -> LocalPoint? {
        let sceneX = (self.x - baseX) * 128 + 64
        let sceneY = (self.y - baseY) * 128 + 64
        guard sceneX >= 0 && sceneX < 104 * 128 && sceneY >= 0 && sceneY < 104 * 128 else {
            return nil
        }
        return LocalPoint(x: sceneX, y: sceneY)
    }
}
