/// The old forest, seen from above: icons sit in a mossy glade ringed by
/// standing stones. All round stands deep wood, the broad crowns of ancient
/// trees almost closing over the dark floor, with a stream and a footpath
/// winding through. Mist drifts between the trees. By night the stream and
/// the runes on the stones glow, and fireflies come out.
///
/// Palette: 0 moss of the glade · 1 leaf, dark green · 2 leaf, olive · 3 leaf, gold
/// 4 stone · 5 water and everything that glows · 6 mist · 7 forest floor
let shaderForest = """

// How far the stream's middle is from here, in points; and the footpath's.
static float streamAway(float2 p) {
    return abs(gnoise(p / 820.0 + 31.0) + 0.04 * gnoise(p / 80.0 + 2.0)) * 820.0;
}
static float pathAway(float2 p) {
    return abs(gnoise(p / 700.0 + 77.0) + 0.035 * gnoise(p / 60.0 + 9.0)) * 700.0;
}

// A standing stone from above: a rounded slab, turned.
static float slab(float2 e, float2 size, float turn) {
    float c = cos(turn), s = sin(turn);
    float2 q = abs(float2(e.x * c + e.y * s, -e.x * s + e.y * c)) - size + 1.5;
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - 1.5;
    return 1.0 - smoothstep(-0.6, 0.6, d);
}

// The ground's fourth channel says how much a thing glows after dark.
fragment float4 forestGround(VertexOut in [[stage_in]],
                             constant Uniforms &u [[buffer(0)]],
                             texture2d<float> data [[texture(0)]],
                             sampler smp [[sampler(0)]]) {
    float2 p = in.position.xy / u.scale;
    float2 uv = p / u.size;
    float l = data.sample(smp, uv).x;
    float slope = max(length(gradientOf(data, smp, uv, u.size, 0)), 0.0008);
    float2 away = u.light.xy;

    // The forest floor: dark earth, leaf litter, patches of fern.
    float3 c = u.color[7].rgb * (0.80 + 0.40 * fbm(p / 90.0 + 4.0));
    c = mix(c, u.color[1].rgb * 0.50, smoothstep(0.50, 0.70, fbm(p / 22.0 + 9.0)));
    c *= 1.0 - 0.10 * step(0.93, cellHash(floor(p / 1.8)));
    float glow = 0.0;

    // A footpath of trodden earth, and the stream between darker banks.
    float trodden = 1.0 - smoothstep(3.0, 5.5, pathAway(p) + 1.5 * gnoise(p / 9.0));
    c = mix(c, float3(0.30, 0.25, 0.17) * (0.85 + 0.30 * fbm(p / 14.0)), trodden * 0.85);
    float bend = streamAway(p);
    c = mix(c, c * 0.55, 1.0 - smoothstep(7.0, 10.0, bend));
    float water = 1.0 - smoothstep(4.5, 6.0, bend);
    c = mix(c, mix(u.color[1].rgb, u.color[5].rgb, 0.45) * (0.55 + 0.20 * smoothstep(0.0, 4.0, bend)), water);
    glow = water * 0.45;

    // The glade: deep moss, mottled, with a darker fringe of grass.
    float3 moss = u.color[0].rgb * (0.90 + 0.20 * fbm(p / 70.0 + 2.0));
    moss = mix(moss, moss * 0.88, smoothstep(0.48, 0.60, fbm(p / 24.0 + 14.0)));
    moss *= 1.0 - 0.06 * step(0.965, cellHash(floor(p / 1.6)));
    float glade = smoothstep(-0.5, 0.5, (l + 0.035) / slope);
    c = mix(c, moss, glade);
    glow *= 1.0 - glade;
    c = mix(c, c * 0.72, contour(l, -0.035, slope, 7.0) * 0.6);

    // What stands on the ground, shadows first so nothing is shaded by its
    // own shadow: the stones round the glade, then young trees, then ancient ones.
    for (int pass = 0; pass < 2; pass++) {
        for (int layer = 0; layer < 3; layer++) {
            float pitch = layer == 0 ? 46.0 : (layer == 1 ? 34.0 : 62.0);
            float2 id0 = floor(p / pitch);
            for (int j = -1; j <= 1; j++) {
                for (int i = -1; i <= 1; i++) {
                    float2 id = id0 + float2(float(i), float(j));
                    float2 key = id + float(layer) * 57.0;
                    if (hash(key + 2.9) > (layer == 0 ? 0.80 : (layer == 1 ? 0.72 : 0.88))) continue;
                    float2 centre = (id + 0.5 + (float2(hash(key + 1.1), hash(key + 5.9)) - 0.5) * (layer == 0 ? 0.4 : 0.7)) * pitch;
                    float there = data.sample(smp, centre / u.size).x;
                    float seed = hash(key + 4.4) * 6.28;
                    float2 e = p - centre;

                    if (layer == 0) {
                        // A standing stone. Seen from straight above it would be
                        // a grey dot, so like a stone on an old map it is drawn
                        // upright from its foot: a tall, leaning, round-topped
                        // slab, lit on one side, throwing a long shadow. Each is
                        // moved onto one line round the glade, so together they
                        // make a ring.
                        float2 rise = gradientOf(data, smp, centre / u.size, u.size, 0);
                        float steep = max(length(rise), 0.0005);
                        float off = (there + 0.085) / steep;
                        if (abs(off) > 13.0) continue;
                        centre -= rise / steep * off;
                        e = p - centre;
                        float wide = 4.6 + 1.8 * hash(key + 8.3);
                        float tall = 18.0 + 10.0 * hash(key + 3.6);
                        if (pass == 0) {
                            float2 reach = thrown(tall * 0.9, u);
                            float k = clamp(dot(e, reach) / max(dot(reach, reach), 0.01), 0.0, 1.0);
                            float girth = wide * (1.0 - 0.25 * k);
                            c = mix(c, c * 0.45, (1.0 - smoothstep(girth - 1.0, girth + 1.0, length(e - reach * k))) * 0.80 * u.light.w);
                            continue;
                        }
                        float up = clamp(-e.y / tall, 0.0, 1.0);                 // 0 at its foot, 1 at its top
                        float2 q = float2(e.x - (hash(key + 7.1) - 0.5) * 5.0 * up, e.y + tall * 0.5);
                        q.x /= 1.0 - 0.30 * up * up;                             // narrower toward the top
                        // A weathered outline: nothing straight, nothing even,
                        // and the top broken off at a slant.
                        float rough = 0.9 * gnoise(p / 3.5 + seed) + 0.5 * gnoise(p / 1.7 + seed * 2.0);
                        float2 box = abs(q) - float2(wide, tall * 0.5) + 2.0;
                        float d = length(max(box, 0.0)) + min(max(box.x, box.y), 0.0) - 2.0 + rough;
                        float slant = (hash(key + 5.1) - 0.5) * 0.9;
                        d = max(d, (-tall * 0.5 + 1.5 + slant * q.x + abs(slant) * wide) - q.y + 0.5 * rough);
                        float stone = 1.0 - smoothstep(-0.5, 0.5, d);

                        // Where it meets the ground the grass is in its shade.
                        float2 foot = e * float2(1.0, 2.2);
                        c = mix(c, c * 0.55, exp(-dot(foot, foot) / (wide * wide * 1.6)) * 0.6);

                        // Old stone: grey, mottled, lit on one side, darker and
                        // damp toward its foot, streaked by rain, patched with
                        // lichen, cracked here and there, mossy at foot and crown.
                        float sided = clamp(away.x * 4.0, -1.0, 1.0);
                        float dim = smoothstep(-0.35, 0.35, q.x / wide * sided + 0.25 * gnoise(p / 4.0 + seed));
                        float3 tone = u.color[4].rgb * 0.74 * (0.90 + 0.20 * hash(key + 6.2)) * mix(1.12, 0.62, dim);
                        tone *= mix(0.80, 1.0, smoothstep(0.0, 0.5, up));
                        tone *= (0.86 + 0.28 * fbm(p / 5.0 + seed)) * (0.94 + 0.12 * fbm(p / 1.3 + seed));
                        tone *= 1.0 - 0.10 * smoothstep(0.50, 0.80, fbm(float2(p.x / 1.2, p.y / 9.0) + seed));
                        float lichen = smoothstep(0.62, 0.72, fbm(p / 3.0 + seed * 3.0));
                        tone = mix(tone, float3(0.62, 0.62, 0.42) * mix(1.0, 0.65, dim), lichen * 0.55);
                        float crack = (1.0 - smoothstep(0.0, 0.05, abs(gnoise(p / 6.0 + seed * 5.0)))) * step(0.5, hash(key + 2.2));
                        tone *= 1.0 - 0.35 * crack;
                        float mossy = smoothstep(0.28, 0.0, up + 0.15 * gnoise(p / 2.0 + seed)) + 0.6 * smoothstep(0.85, 1.0, up + 0.10 * gnoise(p / 2.0 + seed + 9.0));
                        tone = mix(tone, u.color[0].rgb * 0.70 * mix(1.0, 0.70, dim), clamp(mossy, 0.0, 1.0) * 0.8);
                        tone *= 0.75 + 0.25 * (1.0 - smoothstep(-1.6, 0.0, d));   // its edges turn away from the light

                        // On some, a mark cut long ago: barely there by day.
                        float rune = 0.0;
                        if (hash(key + 9.9) > 0.55) {
                            float stroke = (1.0 - smoothstep(0.3, 0.9, abs(q.x))) * step(abs(q.y + tall * 0.08), tall * 0.15);
                            float tick = (1.0 - smoothstep(0.3, 0.9, abs(q.x - (q.y + tall * 0.16) * 0.8))) * step(abs(q.y + tall * 0.16), 2.0) * step(0.0, q.x);
                            rune = max(stroke, tick);
                        }
                        c = mix(c, tone * (1.0 - 0.22 * rune), stone);
                        glow = mix(glow, rune, stone);
                        continue;
                    }

                    // A tree, kept off the glade, the path and the stream.
                    if (there > (layer == 1 ? -0.165 : -0.190)) continue;
                    if (streamAway(centre) < (layer == 1 ? 15.0 : 30.0)) continue;
                    if (pathAway(centre) < (layer == 1 ? 12.0 : 22.0)) continue;
                    float radius = (layer == 1 ? 11.0 : 25.0) * (0.85 + 0.40 * hash(key + 8.3));
                    if (length(e) > radius * 2.6) continue;
                    if (pass == 0) {
                        float2 es = e - thrown(radius * 0.55, u);
                        c = mix(c, c * 0.45, (1.0 - smoothstep(radius - 2.0, radius + 2.0, length(es))) * 0.75 * u.light.w);
                        continue;
                    }
                    // The crown is a heap of leafy clumps, which scallop its
                    // edge; each clump is lit on the side the sun is.
                    float2 from;
                    float clump = puffs(e + seed * 37.0, radius * 0.40, from);
                    float cover = 1.0 - smoothstep(0.96, 1.04, length(e) / radius + 0.26 * (clump - 0.45));
                    if (cover <= 0.0) continue;
                    float kind = hash(key + 12.5);
                    float3 leaf = kind < 0.58 ? u.color[1].rgb : (kind < 0.96 ? u.color[2].rgb : u.color[3].rgb);
                    leaf *= 0.85 + 0.30 * hash(key + 3.6);
                    float shade = 0.5 + 0.5 * dot(from, away) * smoothstep(0.1, 0.7, clump);
                    float dome = smoothstep(-radius, radius, dot(e, away));
                    float3 tree = leaf * mix(1.30, 0.62, 0.55 * shade + 0.45 * dome) * (1.0 - 0.30 * smoothstep(0.55, 1.05, clump));
                    c = mix(c, tree, cover);
                    glow = mix(glow, 0.0, cover);
                }
            }
        }
    }
    return float4(c, glow);
}

fragment float4 forestScene(VertexOut in [[stage_in]],
                            constant Uniforms &u [[buffer(0)]],
                            texture2d<float> ground [[texture(0)]],
                            texture2d<float> data [[texture(1)]],
                            sampler smp [[sampler(0)]]) {
    float2 p = in.position.xy / u.scale;
    float2 uv = p / u.size;
    float t = u.time;
    float l = data.sample(smp, uv).x;
    float4 g = ground.sample(smp, uv);
    float3 c = g.rgb;
    float3 magic = u.color[5].rgb;
    float among = 1.0 - smoothstep(-0.10, 0.0, l);      // 1 in the wood, 0 in the glade

    // The stream runs.
    c += magic * 0.07 * g.a * gnoise(p / 7.0 + float2(t * 0.9, t * 0.5));

    // Mist lies between the trees and drifts, thicker when the sun is down.
    float mist = smoothstep(0.45, 0.80, fbm(p / 260.0 + float2(t * 0.012, -t * 0.008)) + 0.12 * gnoise(p / 60.0 + float2(-t * 0.03, t * 0.02)));
    c = mix(c, u.color[6].rgb, mist * (0.16 + 0.12 * u.night) * (0.25 + 0.75 * among));

    c = grade(c, u);

    // After dark the water and the runes shine.
    c += magic * g.a * (0.05 + 0.85 * u.night) * (0.85 + 0.15 * sin(t * 1.3 + p.x * 0.05 + p.y * 0.03));
    c += magic * splash(p, t, u) * 0.45;

    // Fireflies wander and blink among the trees: a few by day, many by night.
    for (int layer = 0; layer < 2; layer++) {
        float pitch = layer == 0 ? 62.0 : 39.0;
        float2 id = floor(p / pitch);
        float chance = cellHash(id + float(layer) * 23.0);
        if (chance < 0.10 + 0.50 * u.night) {
            float h1 = hash(id + 4.0), h2 = hash(id + 6.0);
            float2 at = (id + 0.5) * pitch + 13.0 * float2(sin(t * (0.25 + 0.3 * h1) + h2 * 6.28), cos(t * (0.21 + 0.3 * h2) + h1 * 6.28));
            float d = length(p - at);
            float blink = pow(max(0.0, sin(t * (0.7 + h1) + h2 * 40.0)), 3.0);
            float spark = (1.0 - smoothstep(0.6, 1.5, d)) + 0.45 * exp(-d * d / 18.0);
            c += float3(0.85, 1.0, 0.45) * spark * blink * (0.08 + 0.92 * u.night) * among;
        }
    }
    return float4(dither(c, in.position.xy), 1.0);
}
"""
