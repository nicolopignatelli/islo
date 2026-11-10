/// Neon grid: a dark floor ruled with lines of light. Icons stand on plain
/// dark platforms built of grid squares, so every edge is straight and every
/// corner square; each is outlined in light, and the outline echoes outward. Packets of light run along the lines.
/// Nothing here is lit by the sun: the light is blue by day and turns red
/// at night.
///
/// Palette: 0 floor · 1 the light by day · 2 the light at night
/// 3 the rival racer by day · 4 the rival racer at night
let shaderGrid = """

// 1 on a line of a grid with this spacing, 0 away from it.
static float ruled(float v, float pitch, float width) {
    float d = abs(fract(v / pitch + 0.5) - 0.5) * pitch;
    return 1.0 - smoothstep(width - 0.5, width + 0.5, d);
}

// Is this square of the fine grid part of a platform?
static float platform(float2 square, texture2d<float> data, sampler smp, constant Uniforms &u) {
    float4 d = data.sample(smp, (square + 0.5) * 24.0 / u.size);
    return (d.x > -0.03 || d.z < 1.15) ? 1.0 : 0.0;
}

// The ground holds brightness only, to be coloured by the hour:
// r lines and panels · g a faint wash · b the outlines round the icons
// a 1 on a platform, 0 out on the grid.
fragment float4 gridGround(VertexOut in [[stage_in]],
                           constant Uniforms &u [[buffer(0)]],
                           texture2d<float> data [[texture(0)]],
                           sampler smp [[sampler(0)]]) {
    float2 p = in.position.xy / u.scale;
    // How far it is to the nearest square of the other sort, measured the
    // way the grid runs, so the lines drawn from it turn square corners.
    float2 square = floor(p / 24.0);
    float mine = platform(square, data, smp, u);
    float near = 99.0;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            if (i == 0 && j == 0) continue;
            float2 other = square + float2(float(i), float(j));
            if (platform(other, data, smp, u) == mine) continue;
            float2 gap = max(max(other * 24.0 - p, p - (other + 1.0) * 24.0), 0.0);
            near = min(near, max(gap.x, gap.y));
        }
    }
    float open = 1.0 - mine;

    float major = max(ruled(p.x, 48.0, 0.6), ruled(p.y, 48.0, 0.6));
    float minor = max(ruled(p.x, 12.0, 0.3), ruled(p.y, 12.0, 0.3));

    // Some squares are raised panels: a bright inner outline and a faint fill.
    float2 id = floor(p / 48.0);
    float2 f = fract(p / 48.0) * 48.0;
    float inset = min(min(f.x, 48.0 - f.x), min(f.y, 48.0 - f.y));
    float raised = step(0.84, hash(id + 3.1));
    float rim = raised * (1.0 - smoothstep(0.5, 1.3, abs(inset - 6.0)));
    float fill = raised * smoothstep(5.5, 6.5, inset);
    // A few carry a smaller square inside.
    float inner = raised * step(0.5, hash(id + 6.6)) * (1.0 - smoothstep(0.4, 1.1, abs(inset - 15.0)));

    // Some crossings carry a node, a few of those a ring.
    float2 crossing = floor(p / 48.0 + 0.5);
    float away = length(p - crossing * 48.0);
    float pick = hash(crossing + 9.0);
    float node = step(0.72, pick) * (1.0 - smoothstep(2.2, 3.2, away));
    float ring = step(0.90, pick) * (1.0 - smoothstep(0.4, 1.2, abs(away - 8.0)));

    float lines = major * 0.50 + minor * 0.09 + rim * 0.80 + inner * 0.45 + node + ring * 0.70;
    lines *= mix(0.10, 1.0, open);

    // The platform's outline, a glow beside it, and its echoes out on the floor.
    float edge = 1.0 - smoothstep(0.7, 1.7, near);
    float echo = 0.0;
    for (int k = 1; k <= 3; k++) {
        echo += (1.0 - smoothstep(0.3, 1.0, abs(near - 6.0 * float(k)))) * (1.0 - float(k) / 4.0) * 0.7;
    }
    float halo = exp(-near / 7.0) * 0.30;

    float wash = fill * 0.10 * open + 0.035 * fbm(p / 260.0 + 4.0) + 0.030 * (1.0 - open);
    return float4(lines, wash, edge + echo * open + halo, mine);
}

fragment float4 gridScene(VertexOut in [[stage_in]],
                          constant Uniforms &u [[buffer(0)]],
                          texture2d<float> ground [[texture(0)]],
                          texture2d<float> data [[texture(1)]],
                          sampler smp [[sampler(0)]]) {
    float2 p = in.position.xy / u.scale;
    float2 uv = p / u.size;
    float t = u.time;
    float4 g = ground.sample(smp, uv);
    float open = 1.0 - g.a;
    float3 hue = mix(u.color[1].rgb, u.color[2].rgb, u.night);

    // The lines breathe, slowly and not all together.
    float lines = g.r * (0.82 + 0.18 * sin(t * 0.5 + 6.0 * fbm(p / 400.0 + 2.0)));

    // Packets of light run along some of the lines, each trailing a tail.
    float packets = 0.0;
    for (int axis = 0; axis < 2; axis++) {
        float along = axis == 0 ? p.x : p.y;
        float across = axis == 0 ? p.y : p.x;
        float span = (axis == 0 ? u.size.x : u.size.y) + 500.0;
        float line = floor(across / 48.0 + 0.5);
        float pick = hash1(line * 1.7 + float(axis) * 31.0);
        if (pick > 0.5) {
            float way = hash1(line * 2.9 + 5.0) > 0.5 ? 1.0 : -1.0;
            float head = fract(hash1(line * 4.1 + 2.0) + t * (0.020 + 0.030 * pick) * way) * span - 250.0;
            float behind = (head - along) * way;
            float on = 1.0 - smoothstep(0.4, 1.6, abs(across - line * 48.0));
            if (behind > 0.0) packets += on * exp(-behind / 110.0) * 0.8;
            packets += on * exp(-behind * behind / 10.0);
        }
    }
    packets *= open;

    float3 c = u.color[0].rgb + hue * g.g;
    c += hue * (lines + g.b * 1.15);
    c += float3(1.0) * (0.35 * pow(clamp(lines, 0.0, 1.0), 3.0) + 0.45 * pow(clamp(g.b, 0.0, 1.0), 3.0));
    c += mix(hue, float3(1.0), 0.45) * packets;
    c += mix(hue, float3(1.0), 0.3) * splash(p, t, u) * 0.9;
    return float4(dither(grade(c, u), in.position.xy), 1.0);
}
"""
