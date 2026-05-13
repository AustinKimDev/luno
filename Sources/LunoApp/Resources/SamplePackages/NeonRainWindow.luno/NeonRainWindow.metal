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

static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float rainLayer(
    float2 uv,
    float time,
    float columns,
    float rows,
    float fallSpeed,
    float width,
    float length,
    float slant,
    float seed
) {
    float2 p = uv;
    p.x += p.y * slant;
    p.y -= time * fallSpeed;

    float2 q = float2(p.x * columns, p.y * rows);
    float2 cell = floor(q);
    float2 local = fract(q);
    float random = hash21(cell + seed);
    float laneX = 0.12 + 0.76 * hash21(float2(cell.x, seed));
    float y = fract(local.y + random);

    float lane = smoothstep(width, 0.0, abs(local.x - laneX));
    float trail = smoothstep(length, 0.0, y) * smoothstep(0.0, 0.035, y);
    float active = smoothstep(0.54, 1.0, random);
    return lane * trail * active;
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
    float beat = clamp(u.audioBass * 3.4 + u.audioRMS * 2.2, 0.0, 1.0);
    float t = u.time * speed;

    float2 baseUV = coverUV(uv, u.resolution, backgroundTexture);
    float fineRain = rainLayer(uv, t, 92.0, 28.0, 1.25 + beat * 0.85, 0.040, 0.62, 0.060, 3.0);
    float midRain = rainLayer(uv + float2(0.11, 0.0), t, 58.0, 20.0, 0.90 + beat * 0.65, 0.052, 0.54, 0.035, 17.0);
    float closeRain = rainLayer(uv + float2(-0.07, 0.0), t, 32.0, 12.0, 0.58 + beat * 0.45, 0.070, 0.42, 0.020, 41.0);
    float rain = clamp(fineRain * 0.55 + midRain * 0.75 + closeRain * 0.95, 0.0, 1.0);

    float glassFlow = sin((uv.x * 18.0 + uv.y * 5.0) - t * 0.85) * 0.5 + 0.5;
    glassFlow = pow(glassFlow, 5.0) * 0.08;
    float2 distortion = float2(
        sin((uv.y + t * 0.08) * 36.0) * 0.0016,
        rain * 0.0065 + glassFlow * 0.004
    );
    distortion *= 1.0 + beat * 0.65;

    float3 color = backgroundTexture.sample(backgroundSampler, baseUV + distortion).rgb;
    float3 shifted = backgroundTexture.sample(backgroundSampler, baseUV + distortion * 1.65 + float2(0.002, -0.001)).rgb;
    color = mix(color, shifted, clamp(rain * 0.28 + glassFlow, 0.0, 0.45));

    float neonFlash = smoothstep(0.45, 1.0, beat) * (0.25 + 0.5 * sin(t * 5.0) * sin(t * 5.0));
    color += float3(0.10, 0.18, 0.22) * rain * 0.22;
    color += float3(0.15, 0.05, 0.20) * neonFlash;
    color = applyColorControls(color, u);

    return half4(half3(color), 1.0);
}
