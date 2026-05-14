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

static float3 layerColor(int idx) {
    float3 palette[6];
    palette[0] = float3(0.10, 0.04, 0.22);   // deep eggplant
    palette[1] = float3(0.22, 0.08, 0.38);   // velvet purple
    palette[2] = float3(0.36, 0.16, 0.55);   // amethyst
    palette[3] = float3(0.55, 0.30, 0.72);   // lavender
    palette[4] = float3(0.78, 0.55, 0.85);   // pale lilac
    palette[5] = float3(0.92, 0.78, 0.92);   // silk pink
    return palette[clamp(idx, 0, 5)];
}

static float waveLayer(float2 uv, float yCenter, float freq, float phase, float amp, float thickness, float t) {
    float wave = yCenter
        + sin(uv.x * freq + t + phase) * amp
        + sin(uv.x * freq * 0.5 + t * 0.7 + phase) * amp * 0.4;
    float d = abs(uv.y - wave);
    return 1.0 - smoothstep(thickness * 0.5, thickness, d);
}

fragment half4 lunoFragment(LunoVertexOut in [[stage_in]], constant LunoUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float speed = max(u.parameter0.x, 0.1);
    float t = u.time * speed * 0.18;
    float breathing = u.audioBass * 0.03;

    // Background: dark velvet
    float3 color = float3(0.04, 0.02, 0.08);

    // 6 layers, deep to light, each with own freq/phase
    float ampBase = 0.05 + u.audioRMS * 0.02;
    float thickBase = 0.18;
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float yC = mix(0.18, 0.85, fi / 5.0);
        float freq = 2.2 + fi * 0.4;
        float phase = fi * 1.27;
        float amp = ampBase * (1.0 + fi * 0.12);
        float thick = thickBase * (1.0 + fi * 0.08);
        float wave = waveLayer(uv, yC + breathing * sin(fi * 2.1 + t), freq, phase, amp, thick, t);
        float3 lc = layerColor(i);
        color = mix(color, lc, wave * 0.8);
    }

    // Soft glow near upper-middle region
    float topGlow = exp(-pow((uv.y - 0.6) * 2.0, 2.0)) * 0.08;
    color += float3(0.4, 0.3, 0.55) * topGlow * (0.5 + u.audioBass);

    color = applyControls(color, u);
    return half4(half3(clamp(color, 0.0, 1.0)), 1.0);
}
