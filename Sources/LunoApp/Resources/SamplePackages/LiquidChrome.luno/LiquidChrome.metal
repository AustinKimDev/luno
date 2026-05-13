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
    float ripple = sin((p.x * 5.0 + sin(p.y * 4.0 + t)) + t);
    ripple += cos((p.y * 7.0 + cos(p.x * 3.0 - t * 0.8)) - t * 0.6);
    float metal = smoothstep(-0.25, 1.0, ripple * 0.45 + u.audioTreble * 0.55);
    float highlight = pow(smoothstep(0.0, 1.0, metal), 4.0);

    float3 graphite = float3(0.035, 0.04, 0.055);
    float3 silver = float3(0.58, 0.68, 0.78);
    float3 violet = float3(0.44, 0.25, 0.88);
    float3 color = mix(graphite, silver, metal);
    color = mix(color, violet, smoothstep(0.5, 1.0, metal + u.audioRMS * 0.5));
    color += highlight * float3(0.35, 0.45, 0.55);

    return half4(half3(applyColorControls(color, u)), 1.0);
}
