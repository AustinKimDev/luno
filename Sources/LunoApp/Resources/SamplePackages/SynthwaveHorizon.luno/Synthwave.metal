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
        float2(3.0, -1.0),
        float2(-1.0, 3.0)
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
    float speed = max(u.parameter0.x, 0.1);

    // Hardcoded scene constants
    const float horizon     = 0.52;
    const float gridDensity = 16.0;

    float t = u.time * speed;
    float energy = clamp(u.audioRMS * 0.6 + u.audioBass * 0.4, 0.0, 1.0);
    float aspect = u.resolution.x / max(u.resolution.y, 1.0);

    // Sky gradient (above horizon)
    float skyT = clamp((uv.y - horizon) / max(1.0 - horizon, 0.001), 0.0, 1.0);
    float3 skyTop     = float3(0.10, 0.04, 0.22);   // deep purple
    float3 skyMid     = float3(0.65, 0.18, 0.42);   // magenta
    float3 skyHorizon = float3(1.0,  0.55, 0.30);   // orange
    float3 sky = mix(skyHorizon, mix(skyMid, skyTop, smoothstep(0.4, 1.0, skyT)), smoothstep(0.0, 0.4, skyT));

    // Sun
    float2 sunCenter = float2(0.5, horizon - 0.04);
    float2 sunDelta  = (uv - sunCenter) * float2(aspect, 1.0);
    float sunDist    = length(sunDelta);
    float sunRadius  = 0.14;
    float sunCore    = 1.0 - smoothstep(sunRadius * 0.78, sunRadius, sunDist);
    float sunBloom   = 1.0 - smoothstep(sunRadius, sunRadius * 1.55, sunDist);
    float sunBlend   = clamp((sunDelta.y + sunRadius) / (sunRadius * 2.0), 0.0, 1.0);
    float3 sunTop    = float3(1.0, 0.95, 0.55);
    float3 sunBottom = float3(1.0, 0.35, 0.55);
    float3 sunColor  = mix(sunBottom, sunTop, sunBlend);

    // Scan bands through the sun — treble jitters band density
    float trebleJitter = u.audioTreble * 0.4;
    float scanY = (uv.y - sunCenter.y) * 8.0 - t * 0.2 + sin(t * 6.0 + uv.y * 20.0) * trebleJitter * 0.02;
    float scanMask = step(0.55, fract(scanY));
    sunCore  *= mix(1.0, 1.0 - scanMask,       0.95);
    sunBloom *= mix(1.0, 1.0 - scanMask * 0.5, 0.6);

    float3 color;

    if (uv.y >= horizon) {
        // Sky region: gradient + sun
        color = sky;
        color += sunColor * sunCore  * 1.1;
        color += sunColor * sunBloom * 0.25;
    } else {
        // Ground: perspective grid
        float groundT = (horizon - uv.y) / max(horizon, 0.001);

        // Horizontal lines scroll forward over time
        float row = uv.y * 50.0 + t * 4.0;
        float horizLine = smoothstep(0.94, 0.985, fract(row)) * smoothstep(0.0, 0.18, groundT);

        // Vertical lines converge to vanishing point at horizon center
        float depth = 1.0 / max(groundT + 0.02, 0.02);
        float perspX = (uv.x - 0.5) * depth + 0.5;
        float vertCell = fract(perspX * gridDensity);
        float vertLine = smoothstep(0.93, 0.98, abs(vertCell - 0.5) * 2.0) * smoothstep(0.0, 0.24, groundT);

        // Grid: pink near horizon, cyan in foreground
        float3 gridPink = float3(1.0, 0.20, 0.65);
        float3 gridCyan = float3(0.20, 0.95, 1.0);
        float3 gridColor = mix(gridPink, gridCyan, clamp(groundT * 1.4, 0.0, 1.0));

        float gridBoost = 1.0 + u.audioBass * 0.9;
        float lines = max(horizLine, vertLine) * gridBoost;

        float3 groundBase = mix(float3(0.06, 0.02, 0.12), float3(0.18, 0.04, 0.28), groundT);
        color = groundBase + gridColor * lines * (0.75 + energy * 0.6);

        // Horizon glow band
        float horizonGlow = smoothstep(0.0, 0.12, groundT) * (1.0 - smoothstep(0.0, 0.32, groundT));
        color += float3(1.0, 0.45, 0.70) * horizonGlow * (0.4 + u.audioRMS * 0.2);
    }

    // RMS-driven haze near horizon
    float haze = exp(-pow((uv.y - horizon) * 6.0, 2.0)) * u.audioRMS * 0.18;
    color += float3(1.0, 0.6, 0.9) * haze;

    color = applyControls(color, u);
    return half4(half3(color), 1.0);
}
