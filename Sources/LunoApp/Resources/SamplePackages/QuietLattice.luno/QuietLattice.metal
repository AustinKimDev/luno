#include <metal_stdlib>
using namespace metal;

struct LunoVertexOut {
    float4 position [[position]];
    float2 uv;
};

struct LunoUniforms {
    float time;
    float deltaTime;
    float2 resolution;
    float displayScale;
    float audioRMS;
    float audioBass;
    float audioMid;
    float audioTreble;
    float4 parameter0;
    float4 colorParameter0;
    float4 colorParameter1;
    float4 colorParameter2;
    float4 colorParameter3;
    float4 albumColor0;
    float4 albumColor1;
    float4 albumColor2;
    float4 albumColor3;
};

// parameter0: x=speed, y=tintStrength, z=brightness, w=saturation
// colorParameter0: tint color

vertex LunoVertexOut lunoVertex(uint vertexID [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };
    LunoVertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.uv = positions[vertexID] * 0.5 + 0.5;
    return out;
}

static float3 applyControls(float3 color, constant LunoUniforms &u) {
    float tintStrength = clamp(u.parameter0.y, 0.0, 1.0);
    float brightness   = max(u.parameter0.z, 0.0);
    float saturation   = max(u.parameter0.w, 0.0);
    float luminance = dot(color, float3(0.2126, 0.7152, 0.0722));
    color = mix(float3(luminance), color, saturation);
    color = mix(color, u.colorParameter0.rgb, tintStrength);
    return clamp(color * brightness, 0.0, 1.0);
}

fragment half4 lunoFragment(LunoVertexOut in [[stage_in]], constant LunoUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float aspect = u.resolution.x / max(u.resolution.y, 1.0);
    float2 p = float2((uv.x - 0.5) * aspect, uv.y - 0.5);
    float speed = max(u.parameter0.x, 0.05);

    // 1. Background: near-black with subtle radial vignette from corners
    float3 bg = float3(0.018, 0.022, 0.038);
    float vignette = 1.0 - smoothstep(0.0, 1.05, length(p));
    float3 color = bg * (0.7 + vignette * 0.5);

    // 2. Dot grid (40x24 cells)
    const float gridX = 40.0;
    const float gridY = 24.0;
    float2 cellUV   = float2(uv.x * gridX, uv.y * gridY);
    float2 cellIndex = floor(cellUV);
    float2 local    = fract(cellUV) - 0.5;

    // Depth shading: dots fade with distance from center
    float distFromCenter = length((cellIndex / float2(gridX, gridY)) - 0.5);
    float depthFade = exp(-distFromCenter * 2.0);

    float dotRadius = 0.06;
    float dotMask = 1.0 - smoothstep(dotRadius * 0.4, dotRadius, length(local));
    color += float3(0.45, 0.50, 0.65) * dotMask * depthFade * 0.35;

    // 3. Traversal line — slow horizontal sweep top-to-bottom
    float lineProgress = fract(u.time * speed * 0.05);
    float lineY = mix(0.15, 0.85, lineProgress);
    float distToLine = abs(uv.y - lineY);
    float lineWidth = 0.003;
    float lineCore  = 1.0 - smoothstep(0.0, lineWidth, distToLine);
    float lineGlow  = exp(-distToLine * 80.0) * 0.6;
    float lineBoost = 1.0 + u.audioRMS * 0.8;
    color += float3(0.85, 0.92, 1.0) * (lineCore + lineGlow) * lineBoost * 0.35;

    // 4. Dots near the traversal line bloom slightly brighter
    float lineProximity = exp(-distToLine * 35.0);
    color += float3(0.55, 0.65, 0.85) * dotMask * depthFade * lineProximity * 0.4;

    color = applyControls(color, u);
    return half4(half3(clamp(color, 0.0, 1.0)), 1.0);
}
