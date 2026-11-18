//
//  LocalPoint.swift
//  RuneLiteMobile
//
//  Created for iOS Standalone RuneLite Client Architecture.
//  Copyright © 2026 TWU LLC. All rights reserved.
//

import Foundation

/// Represents a fine-grained 2D coordinate inside the 104x104 local scene chunk.
/// Each tile is 128x128 fine units (center is at +64, +64).
public struct LocalPoint: Hashable, Codable, Sendable, CustomStringConvertible {
    /// Fine local coordinate X (0 ... 13312)
    public let x: Int
    /// Fine local coordinate Y (0 ... 13312)
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    /// Tile X in scene coordinates (0 ... 103)
    public var sceneX: Int {
        return x / 128
    }

    /// Tile Y in scene coordinates (0 ... 103)
    public var sceneY: Int {
        return y / 128
    }

    public var description: String {
        return "LocalPoint(sceneX: \(sceneX), sceneY: \(sceneY), fine: (\(x), \(y)))"
    }

    /// Creates a LocalPoint centered on a given scene tile
    public static func fromSceneTile(sceneX: Int, sceneY: Int) -> LocalPoint {
        return LocalPoint(x: sceneX * 128 + 64, y: sceneY * 128 + 64)
    }

    /// Returns distance to another local point in fine units
    public func distanceTo(_ other: LocalPoint) -> Double {
        let dx = Double(self.x - other.x)
        let dy = Double(self.y - other.y)
        return sqrt(dx * dx + dy * dy)
    }
}
