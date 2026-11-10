/// Pixel quest: the overworld of a 16-bit role-playing game, in the manner
/// of the consoles of the early 1990s. Everything is made of pixels 3 points
/// wide. The land is rolling grass, deep forest, mountain ranges and dark
/// water, each painted with a 16-pixel picture that repeats without a seam;
/// where one gives way to another is decided pixel by pixel, so coasts and
/// the edges of woods wander instead of following squares. Here and there
/// stands a place two tiles by two: a castle, a village, a ruin, a farm, a
/// travellers' camp, an abbey or a hamlet. The icons stand on
/// an open meadow with plain grass round it. The pictures are in
/// PixelArt.swift.
///
/// The ground's fourth channel tells the scene, and the walkers, what a
/// pixel is: 1 open water · 0.5 a window, lit at night · 0.25 ground one
/// can walk on · 0 anything else.
///
/// Palette: 0 lamplight in the windows · 1 foam on the water · 2 sand at its edge
let shaderPixel = """

constant float PIXEL = 3.0;                           // points
constant float2 SHEET = float2(336.0, 32.0);          // the sheet of pictures, in pixels: 7 tiles, 7 landmarks
constant float LAND_GRASS = 0.0, LAND_FOREST = 3.0, LAND_MOUNTAIN = 4.0, LAND_WATER = 5.0, LAND_MEADOW = 6.0;

// What kind of land a pixel is, and in `depth` how far inside that kind it
// lies (small at its edge). The edges are roughened two pixels at a time.
static float pixelLand(float2 px, texture2d<float> data, sampler smp, constant Uniforms &u, thread float &depth) {
    float2 q = px / 16.0;
    float l = data.sample(smp, (px + 0.5) * PIXEL / u.size).x;
    float rough = (cellHash(floor(px / 2.0)) - 0.5) * 0.010;
    depth = 1.0;
    if (l + rough * 2.0 > -0.03) return LAND_MEADOW;
    if (l > -0.15) return LAND_GRASS;                                 // open grass round the meadow
    float wet = fbm(q / 11.0 + 40.0) + rough;
    if (wet < 0.36) { depth = 0.36 - wet; return LAND_WATER; }
    float high = fbm(q / 9.0 + 3.0) + rough;
    if (high > 0.66) { depth = high - 0.66; return LAND_MOUNTAIN; }
    float wood = fbm(q / 5.0 + 20.0) + rough;
    if (high > 0.52 || wood > 0.60) { depth = max(high - 0.52, wood - 0.60); return LAND_FOREST; }
    return LAND_GRASS;
}

static float3 pixelPicture(texture2d<float> sheet, sampler smp, float2 at) {
    return sheet.sample(smp, (at + 0.5) / SHEET).rgb;
}

fragment float4 pixelGround(VertexOut in [[stage_in]],
                            constant Uniforms &u [[buffer(0)]],
                            texture2d<float> data [[texture(0)]],
                            texture2d<float> sheet [[texture(1)]],
                            sampler smp [[sampler(0)]]) {
    float2 px = floor(in.position.xy / u.scale / PIXEL);
    float2 tile = floor(px / 16.0);
    float2 at = px - tile * 16.0;
    float depth;
    float land = pixelLand(px, data, smp, u, depth);
    float3 c;
    float what = 0.0;

    if (land == LAND_GRASS || land == LAND_MEADOW) {
        // Grass: each tile one of three pictures that match at their edges.
        float pick = cellHash(tile + 3.0);
        float picture = land == LAND_MEADOW ? 6.0 : (pick < 0.62 ? 0.0 : (pick < 0.975 ? 1.0 : 2.0));
        c = pixelPicture(sheet, smp, float2(picture * 16.0 + at.x, at.y));
        what = 0.25;
        // It lies in the shade of whatever stands just above it.
        float unused;
        float above = pixelLand(px - float2(0.0, 3.0), data, smp, u, unused);
        if (above == LAND_FOREST || above == LAND_MOUNTAIN) c *= 0.74;
    } else {
        c = pixelPicture(sheet, smp, float2(land * 16.0 + at.x, at.y));
        if (land == LAND_WATER) {
            // Water meets land with a strip of sand and a line of foam.
            what = 1.0;
            if (depth < 0.007) { c = u.color[2].rgb * (depth < 0.003 ? 1.0 : 0.88); what = 0.0; }
            else if (depth < 0.010) c = u.color[1].rgb;
            else if (depth < 0.030) c *= 1.18;                        // shallows
        } else if (depth < 0.004) {
            c = mix(c, float3(0.04, 0.08, 0.09), 0.75);               // forest and mountain end in a dark edge
        }
    }

    // Landmarks stand on blocks of two tiles by two, where all of it is open grass.
    float2 block = floor(tile / 2.0) * 2.0;
    float place = cellHash(block + 9.0);
    if (place < 0.14) {
        bool clear = true;
        for (int k = 0; k < 5; k++) {
            float2 corner = k == 4 ? float2(16.0, 16.0) : float2(k % 2 == 0 ? 3.0 : 28.0, k < 2 ? 3.0 : 28.0);
            float inside;
            if (pixelLand(block * 16.0 + corner, data, smp, u, inside) != LAND_GRASS) clear = false;
        }
        if (clear) {
            // Which place it is: castle · village · ruin · farm · camp · abbey · hamlet.
            float which = place < 0.016 ? 0.0 : (place < 0.040 ? 1.0 : (place < 0.054 ? 2.0 : (place < 0.086 ? 3.0 : (place < 0.106 ? 4.0 : (place < 0.118 ? 5.0 : 6.0)))));
            float3 mark = pixelPicture(sheet, smp, float2(112.0 + which * 32.0, 0.0) + (px - block * 16.0));
            bool nothing = mark.r > 0.7 && mark.b > 0.7 && mark.g < 0.3;      // magenta: the land shows
            if (!nothing) {
                c = mark;
                // Windows, and the flames of a camp fire, give light after dark.
                bool window = distance(mark, float3(0.10, 0.18, 0.40)) < 0.12;
                bool flame = mark.r > 0.9 && mark.g > 0.45 && mark.b < 0.45;
                what = (window || flame) ? 0.5 : 0.0;
            } else if (land != LAND_GRASS) {
                c = pixelPicture(sheet, smp, at);                                     // level ground round it
                what = 0.25;
            }
        }
    }
    return float4(c, what);
}

fragment float4 pixelScene(VertexOut in [[stage_in]],
                           constant Uniforms &u [[buffer(0)]],
                           texture2d<float> ground [[texture(0)]],
                           texture2d<float> data [[texture(1)]],
                           sampler smp [[sampler(0)]]) {
    // Everything is worked out once for each big pixel, at its middle.
    float2 px = floor(in.position.xy / u.scale / PIXEL);
    float2 p = (px + 0.5) * PIXEL;
    float t = u.time;
    float4 g = ground.sample(smp, p / u.size);
    float3 c = g.rgb;

    if (g.a > 0.9) {
        // Ripples: short bright dashes that march along, row by row.
        float row = floor(px.y / 4.0);
        if (fmod(px.y, 4.0) == 1.0 && fmod(px.x + row * 5.0 + floor(t * 2.0), 8.0) < 3.0) c = mix(c, u.color[1].rgb, 0.40);
        else if (fmod(px.y, 4.0) == 3.0 && fmod(px.x + row * 3.0 + floor(t * 1.5), 11.0) < 2.0) c *= 0.88;
    }
    // Clouds pass over, unseen but for their shadows.
    float cloud = fbm((p + float2(t * 6.0, t * 2.5)) / 420.0) + 0.10 * gnoise((p + float2(t * 6.0, t * 2.5)) / 90.0);
    c *= 1.0 - 0.20 * step(0.60, cloud);
    // A change in the meadow sends out a ring, in pixels like everything else.
    c = mix(c, float3(1.0), step(0.35, splash(p, t, u)) * 0.55);

    c = grade(c, u);
    // Windows are lit once it is dark.
    if (abs(g.a - 0.5) < 0.1) c = mix(c, u.color[0].rgb, smoothstep(0.3, 0.7, u.night));
    return float4(c, 1.0);
}
"""
