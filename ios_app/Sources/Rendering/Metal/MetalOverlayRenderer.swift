// ==============================================================================
// Program: MetalOverlayRenderer.swift
// Programmer: Ethan-da-Tech-Wizard
// Last Modified: November 18, 2026
// Purpose: Hardware-Accelerated Apple Metal 2D/3D Overlay Renderer.
//          Renders high-performance, low-latency visual HUD indicators, ground tile
//          quads, and contrast bounding boxes directly on the GPU at 60/120 FPS
//          using custom Metal shading language (MSL) pipelines and alpha blending.
// ==============================================================================

// ==============================================================================
// Architecture Overview & GPU Graphics Pipelines:
// ==============================================================================
// In computer systems architecture, rendering
// graphics on the CPU (software rendering) is slow and battery-intensive.
// Modern operating systems utilize dedicated Graphics Processing Units (GPUs).
//
// Apple Metal Graphics Pipeline:
// 1. MTLDevice: Represents the physical Apple Silicon GPU chip (e.g., A16/A17/M2).
// 2. MTLCommandQueue: Thread-safe FIFO queue accepting GPU command buffers.
// 3. MTLRenderPipelineState: Compiled GPU program pairing a vertex shader
//    (`overlayVertexShader`) and a fragment shader (`overlayFragmentShader`).
// 4. Alpha Blending Configuration:
//    - Source Factor: `sourceAlpha`
//    - Destination Factor: `oneMinusSourceAlpha`
//    - Resulting Color: `(Source * SourceAlpha) + (Destination * (1 - SourceAlpha))`
//    This mathematical blending formula allows translucent tile highlights and
//    HUD bounding boxes to blend smoothly over the underlying 3D game world.
// ==============================================================================

import Foundation
import MetalKit
import simd

/// 2D Vertex structure passed to the GPU vertex shader.
// Layout must match the vertex struct declared in Shaders.metal (float2 position + float4 colour).
struct OverlayVertex {
    var position: SIMD2<Float>  // Pixel coordinate (X, Y)
    var color: SIMD4<Float>     // Normalized RGBA color (0.0 to 1.0)
}

/// Uniform buffer containing current viewport dimensions.
struct ViewportUniforms {
    var viewportSize: SIMD2<Float>  // Viewport width and height in points
}

/// Hardware-accelerated Metal overlay renderer operating at 60/120 FPS.
public final class MetalOverlayRenderer: NSObject, MTKViewDelegate {
    /// Shared singleton instance.
    public static let shared = MetalOverlayRenderer()

    public private(set) var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer?

    private override init() {
        super.init()
        setupMetal()
    }

    /// Initializes GPU hardware device, command queue, and compiles the render pipeline.
    private func setupMetal() {
        // Step 1: Obtain reference to the default system Metal GPU device
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("❌ [MetalOverlayRenderer] Failed to initialize default Metal device.")
            return
        }
        self.device = defaultDevice
        // Step 2: Create command queue for submitting GPU render jobs
        self.commandQueue = defaultDevice.makeCommandQueue()

        do {
            // Step 3: Access precompiled default Metal shading library (Shaders.metal)
            // If the shader library is missing the pipeline stays nil and draw(in:) returns early each frame, so nothing is drawn.
            guard let defaultLibrary = defaultDevice.makeDefaultLibrary() else {
                print("⚠️ [MetalOverlayRenderer] Default Metal library not found, building runtime shaders.")
                return
            }
            let vertexFunction = defaultLibrary.makeFunction(name: "overlayVertexShader")
            let fragmentFunction = defaultLibrary.makeFunction(name: "overlayFragmentShader")

            // Step 4: Configure pipeline descriptor with shaders and pixel format
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            // Step 5: Configure hardware alpha blending for smooth transparent HUD overlays
            // Standard source-alpha blending so semi-transparent overlays composite over the game/background.
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

            // Step 6: Compile the synchronous render pipeline state
            self.pipelineState = try defaultDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("❌ [MetalOverlayRenderer] Pipeline compilation error: \(error.localizedDescription)")
        }
    }

    // MARK: - MTKViewDelegate Callbacks

    /// Called whenever the drawable size changes (e.g., orientation change or split screen).
    ///
    /// - Parameters:
    ///   - view: The MTKView triggering the update.
    ///   - size: New drawable size in pixels.
    // Keeps GameState.viewportSize in sync with the drawable size (in pixels, whereas draw uses view.bounds in points).
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        GameState.shared.viewportSize = size
    }

    /// Render loop callback invoked by MTKView every display frame (60 or 120 FPS).
    ///
    /// - Parameter view: MTKView containing destination CAMetalDrawable.
    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandQueue = self.commandQueue,
              let pipelineState = self.pipelineState else {
            return
        }

        // Configure transparent background: alpha = 0.0 clears frame without black opaque wash
        // Clear to fully transparent so only overlay shapes are visible.
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0.0)

        // Allocate command buffer and render command encoder
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)

        // Pass viewport dimensions uniform buffer to vertex shader at buffer index 1
        // Passed to the vertex shader to convert pixel coordinates to clip space.
        var uniforms = ViewportUniforms(viewportSize: SIMD2<Float>(Float(view.bounds.width), Float(view.bounds.height)))
        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<ViewportUniforms>.stride, index: 1)

        // Collect all draw commands from registered plugins
        let context = MetalRenderContext(
            viewportSize: view.bounds.size,
            commandBuffer: commandBuffer,
            renderEncoder: renderEncoder,
            gameState: GameState.shared
        )
        let commands = PluginManager.shared.collectDrawCommands(context: context)

        // Convert high-level draw commands into hardware GPU triangle vertices
        var vertices: [OverlayVertex] = []
        for command in commands {
            switch command {
            case .polygon(let points, let fillColor, _, _):
                // A quadrilateral tile is decomposed into 2 triangles: (0, 1, 2) and (0, 2, 3)
                guard points.count >= 4 else { continue }
                let col = simdColor(from: fillColor)
                let p0 = SIMD2<Float>(Float(points[0].x), Float(points[0].y))
                let p1 = SIMD2<Float>(Float(points[1].x), Float(points[1].y))
                let p2 = SIMD2<Float>(Float(points[2].x), Float(points[2].y))
                let p3 = SIMD2<Float>(Float(points[3].x), Float(points[3].y))

                // Triangle 1
                vertices.append(OverlayVertex(position: p0, color: col))
                vertices.append(OverlayVertex(position: p1, color: col))
                vertices.append(OverlayVertex(position: p2, color: col))

                // Triangle 2
                vertices.append(OverlayVertex(position: p0, color: col))
                vertices.append(OverlayVertex(position: p2, color: col))
                vertices.append(OverlayVertex(position: p3, color: col))

            case .boundingBox(let rect, let color, _):
                // Rectangular bounding box decomposed into 2 triangles
                let col = simdColor(from: color)
                let minX = Float(rect.minX)
                let minY = Float(rect.minY)
                let maxX = Float(rect.maxX)
                let maxY = Float(rect.maxY)

                let p0 = SIMD2<Float>(minX, minY)
                let p1 = SIMD2<Float>(maxX, minY)
                let p2 = SIMD2<Float>(maxX, maxY)
                let p3 = SIMD2<Float>(minX, maxY)

                // Triangle 1
                vertices.append(OverlayVertex(position: p0, color: col))
                vertices.append(OverlayVertex(position: p1, color: col))
                vertices.append(OverlayVertex(position: p2, color: col))

                // Triangle 2
                vertices.append(OverlayVertex(position: p0, color: col))
                vertices.append(OverlayVertex(position: p2, color: col))
                vertices.append(OverlayVertex(position: p3, color: col))

            // Not rendered by this Metal path; the in-code note about a CoreAnimation text layer refers to code that does not exist in this repo.
            case .text, .icon:
                // Text layers rendered via CoreAnimation overlay
                break
            }
        }

        // If vertices exist, upload to GPU shared memory buffer and issue draw call
        if !vertices.isEmpty, let device = self.device {
            let bufferSize = vertices.count * MemoryLayout<OverlayVertex>.stride
            // A new buffer is allocated every frame; fine for small overlays, wasteful for heavy ones.
            let vertexBuffer = device.makeBuffer(bytes: vertices, length: bufferSize, options: .storageModeShared)
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        }

        // Finalize rendering and present drawable to display
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    /// Converts standard CoreGraphics CGColor into SIMD4<Float> format required by Metal.
    private func simdColor(from cgColor: CGColor) -> SIMD4<Float> {
        // Assumes an RGB colour space; grayscale CGColors (2 components) fall back to opaque white.
        guard let components = cgColor.components, components.count >= 3 else {
            return SIMD4<Float>(1, 1, 1, 1)
        }
        let alpha = components.count >= 4 ? Float(components[3]) : 1.0
        return SIMD4<Float>(Float(components[0]), Float(components[1]), Float(components[2]), alpha)
    }
}
