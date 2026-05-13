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
};

vertex LunoVertexOut lunoVertex(uint vertexID [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1.0, -1.0),
        float2(3.0, -1.0),
        float2(-1.0, 3.0)
    };

    LunoVertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.uv = positions[vertexID] * 0.5 + 0.5;
    return out;
}

static float3 applyColorControls(float3 color, constant LunoUniforms &u) {
    float tintStrength = clamp(u.parameter0.y, 0.0, 1.0);
    float brightness = max(u.parameter0.z, 0.0);
    float saturation = max(u.parameter0.w, 0.0);
    float3 tint = u.colorParameter0.rgb;
    float luminance = dot(color, float3(0.2126, 0.7152, 0.0722));

    color = mix(float3(luminance), color, saturation);
    color = mix(color, tint, tintStrength);
    return clamp(color * brightness, 0.0, 1.0);
}

fragment half4 lunoFragment(LunoVertexOut in [[stage_in]], constant LunoUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float aspect = u.resolution.x / max(u.resolution.y, 1.0);
    float2 p = float2((uv.x - 0.5) * aspect, uv.y - 0.5);

    float speed = max(u.parameter0.x, 0.1);
    float t = u.time * speed;
    float gridX = abs(fract((p.x + t * 0.035) * 12.0) - 0.5);
    float gridY = abs(fract((p.y - t * 0.025) * 12.0) - 0.5);
    float lines = 1.0 - smoothstep(0.015, 0.055 + u.audioMid * 0.03, min(gridX, gridY));
    float pulse = smoothstep(0.2, 1.0, sin(length(p) * 14.0 - t * 2.0) * 0.5 + 0.5);

    float3 base = float3(0.015, 0.018, 0.045);
    float3 blue = float3(0.08, 0.38, 0.95);
    float3 cyan = float3(0.10, 0.92, 0.86);
    float3 color = base + blue * lines * (0.35 + u.audioBass * 0.7);
    color += cyan * pulse * 0.16;
    color += float3(0.03, 0.04, 0.08) * smoothstep(0.75, 0.0, length(p));

    return half4(half3(applyColorControls(color, u)), 1.0);
}
