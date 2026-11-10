/// Every landscape is drawn in four steps:
///
/// 1. data    – the terrain the icons imply: height above the edge of their
///              calm ground, how near icons are, and where they sit.
///              One pixel per point. Shared by all landscapes.
/// 2. ground  – everything that stays still, drawn once per change.
/// 3. scene   – the ground plus whatever moves in the picture itself.
/// 4. sprites – the creatures and craft that live there.
///
/// Steps 1 and 2 run only while the terrain is changing; 3 and 4 every frame.
/// Each landscape supplies its own ground and scene in its own file.
let shaderCommon = """
#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float2 size;        // points
    float  time;        // seconds
    float  scale;       // pixels per point
    int    count;
    int    landscape;
    float  night;       // 0 by day, 1 by night
    float  unused1;
    float4 color[8];    // the theme's palette; each landscape documents its slots
    float4 rings[8];    // x, y, start time of a splash where land rose or sank
    float4 light;       // xy: the way shadows fall; z: how long they are (1 = sun well up); w: how dark, 0…1
    float4 ambient;     // rgb: the colour of the light now; a: how much colour the dark takes away
    float4 icons[64];   // x, y in points from the top-left; z = strength; w = seed
};

struct VertexOut {
    float4 position [[position]];
};

vertex VertexOut fullScreenVertex(uint vid [[vertex_id]]) {
    float2 p = float2((vid << 1) & 2, vid & 2);
    VertexOut out;
    out.position = float4(p * 2.0 - 1.0, 0.0, 1.0);
    return out;
}

// ---------------------------------------------------------------- noise

static float hash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// A hash with no visible pattern on whole-number cells.
static float cellHash(float2 cell) {
    return fract(sin(dot(cell, float2(127.1, 311.7))) * 43758.5453);
}

static float hash1(float x) {
    return fract(sin(x * 127.1 + 311.7) * 43758.5453);
}

// Smooth gradient noise in roughly -0.7...0.7, with no visible grid.
static float gnoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 w = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float a0 = hash(i) * 6.2832;
    float a1 = hash(i + float2(1.0, 0.0)) * 6.2832;
    float a2 = hash(i + float2(0.0, 1.0)) * 6.2832;
    float a3 = hash(i + float2(1.0, 1.0)) * 6.2832;
    float v0 = dot(float2(cos(a0), sin(a0)), f);
    float v1 = dot(float2(cos(a1), sin(a1)), f - float2(1.0, 0.0));
    float v2 = dot(float2(cos(a2), sin(a2)), f - float2(0.0, 1.0));
    float v3 = dot(float2(cos(a3), sin(a3)), f - float2(1.0, 1.0));
    return mix(mix(v0, v1, w.x), mix(v2, v3, w.x), w.y);
}

// Layered gradient noise, 0…1, soft and cloud-like.
static float fbm(float2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * gnoise(p);
        p = float2(p.x * 1.6 - p.y * 1.2, p.x * 1.2 + p.y * 1.6) + 17.0;
        a *= 0.5;
    }
    return clamp(0.5 + v * 0.9, 0.0, 1.0);
}

// ---------------------------------------------------------------- 1. data

constant float RADIUS = 170.0;   // reach of one icon's ground, in points
constant float SHELF  = 380.0;   // reach of its wider surroundings
constant float COAST  = 0.38;    // field value at the edge of the calm ground
fragment float4 dataFragment(VertexOut in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 p0 = in.position.xy;   // this target is one pixel per point

    // Warp the ground so edges get bays and headlands instead of arcs.
    float2 p = p0 + 30.0 * float2(gnoise(p0 / 210.0), gnoise(p0 / 210.0 + 40.0))
                  +  9.0 * float2(gnoise(p0 / 55.0 + 7.0), gnoise(p0 / 55.0 + 90.0));
    float f = 0.0;
    float shelf = 0.0;
    float clear = 1e4;
    for (int i = 0; i < u.count; i++) {
        float4 icon = u.icons[i];
        float2 d0 = p0 - icon.xy;
        if (icon.z > 0.3) clear = min(clear, max(abs(d0.x) / 60.0, abs(d0.y) / 52.0));
        float2 d = p - icon.xy;
        float dist2 = dot(d, d);
        float radius = RADIUS * (0.82 + 0.40 * icon.w);
        float q = dist2 / (radius * radius);
        if (q < 1.0) {
            float w = 1.0 - q;
            f += icon.z * w * w * w;
        }
        float e = dist2 / (SHELF * SHELF);
        if (e < 1.0) {
            float w = 1.0 - e;
            shelf += icon.z * w * w * w;
        }
    }
    float rough = (fbm(p0 / 90.0) - 0.5) * 0.34;
    float l = f + rough * smoothstep(0.05, 0.5, f) - COAST;
    return float4(l, 1.0 - exp(-1.6 * shelf), clear, f);
}

// ---------------------------------------------------------------- helpers

// How fast one channel of the data changes here, per point.
static float2 gradientOf(texture2d<float> data, sampler smp, float2 uv, float2 size, int channel) {
    float2 e = 1.5 / size;
    float4 right = data.sample(smp, uv + float2(e.x, 0.0)), left = data.sample(smp, uv - float2(e.x, 0.0));
    float4 down = data.sample(smp, uv + float2(0.0, e.y)), up = data.sample(smp, uv - float2(0.0, e.y));
    return float2(right[channel] - left[channel], down[channel] - up[channel]) / 3.0;
}

// How far, and which way, the shadow lands of something whose shadow is
// `len` points long when the sun is well up.
static float2 thrown(float len, constant Uniforms &u) {
    return u.light.xy * len * u.light.z;
}

// The time of day: the dark takes some colour away, and the light tints the rest.
static float3 grade(float3 c, constant Uniforms &u) {
    float grey = dot(c, float3(0.30, 0.59, 0.11));
    return mix(c, float3(grey), u.ambient.a) * u.ambient.rgb;
}

// A line of constant width in points along the contour value = at.
static float contour(float value, float at, float slope, float width) {
    float dist = abs(value - at) / slope;
    return 1.0 - smoothstep(width * 0.5 - 0.5, width * 0.5 + 0.5, dist);
}

// Two rings running outward from each place where ground just rose or sank.
static float splash(float2 p, float t, constant Uniforms &u) {
    float total = 0.0;
    for (int i = 0; i < 8; i++) {
        float4 ring = u.rings[i];
        float age = t - ring.z;
        if (ring.w > 0.0 && age > 0.0 && age < 2.6) {
            float dist = length(p - ring.xy);
            float fade = 1.0 - age / 2.6;
            float r1 = 24.0 + 170.0 * (1.0 - exp(-age * 1.5));
            float r2 = 24.0 + 170.0 * (1.0 - exp(-max(age - 0.35, 0.0) * 1.5));
            float mark = (1.0 - smoothstep(0.8, 2.0, abs(dist - r1))) + 0.6 * (1.0 - smoothstep(0.6, 1.6, abs(dist - r2)));
            total += clamp(mark, 0.0, 1.0) * fade * fade;
        }
    }
    return clamp(total, 0.0, 1.0);
}

static float3 dither(float3 c, float2 pixel) {
    return c + (hash(pixel + 0.5) - 0.5) / 128.0;
}

// ---------------------------------------------------------------- 4. sprites

struct SpriteIn {
    float2 pos;     // centre, in points
    float2 size;    // points
    float2 cell;    // column, row in the atlas
    float  angle;
    float  alpha;
    float4 tint;    // rgb multiplies the sprite; a = 1 turns it into a flat silhouette
    float2 fall;    // if not zero: the sprite's height runs this way, this far (a shadow
                    // thrown on the ground), whichever way the sprite itself is turned
    float2 glow;    // x = 1: it gives its own light, and the hour does not tint it
};

struct SpriteOut {
    float4 position [[position]];
    float2 uv;
    float  alpha;
    float4 tint;
    float  glow;
};

vertex SpriteOut spriteVertex(uint vid [[vertex_id]], uint iid [[instance_id]],
                              constant Uniforms &u [[buffer(0)]],
                              const device SpriteIn *sprites [[buffer(1)]]) {
    SpriteIn s = sprites[iid];
    float2 corner = float2(float(vid & 1), float(vid >> 1)) * 2.0 - 1.0;
    float2 local = corner * s.size * 0.5;
    float ca = cos(s.angle), sa = sin(s.angle);
    float2 world = s.pos + float2(local.x * ca - local.y * sa, local.x * sa + local.y * ca);
    if (s.fall.x != 0.0 || s.fall.y != 0.0) world = s.pos + local.x * float2(ca, sa) + corner.y * 0.5 * s.fall;
    SpriteOut out;
    out.position = float4(world.x / u.size.x * 2.0 - 1.0, 1.0 - world.y / u.size.y * 2.0, 0.0, 1.0);
    out.uv = (s.cell + corner * 0.5 + 0.5) / float2(4.0, 15.0);
    out.alpha = s.alpha;
    out.tint = s.tint;
    out.glow = s.glow.x;
    return out;
}

fragment float4 spriteFragment(SpriteOut in [[stage_in]],
                               constant Uniforms &u [[buffer(0)]],
                               texture2d<float> atlas [[texture(0)]],
                               sampler smp [[sampler(0)]]) {
    float4 t = atlas.sample(smp, in.uv);   // premultiplied
    float3 rgb = mix(t.rgb * in.tint.rgb, in.tint.rgb * t.a, in.tint.a);
    return float4(in.glow > 0.5 ? rgb : grade(rgb, u), t.a) * in.alpha;
}
"""

/// The whole shader library: the shared parts, then one file per landscape.
let shaderSource = shaderCommon + shaderShore + shaderClouds + shaderLake + shaderOasis + shaderReef + shaderGrid + shaderForest + shaderCity + shaderPixel
