// Program: aegis-runelite-ios - Shaders.metal
// Programmer: Ethan-da-Tech-Wizard (written with Claude, an AI assistant)
// Last Modified: 2026-11-18
// Purpose: Metal vertex and fragment shaders that map pixel coordinates to clip space and output vertex colors.

// ==============================================================================
// Overview: Shader Architecture:
// ==============================================================================
// In modern GPU programming, "shaders" are small programs written in specialized
// shading languages (here, Metal Shading Language / C++14 dialect) that execute
// in parallel across thousands of GPU cores.
//
// Pipeline Stages:
// 1. Vertex Shader (`overlayVertexShader`):
//    - Executes once for every vertex in the input stream.
//    - Coordinate Transformation: UIKit screen coordinates have the origin (0, 0)
//      at the top-left, with X increasing rightward and Y increasing downward.
//      Normalized Device Coordinates (NDC) in graphics APIs require X and Y to
//      range from -1.0 to +1.0, with (0, 0) at the exact center of the screen:
//        `ndcX = (pixelX / (viewportWidth * 0.5)) - 1.0`
//        `ndcY = 1.0 - (pixelY / (viewportHeight * 0.5))`
// 2. Rasterizer:
//    - Automatically interpolates vertex attributes (colors, coordinates)
//      across each pixel (fragment) inside the triangle.
// 3. Fragment Shader (`overlayFragmentShader`):
//    - Executes once for every pixel covered by the triangle geometry.
//    - Emits the final blended RGBA color value.
// ==============================================================================

#include <metal_stdlib>
using namespace metal;

// 2D Vertex structure matching the CPU-side OverlayVertex layout in Swift
struct OverlayVertex {
    float2 position [[attribute(0)]];
    float4 color    [[attribute(1)]];
};

// Data passed from the vertex shader to the rasterizer and fragment shader
struct RasterizerData {
    float4 position [[position]];  // Vertex position in clip space
    float4 color;                  // Interpolated RGBA color
};

// Uniform buffer containing screen viewport dimensions
struct ViewportUniforms {
    float2 viewportSize;
};

// Vertex Shader: Projects 2D screen points to Normalized Device Coordinates (-1 ... 1)
vertex RasterizerData overlayVertexShader(
    uint vertexID [[vertex_id]],
    constant OverlayVertex* vertices [[buffer(0)]],
    constant ViewportUniforms& uniforms [[buffer(1)]]
) {
    RasterizerData out;
    float2 pixelPos = vertices[vertexID].position;

    // Step 1: Scale horizontal coordinate from [0, W] to [-1.0, +1.0]
    float x = (pixelPos.x / (uniforms.viewportSize.x * 0.5)) - 1.0;

    // Step 2: Scale vertical coordinate from [0, H] to [+1.0, -1.0] (inverting Y-axis)
    float y = 1.0 - (pixelPos.y / (uniforms.viewportSize.y * 0.5));

    // Step 3: Emit 4D homogeneous position (Z=0.0, W=1.0)
    out.position = float4(x, y, 0.0, 1.0);
    out.color = vertices[vertexID].color;
    return out;
}

// Fragment Shader: Returns interpolated RGBA color to the hardware blend unit
fragment float4 overlayFragmentShader(RasterizerData in [[stage_in]]) {
    return in.color;
}
