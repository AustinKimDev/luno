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
    float audioLift = u.audioBass * 0.45 + u.audioRMS * 0.2;
    float t = u.time * speed;

    float waveA = sin((p.x * 8.0) + t + sin(p.y * 7.0 + t * 0.7));
    float waveB = sin((p.y * 9.0) - t * 0.8 + cos(p.x * 5.0));
    float field = smoothstep(-0.15 - audioLift, 0.9, waveA * 0.45 + waveB * 0.35 + p.y);

    float3 night = float3(0.02, 0.03, 0.08);
    float3 teal = float3(0.05, 0.82, 0.74);
    float3 violet = float3(0.52, 0.26, 0.95);
    float3 color = mix(night, teal, field);
    color = mix(color, violet, smoothstep(0.35, 1.0, field + audioLift));
    color += float3(0.08, 0.16, 0.25) * smoothstep(0.7, 0.0, length(p));
    color = applyColorControls(color, u);

    return half4(half3(color), 1.0);
}
