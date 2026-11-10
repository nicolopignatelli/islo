/// Desert oasis: icons sit on a still pool ringed by a green bank and palms;
/// smooth dunes lie between.
///
/// Palette: 0 sand in the light · 1 sand · 2 sand in shade · 3 green bank
/// 4 pool at its edge · 5 pool at its deepest · 6 palm, dark · 7 palm, light
let shaderOasis = """

// A palm seen from above: eight fronds round a centre. Returns how much of
// the frond covers this point, and in `rib` how near it is to a frond's spine.
static float palm(float2 rd, float radius, float turn, thread float &rib) {
    float angle = atan2(rd.y, rd.x);
    rib = pow(abs(cos(4.0 * angle + turn)), 0.7);
    float reach = radius * (0.40 + 0.60 * rib);
    return 1.0 - smoothstep(reach - 0.8, reach + 0.8, length(rd));
}

fragment float4 oasisGround(VertexOut in [[stage_in]],
                            constant Uniforms &u [[buffer(0)]],
                            texture2d<float> data [[texture(0)]],
                            sampler smp [[sampler(0)]]) {
    float2 p = in.position.xy / u.scale;
    float2 uv = p / u.size;
    float l = data.sample(smp, uv).x;
    float slope = max(length(gradientOf(data, smp, uv, u.size, 0)), 0.0008);

    // Dunes: a long slope brightening to its crest, then shade beyond it.
    // The crest is the only hard line.
    float2 q = p / 430.0;
    float a = fract(q.x * 0.9 + q.y * 2.4 + fbm(q * 0.8 + 3.0) * 2.0);
    float3 windward = mix(u.color[1].rgb, u.color[0].rgb, smoothstep(0.10, 0.72, a));
    float3 lee = mix(u.color[2].rgb, u.color[1].rgb, smoothstep(0.72, 1.0, a));
    float3 sand = mix(windward, lee, smoothstep(0.716, 0.724, a));
    sand = mix(sand, u.color[1].rgb, smoothstep(-0.30, -0.08, l) * 0.85);   // level ground by the water
    sand *= 0.98 + 0.04 * fbm(p / 120.0 + 5.0);
    sand *= 1.0 - 0.04 * step(0.988, cellHash(floor(p / 1.3)));

    // Green bank, then the pool deepening toward its middle.
    float3 bank = u.color[3].rgb * (0.90 + 0.20 * fbm(p / 12.0)) * mix(1.0, 0.82, smoothstep(-0.05, 0.0, l));
    float3 pool = mix(u.color[4].rgb, u.color[5].rgb, smoothstep(0.02, 0.45, l));
    float3 c = mix(sand, bank, smoothstep(-0.5, 0.5, (l + 0.075) / slope));
    c = mix(c, pool, smoothstep(-0.5, 0.5, l / slope));

    // Palms along the bank: shadows first, then the crowns over them.
    float2 id0 = floor(p / 38.0);
    for (int pass = 0; pass < 2; pass++) {
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                float2 id = id0 + float2(float(i), float(j));
                if (hash(id + 2.9) > 0.78) continue;
                float2 centre = (id + 0.5) * 38.0 + (float2(hash(id + 1.1), hash(id + 5.9)) - 0.5) * 18.0;
                float4 there = data.sample(smp, centre / u.size);
                if (there.x < -0.085 || there.x > 0.0 || there.z < 1.3) continue;
                float radius = 12.0 + 5.0 * hash(id + 8.3);
                float turn = hash(id + 4.4) * 6.28;
                float rib;
                if (pass == 0) {
                    c = mix(c, c * 0.62, palm(p - centre - thrown(7.8, u), radius, turn, rib) * 0.8 * u.light.w);
                } else {
                    float cover = palm(p - centre, radius, turn, rib);
                    float3 frond = mix(u.color[6].rgb, u.color[7].rgb, rib * rib);
                    frond *= 1.0 - 0.5 * (1.0 - smoothstep(1.0, 3.5, length(p - centre)));
                    c = mix(c, frond, cover);
                }
            }
        }
    }
    return float4(c, 1.0);
}

fragment float4 oasisScene(VertexOut in [[stage_in]],
                           constant Uniforms &u [[buffer(0)]],
                           texture2d<float> ground [[texture(0)]],
                           texture2d<float> data [[texture(1)]],
                           sampler smp [[sampler(0)]]) {
    float2 p = in.position.xy / u.scale;
    float2 uv = p / u.size;
    float t = u.time;
    float l = data.sample(smp, uv).x;
    float3 c = ground.sample(smp, uv).rgb;

    // The pool: the lightest ripple, a few glints, a ring where it just rose.
    float pool = smoothstep(0.0, 0.03, l);
    c *= 1.0 + 0.04 * gnoise(p / 16.0 + float2(t * 0.15, t * 0.08)) * pool;
    float2 star = floor(p / 1.5);
    float chance = cellHash(star);
    if (chance > 0.9985) {
        c = mix(c, float3(1.0), pow(max(0.0, sin(t * (0.5 + hash(star + 3.0)) + chance * 4000.0)), 3.0) * pool);
    }
    c = mix(c, u.color[4].rgb * 1.5, splash(p, t, u) * 0.5 * pool);

    // Wind lifts a veil of sand off the dunes.
    float veil = smoothstep(0.66, 0.90, fbm(float2((p.x * 0.94 - p.y * 0.35) / 140.0 - t * 0.10, (p.y * 0.94 + p.x * 0.35) / 16.0)));
    c = mix(c, u.color[0].rgb * 1.04, veil * 0.22 * (1.0 - smoothstep(-0.20, -0.08, l)));
    return float4(dither(grade(c, u), in.position.xy), 1.0);
}
"""
