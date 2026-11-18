//
//  GroundItemsPlugin.swift
//  RuneLiteMobile
//
//  Created for iOS Standalone RuneLite Client Architecture.
//  Copyright © 2026 TWU LLC. All rights reserved.
//

import Foundation
import CoreGraphics
import UIKit

/// Ground Items overlay plugin displaying dropped loot, values, and despawn timers
public final class GroundItemsPlugin: Plugin {
    public let id: String = "ground_items"
    public let name: String = "Ground Items"
    public let description: String = "Highlights dropped items with color-coding based on Grand Exchange / High Alchemy value."
    public var isEnabled: Bool = true

    // Configuration
    public var showGePrice: Bool = true
    public var showHaPrice: Bool = false
    public var showDespawnTimer: Bool = true
    public var highlightValueThreshold: Int = 10_000

    public init() {}

    public func startUp() {
        print("✅ [GroundItemsPlugin] Started up.")
    }

    public func shutDown() {
        print("🛑 [GroundItemsPlugin] Shut down.")
    }

    public func renderOverlay(context: MetalRenderContext) -> [OverlayDrawCommand] {
        var commands: [OverlayDrawCommand] = []
        let gameState = context.gameState
        let viewport = context.viewportSize

        for item in gameState.groundItems {
            guard let worldPoint = item.worldPoint,
                  let local = worldPoint.toLocalPoint(baseX: gameState.baseTileX, baseY: gameState.baseTileY) else {
                continue
            }

            let tileHeight = gameState.getTileHeight(sceneX: local.sceneX, sceneY: local.sceneY)

            // Project center of tile to screen
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

            // Determine item color based on value tier
            let tierColor = uiColorForTier(item.valueTier)

            // Format label text
            var labelText = item.name
            if item.quantity > 1 {
                labelText += " (\(item.quantity))"
            }
            if showGePrice && item.gePrice > 0 {
                labelText += " [\(formatGp(item.totalGeValue))]"
            }

            // Compute background bounding box
            let textWidth: CGFloat = CGFloat(labelText.count * 7 + 12)
            let boxRect = CGRect(x: screenPos.x - textWidth / 2, y: screenPos.y - 12, width: textWidth, height: 20)

            // Add background box draw command
            commands.append(.boundingBox(rect: boxRect, color: UIColor.black.withAlphaComponent(0.65).cgColor, cornerRadius: 3.0))

            // Add text label draw command
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

    private func uiColorForTier(_ tier: ItemValueTier) -> UIColor {
        switch tier {
        case .hidden: return .gray
        case .low:    return .white
        case .medium: return UIColor(red: 0.6, green: 1.0, blue: 0.6, alpha: 1.0)
        case .high:   return UIColor(red: 1.0, green: 0.7, blue: 0.0, alpha: 1.0)
        case .insane: return UIColor(red: 1.0, green: 0.4, blue: 0.7, alpha: 1.0)
        }
    }

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
