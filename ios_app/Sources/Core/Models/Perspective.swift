// ==============================================================================
// Program: Perspective.swift
// Programmer: Ethan-da-Tech-Wizard
// Last Modified: November 18, 2026
// Purpose: 3D-to-2D Perspective Projection Engine for RuneLite Mobile iOS.
//          Converts 3D OSRS scene points into 2D Apple Metal screen coordinates
//          using precomputed fixed-point trigonometric sine/cosine lookup tables,
//          camera pitch/yaw Euler rotation matrices, and perspective division.
// ==============================================================================

// ==============================================================================
// Architecture Overview & 3D Graphics Mathematics:
// ==============================================================================
// In computer graphics, rendering a 3D virtual
// world onto a flat 2D screen requires a "perspective projection pipeline".
//
// Pipeline Mathematics Step-by-Step:
// 1. Translation to Camera Space:
//    Subtract camera position from target object position:
//    `dx = objectX - cameraX`
//    `dy = objectY - cameraY`
//    `dz = objectZ - cameraZ`
// 2. Camera Rotation (Yaw & Pitch):
//    - Yaw Rotation (Z-axis / Horizontal camera orbit):
//      `x1 = (dx * cosYaw + dy * sinYaw) >> 16`
//      `y1 = (dy * cosYaw - dx * sinYaw) >> 16`
//    - Pitch Rotation (X-axis / Vertical camera tilt):
//      `z2 = (dz * cosPitch - y1 * sinPitch) >> 16`
//      `y2 = (y1 * cosPitch + dz * sinPitch) >> 16`
// 3. Near-Plane Clipping:
//    If `y2 < 50` (depth into screen), the object is behind or too close to the
//    camera and is culled.
// 4. Perspective Division:
//    Objects further away must appear smaller! We divide by depth `y2`:
//    `screenX = halfWidth + (x1 * zoom) / y2`
//    `screenY = halfHeight + (z2 * zoom) / y2`
//
// Why Precomputed Lookup Tables:
// Computing floating-point `sin()` and `cos()` at 60 FPS drains mobile battery.
// Instead, we precalculate a 2048-entry integer lookup table scaled by 65,536 (2^16),
// allowing fast integer multiplication and bit-shift operations (`>> 16`).
// ==============================================================================

import Foundation
import CoreGraphics

/// Perspective projection engine: converts 3D OSRS scene points into 2D Apple Metal screen coordinates.
// Port of RuneLite's Perspective class: fixed-point (integer) 3D-to-screen projection using OSRS conventions.
public final class Perspective {
    public static let unitTileSize: Int = 128
    public static let sceneSize: Int = 104

    // Trigonometric sine lookup table (2048 angular units per circle, scaled by 65,536)
    // 2048 steps per revolution; the 65,536 scale gives 16 fractional bits, undone with >> 16 below.
    public static let sinTable: [Int] = {
        var table = [Int](repeating: 0, count: 2048)
        for i in 0..<2048 {
            table[i] = Int(sin(Double(i) * Double.pi / 1024.0) * 65536.0)
        }
        return table
    }()

    // Trigonometric cosine lookup table (2048 angular units per circle, scaled by 65,536)
    public static let cosTable: [Int] = {
        var table = [Int](repeating: 0, count: 2048)
        for i in 0..<2048 {
            table[i] = Int(cos(Double(i) * Double.pi / 1024.0) * 65536.0)
        }
        return table
    }()

    /// Project a 3D scene point into 2D viewport coordinates.
    ///
    /// - Parameters:
    ///   - localPoint: Fine local scene coordinate (X, Y).
    ///   - z: Height elevation above ground (in fine height units).
    ///   - cameraX: Camera X fine position.
    ///   - cameraY: Camera Y fine position.
    ///   - cameraZ: Camera Z fine position.
    ///   - cameraPitch: Camera pitch angle (0 ... 383).
    ///   - cameraYaw: Camera yaw angle (0 ... 2047).
    ///   - zoom: Viewport zoom scale factor.
    ///   - viewportSize: Viewport dimensions (width, height in points).
    /// - Returns: Projected CGPoint on screen, or nil if behind camera or clipped.
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
        // Step 1: Camera relative translation deltas
        let dx = localPoint.x - cameraX
        let dy = localPoint.y - cameraY
        let dz = z - cameraZ

        // Step 2: Constrain angles to 2048-element table using bitwise AND mask
        // & 2047 wraps any angle into the table (valid because 2048 is a power of two, including for negative inputs in two's complement).
        let yawIndex = cameraYaw & 2047
        let pitchIndex = cameraPitch & 2047

        let sinYaw = sinTable[yawIndex]
        let cosYaw = cosTable[yawIndex]
        let sinPitch = sinTable[pitchIndex]
        let cosPitch = cosTable[pitchIndex]

        // Step 3: Apply Yaw Rotation (Z-axis) with 16-bit fixed point shift
        let x1 = (dx * cosYaw + dy * sinYaw) >> 16
        let y1 = (dy * cosYaw - dx * sinYaw) >> 16

        // Step 4: Apply Pitch Rotation (X-axis) with 16-bit fixed point shift
        let z2 = (dz * cosPitch - y1 * sinPitch) >> 16
        let y2 = (y1 * cosPitch + dz * sinPitch) >> 16

        // Step 5: Near-plane clipping: object must be in front of the camera (y2 >= 50)
        // Near clip: anything closer than 50 units to the camera plane is dropped to avoid divide-by-near-zero and huge projections.
        guard y2 >= 50 else { return nil }

        // Step 6: Viewport center calculation
        let halfWidth = viewportSize.width / 2.0
        let halfHeight = viewportSize.height / 2.0

        // Step 7: Perspective division — scale coordinates inversely by distance y2
        // Perspective divide: screen offset = (lateral or vertical offset * zoom) / depth, centred on the viewport.
        let screenX = halfWidth + (CGFloat(x1 * zoom) / CGFloat(y2))
        let screenY = halfHeight + (CGFloat(z2 * zoom) / CGFloat(y2))

        // Step 8: Viewport bounds check (allow 50pt margin for clipping)
        guard screenX >= -50 && screenX <= viewportSize.width + 50 &&
              screenY >= -50 && screenY <= viewportSize.height + 50 else {
            return nil
        }

        // Return projected 2D screen point
        return CGPoint(x: screenX, y: screenY)
    }

    /// Calculate the 4 projected screen points for a ground tile polygon.
    ///
    /// - Parameters:
    ///   - localPoint: Center fine coordinates of the tile.
    ///   - tileHeight: Elevation height of the ground surface.
    ///   - cameraX, cameraY, cameraZ: Camera world positions.
    ///   - cameraPitch, cameraYaw: Camera orientation angles.
    ///   - zoom: Viewport zoom scale.
    ///   - viewportSize: Screen size in points.
    /// - Returns: Array of 4 CGPoints forming the quadrilateral outline on screen.
    // Returns nil if ANY of the four corners is clipped, so tiles partly off-screen or behind the camera disappear entirely.
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
        // Generate the 4 corners of the 128x128 tile
        let p1 = LocalPoint(x: localPoint.x - halfTile, y: localPoint.y - halfTile)
        let p2 = LocalPoint(x: localPoint.x + halfTile, y: localPoint.y - halfTile)
        let p3 = LocalPoint(x: localPoint.x + halfTile, y: localPoint.y + halfTile)
        let p4 = LocalPoint(x: localPoint.x - halfTile, y: localPoint.y + halfTile)

        // Project all 4 corners into 2D screen coordinates
        guard let c1 = localToCanvas(localPoint: p1, z: tileHeight, cameraX: cameraX, cameraY: cameraY, cameraZ: cameraZ, cameraPitch: cameraPitch, cameraYaw: cameraYaw, zoom: zoom, viewportSize: viewportSize),
              let c2 = localToCanvas(localPoint: p2, z: tileHeight, cameraX: cameraX, cameraY: cameraY, cameraZ: cameraZ, cameraPitch: cameraPitch, cameraYaw: cameraYaw, zoom: zoom, viewportSize: viewportSize),
              let c3 = localToCanvas(localPoint: p3, z: tileHeight, cameraX: cameraX, cameraY: cameraY, cameraZ: cameraZ, cameraPitch: cameraPitch, cameraYaw: cameraYaw, zoom: zoom, viewportSize: viewportSize),
              let c4 = localToCanvas(localPoint: p4, z: tileHeight, cameraX: cameraX, cameraY: cameraY, cameraZ: cameraZ, cameraPitch: cameraPitch, cameraYaw: cameraYaw, zoom: zoom, viewportSize: viewportSize) else {
            return nil
        }

        return [c1, c2, c3, c4]
    }
}
