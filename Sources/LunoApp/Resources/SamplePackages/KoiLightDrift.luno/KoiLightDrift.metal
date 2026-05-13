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
    float beat = clamp(u.audioBass * 3.8 + u.audioRMS * 2.4, 0.0, 1.0);
    float t = u.time * speed;

    float waveA = sin((uv.x * 18.0) + t * 1.5 + sin(uv.y * 9.0 - t));
    float waveB = cos((uv.y * 16.0) - t * 1.1 + cos(uv.x * 7.0 + t));
    float2 drift = float2(waveA, waveB) * (0.006 + beat * 0.025);
    drift += float2(sin(t * 0.12), cos(t * 0.1)) * 0.018;

    float2 baseUV = coverUV(uv, u.resolution, backgroundTexture);
    float3 color = backgroundTexture.sample(backgroundSampler, baseUV + drift).rgb;
    float caustic = pow(sin((uv.x + uv.y) * 22.0 + t * 2.2) * 0.5 + 0.5, 7.0);
    float rings = sin(length(uv - float2(0.5)) * 52.0 - t * (2.0 + beat * 5.0));
    float ringLight = smoothstep(0.78, 1.0, rings) * (0.08 + beat * 0.35);

    color += float3(0.12, 0.26, 0.30) * caustic * (0.18 + beat * 0.5);
    color += float3(0.45, 0.28, 0.08) * ringLight;
    color = applyColorControls(color, u);

    return half4(half3(color), 1.0);
}
