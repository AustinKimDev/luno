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

// parameter0: x=rotationSpeed, y=tintStrength, z=brightness, w=saturation
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

    float rotationSpeed = max(u.parameter0.x, 0.1);
    float rotation = u.time * rotationSpeed * 0.35 * (1.0 + u.audioRMS * 0.15);

    // Album palette
    float3 desktopColor = float3(0.06, 0.04, 0.03);  // warm dark brown
    float3 labelPrimary = u.albumColor1.rgb;
    float3 labelHighlight = u.albumColor3.rgb;
    float3 discEdge = u.albumColor2.rgb * 0.4;
    float3 grooveBase = float3(0.018, 0.012, 0.018);  // near-black disc

    // Desk gradient (slight warm vignette from corners)
    float vignette = 1.0 - smoothstep(0.45, 1.05, length(p));
    float3 color = desktopColor * (0.6 + vignette * 0.6);

    // Disc geometry
    float discRadius = 0.45;
    float r = length(p);
    if (r > discRadius) {
        // Outside disc: just background
        color = applyControls(color, u);
        return half4(half3(color), 1.0);
    }

    // Rotated coords for groove pattern
    float cosR = cos(rotation);
    float sinR = sin(rotation);
    float2 rp = float2(p.x * cosR - p.y * sinR, p.x * sinR + p.y * cosR);
    float angle = atan2(rp.y, rp.x);
    (void)angle; // used for future groove shimmer if needed

    // Outer black ring (~92% to 100% of radius)
    if (r > discRadius * 0.92) {
        color = grooveBase;
    } else if (r > discRadius * 0.28) {
        // Groove region: concentric thin lines
        float grooveDensity = 220.0;
        float groove = sin(r * grooveDensity);
        float grooveMask = smoothstep(0.6, 1.0, abs(groove));
        // Bass deepens grooves
        float bassDeepen = u.audioBass * 0.4;
        float3 grooveColor = mix(grooveBase, discEdge * 0.6, smoothstep(discRadius * 0.6, discRadius * 0.9, r));
        color = mix(grooveColor, grooveColor * (0.6 - bassDeepen * 0.3), grooveMask);
    } else if (r > discRadius * 0.02) {
        // Label region
        float labelFade = smoothstep(discRadius * 0.28, discRadius * 0.22, r);
        float3 labelColor = mix(labelPrimary, labelHighlight, smoothstep(0.0, discRadius * 0.25, r));
        // Subtle radial rings on the label
        float labelRings = sin(r * 60.0) * 0.05;
        labelColor *= 1.0 + labelRings;
        color = mix(grooveBase, labelColor, labelFade);
    } else {
        // Center pin
        color = float3(0.02, 0.02, 0.02);
    }

    // Highlight crescent (light from upper-left)
    float2 lightDir = float2(-0.7, 0.7);
    float lightFactor = clamp(dot(normalize(p + float2(0.001)), lightDir), 0.0, 1.0);
    float highlightRing = 1.0 - smoothstep(discRadius * 0.85, discRadius * 0.96, r);
    float discMask = step(r, discRadius);
    color += float3(0.10, 0.08, 0.12) * lightFactor * highlightRing * discMask * 0.5;

    // Disc rim shadow (right side)
    float rimShadow = smoothstep(discRadius * 0.95, discRadius, r) * (1.0 - lightFactor);
    color *= 1.0 - rimShadow * 0.5 * discMask;

    color = applyControls(color, u);
    return half4(half3(clamp(color, 0.0, 1.0)), 1.0);
}
