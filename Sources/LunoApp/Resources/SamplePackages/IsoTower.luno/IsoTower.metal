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

// Signed distance to a line segment, returns 0..1 mask with given half-width
static float lineSeg(float2 p, float2 a, float2 b, float hw) {
    float2 ab = b - a;
    float2 ap = p - a;
    float t = clamp(dot(ap, ab) / dot(ab, ab), 0.0, 1.0);
    float d = length(ap - ab * t);
    return smoothstep(hw, hw * 0.4, d);
}

// Draw one isometric cube frame centered at `center`, half-size `h`.
// Returns 0..1 alpha mask. Aspect ratio correction via `aspect`.
// Iso cube: top face diamond + bottom face diamond + 4 verticals.
// All positions in UV space with aspect applied on x.
static float isoFrame(float2 uv, float2 center, float h, float lw, float aspect) {
    // Iso projection: x-axis goes right-down, z-axis goes right-up, y-axis goes up.
    // In screen 2D (y up = screen up):
    //   right  = ( cos30, -sin30) * h  = ( sqrt3/2, -0.5 ) * h  (scaled by aspect on x)
    //   left   = (-cos30, -sin30) * h  = (-sqrt3/2, -0.5 ) * h
    //   up     = (0, h)
    // Top face corners (top of the cube):
    //   T (top)    = center + (0,  h)
    //   R (right)  = center + ( sqrt3/2 * h / aspect,  0 )
    //   Bo (bottom)= center + (0, -h)   -- bottom of top diamond
    //   L (left)   = center + (-sqrt3/2 * h / aspect,  0 )
    // Bottom face shifts down by h (the cube depth):
    //   same x, y -= h
    float sx = h * 0.866 / aspect; // sqrt(3)/2
    float2 tT  = center + float2(  0.0,  h);
    float2 tR  = center + float2( sx,    0.0);
    float2 tBo = center + float2(  0.0, -h);
    float2 tL  = center + float2(-sx,    0.0);
    float dy = -h;
    float2 bT  = tT  + float2(0.0, dy);
    float2 bR  = tR  + float2(0.0, dy);
    float2 bBo = tBo + float2(0.0, dy);
    float2 bL  = tL  + float2(0.0, dy);

    float m = 0.0;
    // Top diamond (4 edges)
    m = max(m, lineSeg(uv, tT, tR, lw));
    m = max(m, lineSeg(uv, tR, tBo, lw));
    m = max(m, lineSeg(uv, tBo, tL, lw));
    m = max(m, lineSeg(uv, tL, tT, lw));
    // Bottom diamond (4 edges)
    m = max(m, lineSeg(uv, bT, bR, lw));
    m = max(m, lineSeg(uv, bR, bBo, lw));
    m = max(m, lineSeg(uv, bBo, bL, lw));
    m = max(m, lineSeg(uv, bL, bT, lw));
    // 4 verticals
    m = max(m, lineSeg(uv, tT, bT, lw));
    m = max(m, lineSeg(uv, tR, bR, lw));
    m = max(m, lineSeg(uv, tBo, bBo, lw));
    m = max(m, lineSeg(uv, tL, bL, lw));
    return m;
}

// Draw a layer of iso frames on a regular grid.
// gridSpacing: distance between frame centers (UV space).
// h: half-size of each frame. lw: line half-width.
// offset: applied to UV before grid snapping (for parallax scroll).
// Only tests the 3x3 nearest cells — no unbounded loop over the full screen.
static float isoLayer(float2 uv, float gridSpacing, float h, float lw,
                       float2 offset, float aspect) {
    float2 shifted = uv - offset;
    float2 cell = floor(shifted / gridSpacing);
    float m = 0.0;
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            float2 c = (cell + float2(float(dx), float(dy)) + 0.5) * gridSpacing + offset;
            m = max(m, isoFrame(uv, c, h, lw, aspect));
        }
    }
    return m;
}

fragment half4 lunoFragment(LunoVertexOut in [[stage_in]], constant LunoUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float speed  = max(u.parameter0.x, 0.1);
    float aspect = u.resolution.x / max(u.resolution.y, 1.0);
    float t = u.time * speed;

    // Background: dark vertical gradient, deep blue-black
    float3 bgTop = float3(0.024, 0.031, 0.059); // #06080F-ish
    float3 bgBot = float3(0.032, 0.040, 0.074);
    float3 color = mix(bgBot, bgTop, uv.y);

    float bass  = clamp(u.audioBass, 0.0, 1.0);
    float pulse = 1.0 + bass * 0.4;

    // Line color: cool cyan-white
    float3 lineColor = float3(0.72, 0.88, 1.0);

    // Layer 0 — far, small (size 0.08), slow scroll
    float lw0 = 0.0010;
    float2 off0 = float2(t * 0.022, t * 0.010);
    float m0 = isoLayer(uv, 0.22, 0.06, lw0, off0, aspect) * 0.30;

    // Layer 1 — mid (size 0.16), moderate scroll
    float lw1 = 0.0012;
    float2 off1 = float2(t * 0.038, t * 0.018);
    float m1 = isoLayer(uv, 0.38, 0.11, lw1, off1, aspect) * 0.50;

    // Layer 2 — near, large (size 0.28), faster scroll
    float lw2 = 0.0015;
    float2 off2 = float2(t * 0.062, t * 0.028);
    float m2 = isoLayer(uv, 0.60, 0.18, lw2, off2, aspect) * 0.70;

    float lines = max(max(m0, m1), m2) * pulse;
    color += lineColor * lines;

    // Bass glow: very subtle full-screen wash
    color += float3(0.050, 0.080, 0.120) * bass * 0.5;

    color = applyControls(color, u);
    return half4(half3(color), 1.0);
}
