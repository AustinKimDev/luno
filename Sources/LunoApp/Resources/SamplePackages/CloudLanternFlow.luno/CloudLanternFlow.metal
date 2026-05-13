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

static float2 coverUV(float2 uv, float2 resolution, texture2d<float> image) {
    float screenAspect = resolution.x / max(resolution.y, 1.0);
    float imageAspect = float(image.get_width()) / max(float(image.get_height()), 1.0);
    float2 visible = screenAspect > imageAspect
        ? float2(1.0, imageAspect / screenAspect)
        : float2(screenAspect / imageAspect, 1.0);
    return float2(0.5) + (uv - float2(0.5)) * visible;
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

fragment half4 lunoFragment(
    LunoVertexOut in [[stage_in]],
    constant LunoUniforms &u [[buffer(0)]],
    texture2d<float> backgroundTexture [[texture(0)]],
    sampler backgroundSampler [[sampler(0)]]
) {
    float2 uv = in.uv;
    float speed = max(u.parameter0.x, 0.1);
    float beat = clamp(u.audioBass * 3.4 + u.audioRMS * 2.8, 0.0, 1.0);
    float t = u.time * speed;

    float horizonWeight = smoothstep(0.1, 0.95, uv.y);
    float2 flowA = float2(sin(uv.y * 8.0 + t * 0.9), cos(uv.x * 5.0 - t * 0.55));
    float2 flowB = float2(cos((uv.x + uv.y) * 7.0 - t * 0.7), sin(uv.x * 6.0 + t * 0.4));
    float2 drift = (flowA * 0.012 + flowB * 0.006) * (0.6 + horizonWeight + beat * 1.7);
    drift += float2(-t * 0.012, sin(t * 0.18) * 0.01);

    float2 baseUV = coverUV(uv, u.resolution, backgroundTexture);
    float3 color = backgroundTexture.sample(backgroundSampler, baseUV + drift).rgb;
    float3 glow = backgroundTexture.sample(backgroundSampler, baseUV + drift * 1.8 + float2(0.004, -0.002)).rgb;

    float lanternPulse = smoothstep(0.48, 1.0, dot(glow, float3(0.299, 0.587, 0.114)));
    color = mix(color, glow, 0.12 + beat * 0.2);
    color += float3(0.35, 0.16, 0.06) * lanternPulse * (0.08 + beat * 0.45);
    color += float3(0.05, 0.04, 0.10) * smoothstep(1.0, 0.0, length(uv - float2(0.5)));
    color = applyColorControls(color, u);

    return half4(half3(color), 1.0);
}
