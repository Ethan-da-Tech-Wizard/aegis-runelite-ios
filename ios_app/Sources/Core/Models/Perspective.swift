//
//  Perspective.swift
//  RuneLiteMobile
//
//  Created for iOS Standalone RuneLite Client Architecture.
//  Copyright © 2026 TWU LLC. All rights reserved.
//

import Foundation
import CoreGraphics

/// Perspective projection engine: converts 3D OSRS scene points into 2D Apple Metal screen coordinates.
public final class Perspective {
    public static let unitTileSize: Int = 128
    public static let sceneSize: Int = 104

    // Trigonometric sine and cosine lookup tables (2048 angular units per circle)
    public static let sinTable: [Int] = {
        var table = [Int](repeating: 0, count: 2048)
        for i in 0..<2048 {
            table[i] = Int(sin(Double(i) * Double.pi / 1024.0) * 65536.0)
        }
        return table
    }()

    public static let cosTable: [Int] = {
        var table = [Int](repeating: 0, count: 2048)
        for i in 0..<2048 {
            table[i] = Int(cos(Double(i) * Double.pi / 1024.0) * 65536.0)
        }
        return table
    }()

    /// Project a 3D scene point into 2D viewport coordinates
    /// - Parameters:
    ///   - localPoint: Fine local scene coordinate (X, Y)
    ///   - z: Height elevation above ground (in fine height units)
    ///   - cameraX: Camera X fine position
    ///   - cameraY: Camera Y fine position
    ///   - cameraZ: Camera Z fine position
    ///   - cameraPitch: Camera pitch angle (0 ... 383)
    ///   - cameraYaw: Camera yaw angle (0 ... 2047)
    ///   - zoom: Viewport zoom scale
    ///   - viewportSize: Viewport dimensions (width, height in points)
    /// - Returns: Projected CGPoint on screen, or nil if behind camera or clipped
    public static func localToCanvas(
        localPoint: LocalPoint,
        z: Int,
        cameraX: Int,
        cameraY: Int,
        cameraZ: Int,
        cameraPitch: Int,
        cameraYaw: Int,
        zoom: Int,
        viewportSize: CGSize
    ) -> CGPoint? {
        let dx = localPoint.x - cameraX
        let dy = localPoint.y - cameraY
        let dz = z - cameraZ

        let yawIndex = cameraYaw & 2047
        let pitchIndex = cameraPitch & 2047

        let sinYaw = sinTable[yawIndex]
        let cosYaw = cosTable[yawIndex]
        let sinPitch = sinTable[pitchIndex]
        let cosPitch = cosTable[pitchIndex]

        // Rotation around Yaw (Z-axis)
        let x1 = (dx * cosYaw + dy * sinYaw) >> 16
        let y1 = (dy * cosYaw - dx * sinYaw) >> 16

        // Rotation around Pitch (X-axis)
        let z2 = (dz * cosPitch - y1 * sinPitch) >> 16
        let y2 = (y1 * cosPitch + dz * sinPitch) >> 16

        // Ensure object is in front of camera
        guard y2 >= 50 else { return nil }

        let halfWidth = viewportSize.width / 2.0
        let halfHeight = viewportSize.height / 2.0

        let screenX = halfWidth + (CGFloat(x1 * zoom) / CGFloat(y2))
        let screenY = halfHeight + (CGFloat(z2 * zoom) / CGFloat(y2))

        // Basic viewport bounds check (allow 50pt margin for clipping)
        guard screenX >= -50 && screenX <= viewportSize.width + 50 &&
              screenY >= -50 && screenY <= viewportSize.height + 50 else {
            return nil
        }

        return CGPoint(x: screenX, y: screenY)
    }

    /// Calculate the 4 projected screen points for a ground tile polygon
    public static func getCanvasTilePoly(
        localPoint: LocalPoint,
        tileHeight: Int,
        cameraX: Int,
        cameraY: Int,
        cameraZ: Int,
        cameraPitch: Int,
        cameraYaw: Int,
        zoom: Int,
        viewportSize: CGSize
    ) -> [CGPoint]? {
        let halfTile = unitTileSize / 2
        let p1 = LocalPoint(x: localPoint.x - halfTile, y: localPoint.y - halfTile)
        let p2 = LocalPoint(x: localPoint.x + halfTile, y: localPoint.y - halfTile)
        let p3 = LocalPoint(x: localPoint.x + halfTile, y: localPoint.y + halfTile)
        let p4 = LocalPoint(x: localPoint.x - halfTile, y: localPoint.y + halfTile)

        guard let c1 = localToCanvas(localPoint: p1, z: tileHeight, cameraX: cameraX, cameraY: cameraY, cameraZ: cameraZ, cameraPitch: cameraPitch, cameraYaw: cameraYaw, zoom: zoom, viewportSize: viewportSize),
              let c2 = localToCanvas(localPoint: p2, z: tileHeight, cameraX: cameraX, cameraY: cameraY, cameraZ: cameraZ, cameraPitch: cameraPitch, cameraYaw: cameraYaw, zoom: zoom, viewportSize: viewportSize),
              let c3 = localToCanvas(localPoint: p3, z: tileHeight, cameraX: cameraX, cameraY: cameraY, cameraZ: cameraZ, cameraPitch: cameraPitch, cameraYaw: cameraYaw, zoom: zoom, viewportSize: viewportSize),
              let c4 = localToCanvas(localPoint: p4, z: tileHeight, cameraX: cameraX, cameraY: cameraY, cameraZ: cameraZ, cameraPitch: cameraPitch, cameraYaw: cameraYaw, zoom: zoom, viewportSize: viewportSize) else {
            return nil
        }

        return [c1, c2, c3, c4]
    }
}
