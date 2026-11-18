// ==============================================================================
// Program: TileIndicatorsPlugin.swift
// Programmer: Ethan-da-Tech-Wizard
// Course: CIS 156 / Advanced Systems
// Last Modified: November 18, 2026
// Purpose: Ground Tile Highlighting Overlay Plugin for RuneLite Mobile iOS.
//          Renders visual bounding quadrilaterals onto the 3D game surface to
//          indicate the player's destination tile, hover tile, and current position.
// ==============================================================================

// ==============================================================================
// CIS 156 Educational Overview & 3D Spatial Indicators:
// ==============================================================================
// In isometric and top-down games, player movement can feel ambiguous when
// characters pathfind across irregular terrain.
//
// How Tile Indicators Aid Navigation:
// 1. Destination Tile (Red Highlight): Marks the exact world tile where the player
//    tapped to walk. This gives immediate feedback confirming that the touch was
//    registered by the game engine.
// 2. Current Player Tile (Cyan Highlight): Marks the discrete grid tile where the
//    server considers the player to be standing. Because character walking animations
//    interpolate smoothly between tiles, visual sprites often lag behind server position.
//    Highlighting the true server tile is vital for dodging boss attacks in high-level PvM.
// 3. Hover Tile (Yellow Highlight): Previews the tile directly beneath a cursor or finger.
//
// Rendering Process:
// For each active highlight, the plugin:
// - Converts the WorldPoint into local chunk coordinates (`LocalPoint`).
// - Retrieves ground elevation height (`getTileHeight`).
// - Computes the 4 screen-space corner vertices using `Perspective.getCanvasTilePoly()`.
// - Emits an `OverlayDrawCommand.polygon` for Metal hardware rendering.
// ==============================================================================

import Foundation
import CoreGraphics
import UIKit

/// Renders destination tile, hover tile, and current player tile highlights.
public final class TileIndicatorsPlugin: Plugin {
    public let id: String = "tile_indicators"
    public let name: String = "Tile Indicators"
    public let description: String = "Highlights the destination tile, hover tile, and current player tile."
    public var isEnabled: Bool = true

    // Configurable highlight settings
    public var highlightDestination: Bool = true
    public var highlightCurrentTile: Bool = true
    public var highlightHoverTile: Bool = true

    // High-visibility semi-transparent colors
    public var destinationColor: CGColor = UIColor.systemRed.withAlphaComponent(0.6).cgColor
    public var currentTileColor: CGColor = UIColor.systemCyan.withAlphaComponent(0.4).cgColor
    public var hoverColor: CGColor = UIColor.systemYellow.withAlphaComponent(0.4).cgColor

    public init() {}

    /// Lifecycle hook: Called when the plugin is activated.
    public func startUp() {
        print("✅ [TileIndicatorsPlugin] Started up.")
    }

    /// Lifecycle hook: Called when the plugin is deactivated.
    public func shutDown() {
        print("🛑 [TileIndicatorsPlugin] Shut down.")
    }

    /// Generates polygon overlay draw commands for all active highlighted tiles.
    ///
    /// - Parameter context: The MetalRenderContext containing camera and viewport parameters.
    /// - Returns: Array of OverlayDrawCommand primitives.
    public func renderOverlay(context: MetalRenderContext) -> [OverlayDrawCommand] {
        var commands: [OverlayDrawCommand] = []
        let gameState = context.gameState
        let viewport = context.viewportSize

        // Stage 1: Render Destination Tile Highlight
        if highlightDestination, let dest = gameState.destinationTile {
            if let local = dest.toLocalPoint(baseX: gameState.baseTileX, baseY: gameState.baseTileY) {
                let tileHeight = gameState.getTileHeight(sceneX: local.sceneX, sceneY: local.sceneY)
                if let poly = Perspective.getCanvasTilePoly(
                    localPoint: local,
                    tileHeight: tileHeight,
                    cameraX: gameState.cameraX,
                    cameraY: gameState.cameraY,
                    cameraZ: gameState.cameraZ,
                    cameraPitch: gameState.cameraPitch,
                    cameraYaw: gameState.cameraYaw,
                    zoom: gameState.cameraZoom,
                    viewportSize: viewport
                ) {
                    commands.append(.polygon(
                        points: poly,
                        fillColor: destinationColor,
                        strokeColor: destinationColor,
                        strokeWidth: 2.0
                    ))
                }
            }
        }

        // Stage 2: Render Current Player Tile Highlight
        if highlightCurrentTile {
            let player = gameState.localPlayer
            let local = player.localPoint
            let tileHeight = gameState.getTileHeight(sceneX: local.sceneX, sceneY: local.sceneY)
            if let poly = Perspective.getCanvasTilePoly(
                localPoint: local,
                tileHeight: tileHeight,
                cameraX: gameState.cameraX,
                cameraY: gameState.cameraY,
                cameraZ: gameState.cameraZ,
                cameraPitch: gameState.cameraPitch,
                cameraYaw: gameState.cameraYaw,
                zoom: gameState.cameraZoom,
                viewportSize: viewport
            ) {
                commands.append(.polygon(
                    points: poly,
                    fillColor: currentTileColor,
                    strokeColor: currentTileColor,
                    strokeWidth: 1.5
                ))
            }
        }

        // Stage 3: Render Hover Tile Highlight
        if highlightHoverTile, let hover = gameState.hoverTile {
            if let local = hover.toLocalPoint(baseX: gameState.baseTileX, baseY: gameState.baseTileY) {
                let tileHeight = gameState.getTileHeight(sceneX: local.sceneX, sceneY: local.sceneY)
                if let poly = Perspective.getCanvasTilePoly(
                    localPoint: local,
                    tileHeight: tileHeight,
                    cameraX: gameState.cameraX,
                    cameraY: gameState.cameraY,
                    cameraZ: gameState.cameraZ,
                    cameraPitch: gameState.cameraPitch,
                    cameraYaw: gameState.cameraYaw,
                    zoom: gameState.cameraZoom,
                    viewportSize: viewport
                ) {
                    commands.append(.polygon(
                        points: poly,
                        fillColor: hoverColor,
                        strokeColor: hoverColor,
                        strokeWidth: 1.0
                    ))
                }
            }
        }

        return commands
    }
}
