# The three wanderers as cut from the generated sheet (see ../gen/cut.py): 32 x 48 pixels,
# nine pictures each, a palette of 48 colours for each character.
import numpy as np, os
G = os.path.dirname(os.path.abspath(__file__))
LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
sprites = np.load(os.path.join(G, "sprites.npy")); palettes = np.load(os.path.join(G, "palettes.npy"))
PARTY = {}
for name, frames, pal in zip(["swordsman", "sorceress", "archer"], sprites, palettes):
    colours = {LETTERS[i]: tuple(float(v) for v in c) for i, c in enumerate(pal)}
    grids = [["".join("." if v < 0 else LETTERS[v] for v in row) for row in f] for f in frames]
    PARTY[name] = (colours, grids[0:3], grids[3:6], grids[6:9])
def frames(view): return view
def check(): return True
