//
//  MetalOverlayRenderer.swift
//  RuneLiteMobile
//
//  Created for iOS Standalone RuneLite Client Architecture.
//  Copyright © 2026 TWU LLC. All rights reserved.
//

import Foundation
import MetalKit
import simd

struct OverlayVertex {
    var position: SIMD2<Float>
    var color: SIMD4<Float>
}

struct ViewportUniforms {
    var viewportSize: SIMD2<Float>
}

/// Hardware-accelerated Metal overlay renderer operating at 60/120 FPS
public final class MetalOverlayRenderer: NSObject, MTKViewDelegate {
    public static let shared = MetalOverlayRenderer()

    public private(set) var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer?

    private override init() {
        super.init()
        setupMetal()
    }

    private func setupMetal() {
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("❌ [MetalOverlayRenderer] Failed to initialize default Metal device.")
            return
        }
        self.device = defaultDevice
        self.commandQueue = defaultDevice.makeCommandQueue()

        do {
            guard let defaultLibrary = defaultDevice.makeDefaultLibrary() else {
                print("⚠️ [MetalOverlayRenderer] Default Metal library not found, building runtime shaders.")
                return
            }
            let vertexFunction = defaultLibrary.makeFunction(name: "overlayVertexShader")
            let fragmentFunction = defaultLibrary.makeFunction(name: "overlayFragmentShader")

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            // Alpha blending for smooth transparent HUD overlays
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

            self.pipelineState = try defaultDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("❌ [MetalOverlayRenderer] Pipeline compilation error: \(error.localizedDescription)")
        }
    }

    // MARK: - MTKViewDelegate

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        GameState.shared.viewportSize = size
    }

    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandQueue = self.commandQueue,
              let pipelineState = self.pipelineState else {
            return
        }

        // Render pass load action is MTLLoadActionClear with alpha 0.0 for transparent HUD
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0.0)

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)

        // Viewport uniforms
        var uniforms = ViewportUniforms(viewportSize: SIMD2<Float>(Float(view.bounds.width), Float(view.bounds.height)))
        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<ViewportUniforms>.stride, index: 1)

        // Collect plugin draw commands
        let context = MetalRenderContext(
            viewportSize: view.bounds.size,
            commandBuffer: commandBuffer,
            renderEncoder: renderEncoder,
            gameState: GameState.shared
        )
        let commands = PluginManager.shared.collectDrawCommands(context: context)

        // Convert commands to vertex quads
        var vertices: [OverlayVertex] = []
        for command in commands {
            switch command {
            case .polygon(let points, let fillColor, _, _):
                guard points.count >= 4 else { continue }
                let col = simdColor(from: fillColor)
                // Two triangles for quad (0, 1, 2) and (0, 2, 3)
                let p0 = SIMD2<Float>(Float(points[0].x), Float(points[0].y))
                let p1 = SIMD2<Float>(Float(points[1].x), Float(points[1].y))
                let p2 = SIMD2<Float>(Float(points[2].x), Float(points[2].y))
                let p3 = SIMD2<Float>(Float(points[3].x), Float(points[3].y))

                vertices.append(OverlayVertex(position: p0, color: col))
                vertices.append(OverlayVertex(position: p1, color: col))
                vertices.append(OverlayVertex(position: p2, color: col))

                vertices.append(OverlayVertex(position: p0, color: col))
                vertices.append(OverlayVertex(position: p2, color: col))
                vertices.append(OverlayVertex(position: p3, color: col))

            case .boundingBox(let rect, let color, _):
                let col = simdColor(from: color)
                let minX = Float(rect.minX)
                let minY = Float(rect.minY)
                let maxX = Float(rect.maxX)
                let maxY = Float(rect.maxY)

                let p0 = SIMD2<Float>(minX, minY)
                let p1 = SIMD2<Float>(maxX, minY)
                let p2 = SIMD2<Float>(maxX, maxY)
                let p3 = SIMD2<Float>(minX, maxY)

                vertices.append(OverlayVertex(position: p0, color: col))
                vertices.append(OverlayVertex(position: p1, color: col))
                vertices.append(OverlayVertex(position: p2, color: col))

                vertices.append(OverlayVertex(position: p0, color: col))
                vertices.append(OverlayVertex(position: p2, color: col))
                vertices.append(OverlayVertex(position: p3, color: col))

            case .text, .icon:
                // Handled in CoreAnimation / CATextLayer overlay or font texture atlas
                break
            }
        }

        if !vertices.isEmpty, let device = self.device {
            let bufferSize = vertices.count * MemoryLayout<OverlayVertex>.stride
            let vertexBuffer = device.makeBuffer(bytes: vertices, length: bufferSize, options: .storageModeShared)
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        }

        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func simdColor(from cgColor: CGColor) -> SIMD4<Float> {
        guard let components = cgColor.components, components.count >= 3 else {
            return SIMD4<Float>(1, 1, 1, 1)
        }
        let alpha = components.count >= 4 ? Float(components[3]) : 1.0
        return SIMD4<Float>(Float(components[0]), Float(components[1]), Float(components[2]), alpha)
    }
}
