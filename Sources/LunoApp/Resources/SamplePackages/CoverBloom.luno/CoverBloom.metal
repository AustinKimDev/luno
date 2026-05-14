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

// parameter0: x=bloomRadius, y=tintStrength, z=brightness, w=saturation
// colorParameter0: tint color
// albumColor0=background, albumColor1=primary, albumColor2=secondary, albumColor3=highlight

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
    float aspect = u.resolution.x / max(u.resolution.y, 1.0);
    float2 p = float2((uv.x - 0.5) * aspect, uv.y - 0.5);
    float r = length(p);
    float angle = atan2(p.y, p.x);
    float t = u.time * 0.3;

    float bloomRadius = clamp(u.parameter0.x, 0.3, 1.2);
    float radius = bloomRadius * (0.85 + u.audioRMS * 0.18);

    // Album palette
    float3 bgColor    = u.albumColor0.rgb;
    float3 primary    = u.albumColor1.rgb;
    float3 secondary  = u.albumColor2.rgb;
    float3 highlight  = u.albumColor3.rgb;

    // Background — very dim album bg
    float3 color = bgColor * 0.35;

    // Concentric bloom zones (inside-out)
    float zoneCore  = 1.0 - smoothstep(0.0, radius * 0.18, r);
    float zoneRing1 = (1.0 - smoothstep(radius * 0.18, radius * 0.42, r));
    float zoneRing2 = (1.0 - smoothstep(radius * 0.42, radius * 0.72, r));
    float zoneRing3 = (1.0 - smoothstep(radius * 0.72, radius * 1.05, r));

    color = mix(color, primary,   zoneRing1 * 0.85);
    color = mix(color, secondary, zoneRing2 * 0.72);
    color = mix(color, highlight, zoneRing3 * 0.6);
    color = mix(color, mix(highlight, primary, 0.5), zoneCore);

    // Filaments — angular sparkles, treble-driven
    float filamentCount = 32.0;
    float angularNoise  = sin(angle * filamentCount + t * 1.6) * 0.5 + 0.5;
    float filamentMask  = smoothstep(0.75, 0.95, angularNoise);
    float radialDecay   = exp(-r * 2.5);
    float filaments     = filamentMask * radialDecay * (0.4 + u.audioTreble * 1.6);
    color += highlight * filaments * 0.55;

    // Outer halo pulse — rms expands radius further
    float outerHalo = exp(-pow((r - radius * 1.0), 2.0) * 25.0) * (0.18 + u.audioRMS * 0.32);
    color += secondary * outerHalo;

    // Bass-driven brightness wash near center
    float bassWash = exp(-r * 1.8) * u.audioBass * 0.45;
    color += highlight * bassWash;

    // Mid energy adds subtle inner ripples
    float ripples = sin(r * 22.0 - t * 3.0) * 0.5 + 0.5;
    color += primary * ripples
           * smoothstep(0.0, radius * 0.5, r)
           * smoothstep(radius * 0.9, 0.0, r)
           * u.audioMid * 0.15;

    color = applyControls(color, u);
    return half4(half3(clamp(color, 0.0, 1.0)), 1.0);
}
