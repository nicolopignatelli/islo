/// Coral reef, seen from the surface: icons sit on clearings of pale sea bed;
/// around them grows a reef of brain, branching and plate corals, and beyond
/// it lies a deep floor of weed beds, sand channels and boulders.
///
/// Palette: 0 sea bed · 1 rock the coral grows on · 2, 3, 4 three corals
/// 5 light rippling down from the surface · 6 what depth does to colour
/// 7 shadow under the lip of the reef
let shaderReef = """

// Light focused by the surface onto the bottom: soft bright curves.
static float ripples(float2 p, float t) {
    float2 q = p / 26.0;
    float2 r = float2(q.x * 0.8 - q.y * 0.6, q.x * 0.6 + q.y * 0.8) * 1.37 + 9.0;
    float a = 1.0 - min(abs(gnoise(q + float2(t * 0.06, -t * 0.04))) * 2.6, 1.0);
    float b = 1.0 - min(abs(gnoise(r + float2(-t * 0.05, t * 0.035))) * 2.6, 1.0);
    return 0.5 * (pow(a, 4.0) + pow(b, 4.0));
}

static float capsule(float2 p, float2 a, float2 b) {
    float2 pa = p - a, ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

// A lumpy outline: how far the edge lies in this direction, as a share of
// the radius. Never a circle.
static float lumpy(float2 around, float seed) {
    return 0.88 + 0.30 * gnoise(around * 1.2 + seed) + 0.11 * gnoise(around * 3.1 + seed + 9.0);
}

// One coral colony: how much of it covers this point, and in `tone` how
// light its surface is there.
//   form 0  brain coral: a lumpy boulder grooved like a maze
//   form 1  staghorn: stems forking outward from the middle, pale at the tips
//   form 3  anemone · form 4  starfish
//   form 2  plate coral: irregular plates lying over one another, pale-rimmed
static float colony(int form, float2 rd, float radius, float seed, thread float &tone) {
    tone = 1.0;
    if (length(rd) > radius * 1.6) return 0.0;
    if (form == 0) {
        float cr = cos(seed), sr = sin(seed);
        float2 e = float2(cr * rd.x + sr * rd.y, -sr * rd.x + cr * rd.y);
        e.y *= 1.0 + 0.5 * hash1(seed + 2.0);
        float dist = length(e);
        float reach = radius * lumpy(e / max(dist, 0.0001), seed);
        float2 w = rd / 4.2 + 1.6 * float2(gnoise(rd / 15.0 + seed), gnoise(rd / 15.0 + seed + 31.0));
        float groove = abs(sin(w.x * 1.7 + 1.5 * sin(w.y * 1.3)));
        float k = dist / reach;
        tone = 0.78 + 0.30 * smoothstep(0.20, 0.60, groove) - 0.18 * k * k;
        return 1.0 - smoothstep(reach - 0.9, reach + 0.9, dist);
    }
    if (form == 1) {
        // Staghorn from above: stems leave the middle in every direction.
        // Every colony has its own number of stems, unevenly spaced; every
        // stem its own length; and each branch may fork, run on unforked,
        // or stop, so no two colonies share a shape.
        float best = 1000.0;
        float order = 0.0;
        int stems = 3 + int(hash1(seed + 0.7) * 4.99);
        for (int stem = 0; stem < stems; stem++) {
            float fs = float(stem);
            float vigour = 0.55 + 0.75 * hash1(seed + fs * 7.3 + 2.0);
            float2 ends[16];
            float turns[16];
            bool alive[16];
            for (int n = 1; n < 16; n++) {
                int depth = n < 2 ? 0 : (n < 4 ? 1 : (n < 8 ? 2 : 3));
                float key = seed + fs * 13.0 + float(n) * 1.7;
                float2 start = float2(0.0);
                float turn;
                bool grows = true;
                if (n == 1) {
                    turn = seed + (fs + 0.8 * (hash1(key) - 0.5)) * 6.2832 / float(stems);
                } else {
                    start = ends[n / 2];
                    // chance of this branch existing falls with depth and with a weak stem
                    grows = alive[n / 2] && hash1(key + 9.1) < (depth == 1 ? 0.85 : (depth == 2 ? 0.62 : 0.40)) * (0.6 + 0.5 * vigour);
                    turn = turns[n / 2] + ((n & 1) == 1 ? 1.0 : -1.0) * (0.10 + 0.55 * hash1(key));
                }
                alive[n] = grows;
                turns[n] = turn;
                ends[n] = start;
                if (!grows) continue;
                float len = radius * 0.42 * vigour * pow(0.78, float(depth)) * (0.55 + 0.75 * hash1(key + 5.3));
                float2 end = start + len * float2(cos(turn), sin(turn));
                ends[n] = end;
                float d = capsule(rd, start, end) - radius * (0.078 - 0.011 * float(depth));
                if (d < best) { best = d; order = float(depth); }
            }
        }
        tone = 0.78 + 0.11 * order + 0.10 * smoothstep(0.0, -1.6, best);
        return 1.0 - smoothstep(-0.7, 0.7, best);
    }
    if (form == 3) {
        // Anemone: a ring of soft tentacles round a dark mouth, pale at the tips.
        float dist = length(rd);
        float angle = atan2(rd.y, rd.x) + 0.25 * gnoise(rd / 9.0 + seed);
        float finger = pow(abs(cos(angle * 6.5 + seed)), 0.8);
        float reach = radius * 0.80 * (0.50 + 0.50 * finger) * (0.9 + 0.2 * gnoise(rd / max(dist, 0.0001) * 2.0 + seed));
        float k = dist / max(reach, 0.0001);
        tone = 0.80 + 0.40 * k * k * finger;
        tone = mix(0.50, tone, smoothstep(radius * 0.13, radius * 0.20, dist));
        return 1.0 - smoothstep(reach - 0.8, reach + 0.8, dist);
    }
    if (form == 4) {
        // Starfish: five tapering arms, one always a little bent.
        float best = 1000.0;
        for (int arm = 0; arm < 5; arm++) {
            float turn = seed + float(arm) * 1.2566 + (hash1(seed + float(arm)) - 0.5) * 0.35;
            float2 tip = radius * 0.62 * float2(cos(turn), sin(turn));
            float2 pa = rd, ba = tip;
            float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
            best = min(best, length(pa - ba * h) - radius * (0.17 - 0.13 * h));
        }
        tone = 1.0 + 0.18 * smoothstep(0.0, -2.0, best);
        return 1.0 - smoothstep(-0.6, 0.6, best);
    }
    float cover = 0.0;
    for (int k = 0; k < 3; k++) {
        float fk = float(k);
        float2 e = rd - (k == 0 ? float2(0.0) : radius * 0.46 * float2(cos(seed + 2.3 * fk), sin(seed + 2.3 * fk)));
        float dist = length(e);
        float reach = radius * (k == 0 ? 0.82 : 0.50) * lumpy(e / max(dist, 0.0001), seed + 5.0 * fk);
        float plate = 1.0 - smoothstep(reach - 0.8, reach + 0.8, dist);
        float under = 1.0 - smoothstep(reach - 0.8, reach + 1.5, length(e - float2(2.2, 3.0)));
        tone = mix(tone, tone * 0.70, under * cover);
        float kk = dist / reach;
        float face = 0.86 + 0.24 * smoothstep(0.70, 0.86, kk) + 0.04 * sin(kk * 15.0);
        tone = mix(tone, face, plate);
        cover = max(cover, plate);
    }
    return cover;
}

fragment float4 reefGround(VertexOut in [[stage_in]],
                           constant Uniforms &u [[buffer(0)]],
                           texture2d<float> data [[texture(0)]],
                           sampler smp [[sampler(0)]]) {
    float2 p = in.position.xy / u.scale;
    float2 uv = p / u.size;
    float4 d = data.sample(smp, uv);
    float l = d.x;
    float slope = max(length(gradientOf(data, smp, uv, u.size, 0)), 0.0008);

    float3 sand = u.color[0].rgb * (0.97 + 0.06 * fbm(p / 110.0 + 2.0));
    sand *= 1.0 + 0.02 * sin(p.x * 0.20 + p.y * 0.33 + fbm(p / 40.0) * 5.0);

    // The reef: a paler rock shelf round the clearings, open water beyond.
    float3 rock = u.color[1].rgb * (0.90 + 0.20 * fbm(p / 60.0 + 9.0));
    float shelf = smoothstep(0.36, 0.50, d.y + (fbm(p / 34.0 + 4.0) - 0.5) * 0.22);
    // Deep floor: dark beds of weed with paler channels of sand between,
    // and boulders lying about.
    float3 deep = rock * u.color[6].rgb;
    float channel = smoothstep(0.44, 0.62, fbm(p / 250.0 + 21.0) + 0.02 * gnoise(p / 14.0));
    deep = mix(deep, mix(deep, u.color[0].rgb, 0.20), channel);
    deep *= 1.0 + 0.05 * (1.0 - channel) * sin(p.x * 0.5 + p.y * 0.9 + 4.0 * fbm(p / 30.0));
    float2 bid0 = floor(p / 110.0);
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            float2 id = bid0 + float2(float(i), float(j));
            if (hash(id + 14.2) > 0.45) continue;
            float2 centre = (id + 0.5 + (float2(hash(id + 3.3), hash(id + 6.1)) - 0.5) * 0.8) * 110.0;
            float size = 7.0 + 15.0 * hash(id + 2.7);
            float seed = hash(id + 7.9) * 40.0;
            float2 e = p - centre;
            float dist = length(e);
            if (dist > size * 2.0) continue;
            float reach = size * lumpy(e / max(dist, 0.0001), seed);
            deep = mix(deep, deep * 0.72, (1.0 - smoothstep(reach - 1.0, reach + 2.0, length(e - thrown(4.3, u)))) * u.light.w);
            float2 lit = e + u.light.xy * size * 0.37;
            float3 stone = mix(rock * u.color[6].rgb, float3(0.16, 0.24, 0.30), 0.55) * (1.0 - smoothstep(reach * 0.55 - 1.0, reach * 0.55 + 1.0, length(lit)) > 0.5 ? 1.30 : 0.95);
            deep = mix(deep, stone, 1.0 - smoothstep(reach - 0.8, reach + 0.8, dist));
        }
    }
    float3 reef = mix(deep, mix(rock, u.color[0].rgb, 0.22) * (0.94 + 0.12 * fbm(p / 9.0)), shelf);

    // Colonies on the shelf, two sizes; each shades the rock beside it.
    for (int layer = 0; layer < 2; layer++) {
        float cell = layer == 0 ? 92.0 : 46.0;
        float2 id0 = floor(p / cell);
        for (int j = -1; j <= 1; j++) {
            for (int i = -1; i <= 1; i++) {
                float2 id = id0 + float2(float(i), float(j)) + float(layer) * 100.0;
                float kind = hash(id + 3.7);
                if (kind < (layer == 0 ? 0.25 : 0.55)) continue;
                float2 centre = (id - float(layer) * 100.0 + 0.5 + (float2(hash(id + 1.1), hash(id + 5.9)) - 0.5) * 0.7) * cell;
                float4 there = data.sample(smp, centre / u.size);
                if (there.x > -0.07 || there.y < 0.44) continue;
                float choice = hash(id + 6.3);
                int form = choice < 0.26 ? 0 : (choice < 0.52 ? 1 : (choice < 0.74 ? 2 : (choice < 0.90 || layer == 0 ? 3 : 4)));
                float radius = cell * (form == 1 ? 0.44 : (form == 4 ? 0.26 : 0.33)) * (0.75 + 0.35 * hash(id + 8.1));
                float seed = hash(id + 9.9) * 40.0;
                float tone;
                float cast = colony(form, p - centre - thrown(5.0, u), radius, seed, tone);
                reef = mix(reef, reef * u.color[7].rgb * 0.8, cast * 0.7 * u.light.w);
                float cover = colony(form, p - centre, radius, seed, tone);
                float pick = hash(id + 12.5);
                float3 coral = pick < 0.40 ? u.color[2].rgb : (pick < 0.72 ? u.color[3].rgb : u.color[4].rgb);
                reef = mix(reef, mix(coral, u.color[1].rgb, 0.15) * tone, cover);
            }
        }
    }

    float onSand = smoothstep(-0.5, 0.5, l / slope);
    float3 c = mix(reef, sand, onSand);
    c = mix(c, c * u.color[7].rgb, (1.0 - smoothstep(0.0, 0.05, l)) * onSand * 0.6);
    return float4(c, 1.0);
}

fragment float4 reefScene(VertexOut in [[stage_in]],
                          constant Uniforms &u [[buffer(0)]],
                          texture2d<float> ground [[texture(0)]],
                          texture2d<float> data [[texture(1)]],
                          sampler smp [[sampler(0)]]) {
    float2 p = in.position.xy / u.scale;
    float2 uv = p / u.size;
    float t = u.time;

    // Seen through moving water, everything sways a little.
    float2 sway = 1.6 * float2(gnoise(p / 60.0 + float2(t * 0.12, t * 0.05)), gnoise(p / 60.0 + float2(30.0 - t * 0.10, t * 0.08)));
    float3 c = ground.sample(smp, uv + sway / u.size).rgb;

    // Light ripples down from the surface, and drifts in slow patches.
    c += u.color[5].rgb * ripples(p, t) * 0.055;
    c *= 1.0 + 0.10 * (fbm(p / 200.0 + float2(t * 0.015, t * 0.010)) - 0.5);
    c += u.color[5].rgb * splash(p, t, u) * 0.30;
    return float4(dither(grade(c, u), in.position.xy), 1.0);
}
"""
