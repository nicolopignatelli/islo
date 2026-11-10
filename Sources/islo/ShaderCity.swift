/// ASCII city: a town plan typed out in characters. Every cell of a grid
/// 8 points wide and 16 high shows one character on a coloured ground.
/// A building is drawn the way old games drew them: its roof as a box of
/// + - | seen from above, and below it the front wall, one row of [] windows
/// for every storey. Streets carry cars that step from cell to cell, parks
/// are grass and trees, and the icons stand on an open square.
///
/// By day it is dark type on pale paper, the buildings painted and throwing
/// shadows. By night the paper is dark, the type glows, windows are lit and
/// street lamps come on. The characters come from the sheet in Glyphs.swift.
///
/// Palette: 0 paper by day · 1 paper by night · 2 type by day · 3 type by night
/// 4 lit windows, lamps and headlights · 5 parks · 6 streets by day
let shaderCity = """

constant float2 CELL = float2(8.0, 16.0);     // points
constant float2 BLOCK = float2(20.0, 9.0);    // cells from one street to the next

// Places in the sheet of characters.
constant float G_BLANK = 0.0, G_DOT = 1.0, G_COLON = 2.0, G_COMMA = 3.0, G_QUOTE = 4.0, G_DASH = 5.0;
constant float G_EQUALS = 6.0, G_PLUS = 7.0, G_BAR = 8.0, G_HASH = 9.0, G_PERCENT = 10.0, G_AT = 11.0;
constant float G_O = 12.0, G_STAR = 13.0, G_TILDE = 14.0, G_CARET = 15.0, G_AMP = 16.0, G_X = 17.0;
constant float G_LESS = 18.0, G_MORE = 19.0, G_V = 20.0, G_OPEN = 21.0, G_CLOSE = 22.0, G_UNDER = 23.0;

struct Lot {
    float kind;      // 0 street · 1 building · 2 park · 3 paving
    float storeys;   // 1…4
    float2 lo;       // first cell
    float2 hi;       // one past the last cell
    float seed;
};

// What stands on a cell. Streets run every BLOCK cells; each block between
// them is split into one to four lots.
static Lot lotAt(float2 cell, texture2d<float> data, sampler smp, constant Uniforms &u) {
    float2 b = floor(cell / BLOCK);
    float2 lc = cell - b * BLOCK;
    Lot lot;
    lot.kind = 0.0; lot.storeys = 0.0; lot.lo = cell; lot.hi = cell + 1.0; lot.seed = 0.0;
    if (lc.x < 2.0 || lc.y < 1.0) return lot;

    float2 lo = float2(2.0, 1.0), hi = BLOCK;
    float2 key = b;
    if (hash(b + 0.7) < 0.12) {
        lot.kind = 2.0;                               // the whole block is a park
    } else {
        if (hash(b + 1.9) > 0.22) {
            float sx = 8.0 + floor(hash(b + 2.3) * 7.0);
            if (lc.x < sx) hi.x = sx; else lo.x = sx;
        }
        key = b * 7.0 + lo;
        if (hash(key + 3.1) > 0.60) {
            float sy = 4.0 + floor(hash(key + 4.7) * 3.0);
            if (lc.y < sy) hi.y = sy; else lo.y = sy;
        }
        key = b * 13.0 + lo * 3.0 + hi;
        lot.kind = hash(key + 5.3) < 0.09 ? 2.0 : 1.0;
        lot.storeys = 1.0 + floor(hash(key + 6.1) * 4.0);
    }
    lot.lo = b * BLOCK + lo;
    lot.hi = b * BLOCK + hi;
    lot.seed = hash(key + 8.8);
    // The front wall needs a row for each storey, and the roof two rows.
    lot.storeys = min(lot.storeys, lot.hi.y - lot.lo.y - 2.0);

    // Nothing is built on the icons' square, or half on it.
    float2 a = lot.lo * CELL, z = lot.hi * CELL;
    float near = max(max(data.sample(smp, a / u.size).x, data.sample(smp, z / u.size).x),
                     max(data.sample(smp, float2(a.x, z.y) / u.size).x, data.sample(smp, float2(z.x, a.y) / u.size).x));
    near = max(near, data.sample(smp, (a + z) * 0.5 / u.size).x);
    if (near > -0.06) { lot.kind = 3.0; lot.storeys = 0.0; }
    return lot;
}

fragment float4 cityGround(VertexOut in [[stage_in]]) {
    return float4(0.0, 0.0, 0.0, 1.0);    // the city is typed afresh every frame
}

fragment float4 cityScene(VertexOut in [[stage_in]],
                          constant Uniforms &u [[buffer(0)]],
                          texture2d<float> ground [[texture(0)]],
                          texture2d<float> data [[texture(1)]],
                          texture2d<float> font [[texture(2)]],
                          sampler smp [[sampler(0)]]) {
    float2 p = in.position.xy / u.scale;
    float t = u.time;
    float2 cell = floor(p / CELL);
    float2 f = fract(p / CELL);
    float2 middle = (cell + 0.5) * CELL;
    float l = data.sample(smp, middle / u.size).x;

    // The paper goes dark first; then the type turns from dark to bright.
    float dusk = smoothstep(0.10, 0.60, u.night);
    float lit = smoothstep(0.50, 0.80, u.night);
    float3 paper = mix(u.color[0].rgb, u.color[1].rgb, dusk);
    paper *= 1.0 + float3(0.10, -0.04, -0.14) * sin(3.1416 * u.night);          // a flush at sunrise and sunset
    float3 type = mix(u.color[2].rgb, u.color[3].rgb, lit);
    float3 lamp = u.color[4].rgb;

    Lot lot = lotAt(cell, data, smp, u);
    float glyph = G_BLANK;
    float3 ink = type;
    float3 back = paper;
    float height = 0.0;       // what throws and takes shade
    float bright = 0.0;       // 1 for things that give light and take no shade

    if (l > -0.02) {
        // The square: an even sprinkling of dots.
        if (fmod(cell.x, 2.0) == 0.0 && fmod(cell.y, 2.0) == 0.0) glyph = G_DOT;
        ink = mix(paper, type, 0.30);
    } else if (lot.kind == 1.0) {
        height = lot.storeys;
        // Each building has its paint.
        float pick = fract(lot.seed * 17.0);
        float3 paint = pick < 0.28 ? float3(0.86, 0.60, 0.48) : (pick < 0.52 ? float3(0.62, 0.72, 0.82) : (pick < 0.76 ? float3(0.90, 0.80, 0.56) : float3(0.68, 0.80, 0.70)));
        float3 roof = mix(paint, paint * 0.13 + float3(0.012, 0.020, 0.050), dusk);
        float roofRows = (lot.hi.y - lot.lo.y) - lot.storeys;
        float row = cell.y - lot.lo.y;
        bool sideX = cell.x == lot.lo.x || cell.x == lot.hi.x - 1.0;
        if (row < roofRows) {
            // The roof, from above: a box, with a little gear on it.
            bool sideY = row == 0.0 || row == roofRows - 1.0;
            back = roof;
            if (sideX && sideY) glyph = G_PLUS;
            else if (sideY) glyph = G_DASH;
            else if (sideX) glyph = G_BAR;
            else {
                float gear = cellHash(cell + 3.0);
                if (gear > 0.93) glyph = gear > 0.965 ? G_O : G_X;
                else if (fract(lot.seed * 5.0) > 0.6 && fmod(cell.x + cell.y, 2.0) == 0.0) glyph = G_DOT;
                ink = mix(roof, type, 0.55);
            }
        } else {
            // The front wall: a row of windows for every storey.
            back = roof * mix(0.80, 1.0, dusk) * (1.0 - 0.06 * (row - roofRows));
            if (sideX) glyph = G_BAR;
            else {
                float col = cell.x - lot.lo.x - 1.0;
                float part = fmod(col, 3.0);
                bool room = !(part == 0.0 && cell.x + 1.0 >= lot.hi.x - 1.0);
                if (part < 2.0 && room) {
                    glyph = part == 0.0 ? G_OPEN : G_CLOSE;
                    float2 pane = float2(floor(col / 3.0) + lot.lo.x * 3.0, cell.y);
                    float who = cellHash(pane + 11.0);
                    // Someone is home behind about half of them, and now and
                    // then a light goes on or off.
                    float on = lit * step(fract(who * 3.0 + floor(t / 19.0 + who * 7.0) * 0.31), 0.55);
                    ink = mix(mix(type, back, 0.25), lamp, on);
                    back = mix(back, lamp * 0.30, on);
                    bright = on;
                }
            }
        }
    } else if (lot.kind == 2.0) {
        float what = cellHash(cell + 5.0);
        float3 grass = u.color[5].rgb;
        back = mix(mix(paper, grass, 0.45), grass * 0.10 + float3(0.0, 0.012, 0.02), dusk);
        glyph = what > 0.84 ? (what > 0.93 ? G_AT : G_AMP) : (what > 0.45 ? G_QUOTE : (what > 0.25 ? G_COMMA : G_BLANK));
        float3 leaf = mix(grass * 0.42, grass * 0.75, lit);
        ink = what > 0.84 ? leaf : mix(back, leaf, 0.55);
        height = what > 0.84 ? 1.0 : 0.0;
    } else if (lot.kind == 3.0) {
        if (cellHash(cell + 7.0) > 0.80) glyph = G_COMMA;
        ink = mix(paper, type, 0.30);
    } else {
        // Streets: tarmac, a broken line down the middle of the cross
        // streets, and cars that move a whole cell at a time.
        back = mix(u.color[6].rgb, u.color[1].rgb * 1.6 + 0.012, dusk);
        float3 line = mix(back, mix(float3(1.0), type, lit), 0.55);
        float2 lc = cell - floor(cell / BLOCK) * BLOCK;
        bool crossStreet = lc.y < 1.0;
        bool avenue = lc.x < 2.0;
        if (crossStreet && !avenue && fmod(cell.x, 2.0) == 0.0) { glyph = G_DASH; ink = line; }
        if (avenue && !crossStreet && lc.x < 1.0 && fmod(cell.y, 2.0) == 0.0) { glyph = G_COLON; ink = line; }
        float car = 0.0;
        if (crossStreet) {
            float way = hash1(cell.y * 1.3 + 2.0) > 0.5 ? 1.0 : -1.0;
            float place = cell.x - way * floor(t * (4.0 + 4.0 * hash1(cell.y * 3.1 + 7.0)));
            float pick = cellHash(float2(place, cell.y * 3.7));
            if (pick > 0.955) { glyph = way > 0.0 ? G_MORE : G_LESS; car = pick; }
        } else if (avenue) {
            float way = lc.x < 1.0 ? 1.0 : -1.0;
            float place = cell.y - way * floor(t * (2.0 + 2.0 * hash1(cell.x * 2.7 + 4.0)));
            float pick = cellHash(float2(cell.x * 5.3, place));
            if (pick > 0.93) { glyph = way > 0.0 ? G_V : G_CARET; car = pick; }
        }
        if (car > 0.0) {
            float tone = fract(car * 137.0);
            float3 paint = tone < 0.35 ? float3(0.80, 0.14, 0.10) : (tone < 0.65 ? float3(0.08, 0.24, 0.62) : float3(0.08, 0.08, 0.10));
            ink = mix(paint, mix(lamp, float3(1.0), 0.5), lit);
            back = mix(back, lamp * 0.22, lit);
            bright = 1.0;
        }
    }

    // Shade: is there something taller between this cell and the sun?
    float shade = 1.0;
    if (u.light.w > 0.0 && bright < 0.5) {
        for (int k = 1; k <= 2; k++) {
            float2 toward = middle - u.light.xy * u.light.z * 13.0 * float(k);
            Lot other = lotAt(floor(toward / CELL), data, smp, u);
            float theirs = other.kind == 1.0 ? other.storeys : 0.0;
            if (theirs >= height + float(k) * 1.5 - 0.5 && (other.lo.x != lot.lo.x || other.lo.y != lot.lo.y)) shade = 1.0 - 0.34 * u.light.w;
        }
    }

    float2 at = float2((glyph + clamp(f.x, 0.04, 0.96)) / 24.0, f.y);
    float mark = font.sample(smp, at).r;
    float3 c = mix(back, ink, mark) * shade;

    // Street lamps stand at the corners of every block and light a pool at night.
    float2 corner = floor(p / (BLOCK * CELL) + 0.5) * BLOCK * CELL + float2(8.0, 8.0);
    float2 off = p - corner;
    float pool = exp(-dot(off, off) / 900.0) * lit * (1.0 - smoothstep(-0.10, -0.02, l));
    c += lamp * pool * (0.16 + 0.45 * mark);

    // A change in the square sends a ring out through the type.
    c = mix(c, mix(type, lamp, 0.5), splash(p, t, u) * (0.12 + 0.6 * mark));
    return float4(dither(c, in.position.xy), 1.0);
}
"""
