/// Above the clouds: the view straight down from a great height. Far below
/// lies farmland, a patchwork of fields, hedges, woods and a river, and the
/// icons sit over a lake. Fair-weather clouds drift across between us and
/// the ground, each throwing its shadow far off to one side, and they thin
/// away before they reach an icon.
///
/// Palette: 0 lake · 1 field, green · 2 field, pale green · 3 field, wheat
/// 4 woods and hedges · 5 cloud in the light · 6 cloud in shade · 7 haze
let shaderClouds = """

// Farmland from the air: irregular fields, each one colour, some ploughed
// in stripes, with a dark hedge between neighbours.
static float3 farmland(float2 p, constant Uniforms &u) {
    float2 q = p / 105.0;
    q += 0.16 * float2(gnoise(q * 0.6 + 3.0), gnoise(q * 0.6 + 40.0));
    float2 cell = floor(q);
    float2 f = fract(q);
    float d1 = 9.0, d2 = 9.0;
    float2 id = cell;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            float2 o = float2(float(i), float(j));
            float2 pt = o + 0.5 + 0.8 * (float2(hash(cell + o + 1.3), hash(cell + o + 7.7)) - 0.5);
            float2 dv = abs(pt - f);
            float d = max(dv.x, dv.y) * 0.75 + length(dv) * 0.25;   // squarish fields
            if (d < d1) { d2 = d1; d1 = d; id = cell + o; }
            else if (d < d2) { d2 = d; }
        }
    }
    float pick = hash(id + 3.1);
    float3 c = pick < 0.36 ? u.color[1].rgb : (pick < 0.66 ? u.color[2].rgb : (pick < 0.86 ? u.color[3].rgb : mix(u.color[1].rgb, u.color[3].rgb, 0.5)));
    c *= 0.93 + 0.14 * hash(id + 9.4);
    float a = hash(id + 5.5) * 3.1416;
    if (hash(id + 2.2) > 0.45) c *= 1.0 + 0.04 * sin(dot(p, float2(cos(a), sin(a))) * 1.3);
    float edge = (d2 - d1) * 0.5 * 105.0;
    return mix(c, u.color[4].rgb, (1.0 - smoothstep(0.7, 1.7, edge)) * 0.75);
}

// Where the cloud masses lie: broad and soft. 0…1.
static float mass(float2 p) {
    float2 q = p / 310.0;
    float v = 0.5 * gnoise(q);
    q = float2(q.x * 1.6 - q.y * 1.2, q.x * 1.2 + q.y * 1.6) + 17.0;
    return 0.5 + 0.9 * (v + 0.27 * gnoise(q));
}

// A cumulus is a heap of puffs. Returns how far this point is from the
// middle of the nearest puff (0 at its middle, about 1 at its rim) and, in
// `from`, which way that middle lies.
static float puffs(float2 p, float size, thread float2 &from) {
    float2 q = p / size;
    float2 cell = floor(q);
    float2 f = fract(q);
    float best = 9.0;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            float2 o = float2(float(i), float(j));
            float2 pt = o + 0.5 + 0.85 * (float2(hash(cell + o + 2.3), hash(cell + o + 8.1)) - 0.5);
            float d = length(f - pt) / (0.55 + 0.60 * hash(cell + o + 4.7));
            if (d < best) { best = d; from = (f - pt) / max(length(f - pt), 0.0001); }
        }
    }
    return best;
}

fragment float4 cloudsGround(VertexOut in [[stage_in]],
                             constant Uniforms &u [[buffer(0)]],
                             texture2d<float> data [[texture(0)]],
                             sampler smp [[sampler(0)]]) {
    float2 p = in.position.xy / u.scale;
    float2 uv = p / u.size;
    float l = data.sample(smp, uv).x;
    float slope = max(length(gradientOf(data, smp, uv, u.size, 0)), 0.0008);

    float3 c = farmland(p, u);

    // Woods: dark, with lumpy edges and a mottling of crowns.
    float wood = smoothstep(0.615, 0.625, fbm(p / 190.0 + 8.0) + 0.035 * gnoise(p / 7.0));
    float3 trees = u.color[4].rgb * (0.86 + 0.34 * smoothstep(-0.2, 0.4, gnoise(p / 3.2 + 2.0)));
    c = mix(c, trees, wood);

    // A river winds through, with a pale bank.
    float bend = abs(gnoise(p / 560.0 + 60.0) + 0.05 * gnoise(p / 90.0 + 4.0)) * 560.0;
    c = mix(c, mix(u.color[3].rgb, float3(1.0), 0.25), 1.0 - smoothstep(4.5, 5.5, bend));
    c = mix(c, u.color[0].rgb * 1.08, 1.0 - smoothstep(2.8, 3.8, bend));

    // The lake under the icons: a pale shore, then still water.
    c = mix(c, mix(u.color[3].rgb, float3(1.0), 0.30), smoothstep(-0.5, 0.5, (l + 0.012) / slope));
    float3 water = u.color[0].rgb * (1.04 - 0.10 * smoothstep(0.0, 0.35, l));
    c = mix(c, water, smoothstep(-0.5, 0.5, l / slope));

    // The air between us and the ground.
    c = mix(c, u.color[7].rgb, 0.20);
    return float4(c, 1.0);
}

fragment float4 cloudsScene(VertexOut in [[stage_in]],
                            constant Uniforms &u [[buffer(0)]],
                            texture2d<float> ground [[texture(0)]],
                            texture2d<float> data [[texture(1)]],
                            sampler smp [[sampler(0)]]) {
    float2 p = in.position.xy / u.scale;
    float2 uv = p / u.size;
    float t = u.time;
    float l = data.sample(smp, uv).x;
    float3 c = ground.sample(smp, uv).rgb;

    // A glint or two on the lake, and a ring where it just changed.
    float onLake = smoothstep(0.0, 0.03, l);
    c *= 1.0 + 0.03 * gnoise(p / 18.0 + float2(t * 0.12, t * 0.07)) * onLake;
    c = mix(c, float3(1.0), splash(p, t, u) * 0.35 * onLake);

    // Clouds drift on the wind and thin away before they reach an icon.
    float2 cp = p - float2(7.0, 2.5) * t;
    float keep = 0.5 * smoothstep(-0.24, -0.05, l);
    float level = 0.60;
    float2 drop = thrown(77.0, u);
    float shadow = mass(cp - drop) + 0.03 - 0.5 * smoothstep(-0.24, -0.05, data.sample(smp, uv - drop / u.size).x);
    c = mix(c, c * float3(0.60, 0.66, 0.80), smoothstep(level - 0.02, level + 0.03, shadow) * 0.55 * u.light.w * (1.0 - onLake));

    // Each cloud is a heap of puffs of two sizes, which scallop its outline.
    // The same heap, looked up a little further from the light, gives the shading:
    // a rim of shade along the side away from the light, and brighter tops.
    float2 from;
    float here = mass(cp) - keep + 0.075 * (0.75 - puffs(cp, 64.0, from)) + 0.030 * (0.75 - puffs(cp + 11.0, 27.0, from));
    float2 lp = cp + u.light.xy * 11.8;
    float toward = mass(lp) - keep + 0.075 * (0.75 - puffs(lp, 64.0, from)) + 0.030 * (0.75 - puffs(lp + 11.0, 27.0, from));
    float body = smoothstep(level - 0.003, level + 0.003, here);
    float3 soft = mix(u.color[5].rgb, u.color[6].rgb, 0.22);
    float3 cloud = mix(u.color[6].rgb, soft, smoothstep(level + 0.022, level + 0.028, toward));
    cloud = mix(cloud, u.color[5].rgb, smoothstep(level + 0.082, level + 0.088, toward));
    c = mix(c, cloud, body);
    return float4(dither(grade(c, u), in.position.xy), 1.0);
}
"""
