from PIL import Image
import importlib, chars_ai as chars, art2
PAL = dict(art2.PAL)
PAL.update({'q': (0.80,0.74,0.60), 'Q': (0.60,0.53,0.43), 'u': (0.32,0.38,0.52), 'U': (0.20,0.24,0.37), 'V': (0.46,0.54,0.68),
            'E': (0.68,0.52,0.24), 'F': (0.48,0.35,0.17), 'h': (0.74,0.74,0.78), 'b': (0.16,0.22,0.16),
            'j': (0.78,0.74,0.63), 'J': (0.61,0.57,0.49), 'z': (0.40,0.37,0.33), 'Z': (0.25,0.23,0.22),
            'O': (0.90,0.84,0.68), 'P': (0.34,0.22,0.14), '1': (0.74,0.30,0.24), '3': (0.82,0.66,0.34),
            '4': (0.95,0.55,0.15), '5': (1.00,0.85,0.35)})
TERRAIN = ['grassA','grassB','scrub','forest','mountain','water','meadow']
T = {k: art2.TT[k] for k in TERRAIN}

# ---------------- landmarks, 32 x 32, built from simple shapes ('.' shows the land beneath)
def blank(): return [['.']*32 for _ in range(32)]
def put(g,x,y,c):
    if 0<=x<32 and 0<=y<32: g[y][x]=c
def wall(g,x0,y0,x1,y1,base='C',light='c',dark='x',line='k',bricks=True):
    for y in range(y0,y1+1):
        for x in range(x0,x1+1):
            c = base
            if x==x0+1: c = light
            if x>=x1-1: c = dark
            if bricks and y%3==0 and (x + (y//3)%2*2)%4==0 and x0+1<x<x1-1: c = dark
            if x in (x0,x1) or y in (y0,y1): c = line
            put(g,x,y,c)
def crenels(g,x0,x1,y,light='c',line='k'):
    for x in range(x0,x1+1):
        if (x-x0)%3!=2:
            put(g,x,y,line); put(g,x,y+1,light if (x-x0)%3==0 else 'C')
    for x in range(x0,x1+1): put(g,x,y+2,line) if g[y+2][x]=='.' else None
def cone(g,cx0,cx1,ytop,ybase,base='u',light='V',dark='U',line='k'):
    h = ybase-ytop
    for y in range(ytop,ybase+1):
        k = (y-ytop)/max(h,1)
        half = (cx1-cx0)/2*k
        mid = (cx0+cx1)/2
        a, b = int(round(mid-half-0.5)), int(round(mid+half+0.5))
        for x in range(a,b+1):
            c = base
            if x<=a+ max(1,int((b-a)*0.3)): c = light
            if x>=b- max(1,int((b-a)*0.3)): c = dark
            if x in (a,b) or y==ybase: c = line
            put(g,x,y,c)
def castle():
    g = blank()
    wall(g,9,9,22,26)                      # the keep
    crenels(g,9,22,7)
    wall(g,13,3,18,10)                     # its tower
    cone(g,12,19,-3,3)
    for x,y in [(15,6),(16,6),(15,7),(16,7)]: put(g,x,y,'y')
    for x in (11,12,19,20):
        for y in (13,14,15): put(g,x,y,'y')
    for side in (0,1):                     # corner towers with slate roofs
        x0 = 1 if side==0 else 23
        wall(g,x0,12,x0+7,28)
        cone(g,x0-1,x0+8,4,12)
        for y in (16,17,18): put(g,x0+3,y,'y'); put(g,x0+4,y,'y')
    wall(g,6,19,25,29)                     # the curtain wall in front
    crenels(g,6,25,17)
    for y in range(22,30):                 # the gate
        for x in range(13,19):
            arch = (y==22 and x in (13,18))
            if not arch: put(g,x,y,'o' if (x+y)%2 else 'k')
    for x in range(12,20): put(g,x,21,'k')
    for y in range(22,30): put(g,12,y,'k'); put(g,19,y,'k')
    put(g,15,-0,'r')
    for x in range(1,31): put(g,x,30,'b') if g[29][x]!='.' or g[28][x]!='.' else None
    for y in range(0,3):                   # banner on the spire
        put(g,16,y,'k')
    put(g,17,0,'r'); put(g,18,0,'r'); put(g,17,1,'R')
    return ["".join(r) for r in g]
def rnd(x,y,k=0):
    v = (x*374761393 + y*668265263 + k*2147483647) & 0xffffffff
    v = (v ^ (v >> 13)) * 1274126177 & 0xffffffff
    return ((v ^ (v >> 16)) & 0xffff) / 65535.0
def roof(g, x0, y0, w, rh, base, dark, light):
    """A tiled roof seen from a little above: hipped at the top corners, lit on the left."""
    for y in range(rh):
        inset = 2 if y == 0 else (1 if y == 1 else 0)
        a, b = x0 + inset, x0 + w - 1 - inset
        for x in range(a, b + 1):
            c = base
            if x - a < 2: c = light
            if b - x < 2: c = dark
            if y % 2 == 1 and (x + y // 2) % 3 == 0 and c == base: c = dark       # courses of tiles
            if y == rh - 1: c = dark                                              # the eave, in shade
            if x in (a, b) or y == 0: c = 'k'
            put(g, x, y0 + y, c)
def cottage(g, x0, y0, w, h, colours, chimney=None, door=None, smoke=False):
    """A timber-framed house: a deep tiled roof, a plastered wall with corner posts, a door, two windows."""
    base, dark, light = colours
    rh = h // 2
    for y in range(rh - 1, h):                                                    # the wall
        for x in range(x0 + 1, x0 + w - 1):
            c = 'O' if x < x0 + w - 4 else 'q'
            if y == rh - 1 or y == rh: c = 'Q'                                    # in the shade of the eave
            if x in (x0 + 1, x0 + w - 2) or y == h - 1: c = 'k'
            put(g, x, y0 + y, c)
    for y in range(rh, h - 1): put(g, x0 + 2, y0 + y, 'P'); put(g, x0 + w - 3, y0 + y, 'P')   # corner posts
    d = door if door is not None else x0 + w // 2
    for y in range(h - 5, h - 1):
        put(g, d - 1, y0 + y, 'P'); put(g, d, y0 + y, 'o'); put(g, d + 1, y0 + y, 'o'); put(g, d + 2, y0 + y, 'P')
    put(g, d, y0 + h - 5, 'P'); put(g, d + 1, y0 + h - 5, 'P')
    for wx in (x0 + 4, x0 + w - 6):
        if wx + 1 < d - 1 or wx > d + 2:
            for (dx, dy, c) in [(0, 0, 'y'), (1, 0, 'y'), (0, 1, 'y'), (1, 1, 'k'), (0, 2, 'P'), (1, 2, 'P')]: put(g, wx + dx, y0 + rh + 1 + dy, c)
    roof(g, x0, y0, w, rh, base, dark, light)
    if chimney is not None:
        for (dx, dy, c) in [(0, -2, 'k'), (1, -2, 'k'), (0, -1, 'c'), (1, -1, 'x'), (0, 0, 'C'), (1, 0, 'x')]: put(g, chimney + dx, y0 + dy, c)
        if smoke:
            for (dx, dy, c) in [(0, -4, 'h'), (1, -5, 'h'), (1, -6, 'c'), (2, -7, 'h')]: put(g, chimney + dx, y0 + dy, c)
    for x in range(x0 + 1, x0 + w - 1): put(g, x, y0 + h, 'b')                     # its shadow on the ground
def bush(g, cx, cy):
    for (dx, dy, c) in [(-1,-3,'k'),(0,-3,'k'),(1,-3,'k'),(-2,-2,'k'),(-1,-2,'i'),(0,-2,'i'),(1,-2,'L'),(2,-2,'k'),
                        (-3,-1,'k'),(-2,-1,'i'),(-1,-1,'L'),(0,-1,'L'),(1,-1,'L'),(2,-1,'T'),(3,-1,'k'),
                        (-3,0,'k'),(-2,0,'L'),(-1,0,'L'),(0,0,'T'),(1,0,'T'),(2,0,'t'),(3,0,'k'),
                        (-2,1,'k'),(-1,1,'T'),(0,1,'T'),(1,1,'t'),(2,1,'k'),(-1,2,'k'),(0,2,'o'),(1,2,'k'),(0,3,'o')]:
        put(g, cx + dx, cy + dy, c)
def church(g, x0, y0, w=10, h=12):
    """A small stone church: a gabled slate roof, a low bell-cote on the ridge, arched windows."""
    wall(g, x0 + 1, y0 + 5, x0 + w - 2, y0 + h, bricks=True)
    roof(g, x0, y0 + 3, w, 4, 'u', 'U', 'V')
    cx = x0 + w // 2
    for (dx, dy, c) in [(-2, 0, 'k'), (-1, 0, 'k'), (0, 0, 'k'), (1, 0, 'k'), (-2, 1, 'k'), (-1, 1, 'V'), (0, 1, 'U'), (1, 1, 'k'),
                        (-2, 2, 'k'), (-1, 2, 'c'), (0, 2, 'y'), (1, 2, 'k'), (-2, 3, 'k'), (-1, 3, 'c'), (0, 3, 'C'), (1, 3, 'k')]:
        put(g, cx + dx, y0 + dy, c)
    for wx in (x0 + 2, x0 + w - 4):
        put(g, wx, y0 + 8, 'y'); put(g, wx, y0 + 9, 'y')
    for y in range(y0 + h - 3, y0 + h): put(g, cx - 1, y, 'o'); put(g, cx, y, 'o')
    for x in range(x0 + 1, x0 + w - 1): put(g, x, y0 + h + 1, 'b')
def town():
    g = blank()
    RED, SLATE, OCHRE = ('r', 'R', '1'), ('u', 'U', 'V'), ('E', 'F', '3')
    church(g, 11, 2, 10, 14)
    cottage(g, 0, 8, 12, 13, RED, chimney=2, door=3, smoke=True)
    cottage(g, 20, 7, 12, 13, OCHRE, chimney=28, door=27)
    cottage(g, 8, 17, 16, 13, SLATE, chimney=19, door=15)
    bush(g, 3, 26); bush(g, 28, 25)
    for (x, y) in [(15, 30), (16, 30), (17, 30), (15, 31), (16, 31), (14, 31)]: put(g, x, y, 'd' if (x + y) % 2 else 'D')
    return ["".join(r) for r in g]
def farm():
    """A windmill, a barn, and a fenced field of ripe wheat."""
    g = blank()
    # the field, in furrows, with a fence along the top and side
    for y in range(18, 30):
        for x in range(16, 31):
            put(g, x, y, '3' if y % 2 == 0 else ('E' if (x + y) % 5 else 'F'))
    for x in range(15, 32):
        put(g, x, 17, 'P' if x % 3 == 0 else 'k')
        if x % 3 == 0: put(g, x, 16, 'P')
    for y in range(17, 31): put(g, 15, y, 'P' if y % 3 == 0 else 'k'); put(g, 31, y, 'P' if y % 3 == 0 else 'k')
    for x in range(15, 32): put(g, x, 30, 'k')
    # the barn
    cottage(g, 0, 15, 14, 14, ('r', 'R', '1'), door=6)
    # the windmill: a tapering stone tower, a dark cap, four sails
    cx = 22
    for y in range(6, 17):
        half = 2 + (y - 6) // 4
        for x in range(cx - half, cx + half + 1):
            c = 'c' if x < cx else ('C' if x < cx + half - 0 else 'x')
            if x == cx + half: c = 'x'
            if x in (cx - half - 0, cx + half) and False: c = 'k'
            put(g, x, y, c)
        put(g, cx - half - 1, y, 'k'); put(g, cx + half + 1, y, 'k')
    for x in range(cx - 3, cx + 4): put(g, x, 5, 'F' if abs(x - cx) < 3 else 'k'); put(g, x, 4, 'k' if abs(x - cx) > 1 else 'F')
    put(g, cx - 1, 3, 'k'); put(g, cx, 3, 'k'); put(g, cx + 1, 3, 'k')
    put(g, cx, 10, 'y'); put(g, cx, 11, 'y'); put(g, cx, 14, 'o'); put(g, cx, 15, 'o'); put(g, cx, 16, 'o')
    for k in range(1, 9):
        for (sx, sy) in [(1, 1), (-1, 1), (1, -1), (-1, -1)]:
            x, y = cx + sx * k, 7 + sy * k
            put(g, x, y, 'P')
            if k > 2: put(g, x + sx * 0 + (1 if sy > 0 else -1) * sx * 0, y - sy, 'O'); put(g, x - sx, y, 'q')
    put(g, cx, 7, 'k')
    return ["".join(r) for r in g]
def tent(g, cx, y0, hw, h, cloth, shade):
    for y in range(h):
        half = int(round(hw * (y + 1) / h))
        for x in range(cx - half, cx + half + 1):
            c = cloth if x <= cx else shade
            if x in (cx - half, cx + half) or y == h - 1: c = 'k'
            put(g, x, y0 + y, c)
    for y in range(h - 4, h - 1):
        for x in range(cx - (y - (h - 5)) // 1 + 0, cx + (y - (h - 5)) + 1): put(g, x, y0 + y, 'o')
    put(g, cx, y0 - 1, 'k'); put(g, cx, y0 - 2, 'P')
    for x in range(cx - hw, cx + hw + 1): put(g, x, y0 + h, 'b')
def camp():
    """Travellers' tents round a fire, a banner on a pole."""
    g = blank()
    tent(g, 8, 5, 6, 11, 'O', 'Q')
    tent(g, 23, 7, 6, 10, '3', 'E')
    tent(g, 15, 17, 7, 12, 'q', 'Q')
    # the banner
    for y in range(1, 9): put(g, 16, y, 'P')
    for (x, y, c) in [(17, 1, 'r'), (18, 1, 'r'), (19, 1, 'r'), (17, 2, 'r'), (18, 2, 'R'), (19, 2, 'R'), (17, 3, 'R'), (18, 3, 'R')]: put(g, x, y, c)
    # the fire, in a ring of stones; its flames show as light after dark
    for (x, y, c) in [(26, 22, '5'), (26, 23, '4'), (27, 23, '5'), (25, 24, '4'), (26, 24, '5'), (27, 24, '4'), (25, 25, '4'), (26, 25, '4'), (27, 25, '4'),
                      (24, 26, 'C'), (25, 26, 'x'), (26, 26, 'C'), (27, 26, 'x'), (28, 26, 'C'), (24, 25, 'k'), (28, 25, 'k'), (25, 27, 'k'), (26, 27, 'k'), (27, 27, 'k')]:
        put(g, x, y, c)
    # packs and a log to sit on
    for (x, y, c) in [(3, 22, 'k'), (4, 22, 'k'), (5, 22, 'k'), (2, 23, 'k'), (3, 23, 'P'), (4, 23, 'E'), (5, 23, 'P'), (6, 23, 'k'), (3, 24, 'k'), (4, 24, 'k'), (5, 24, 'k'),
                      (22, 29, 'k'), (23, 29, 'P'), (24, 29, 'P'), (25, 29, 'P'), (26, 29, 'P'), (27, 29, 'k'), (23, 30, 'k'), (24, 30, 'k'), (25, 30, 'k'), (26, 30, 'k')]:
        put(g, x, y, c)
    return ["".join(r) for r in g]
def abbey():
    """A walled abbey: a church within a square of stone wall, cypresses in its garden."""
    g = blank()
    for x in range(2, 30):                                   # the back wall
        put(g, x, 5, 'k'); put(g, x, 6, 'c' if x % 4 else 'C'); put(g, x, 7, 'x'); put(g, x, 8, 'k')
    for y in range(6, 27):                                   # the side walls
        for (x, c) in [(1, 'k'), (2, 'c'), (3, 'x'), (4, 'k'), (27, 'k'), (28, 'c'), (29, 'x'), (30, 'k')]: put(g, x, y, c)
    for y in range(9, 26):                                   # the garden
        for x in range(5, 27): put(g, x, y, 'l' if rnd(x, y, 2) > 0.8 else 'g')
    church(g, 9, 6, 14, 17)
    for cx in (6, 25):                                       # cypresses
        for y in range(12, 22):
            put(g, cx, y, 'T' if y % 2 else 'L'); put(g, cx + 1, y, 't')
            put(g, cx - 1, y, 'k'); put(g, cx + 2, y, 'k')
        put(g, cx, 11, 'k'); put(g, cx + 1, 11, 'k'); put(g, cx, 22, 'o'); put(g, cx + 1, 22, 'k')
    wall(g, 1, 25, 30, 30, bricks=True)                      # the front wall and its gate
    for y in range(26, 31):
        for x in range(14, 18): put(g, x, y, 'o' if y > 26 or x in (15, 16) else 'k')
    for x in range(13, 19): put(g, x, 25, 'k')
    return ["".join(r) for r in g]
def haystack(g, cx, cy):
    for (dx, dy, c) in [(-1, -3, 'k'), (0, -3, 'k'), (1, -3, 'k'), (-2, -2, 'k'), (-1, -2, '3'), (0, -2, '3'), (1, -2, 'E'), (2, -2, 'k'),
                        (-3, -1, 'k'), (-2, -1, '3'), (-1, -1, '3'), (0, -1, 'E'), (1, -1, 'E'), (2, -1, 'F'), (3, -1, 'k'),
                        (-3, 0, 'k'), (-2, 0, '3'), (-1, 0, 'E'), (0, 0, 'E'), (1, 0, 'F'), (2, 0, 'F'), (3, 0, 'k'),
                        (-3, 1, 'k'), (-2, 1, 'k'), (-1, 1, 'k'), (0, 1, 'k'), (1, 1, 'k'), (2, 1, 'k'), (3, 1, 'k')]:
        put(g, cx + dx, cy + dy, c)
def hamlet():
    """Two thatched cottages, a well between them, haystacks and a tree."""
    g = blank()
    THATCH = ('E', 'F', '3')
    cottage(g, 1, 3, 13, 13, THATCH, chimney=4, door=9, smoke=True)
    cottage(g, 17, 13, 14, 14, THATCH, chimney=26, door=22)
    for (x, y, c) in [(8, 21, 'k'), (9, 21, 'k'), (10, 21, 'k'), (7, 22, 'k'), (8, 22, 'c'), (9, 22, 'C'), (10, 22, 'x'), (11, 22, 'k'),
                      (7, 23, 'k'), (8, 23, 'y'), (9, 23, 'y'), (10, 23, 'y'), (11, 23, 'k'), (7, 24, 'k'), (8, 24, 'C'), (9, 24, 'x'), (10, 24, 'x'), (11, 24, 'k'),
                      (8, 25, 'k'), (9, 25, 'k'), (10, 25, 'k'), (9, 19, 'P'), (9, 20, 'P'), (8, 19, 'P'), (10, 19, 'P')]:
        put(g, x, y, c)
    haystack(g, 4, 28); haystack(g, 12, 29)
    bush(g, 22, 6)
    return ["".join(r) for r in g]
def stone(g,x0,y0,x1,y1,tops=None):
    """A block of weathered masonry: pale on the left, shaded on the right, courses of blocks."""
    for x in range(x0,x1+1):
        top = y0 + (tops[x-x0] if tops else 0)
        for y in range(top,y1+1):
            c = 'J'
            if x<=x0+1: c = 'j'
            if x>=x1-1: c = 'z'
            if (y-y1)%4==0 or ((x + ((y1-y)//4)%2*3)%6==0): c = 'z' if c!='j' else 'J'
            if rnd(x,y)>0.90: c = 'j'
            if x in (x0,x1) or y==y1 or y==top: c = 'Z'
            put(g,x,y,c)
        if rnd(x,top,3)>0.55: put(g,x,top,'L')                   # moss along the broken top
def column(g,x,y0,y1,broken=False):
    for y in range(y0,y1+1):
        for i,c in enumerate(['Z','j','J','J','z','Z']): put(g,x+i,y,c)
        if (y-y0)%5==4:
            for i in range(1,5): put(g,x+i,y,'z')              # the joints between its drums
    if not broken:
        for i in range(-1,7): put(g,x+i,y0-1,'j' if 0<=i<4 else 'Z'); put(g,x+i,y0-2,'Z')
    else:
        put(g,x+1,y0,'.'); put(g,x+2,y0,'Z'); put(g,x+4,y0,'.'); put(g,x+5,y0,'.'); put(g,x+4,y0+1,'Z'); put(g,x,y0,'.'); put(g,x,y0+1,'Z')
    for i in range(-1,7): put(g,x+i,y1+1,'J' if 0<=i<5 else 'Z'); put(g,x+i,y1+2,'Z')
def ruin():
    g = blank()
    # what is left of the paved floor
    for y in range(21,30):
        for x in range(2,30):
            dx, dy = (x-15.5)/14.5, (y-25)/4.6
            if dx*dx+dy*dy < 1 and rnd(x//2,y//2,5) > 0.22:
                put(g,x,y,'z' if (x%5==0 or y%3==0) else ('J' if rnd(x,y,7)>0.3 else 'j'))
    # the back wall, its top broken away, with a doorway whose arch still stands
    stone(g,2,7,14,22,tops=[6,4,3,0,0,1,1,0,0,2,5,8,10])
    for y in range(13,23):
        for x in range(6,10):
            if not (y==13 and x in (6,9)): put(g,x,y,'Z' if y<15 else 'k')
    for x in range(5,11): put(g,x,12,'j' if x not in (5,10) else 'Z')
    # two columns still upright, one whole and one snapped, and one fallen
    column(g,17,6,22)
    column(g,24,14,23,broken=True)
    for x in range(13,24):
        put(g,x,26,'Z'); put(g,x,27,'j'); put(g,x,28,'J'); put(g,x,29,'Z')
        if (x-13)%4==3: put(g,x,27,'z'); put(g,x,28,'z')
    put(g,12,27,'Z'); put(g,12,28,'Z'); put(g,24,27,'Z'); put(g,24,28,'Z')
    # ivy down the wall, rubble about
    for (x,y0,n) in [(3,9,7),(12,13,6),(13,16,4)]:
        for i in range(n): put(g,x+(i%3==1),y0+i,'L' if i%2 else 'i')
    for x,y in [(27,27),(4,27),(9,29),(28,21),(1,24)]: put(g,x,y,'J'); put(g,x+1,y,'z'); put(g,x,y+1,'Z'); put(g,x+1,y+1,'Z')
    return ["".join(r) for r in g]
LAND = {'castle': castle(), 'town': town(), 'ruin': ruin(), 'farm': farm(), 'camp': camp(), 'abbey': abbey(), 'hamlet': hamlet()}

# ---------------- other figures, 16 x 16
SHIP = dict(k=(0.13,0.09,0.09), H=(0.52,0.33,0.18), h=(0.34,0.20,0.12), W=(0.93,0.91,0.83), w=(0.70,0.69,0.66), r=(0.60,0.14,0.14))
EAGLE = dict(k=(0.10,0.07,0.06), B=(0.38,0.25,0.16), b=(0.25,0.16,0.10), W=(0.95,0.95,0.92))
def L(t): return [x for x in t.split("\n") if x]
OTHER = {
 'ship': (SHIP, L("""
.......kr.......
.......krr......
......kWk.......
.....kWWWk......
....kWWWWk.k....
...kWWWWWkkWk...
...kWWwWWkWWk...
..kWWWwWWkWWWk..
..kwwwwwwkWwwk..
.....k...k......
kkkkkkkkkkkkkkk.
.kHHHHHHHHHHHhk.
.kHhHhHhHhHhhk..
..khhhhhhhhhk...
...kkkkkkkkk....
................
""")),
 'eagleA': (EAGLE, L("""
................
.......kk.......
......kWWk......
......kWWk......
.k...kBBBBk...k.
kBkkkBBBBBBkkkBk
kBBBBBBbbBBBBBBk
kBbBBBBbbBBBBbBk
.kBbBBBBBBBBbBk.
..kkbBBBBBBbkk..
....kkBBBBkk....
......kBBk......
.....kBbbBk.....
.....kbkkbk.....
......k..k......
................
""")),
 'eagleB': (EAGLE, L("""
................
.......kk.......
......kWWk......
......kWWk......
.....kBBBBk.....
...kkBBBBBBkk...
..kBBBBbbBBBBk..
.kBBbBBbbBBbBBk.
.kBbkBBBBBBkbBk.
.kbk.kBBBBk.kbk.
..k..kBBBBk..k..
......kBBk......
.....kBbbBk.....
.....kbkkbk.....
......k..k......
................
""")),
}
ok = chars.check()
for k,r in T.items():
    assert len(r)==16 and all(len(x)==16 for x in r), k
for k,r in LAND.items():
    assert len(r)==32 and all(len(x)==32 for x in r), k
    for x in r:
        for ch in x: assert ch=='.' or ch in PAL, (k,ch)
for k,(pal,r) in OTHER.items():
    if len(r)!=16 or any(len(x)!=16 for x in r): print("BAD",k,[(i,len(x)) for i,x in enumerate(r) if len(x)!=16]); ok=False
    for x in r:
        for ch in x: assert ch=='.' or ch in pal,(k,ch)
if not ok: raise SystemExit(1)
S=6
img=Image.new("RGB",(32*S*7+16*S*3+60, 32*S),(76,117,66))
def paint(r,ox,oy,pal):
    for y,row in enumerate(r):
        for x,ch in enumerate(row):
            if ch=='.': continue
            c=tuple(int(v*255) for v in pal[ch])
            for dy in range(S):
                for dx in range(S): img.putpixel((ox+x*S+dx,oy+y*S+dy),c)
for i,(k,r) in enumerate(LAND.items()): paint(r,i*(32*S+5),0,PAL)
for i,(k,(pal,r)) in enumerate(OTHER.items()): paint(r,7*(32*S+5)+i*(16*S+5),0,pal)
img.save("art3.png")

def sw(r,ind="            "): return "[\n" + "".join(f'{ind}"{x}",\n' for x in r) + ind[:-4] + "]"
def col(v): return f"({v[0]:.2f}, {v[1]:.2f}, {v[2]:.2f})"
o = "// Pixel art for the Pixel Quest theme: one letter a pixel, a full stop for\n// nothing. Generated by tools/pixelart/regenerate.sh; change the art there, not here.\nimport CoreGraphics\n\nenum PixelArt {\n    typealias Colour = (CGFloat, CGFloat, CGFloat)\n\n"
o += "    /// The colour each letter of the land and its landmarks stands for.\n    static let palette: [Character: Colour] = [\n" + "".join(f'        "{k}": {col(v)},\n' for k,v in PAL.items() if v) + "    ]\n\n"
o += "    /// The land, 16 × 16 each, every one of which repeats without a seam:\n    /// " + ", ".join(TERRAIN) + ".\n    static let terrain: [[String]] = [\n" + "".join(f"        // {k}\n        " + sw(r) + ",\n" for k,r in T.items()) + "    ]\n\n"
o += "    /// Landmarks, 32 × 32 each, standing on two tiles by two: " + ", ".join(LAND) + ".\n    static let landmarks: [[String]] = [\n" + "".join(f"        // {k}\n        " + sw(r) + ",\n" for k,r in LAND.items()) + "    ]\n\n"
o += "    /// A figure: the colours of its letters, and its pictures.\n    struct Figure {\n        var colours: [Character: Colour]\n        var frames: [[String]]\n    }\n\n"
o += "    /// The three wanderers. Each is 32 pixels wide and 48 tall, in pixels half\n    /// the size of the land's, so a figure is one tile wide and one and a half\n    /// tall. They were cut from a generated sprite sheet. Each and has\n    /// nine pictures: walking toward us, to the right, and away from us; for\n    /// each, a step with one foot forward, the moment the feet pass (a pixel\n    /// taller), and a step with the other foot.\n    static let party: [Figure] = [\n"
for name,(pal,front,side,back) in chars.PARTY.items():
    o += f"        // {name}\n        Figure(colours: [" + ", ".join(f'"{k}": {col(v)}' for k,v in pal.items()) + "], frames: [\n"
    for view in (front,side,back):
        for fr in chars.frames(view): o += "            " + sw(fr,"                ") + ",\n"
    o += "        ]),\n"
o += "    ]\n\n    /// Others on the map, 16 × 16: a ship under sail, an eagle with wings out and in.\n    static let others: [Figure] = [\n"
for k,(pal,r) in OTHER.items():
    o += f"        // {k}\n        Figure(colours: [" + ", ".join(f'"{kk}": {col(v)}' for kk,v in pal.items()) + "], frames: [\n            " + sw(r,"                ") + ",\n        ]),\n"
o += "    ]\n"
open("PixelArtData3.txt","w").write(o); print("ok")
