# Cuts the generated sheet into 27 sprites of 32 x 48 pixels (half the size of the map's own
# pixels, so a figure is still one tile wide and one and a half tall), each character on its
# own small palette, feet on a common line.
from PIL import Image
import numpy as np
SRC = "characters-source.png"; COLS, ROWS = 9, 3; W, H = 32, 48; COLOURS = 48
im = np.asarray(Image.open(SRC).convert("RGB")).astype(float) / 255
# how far each pixel is from the magenta ground
key = np.array([1.0, 0.0, 1.0])
dist = np.sqrt(((im - key) ** 2).sum(axis=2))
alpha = np.clip((dist - 0.25) / 0.25, 0, 1)
# also call anything strongly magenta-hued transparent (the fringe)
mag = (im[..., 0] > 0.6) & (im[..., 2] > 0.6) & (im[..., 1] < 0.35)
alpha[mag] = 0
# pull the edge in by a pixel, so no ground-coloured fringe survives the reduction
from PIL import ImageFilter
alpha = np.asarray(Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3))).astype(float) / 255
ch, cw = im.shape[0] / ROWS, im.shape[1] / COLS
boxes = []
for r in range(ROWS):
    for c in range(COLS):
        y0, y1, x0, x1 = int(r * ch), int((r + 1) * ch), int(c * cw), int((c + 1) * cw)
        a = alpha[y0:y1, x0:x1]
        ys, xs = np.where(a > 0.5)
        boxes.append((x0 + xs.min(), y0 + ys.min(), x0 + xs.max() + 1, y0 + ys.max() + 1))
tall = max(b[3] - b[1] for b in boxes)
scale = (H - 2) / tall
print("tallest", tall, "scale", round(scale, 3), "widths", sorted(set(int((b[2]-b[0])*scale) for b in boxes)))
rgba = np.dstack([im * alpha[..., None], alpha])          # premultiplied, so the ground does not bleed in
sprites = []
for i, (x0, y0, x1, y1) in enumerate(boxes):
    piece = Image.fromarray((rgba[y0:y1, x0:x1] * 255).astype(np.uint8), "RGBA")
    w, h = max(1, round((x1 - x0) * scale)), max(1, round((y1 - y0) * scale))
    small = np.asarray(piece.resize((w, h), Image.BOX)).astype(float) / 255
    a = small[..., 3]
    rgb = np.where(a[..., None] > 0.01, small[..., :3] / np.maximum(a[..., None], 0.01), 0)
    solid = a > 0.5
    # stand it on the line: feet at the bottom, the middle of its legs on the centre
    rows = np.where(solid.any(axis=1))[0]; low = solid[int(h * 0.75):]
    xs = np.where(low.any(axis=0))[0]; centre = (xs.min() + xs.max() + 1) / 2 if len(xs) else w / 2
    canvas = np.zeros((H, W, 4))
    ox, oy = int(round(W / 2 - centre)), (H - 1) - (rows.max() + 1)
    for y in range(h):
        for x in range(w):
            if solid[y, x] and 0 <= x + ox < W and 0 <= y + oy < H:
                canvas[y + oy, x + ox, :3] = rgb[y, x]; canvas[y + oy, x + ox, 3] = 1
    # drop stray specks: anything not joined to the figure itself
    filled = canvas[..., 3] > 0; seen = np.zeros_like(filled); best = []
    for sy in range(H):
        for sx in range(W):
            if filled[sy, sx] and not seen[sy, sx]:
                stack = [(sy, sx)]; seen[sy, sx] = True; comp = []
                while stack:
                    cy, cx = stack.pop(); comp.append((cy, cx))
                    for ny, nx in ((cy+1,cx),(cy-1,cx),(cy,cx+1),(cy,cx-1),(cy+1,cx+1),(cy-1,cx-1),(cy+1,cx-1),(cy-1,cx+1)):
                        if 0 <= ny < H and 0 <= nx < W and filled[ny, nx] and not seen[ny, nx]: seen[ny, nx] = True; stack.append((ny, nx))
                if len(comp) > len(best): best = comp
    keep = np.zeros_like(filled)
    for cy, cx in best: keep[cy, cx] = True
    canvas[~keep] = 0
    sprites.append(canvas)
# one palette for each character, from all nine of its pictures
out = []
for r in range(ROWS):
    group = sprites[r * COLS:(r + 1) * COLS]
    pixels = np.concatenate([s[s[..., 3] > 0][:, :3] for s in group])
    strip = Image.fromarray((pixels.reshape(1, -1, 3) * 255).astype(np.uint8), "RGB")
    pal_img = strip.quantize(COLOURS, method=Image.MEDIANCUT, dither=Image.NONE)
    pal = np.array(pal_img.getpalette()[:COLOURS * 3]).reshape(-1, 3) / 255
    frames = []
    for s in group:
        idx = np.full((H, W), -1)
        for y in range(H):
            for x in range(W):
                if s[y, x, 3] > 0: idx[y, x] = int(((pal - s[y, x, :3]) ** 2).sum(axis=1).argmin())
        frames.append(idx)
    out.append((pal, frames))
np.save("sprites.npy", np.array([[f for f in frames] for _, frames in out]))
np.save("palettes.npy", np.array([p for p, _ in out]))
# a preview on grass, enlarged, plus one at the size they will be on the map
S = 6
prev = Image.new("RGB", (COLS * (W + 2) * S, ROWS * (H + 2) * S), (76, 117, 66))
for r, (pal, frames) in enumerate(out):
    for c, idx in enumerate(frames):
        for y in range(H):
            for x in range(W):
                if idx[y, x] >= 0:
                    col = tuple(int(v * 255) for v in pal[idx[y, x]])
                    for dy in range(S):
                        for dx in range(S): prev.putpixel((c * (W + 2) * S + x * S + dx, r * (H + 2) * S + y * S + dy), col)
prev.save("cut.png"); print("ok", prev.size)
