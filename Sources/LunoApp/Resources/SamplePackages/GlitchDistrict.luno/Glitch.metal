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

static float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float3 scene(float2 uv, float t, float audioMid, float audioTreble) {
    // Dark navy base
    float3 color = float3(0.04, 0.05, 0.10);

    // --- City silhouette (bottom 35%) ---
    const float skylineTop = 0.35;
    if (uv.y < skylineTop) {
        // 18 building cells across the width
        const float numCells = 18.0;
        float cell = floor(uv.x * numCells);
        float cellX = fract(uv.x * numCells);

        // Building height: hash to 0.04..0.32 within the 0..skylineTop range
        float bHeight = 0.04 + hash1(cell * 7.13 + 3.7) * 0.28;

        // y==0 at bottom, skylineTop at top of zone
        float buildingMask = step(uv.y, bHeight);

        // Silhouette near-black fill
        float3 silhouette = float3(0.02, 0.02, 0.06);
        color = mix(color, silhouette, buildingMask);

        // Window lights — 18x6 grid
        const float numWinRows = 6.0;
        float winRow = floor(uv.y * (numWinRows / skylineTop));
        float winH = hash21(float2(cell, winRow));
        float inWindow = buildingMask
            * step(0.85, winH)
            * step(0.1, cellX)  // left margin
            * step(cellX, 0.9); // right margin
        float3 winLight = mix(float3(1.0, 0.85, 0.4), float3(1.0, 0.55, 0.2),
                              hash21(float2(cell + 0.5, winRow)));
        color = mix(color, winLight, inWindow * 0.9);
    }

    // --- Hologram glyph panels (upper/middle zone) ---
    // 4 panels with slow drift
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float panelX = 0.15 + fi * 0.22 + sin(t * 0.3 + fi * 1.7) * 0.03;
        float panelY = 0.45 + fi * 0.1 + sin(t * 0.25 + fi * 2.3) * 0.04
                       - fract(t * 0.04 + fi * 0.25) * 0.3; // slow upward drift
        float2 pUV = uv - float2(panelX, panelY);
        float2 pSize = float2(0.14, 0.08);
        float inPanel = step(0.0, pUV.x) * step(pUV.x, pSize.x)
                      * step(0.0, pUV.y) * step(pUV.y, pSize.y);
        if (inPanel > 0.0) {
            float2 localUV = pUV / pSize;
            // Horizontal scan lines inside the panel
            float scanLine = step(0.6, fract(localUV.y * 12.0));
            // Cyan/magenta gradient alternating by panel index
            float3 glyphColor = (fmod(fi, 2.0) < 1.0)
                ? float3(0.0, 0.85, 0.90) // cyan
                : float3(0.9, 0.05, 0.65); // magenta
            float alpha = (0.18 + scanLine * 0.08) * (0.6 + audioMid * 0.4);
            color = mix(color, glyphColor, alpha * inPanel);
        }
    }

    return color;
}

fragment half4 lunoFragment(LunoVertexOut in [[stage_in]], constant LunoUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float speed = max(u.parameter0.x, 0.1);
    float t = u.time * speed;

    // --- Chromatic RGB scanline split ---
    float chromaShift = 0.004 + sin(uv.y * 80.0 + t * 4.0) * 0.002
                        * (1.0 + u.audioMid * 2.5);
    float3 sceneR = scene(uv + float2(chromaShift, 0.0), t, u.audioMid, u.audioTreble);
    float3 sceneG = scene(uv,                             t, u.audioMid, u.audioTreble);
    float3 sceneB = scene(uv - float2(chromaShift, 0.0), t, u.audioMid, u.audioTreble);
    float3 color = float3(sceneR.r, sceneG.g, sceneB.b);

    // --- Treble tearing ---
    if (u.audioTreble > 0.5) {
        float tearY = hash1(floor(u.time * 8.0));
        if (abs(uv.y - tearY) < 0.025) {
            color = 1.0 - color;
        }
    }

    // --- CRT scanlines overlay ---
    float scanline = step(0.92, fract(uv.y * u.resolution.y * 0.4));
    color *= 1.0 - scanline * 0.12;

    return half4(half3(applyControls(color, u)), 1.0);
}
