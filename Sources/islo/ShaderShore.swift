/// Shore: icons sit on pale sand; the sea fills the space between.
///
/// Palette: 0 dry sand · 1 what wetting does to it · 2 shallows · 3 open water
/// 4 loss of red, green, blue with depth (a = depth scale) · 5 foam (a = amount)
/// 6 sparkles (a = how many) · 7 shade on the sand (a = strength)
let shaderShore = """

fragment float4 shoreGround(VertexOut in [[stage_in]],
                            constant Uniforms &u [[buffer(0)]],
                            texture2d<float> data [[texture(0)]],
                            sampler smp [[sampler(0)]]) {
    float2 p = in.position.xy / u.scale;
    float l = data.sample(smp, p / u.size).x;

    // Calm, pale sand: icons and their labels sit on it.
    float3 c = u.color[0].rgb;
    c *= mix(0.955, 1.02, smoothstep(0.0, 0.6, l));
    c *= 0.975 + 0.05 * fbm(p / 120.0 + 2.0);

    // The faintest drifts, lit from wherever the sun stands.
    float b0 = fbm(p / 60.0);
    float2 slope = float2(fbm((p + float2(3.0, 0.0)) / 60.0) - b0, fbm((p + float2(0.0, 3.0)) / 60.0) - b0) * 14.0;
    float lit = dot(slope, u.light.xy) * u.color[7].a * u.light.w;
    c = mix(c, c * u.color[7].rgb, clamp(-lit, 0.0, 1.0));

    // Grains: a few darker and lighter specks.
    float speck = cellHash(floor(p / 1.3));
    c *= 1.0 - 0.07 * step(0.985, speck) + 0.03 * step(speck, 0.012);
    c *= 0.985 + 0.03 * hash(in.position.xy);
    return float4(c, 1.0);
}

// Foam is a lace of bubbles: a bright net with holes.
static float lace(float2 p, float t) {
    float2 q = p / 6.5 + float2(t * 0.05, t * 0.03);
    float a = abs(gnoise(q));
    float b = abs(gnoise(q * 2.3 + 17.0));
    return max(1.0 - smoothstep(0.0, 0.22, a), 0.7 * (1.0 - smoothstep(0.0, 0.20, b)));
}

fragment float4 shoreScene(VertexOut in [[stage_in]],
                           constant Uniforms &u [[buffer(0)]],
                           texture2d<float> ground [[texture(0)]],
                           texture2d<float> data [[texture(1)]],
                           sampler smp [[sampler(0)]]) {
    float2 p = in.position.xy / u.scale;
    float2 uv = p / u.size;
    float t = u.time;
    float4 d = data.sample(smp, uv);
    float l = d.x;
    float shelf = d.y;
    float slope = max(length(gradientOf(data, smp, uv, u.size, 0)), 0.0008);
    float3 foam = u.color[5].rgb;
    float foamAmount = u.color[5].a;

    // The waterline climbs the beach and falls back, at a different moment
    // along each stretch of coast.
    float phase = fbm(p / 260.0 + 5.0) * 9.4;
    float run = 0.5 + 0.5 * sin(t * 0.42 + phase);
    run = run * run * (3.0 - 2.0 * run);
    float edge = 0.004 + 0.070 * run + 0.010 * (fbm(p / 16.0 + float2(0.0, t * 0.04)) - 0.5);
    float a = edge - l;                       // > 0 under water
    float under = smoothstep(-0.5, 0.5, a / slope);

    // Sand the waves reach is wet and golden; the highest wave left a line.
    float3 c = ground.sample(smp, uv).rgb;
    float wet = max(1.0 - smoothstep(0.045, 0.135, l), under);
    c *= mix(float3(1.0), u.color[1].rgb, wet);
    float tideMark = contour(l, 0.100 + 0.012 * (fbm(p / 22.0) - 0.5), slope, 1.3);
    c = mix(c, foam, 0.55 * tideMark * foamAmount);

    // Water: the sand shows through pale at the edge and is lost to blue.
    float depth = clamp(a / 0.40, 0.0, 1.5);
    float thickness = (1.7 * pow(depth, 1.15) + 2.4 * (1.0 - shelf) * smoothstep(0.55, 1.0, depth)) * u.color[4].a;
    float3 through = exp(-u.color[4].rgb * thickness);
    float3 scatter = mix(u.color[2].rgb, u.color[3].rgb, smoothstep(0.25, 2.6, thickness));
    float3 w = c * through + scatter * (1.0 - through);
    w *= 1.0 + 0.16 * (fbm(p / 210.0 + float2(t * 0.012, t * 0.007)) - 0.5) * smoothstep(0.3, 1.5, thickness);

    // Two wave lines travel in from open water and brighten as they arrive.
    float lines = 0.0;
    for (int k = 0; k < 2; k++) {
        float travel = fract(t * 0.045 + float(k) * 0.5 + phase / 18.8);
        float at = -(0.27 - 0.24 * travel);
        lines += contour(l, at, slope, 1.5) * sin(3.1416 * travel) * (0.25 + 0.45 * travel);
    }
    w = mix(w, foam, lines * foamAmount * smoothstep(0.02, 0.06, depth));
    c = mix(c, w, under);

    // Splashes run out over the water where land rose or sank.
    c = mix(c, foam, splash(p, t, u) * 0.8 * under);

    // Foam: a crisp line at the front of the wash and a thinning lace behind.
    float front = 1.0 - smoothstep(0.7, 1.5, abs(a) / slope);
    float trail = exp(-max(a, 0.0) / 0.035) * smoothstep(0.0, 0.004, a) * smoothstep(0.40, 0.80, lace(p, t)) * 0.5;
    c = mix(c, foam, clamp(front + trail, 0.0, 1.0) * foamAmount);

    // Spray: white specks, thick beside the foam, thinning out both ways.
    float pick = cellHash(floor(p / 1.5) + 61.0);
    c = mix(c, foam, step(1.0 - 0.15 * exp(-abs(a) / 0.030), pick) * 0.9 * foamAmount);

    // Sparkles on open water, coming and going.
    float2 star = floor(p / 1.5);
    float chance = cellHash(star);
    if (chance > 1.0 - 0.0016 * u.color[6].a) {
        float twinkle = 0.35 + 0.65 * pow(max(0.0, sin(t * (0.5 + hash(star + 3.0)) + chance * 4000.0)), 3.0);
        c = mix(c, u.color[6].rgb, twinkle * smoothstep(0.08, 0.3, depth));
    }
    return float4(dither(grade(c, u), in.position.xy), 1.0);
}
"""
