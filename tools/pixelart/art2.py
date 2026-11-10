from PIL import Image
PAL = {
 '.': None,
 'g': (0.30,0.46,0.26), 'G': (0.24,0.39,0.23), 'l': (0.38,0.54,0.29),
 'a': (0.40,0.55,0.31), 'A': (0.36,0.51,0.29),
 't': (0.07,0.20,0.15), 'T': (0.11,0.29,0.18), 'L': (0.18,0.39,0.21), 'i': (0.27,0.48,0.24),
 'k': (0.10,0.09,0.12), 'M': (0.27,0.23,0.24), 'm': (0.43,0.37,0.34), 'n': (0.58,0.52,0.46), 's': (0.86,0.88,0.92), 'S': (0.62,0.68,0.80),
 'W': (0.07,0.16,0.36), 'w': (0.10,0.23,0.47), 'v': (0.17,0.33,0.58),
 'd': (0.52,0.43,0.30), 'D': (0.42,0.34,0.25), 'e': (0.61,0.52,0.36),
 'c': (0.62,0.62,0.66), 'C': (0.44,0.44,0.50), 'x': (0.28,0.28,0.34), 'r': (0.55,0.14,0.14), 'R': (0.36,0.09,0.11), 'y': (0.10,0.18,0.40), 'o': (0.20,0.13,0.10),
}
T = {}
T['grassA'] = """
gggggggGgggggggg
ggglgggggggGgggg
gggggggggggggggg
gGgggggglggggggg
gggggGgggggggglg
gggggggggggggggg
gglgggggggGggggg
gggggggGgggggggg
gggggggggggglggg
gGgggglggggggggg
ggggggggggggggGg
ggggGggggglggggg
gggggggggggggggg
glgggggggGgggggg
gggggglggggggGgg
gggGgggggggggggg
"""
T['grassB'] = """
gggggggggggggggg
ggGGgggggggggggg
gGlGGggggggGGggg
ggGGggggggGlGGgg
gggggggggggGGggg
gggggggggggggggg
ggggggGGgggggggg
gggggGlGGggggggg
ggggggGGgggggggg
gggggggggggggggg
gGGggggggggggGGg
GlGGggggggggGlGG
gGGgggggGGgggGGg
gggggggGlGGggggg
ggggggggGGgggggg
gggggggggggggggg
"""
T['scrub'] = """
gggggggggggggggg
gggggggggggTTggg
ggggggggggTLLTgg
ggggggggggTLTTgg
gggkkggggggTTggg
ggkcCkgggggggggg
ggkCCkgggggggggg
gggkkggggggggggg
gggggggggggggggg
ggggggTTgggggggg
gggggTLLTggggkkg
gggggTLTTgggkcCk
ggggggTTggggkCxk
gggggggggggggkkg
ggGggggggggggggg
gggggggggggggggg
"""
canopy = ["tTLiLTtt","TLiiLLTt","LiiLLLTT","LiLLLTTt","LLLLTTTt","TLLTTTtt","tTTTTttt","ttTtttTt"]
forest = [r + r for r in canopy] + [(r + r)[4:12] * 2 for r in canopy]
T['forest'] = "\n".join(forest)
T['mountain'] = """
MMMMMMkkMMMMMMMM
MMMMMksSkMMMMMMM
MMMMksssSkMMMMkM
MMMknssSSMkMMknk
MMknnnsSMMMkknnM
MknnnnnMMMMknnmM
knnnmnnMMMMMmmMM
nnnmmnmMMMMMMmMk
nnmmmmmMMMMMMMkn
nmmmmmmmMMMMMknn
mmmmMmmmMMMMknnm
mmmMMmmmMMMkmmmm
mmMMMMmmMMMMmmmM
mMMMMMMmMMMMMmMM
MMMkMMMMMMMMMMMM
MMMMMMMMMkMMMMMM
"""
T['water'] = """
wwwwwwwwwwwwwwww
wwwwwWWwwwwwwwww
wwvvwwwWWwwwwwww
wvwwvwwwwwwwvvww
wwwwwwwwwwwvwwvw
WWwwwwwwwwwwwwww
wwWWwwwwwwwwwwWW
wwwwwwvvwwwwwwww
wwwwwvwwvwwwwwww
wwwwwwwwwwwWWwww
wwwwwwwwwwwwwWWw
wvvwwwwwwwwwwwww
vwwvwwwwWWwwwwww
wwwwwwwwwwWWwwvv
wwwwwwwwwwwwwvww
WWwwwwwwwwwwwwww
"""
T['road'] = """
dddddddddDdddddd
ddeddddddddddddd
dddddddDdddddedd
dDdddddddddddddd
ddddddeddddddddd
dddddddddddDdddd
dddDdddddddddddd
ddddddddddeddddd
dedddddDdddddddd
dddddddddddddDdd
ddddDddddddddddd
dddddddddedddddd
dddddddddddddded
dDdddddddddDdddd
ddddddeddddddddd
dddddddddddddDdd
"""
T['castle'] = """
gggggggkrrgggggg
gggggggkRggggggg
kxkxkggkkkgkxkxk
kcccxgkcccxkcccx
kcyCxkkcCCxkcyCx
kcCCxccccccxcCCx
kcCCxcCCCCCxcCCx
kcCCxcCyCyCxcCCx
kcCCxcCCCCCxcCCx
kcCCxcCCooCxcCCx
kcCCxcCCooCxcCCx
kxxxxxxxooxxxxxx
gkkkkkkkddkkkkkg
ggGggggdddgggggg
ggggggddddgggGgg
gggggggddggggggg
"""
T['meadow'] = """
aaaaaaaaaaaaaaaa
aaaaAaaaaaaaaaaa
aaaaaaaaaaaaAaaa
aaaaaaaaaaaaaaaa
aAaaaaaaaaaaaaaa
aaaaaaaaaAaaaaaa
aaaaaaaaaaaaaaaa
aaaaaaaaaaaaaaaA
aaaaaaAaaaaaaaaa
aaaaaaaaaaaaaaaa
aaaaaaaaaaaAaaaa
aaAaaaaaaaaaaaaa
aaaaaaaaaaaaaaaa
aaaaaaaaAaaaaaaa
aaaaaaaaaaaaaAaa
aaaaaaaaaaaaaaaa
"""
T['town'] = """
gggggggggggggggg
ggkkkkgggggggggg
gkrrrrkggkkkkkgg
krrRrrrkkrrrrrkg
kkkkkkkkrrrRrrrk
gkcyCckkkkkkkkkk
gkcCCckgkcCyCckg
gkkkkkkkkcCoCckg
ggggkkkkkkkkkkkg
gggkrrrrkggggggg
ggkrrRrrrkgggGgg
ggkkkkkkkkgggggg
gggkcyoCkggggggg
gggkcCoCkggggggg
gggkkkkkkggggggg
gggggggggggggggg
"""
T['ruin'] = """
gggggggggggggggg
ggggggggggkkgggg
gggkkgggggkckggg
ggkcckggggkCkggg
ggkcCkggggkCkggg
ggkcCkggggkCkggg
ggkcCkgggkkCkkgg
ggkcCkgggkxxxkgg
gkkCCkkggggggggg
gkxxxxkggggkkggg
ggggggggggkcCkgg
gggggkkgggkxxkgg
ggggkcCkgggggggg
ggggkxxkgggGgggg
ggGggggggggggggg
gggggggggggggggg
"""
# ---------------- figures: 16 wide, 24 tall, from a shared template
# K outline · H hair or headgear, h its shade · F skin, f its shade · E eye
# A clothes, a their shade · B belt · L legs · S boots · C cloak, c its shade
FRONT_HEAD = """
................
................
.....KKKKKK.....
....KHHHHHHK....
...KHHHHHHHHK...
...KHHHHHHHHK...
...KHhFFFFhHK...
...KhFEFFEFhK...
...KhFFFFFFhK...
....KfFFFFfK....
....KKffffKK....
"""
FRONT_BODY = """
...KCAAAAAACK...
..KCAAAAAAAACK..
..KFAAaBBaAAFK..
..KFKAAAAAAKFK..
...KKaAAAAaKK...
....KBBBBBBK....
....KLLLLLLK....
....KLLKKLLK....
....KLLKKLLK....
"""
BACK_HEAD = """
................
................
.....KKKKKK.....
....KHHHHHHK....
...KHHHHHHHHK...
...KHHHHHHHHK...
...KHHHHHHHHK...
...KHhHHHHhHK...
...KhHHHHHHhK...
....KhhhhhhK....
....KKhhhhKK....
"""
BACK_BODY = """
...KCCCCCCCCK...
..KCCCCCCCCCCK..
..KFCCcCCcCCFK..
..KFKCCCCCCKFK..
...KKCcCCcCKK...
....KcCCCCcK....
....KLLLLLLK....
....KLLKKLLK....
....KLLKKLLK....
"""
LEGS_A = """
....KSSK.KSSK...
....KSSK.KKKK...
....KKKK........
................
"""
LEGS_B = """
....KSSK.KSSK...
....KKKK.KSSK...
.........KKKK...
................
"""
SIDE_HEAD = """
................
................
.....KKKKKK.....
....KHHHHHHK....
...KHHHHHHHHK...
...KHHHHHHHHK...
...KHHHhFFFK....
...KHHhFFEFK....
...KHHhFFFFK....
....KHhfFFK.....
....KKhffKK.....
"""
SIDE_BODY = """
....KCAAAAK.....
...KCCAAAAAK....
...KCCAFAAAK....
...KCCAFAAAK....
....KCaAAAK.....
....KBBBBBK.....
....KLLLLLK.....
....KLLLLLK.....
"""
SIDE_A = """
...KLLKKLLK.....
...KSSK.KSSK....
...KSSK.KSSK....
...KKKK.KKKK....
................
"""
SIDE_B = """
....KLLLLK......
....KSSSSK......
....KSSSSK......
....KKKKKK......
................
"""
# the mage's pointed hat replaces the top of the head
HAT_FRONT = """
.......KK.......
......KHHK......
.....KHHHHK.....
....KHHHHHHK....
..KKHhhhhhhHKK..
..KhhhhhhhhhhK..
...KKFFFFFFKK...
"""
HAT_SIDE = """
......KK........
.....KHHK.......
....KHHHHK......
...KHHHHHHK.....
.KKHHhhhhhhKK...
.KhhhhhhhhhhK...
..KKHhFFFFKK....
"""
HAT_BACK = """
.......KK.......
......KHHK......
.....KHHHHK.....
....KHHHHHHK....
..KKHhhhhhhHKK..
..KhhhhhhhhhhK..
...KKHHHHHHKK...
"""
# the knight's plume
PLUME = """
.......PP.......
......KPPK......
"""
def lines(t): return [x for x in t.split("\n") if x]
def figure(head, body, legs, top=None):
    r = lines(head) + lines(body) + lines(legs)
    if top:
        t = lines(top)
        r[:len(t)] = t
    return r
CHARS = {
 'knight': dict(K='k', H=(0.62,0.66,0.74), h=(0.40,0.44,0.54), F=(0.90,0.72,0.56), f=(0.72,0.54,0.42), E=(0.10,0.10,0.20),
                A=(0.36,0.44,0.62), a=(0.26,0.32,0.48), B=(0.70,0.58,0.24), L=(0.22,0.24,0.34), S=(0.46,0.48,0.56),
                C=(0.24,0.30,0.50), c=(0.17,0.21,0.38), P=(0.66,0.16,0.16)),
 'mage':   dict(K='k', H=(0.36,0.22,0.48), h=(0.24,0.14,0.34), F=(0.90,0.74,0.60), f=(0.70,0.54,0.44), E=(0.10,0.10,0.20),
                A=(0.44,0.28,0.56), a=(0.32,0.20,0.42), B=(0.74,0.62,0.28), L=(0.40,0.25,0.52), S=(0.26,0.16,0.30),
                C=(0.40,0.25,0.52), c=(0.28,0.17,0.38)),
 'ranger': dict(K='k', H=(0.22,0.36,0.22), h=(0.15,0.26,0.17), F=(0.84,0.66,0.50), f=(0.66,0.50,0.38), E=(0.10,0.10,0.20),
                A=(0.30,0.44,0.27), a=(0.21,0.32,0.20), B=(0.42,0.30,0.18), L=(0.34,0.26,0.18), S=(0.20,0.14,0.10),
                C=(0.24,0.38,0.24), c=(0.17,0.28,0.18)),
}
TOPS = {'knight': (PLUME, PLUME, PLUME), 'mage': (HAT_FRONT, HAT_SIDE, HAT_BACK), 'ranger': (None, None, None)}
F = {}   # name -> (rows, colour map)
for name, cmap in CHARS.items():
    tf, ts, tb = TOPS[name]
    F[name+'DownA'] = figure(FRONT_HEAD, FRONT_BODY, LEGS_A, tf)
    F[name+'DownB'] = figure(FRONT_HEAD, FRONT_BODY, LEGS_B, tf)
    F[name+'SideA'] = figure(SIDE_HEAD, SIDE_BODY, SIDE_A, ts)
    F[name+'SideB'] = figure(SIDE_HEAD, SIDE_BODY, SIDE_B, ts)
    F[name+'UpA'] = figure(BACK_HEAD, BACK_BODY, LEGS_A, tb)
    F[name+'UpB'] = figure(BACK_HEAD, BACK_BODY, LEGS_B, tb)
bad = False
TT = {}
for k,v in T.items():
    r = lines(v); TT[k] = r
    if len(r)!=16 or any(len(x)!=16 for x in r): print("BAD tile",k,len(r),[(i,len(x)) for i,x in enumerate(r) if len(x)!=16]); bad=True
    for x in r:
        for ch in x: assert ch in PAL,(k,ch)
for k,r in F.items():
    if len(r)!=24 or any(len(x)!=16 for x in r): print("BAD fig",k,len(r),[(i,len(x)) for i,x in enumerate(r) if len(x)!=16]); bad=True
if bad: raise SystemExit(1)
def colour(ch, cmap=None):
    if ch == '.': return None
    if cmap:
        v = cmap[ch]
        return PAL[v] if isinstance(v,str) else v
    return PAL[ch]
S=6
img = Image.new("RGB",(16*S*len(TT), 16*S + 10 + 24*S*3 + 20),(48,74,42))
def paint(r,ox,oy,cmap=None):
    for y,row in enumerate(r):
        for x,ch in enumerate(row):
            c = colour(ch,cmap)
            if c is None: continue
            for dy in range(S):
                for dx in range(S): img.putpixel((ox+x*S+dx,oy+y*S+dy),tuple(int(v*255) for v in c))
for i,(k,r) in enumerate(TT.items()): paint(r,i*16*S,0)
for j,name in enumerate(CHARS):
    for i,view in enumerate(['DownA','DownB','SideA','SideB','UpA','UpB']):
        paint(F[name+view], i*18*S, 16*S+10 + j*(24*S+5), CHARS[name])
img.save("art2.png")
# a 3x3 field of forest and mountain to check that they tile
tile = Image.new("RGB",(16*4*6+10,16*4*3),(0,0,0))
def small(r,ox,oy,s=4):
    for y,row in enumerate(r):
        for x,ch in enumerate(row):
            c=PAL[ch]
            for dy in range(s):
                for dx in range(s): tile.putpixel((ox+x*s+dx,oy+y*s+dy),tuple(int(v*255) for v in c))
for a in range(3):
    for b in range(3):
        small(TT['forest'],a*64,b*64); small(TT['mountain'],202+a*64,b*64)
tile.save("tiling.png")
# Swift
def sw(r): return "[\n" + "".join(f'            "{x}",\n' for x in r) + "        ]"
out = "// Pixel art for the Pixel Quest theme: one letter a pixel.\n// Change the pictures here by hand.\nimport CoreGraphics\n\nenum PixelArt {\n"
out += "    typealias Colour = (CGFloat, CGFloat, CGFloat)\n\n    /// The colour each letter of a ground tile stands for.\n    static let palette: [Character: Colour] = [\n"
for k,v in PAL.items():
    if v: out += f'        "{k}": ({v[0]:.2f}, {v[1]:.2f}, {v[2]:.2f}),\n'
out += "    ]\n\n    /// Ground tiles, 16 × 16, in the order the shader numbers them.\n    static let tiles: [[String]] = [\n"
for k,r in TT.items(): out += f"        // {k}\n        " + sw(r) + ",\n"
out += "    ]\n\n    /// The party, in marching order. Each wears its own colours: the letters\n    /// of a figure are parts of its dress (K outline · H hair or headgear, h its\n    /// shade · F skin, f its shade · E eye · A clothes, a their shade · B belt\n    /// L legs · S boots · C cloak, c its shade · P plume).\n    static let party = [" + ", ".join(f'"{n}"' for n in CHARS) + "]\n\n    static let dress: [String: [Character: Colour]] = [\n"
for n,cmap in CHARS.items():
    out += f'        "{n}": [' + ", ".join(f'"{k}": ({(PAL[v] if isinstance(v,str) else v)[0]:.2f}, {(PAL[v] if isinstance(v,str) else v)[1]:.2f}, {(PAL[v] if isinstance(v,str) else v)[2]:.2f})' for k,v in cmap.items()) + "],\n"
out += "    ]\n\n    /// The views of a figure, in the order of its cells in the sprite sheet:\n    /// toward us, to the right and away from us, two steps of each.\n    static let views = [\"DownA\", \"DownB\", \"SideA\", \"SideB\", \"UpA\", \"UpB\"]\n\n    /// Figures, 16 wide and 24 tall, by name and view.\n    static let figures: [String: [String]] = [\n"
for k,r in F.items(): out += f'        "{k}": ' + sw(r) + ",\n"
out += "    ]\n"
open("PixelArtData2.txt","w").write(out)
print("ok")
