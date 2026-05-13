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
    float radius = length(p);
    float angle = atan2(p.y, p.x);
    float bands = sin(angle * 5.0 + t * 0.7) * 0.5 + 0.5;
    float flare = smoothstep(0.65, 0.0, radius + sin(t + angle * 2.0) * 0.04);
    float corona = smoothstep(0.9, 0.0, radius) * (0.4 + bands * 0.4 + u.audioBass * 0.45);

    float3 ember = float3(0.95, 0.28, 0.10);
    float3 gold = float3(1.0, 0.78, 0.28);
    float3 dusk = float3(0.04, 0.02, 0.08);
    float3 color = mix(dusk, ember, corona);
    color = mix(color, gold, flare + u.audioRMS * 0.18);
    color += float3(0.18, 0.05, 0.02) * smoothstep(0.9, 0.0, radius);

    return half4(half3(applyColorControls(color, u)), 1.0);
}
