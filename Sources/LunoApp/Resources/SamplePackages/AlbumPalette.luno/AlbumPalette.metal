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

// parameter0: x=mode, y=tintStrength, z=brightness, w=saturation
// albumColor0..3: background, primary, secondary, highlight

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

static float2 rotate2(float2 p, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return float2(p.x * c - p.y * s, p.x * s + p.y * c);
}

static float3 applyControls(float3 color, constant LunoUniforms &u) {
    float tintStrength = clamp(u.parameter0.y, 0.0, 1.0);
    float brightness = max(u.parameter0.z, 0.0);
    float saturation = max(u.parameter0.w, 0.0);
    float luminance = dot(color, float3(0.2126, 0.7152, 0.0722));

    color = mix(float3(luminance), color, saturation);
    color = clamp(color, 0.0, 1.0);
    color = mix(color, u.colorParameter0.rgb, tintStrength);
    return clamp(color * brightness, 0.0, 1.0);
}

static float3 ambientBloom(float2 uv, float2 p, constant LunoUniforms &u) {
    float t = u.time * 0.16;
    float energy = clamp(u.audioRMS * 0.45 + u.audioBass * 0.70, 0.0, 1.0);
    float3 base = u.albumColor0.rgb * 0.72;
    float3 primary = u.albumColor1.rgb;
    float3 secondary = u.albumColor2.rgb;
    float3 highlight = u.albumColor3.rgb;

    float aspect = u.resolution.x / max(u.resolution.y, 1.0);
    float2 q = float2((uv.x - 0.5) * aspect, uv.y - 0.5);
    float2 c1 = float2(-0.42 + sin(t * 0.7) * 0.05, 0.18 + cos(t * 0.5) * 0.05);
    float2 c2 = float2(0.55 + cos(t * 0.6) * 0.06, 0.26 + sin(t * 0.4) * 0.04);
    float2 c3 = float2(0.02 + sin(t * 0.4) * 0.04, -0.42 + cos(t * 0.65) * 0.05);

    float bloomA = exp(-dot(q - c1, q - c1) * (5.8 - energy * 1.1));
    float bloomB = exp(-dot(q - c2, q - c2) * 4.6);
    float bloomC = exp(-dot(q - c3, q - c3) * 4.2);
    float vignette = 1.0 - smoothstep(0.10, 1.25, length(p));
    float angle = atan2(q.y, q.x) + t * 0.62;
    float radius = length(q);
    float haze = (0.5 + 0.5 * sin(angle * 2.0 + radius * 6.0)) * (1.0 - smoothstep(0.05, 1.35, radius));
    float grain = hash21(floor(uv * u.resolution.xy / max(u.displayScale, 1.0)) + floor(u.time * 18.0)) * 0.026;

    float3 color = base * (0.58 + vignette * 0.36);
    color += primary * bloomA * (0.95 + energy * 0.22);
    color += secondary * bloomB * 0.72;
    color += highlight * bloomC * (0.52 + u.audioTreble * 0.18);
    color += mix(primary, secondary, 0.5 + 0.5 * sin(angle)) * haze * 0.16;
    color += grain;
    return color;
}

static float3 spectrumRibbons(float2 uv, float2 p, constant LunoUniforms &u) {
    float time = u.time * (0.26 + u.audioMid * 0.12);
    float energy = clamp(u.audioRMS + u.audioBass * 0.65, 0.0, 1.0);
    float3 base = u.albumColor0.rgb * 0.58;
    float3 primary = u.albumColor1.rgb;
    float3 secondary = u.albumColor2.rgb;
    float3 highlight = u.albumColor3.rgb;
    float3 color = base + mix(primary, secondary, uv.y) * 0.06;

    float2 r = rotate2(uv - 0.5, -0.25);
    float flow = r.x + time * 0.13;
    float waveA = sin(flow * 8.0) * (0.018 + energy * 0.012);
    float waveB = sin(flow * 15.0 - time * 1.7) * 0.010;
    float bandA = 1.0 - smoothstep(0.085, 0.165, abs(r.y - 0.13 - waveA));
    float bandB = 1.0 - smoothstep(0.070, 0.145, abs(r.y + 0.16 - waveB));
    float bandC = 1.0 - smoothstep(0.025, 0.085, abs(r.y + 0.005 - sin(flow * 11.0 + time) * 0.020));
    float endFade = smoothstep(-0.62, -0.25, r.x) * (1.0 - smoothstep(0.28, 0.64, r.x));

    float stripe = 0.5 + 0.5 * sin(flow * 18.0);
    float3 warmRibbon = mix(primary, highlight, stripe);
    float3 coolRibbon = mix(secondary, primary, 0.25 + 0.35 * stripe);
    color += warmRibbon * bandA * endFade * (0.78 + energy * 0.28);
    color += coolRibbon * bandB * endFade * (0.68 + u.audioTreble * 0.20);
    color += highlight * bandC * endFade * (0.34 + energy * 0.18);
    color += (warmRibbon * bandA + coolRibbon * bandB) * endFade * 0.22;
    return color;
}

static float3 particleField(float2 uv, float2 p, constant LunoUniforms &u) {
    float time = u.time * 0.26;
    float energy = clamp(u.audioRMS * 0.60 + u.audioTreble * 0.65, 0.0, 1.0);
    float3 base = u.albumColor0.rgb * 0.48;
    float3 primary = u.albumColor1.rgb;
    float3 secondary = u.albumColor2.rgb;
    float3 highlight = u.albumColor3.rgb;

    float2 gridUV = uv * float2(30.0, 18.0);
    float2 cell = floor(gridUV);
    float2 local = fract(gridUV) - 0.5;
    float seed = hash21(cell);
    float twinkle = sin(time * (2.0 + seed * 5.0) + seed * 6.2831) * 0.5 + 0.5;
    float radius = 0.040 + energy * 0.020 + twinkle * 0.016;
    float dotMask = 1.0 - smoothstep(0.0, radius, length(local));
    float visible = smoothstep(0.88, 0.985, seed);
    float3 particleColor = mix(primary, secondary, hash21(cell + 17.0));
    particleColor = mix(particleColor, highlight, twinkle * 0.45);

    float wave = 0.22 + sin(p.x * 4.5 + time * 1.8) * 0.045 + sin(p.x * 11.0 - time) * 0.018;
    float ribbon = 1.0 - smoothstep(0.006, 0.036 + energy * 0.026, abs(uv.y - wave));
    float barCell = floor(uv.x * 72.0);
    float barPhase = hash21(float2(barCell, 4.0));
    float barHeight = 0.035 + pow(barPhase, 2.0) * 0.17 + energy * 0.11;
    float barX = abs(fract(uv.x * 72.0) - 0.5);
    float bars = (1.0 - smoothstep(0.12, 0.22, barX))
        * smoothstep(0.0, 0.05, uv.y)
        * (1.0 - smoothstep(barHeight, barHeight + 0.05, uv.y));
    float bottomFade = smoothstep(0.0, 0.18, uv.x) * (1.0 - smoothstep(0.82, 1.0, uv.x));
    float halo = exp(-dot(p, p) * (1.6 - energy * 0.35));

    float3 color = base + particleColor * dotMask * visible * (0.42 + twinkle * 0.42 + energy * 0.25);
    color += secondary * ribbon * (0.18 + energy * 0.28);
    color += mix(primary, highlight, uv.x) * bars * bottomFade * 0.42;
    color += primary * halo * 0.18;
    return color;
}

fragment half4 lunoFragment(LunoVertexOut in [[stage_in]], constant LunoUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float aspect = u.resolution.x / max(u.resolution.y, 1.0);
    float2 p = float2((uv.x - 0.5) * aspect, uv.y - 0.5);
    float mode = u.parameter0.x;

    float3 color;
    if (mode < 0.5) {
        color = ambientBloom(uv, p, u);
    } else if (mode < 1.5) {
        color = spectrumRibbons(uv, p, u);
    } else {
        color = particleField(uv, p, u);
    }

    color = applyControls(color, u);
    return half4(half3(color), 1.0);
}
