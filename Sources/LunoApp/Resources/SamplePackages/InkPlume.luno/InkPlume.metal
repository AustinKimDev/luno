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

static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float noise2d(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float a = hash21(i);
    float b = hash21(i + float2(1, 0));
    float c = hash21(i + float2(0, 1));
    float d = hash21(i + float2(1, 1));
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float fbm(float2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise2d(p);
        p *= 2.05;
        a *= 0.5;
    }
    return v;
}

static float2 curl(float2 p) {
    float eps = 0.01;
    float n1 = fbm(p + float2(0, eps));
    float n2 = fbm(p - float2(0, eps));
    float n3 = fbm(p + float2(eps, 0));
    float n4 = fbm(p - float2(eps, 0));
    return float2((n1 - n2) / (2.0 * eps), -(n3 - n4) / (2.0 * eps));
}

fragment half4 lunoFragment(LunoVertexOut in [[stage_in]], constant LunoUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float aspect = u.resolution.x / max(u.resolution.y, 1.0);
    float2 p = float2((uv.x - 0.5) * aspect, uv.y - 0.5);
    float speed = max(u.parameter0.x, 0.1);
    float t = u.time * speed * 0.18;

    // Curl-advect UV through a few steps
    float2 q = p * 1.5 + float2(t, t * 0.6);
    float curlStrength = 0.6 + u.audioTreble * 0.7;
    for (int i = 0; i < 5; i++) {
        q += curl(q) * 0.04 * curlStrength;
    }

    // Sample density
    float density = fbm(q + float2(t * 0.3, -t * 0.2));
    density = pow(density, 1.4);

    // Plume size scales with RMS
    float plumeFactor = 0.35 + u.audioRMS * 0.55;
    float plume = smoothstep(0.45 - plumeFactor * 0.3, 0.85, density);

    // Bass adds a slow pulse to overall density
    plume += u.audioBass * 0.15 * fbm(p * 3.0 + t * 0.2);

    // Ink colors
    float3 bg = float3(0.01, 0.015, 0.04);
    float3 inkDeep = float3(0.05, 0.10, 0.32);
    float3 inkEdge = float3(0.15, 0.55, 0.85);
    float edgeFactor = smoothstep(0.4, 0.0, density);  // brighter at edges
    float3 inkColor = mix(inkDeep, inkEdge, edgeFactor * 0.6);

    float3 color = mix(bg, inkColor, clamp(plume, 0.0, 1.0));

    // Subtle highlight ripples
    float ripple = sin(density * 18.0 + t * 4.0) * 0.05;
    color += float3(0.1, 0.3, 0.5) * ripple * plume;

    color = applyControls(color, u);
    return half4(half3(clamp(color, 0.0, 1.0)), 1.0);
}
