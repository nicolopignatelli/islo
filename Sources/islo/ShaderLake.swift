/// Frozen lake: icons sit on smooth blue ice; snow lies between in long
/// drifts, banked up at the edge of the ice, with stands of firs.
///
/// Palette: 0 ice · 1 ice, deeper tone · 2 snow · 3 snow in shade
/// 4 frost and cracks · 5 shadow on ice and snow · 6 fir
let shaderLake = """

// One tier of a fir's boughs seen from above: a ring of soft, rounded bough
// ends of uneven length, creased where two meet.
static float tier(float2 e, float radius, float boughs, float turn) {
    float angle = atan2(e.y, e.x) + turn;
    float lobe = pow(abs(cos(angle * boughs * 0.5)), 0.55);            // 1 on a bough, 0 in the crease
    float uneven = 0.07 * sin(angle * 3.0 + turn * 5.0) + 0.05 * sin(angle * 5.0 - turn * 3.0);
    float reach = radius * (0.80 + 0.20 * lobe + uneven);
    return 1.0 - smoothstep(reach - 0.7, reach + 0.7, length(e));
}

// A fir seen from high above and a little to one side: four tiers of boughs,
// each smaller than the one below and a step further up toward the tip, so
// the cone shows. Snow lies thick on every tier and leaves only a fringe of
// green showing beneath it. `rd` is measured from the foot of the trunk;
// `away` is the side the light does not reach.
static float4 fir(float2 rd, float radius, float seed, float2 away, float3 green, float3 white, float3 shade) {
    if (length(rd + float2(0.0, radius * 0.5)) > radius * 1.7) return float4(0.0);
    float3 c = green;
    float cover = 0.0;
    for (int k = 0; k < 4; k++) {
        float fk = float(k);
        float size = radius * (1.0 - 0.25 * fk);
        float2 e = rd + float2(0.0, radius * 0.30 * fk);
        e.y *= 1.12;
        float boughs = 9.0 - 1.0 * fk;
        float turn = seed + 0.9 * fk;
        float under = tier(e - float2(1.2, 1.9), size, boughs, turn);
        c = mix(c, c * 0.80, under * cover);
        float ring = tier(e, size, boughs, turn);
        float side = smoothstep(-size * 0.3, size * 0.5, dot(e, away));
        c = mix(c, green * mix(1.12, 0.82, side), ring);
        float2 s = e + float2(size * 0.07, size * 0.10);
        float snow = tier(s, size * 0.80, boughs, turn);
        c = mix(c, mix(white, shade, smoothstep(size * 0.05, size * 0.35, dot(s, away))), snow);
        cover = max(cover, ring);
    }
    return float4(c, cover);
}

fragment float4 lakeGround(VertexOut in [[stage_in]],
                           constant Uniforms &u [[buffer(0)]],
                           texture2d<float> data [[texture(0)]],
                           sampler smp [[sampler(0)]]) {
    float2 p = in.position.xy / u.scale;
    float2 uv = p / u.size;
    float l = data.sample(smp, uv).x;
    float slope = max(length(gradientOf(data, smp, uv, u.size, 0)), 0.0008);

    // Ice: two soft tones, and a few hairline cracks in places.
    float3 ice = mix(u.color[0].rgb, u.color[1].rgb, smoothstep(0.35, 0.75, fbm(p / 170.0 + 3.0)));
    ice *= 0.98 + 0.04 * fbm(p / 40.0 + 8.0);
    float crack = (1.0 - smoothstep(0.0, 0.012, abs(gnoise(p / 95.0 + 13.0)))) * 0.5
                + (1.0 - smoothstep(0.0, 0.008, abs(gnoise(p / 60.0 + 40.0)))) * 0.3;
    ice = mix(ice, u.color[4].rgb, crack * smoothstep(0.40, 0.62, fbm(p / 200.0 + 20.0)) * 0.5);

    // The snow stands above the ice and shades its near edge.
    float cast = data.sample(smp, (p - thrown(6.4, u)) / u.size).x;
    ice = mix(ice, ice * u.color[5].rgb, (1.0 - smoothstep(-0.02, 0.02, cast)) * 0.55 * u.light.w);

    // Snow: long drifts, each brightening to a crisp crest with blue shade
    // beyond it; level beside the lake, and a bright lip where it meets the ice.
    float3 white = u.color[2].rgb;
    float3 mid = mix(white, u.color[3].rgb, 0.30);
    float2 q = p / 400.0;
    float a = fract(q.x * 1.1 - q.y * 2.0 + fbm(q * 0.9 + 6.0) * 2.2);
    float3 windward = mix(mid, white, smoothstep(0.10, 0.72, a));
    float3 lee = mix(u.color[3].rgb, mid, smoothstep(0.72, 1.0, a));
    float3 snow = mix(windward, lee, smoothstep(0.716, 0.724, a));
    snow = mix(snow, mix(white, mid, 0.4), smoothstep(-0.26, -0.06, l) * 0.85);
    snow = mix(snow, float3(1.0), contour(l, -0.014, slope, 3.0) * 0.9);

    float3 c = mix(snow, ice, smoothstep(-0.5, 0.5, l / slope));

    // Firs stand in small stands out on the snow: shadows first, then the
    // trees from the back row forward, so nearer ones overlap those behind.
    float2 id0 = floor(p / 44.0);
    for (int pass = 0; pass < 2; pass++) {
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                float2 id = id0 + float2(float(i), float(j));
                float stand = smoothstep(0.50, 0.62, fbm(id / 4.5 + 7.0));
                if (hash(id + 2.9) > 0.16 + 0.62 * stand) continue;
                float2 foot = (id + 0.5) * 44.0 + (float2(hash(id + 1.1), hash(id + 5.9)) - 0.5) * 20.0;
                float radius = 12.0 + 6.0 * hash(id + 8.3);
                if (data.sample(smp, foot / u.size).x > -0.17) continue;
                if (data.sample(smp, (foot - float2(0.0, radius * 1.6)) / u.size).x > -0.14) continue;
                float2 rd = p - foot;
                if (pass == 0) {
                    // The shadow gives the tree away: a long cone, stepped like the tiers.
                    float2 away = u.light.xy;
                    float reach = radius * 3.0 * u.light.z;
                    float along = dot(rd, away);
                    float across = abs(dot(rd, float2(-away.y, away.x)));
                    float k = clamp(along / reach, 0.0, 1.0);
                    float girth = radius * (1.0 - k) * (0.70 + 0.30 * fract(k * 4.0));
                    float mark = (1.0 - smoothstep(girth - 0.8, girth + 0.8, across)) * step(0.0, along) * step(along, reach);
                    c = mix(c, c * u.color[5].rgb, mark * 0.85 * u.light.w);
                } else {
                    float4 tree = fir(rd, radius, hash(id + 4.4) * 6.28, u.light.xy, u.color[6].rgb, white, u.color[3].rgb);
                    c = mix(c, tree.rgb, tree.a);
                }
            }
        }
    }
    return float4(c, 1.0);
}

fragment float4 lakeScene(VertexOut in [[stage_in]],
                          constant Uniforms &u [[buffer(0)]],
                          texture2d<float> ground [[texture(0)]],
                          texture2d<float> data [[texture(1)]],
                          sampler smp [[sampler(0)]]) {
    float2 p = in.position.xy / u.scale;
    float2 uv = p / u.size;
    float t = u.time;
    float l = data.sample(smp, uv).x;
    float onIce = smoothstep(0.0, 0.03, l);
    float3 c = ground.sample(smp, uv).rgb;

    // Wind chases a thin veil of snow across the ice.
    float veil = smoothstep(0.62, 0.86, fbm(float2((p.x * 0.9 + p.y * 0.4) / 120.0 - t * 0.10, (p.y * 0.9 - p.x * 0.4) / 22.0)));
    c = mix(c, u.color[2].rgb, veil * 0.12 * onIce);

    // A crack rings outward where the ice was just laid bare.
    c = mix(c, u.color[4].rgb, splash(p, t, u) * 0.55 * onIce);

    // Snow falling: two layers of flakes, the nearer ones larger and faster.
    for (int layer = 0; layer < 2; layer++) {
        float size = layer == 0 ? 36.0 : 23.0;
        float2 q = p + float2(10.0, -20.0) * t * (layer == 0 ? 1.5 : 1.0) + float2(sin(t * 0.6 + p.y * 0.02) * 6.0, 0.0);
        float2 id = floor(q / size);
        if (cellHash(id + float(layer) * 17.0) < 0.40) {
            float2 centre = (id + 0.2 + 0.6 * float2(hash(id + 4.0), hash(id + 6.0))) * size;
            float radius = layer == 0 ? 1.4 : 0.9;
            c = mix(c, float3(1.0), (1.0 - smoothstep(radius - 0.5, radius + 0.4, length(q - centre))) * 0.8);
        }
    }
    return float4(dither(grade(c, u), in.position.xy), 1.0);
}
"""
