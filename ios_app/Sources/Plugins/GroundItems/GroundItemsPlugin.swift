// ==============================================================================
// Program: GroundItemsPlugin.swift
// Programmer: Ethan-da-Tech-Wizard
// Last Modified: November 18, 2026
// Purpose: Ground Loot Highlighting and Economic Valuation Overlay Plugin.
//          Renders color-coded text tags and contrast bounding boxes over dropped
//          items on the 3D game canvas according to Grand Exchange market prices.
// ==============================================================================

// ==============================================================================
// Overview: Economic Data Visualization:
// ==============================================================================
// In multiplayer online games with complex trading economies, quickly identifying
// valuable item drops among piles of clutter is essential for efficient gameplay.
//
// Overlay Rendering Strategy:
// 1. World-to-Screen Projection:
//    Iterates through `gameState.groundItems`. Each item's tile coordinate is projected
//    into 2D screen coordinates (`Perspective.localToCanvas`).
// 2. Legibility Optimization (Contrast Bounding Boxes):
//    Text drawn directly over 3D grass, dungeon floors, or water textures is hard
//    to read. We compute the text width dynamically and draw a dark semi-transparent
//    background box (`UIColor.black.withAlphaComponent(0.65)`) behind the text.
// 3. Color-Coded Tiers:
//    - Low: White text (common drops).
//    - Medium: Light green (notable runes, herbs).
//    - High: Orange (rare weapons, armor).
//    - Insane: Pink (ultra-rare uniques > 1M GP).
// ==============================================================================

import Foundation
import CoreGraphics
import UIKit

/// Ground Items overlay plugin displaying dropped loot, values, and despawn timers.
public final class GroundItemsPlugin: Plugin {
    public let id: String = "ground_items"
    public let name: String = "Ground Items"
    public let description: String = "Highlights dropped items with color-coding based on Grand Exchange / High Alchemy value."
    public var isEnabled: Bool = true

    // Configuration settings
    public var showGePrice: Bool = true
    public var showHaPrice: Bool = false
    public var showDespawnTimer: Bool = true
    public var highlightValueThreshold: Int = 10_000

    public init() {}

    /// Lifecycle hook: Started up.
    public func startUp() {
        print("✅ [GroundItemsPlugin] Started up.")
    }

    /// Lifecycle hook: Shut down.
    public func shutDown() {
        print("🛑 [GroundItemsPlugin] Shut down.")
    }

    /// Renders text labels and background boxes for all ground items in view.
    ///
    /// - Parameter context: MetalRenderContext containing scene and camera data.
    /// - Returns: Array of OverlayDrawCommands to be rendered by Metal.
    public func renderOverlay(context: MetalRenderContext) -> [OverlayDrawCommand] {
        var commands: [OverlayDrawCommand] = []
        let gameState = context.gameState
        let viewport = context.viewportSize

        // Step 1: Iterate over each ground item in the game state
        for item in gameState.groundItems {
            // Step 2: Ensure item has a valid world coordinate inside the 104x104 scene
            guard let worldPoint = item.worldPoint,
                  let local = worldPoint.toLocalPoint(baseX: gameState.baseTileX, baseY: gameState.baseTileY) else {
                continue
            }

            let tileHeight = gameState.getTileHeight(sceneX: local.sceneX, sceneY: local.sceneY)

            // Step 3: Project 3D ground tile position to 2D screen coordinates
            guard let screenPos = Perspective.localToCanvas(
                localPoint: local,
                z: tileHeight,
                cameraX: gameState.cameraX,
                cameraY: gameState.cameraY,
                cameraZ: gameState.cameraZ,
                cameraPitch: gameState.cameraPitch,
                cameraYaw: gameState.cameraYaw,
                zoom: gameState.cameraZoom,
                viewportSize: viewport
            ) else {
                continue
            }

            // Step 4: Determine text color based on market value tier
            let tierColor = uiColorForTier(item.valueTier)

            // Step 5: Format label text with quantity and Grand Exchange total value
            var labelText = item.name
            if item.quantity > 1 {
                labelText += " (\(item.quantity))"
            }
            if showGePrice && item.gePrice > 0 {
                labelText += " [\(formatGp(item.totalGeValue))]"
            }

            // Step 6: Calculate dimensions for the dark background bounding box
            let textWidth: CGFloat = CGFloat(labelText.count * 7 + 12)
            let boxRect = CGRect(x: screenPos.x - textWidth / 2, y: screenPos.y - 12, width: textWidth, height: 20)

            // Step 7: Emit bounding box draw command for contrast legibility
            commands.append(.boundingBox(rect: boxRect, color: UIColor.black.withAlphaComponent(0.65).cgColor, cornerRadius: 3.0))

            // Step 8: Emit text draw command with tier accent color
            commands.append(.text(
                text: labelText,
                position: CGPoint(x: boxRect.minX + 6, y: boxRect.minY + 4),
                color: tierColor.cgColor,
                fontName: "HelveticaNeue-Bold",
                fontSize: 11.0
            ))
        }

        return commands
    }

    /// Map ItemValueTier to appropriate display UIColor.
    private func uiColorForTier(_ tier: ItemValueTier) -> UIColor {
        switch tier {
        case .hidden: return .gray
        case .low:    return .white
        case .medium: return UIColor(red: 0.6, green: 1.0, blue: 0.6, alpha: 1.0)
        case .high:   return UIColor(red: 1.0, green: 0.7, blue: 0.0, alpha: 1.0)
        case .insane: return UIColor(red: 1.0, green: 0.4, blue: 0.7, alpha: 1.0)
        }
    }

    /// Format integer GP amounts with K (thousands) or M (millions) suffixes.
    private func formatGp(_ amount: Int) -> String {
        if amount >= 10_000_000 {
            return "\(amount / 1_000_000)M"
        } else if amount >= 10_000 {
            return "\(amount / 1_000)K"
        } else {
            return "\(amount)"
        }
    }
}
