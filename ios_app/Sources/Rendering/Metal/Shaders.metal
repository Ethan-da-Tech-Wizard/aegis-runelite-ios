//
//  Shaders.metal
//  RuneLiteMobile
//
//  Created for iOS Standalone RuneLite Client Architecture.
//  Copyright © 2026 TWU LLC. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

// 2D Vertex structure for overlay geometry
struct OverlayVertex {
    float2 position [[attribute(0)]];
    float4 color    [[attribute(1)]];
};

struct RasterizerData {
    float4 position [[position]];
    float4 color;
};

// Uniforms for viewport projection
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

    // Convert screen coordinates (0 ... W, 0 ... H) to NDC (-1 ... 1)
    float x = (pixelPos.x / (uniforms.viewportSize.x * 0.5)) - 1.0;
    float y = 1.0 - (pixelPos.y / (uniforms.viewportSize.y * 0.5));

    out.position = float4(x, y, 0.0, 1.0);
    out.color = vertices[vertexID].color;
    return out;
}

// Fragment Shader: Renders colored quads with alpha blending
fragment float4 overlayFragmentShader(RasterizerData in [[stage_in]]) {
    return in.color;
}
