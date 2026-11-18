//
//  TileIndicatorsPlugin.swift
//  RuneLiteMobile
//
//  Created for iOS Standalone RuneLite Client Architecture.
//  Copyright © 2026 TWU LLC. All rights reserved.
//

import Foundation
import CoreGraphics
import UIKit

/// Renders destination tile, hover tile, and current player tile highlights
public final class TileIndicatorsPlugin: Plugin {
    public let id: String = "tile_indicators"
    public let name: String = "Tile Indicators"
    public let description: String = "Highlights the destination tile, hover tile, and current player tile."
    public var isEnabled: Bool = true

    // Configurable highlight settings
    public var highlightDestination: Bool = true
    public var highlightCurrentTile: Bool = true
    public var highlightHoverTile: Bool = true

    public var destinationColor: CGColor = UIColor.systemRed.withAlphaComponent(0.6).cgColor
    public var currentTileColor: CGColor = UIColor.systemCyan.withAlphaComponent(0.4).cgColor
    public var hoverColor: CGColor = UIColor.systemYellow.withAlphaComponent(0.4).cgColor

    public init() {}

    public func startUp() {
        print("✅ [TileIndicatorsPlugin] Started up.")
    }

    public func shutDown() {
        print("🛑 [TileIndicatorsPlugin] Shut down.")
    }

    public func renderOverlay(context: MetalRenderContext) -> [OverlayDrawCommand] {
        var commands: [OverlayDrawCommand] = []
        let gameState = context.gameState
        let viewport = context.viewportSize

        // 1. Destination Tile Highlight
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

        // 2. Current Player Tile Highlight
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

        // 3. Hover Tile Highlight
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
