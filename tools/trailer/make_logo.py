"""Draw the Fishus Maximus logo as pixel art on the game's own pixel grid, for the YouTube banner and other marketing, in
the same lettering as Farmus Maximus's and Mosaicus Maximus's.

The letters are Cinzel (SIL Open Font License, kept beside this script), a typeface drawn from Roman inscriptions,
rendered large and sampled down to whole pixels, then shaded by hand rules: sunlit gold on top, deeper ochre below,
a carved edge, a dark outline and a little depth underneath, with a laurel sprig curling out from each side.

Usage: python tools/trailer/make_logo.py
Writes tools/trailer/logo.png and logo_plain.png (the name without the laurel) at 1 pixel per game pixel.
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
OUT = HERE / "logo.png"
PLAIN_OUT = HERE / "logo_plain.png"
CAP = 27
SUPER = 8
LINES = ["FISHUS", "MAXIMUS"]
LINE_GAP = 7
TRACKING = 2
DEPTH = 3

OUTLINE = (58, 34, 26)
DEPTH_DARK = (112, 58, 28)
DEPTH_LIGHT = (142, 76, 34)
EDGE_TOP = (255, 247, 214)
EDGE_LOW = (168, 88, 34)
BANDS = [(255, 232, 160), (250, 212, 110), (240, 182, 72), (224, 150, 52), (204, 122, 42)]
LEAF_DARK, LEAF_MID, LEAF_LIGHT = (52, 86, 46), (86, 128, 62), (138, 172, 88)


def glyph_line(text):
    """One line of capitals as a coverage mask with letters a little apart, CAP pixels tall."""
    font = ImageFont.truetype(str(HERE / "Cinzel.ttf"), 10)
    font.set_variation_by_axes([900])
    cap = font.getbbox("H")
    size = int(10 * CAP * SUPER / (cap[3] - cap[1]))
    font = ImageFont.truetype(str(HERE / "Cinzel.ttf"), size)
    font.set_variation_by_axes([900])
    top = font.getbbox("H")[1]
    widths = [font.getbbox(ch)[2] for ch in text]
    total = sum(widths) + TRACKING * SUPER * (len(text) - 1)
    canvas = Image.new("L", (total + SUPER * 4, CAP * SUPER + SUPER * 2), 0)
    d = ImageDraw.Draw(canvas)
    x = SUPER * 2
    for ch, w in zip(text, widths):
        d.text((x, SUPER - top), ch, font=font, fill=255)
        x += w + TRACKING * SUPER
    small = canvas.resize((canvas.width // SUPER, canvas.height // SUPER), Image.BOX)
    mask = np.array(small) > 110
    cols = np.nonzero(mask.any(0))[0]
    rows = np.nonzero(mask.any(1))[0]
    return mask[rows[0]:rows[-1] + 1, cols[0]:cols[-1] + 1]


def sprig(length, flip):
    """A laurel branch: a curving stem with alternate pointed leaves, shaded and outlined like the letters, growing
    outwards from the name and sweeping up at its tip."""
    w, h = length + 14, 40
    leaf = np.zeros((h, w), np.uint8)
    stem = []
    for i in range(length):
        t = i / (length - 1)
        stem.append((i + 4.0, h - 12.0 - 18.0 * t ** 1.8))
    for k, (sx, sy) in enumerate(stem[:-3]):
        leaf[int(round(sy)), int(round(sx))] = 4
    # Leaves alternate above and below the stem, each leaning towards the tip, the newest smallest.
    for n, k in enumerate(range(2, length - 2, 4)):
        sx, sy = stem[k]
        nx, ny = stem[min(k + 2, length - 1)]
        along = math.atan2(ny - sy, nx - sx)
        side = -1 if n % 2 == 0 else 1
        angle = along + side * 0.75
        size = 8.5 - 3.0 * k / length
        for y in range(h):
            for x in range(w):
                dx, dy = x - sx, y - sy
                u = dx * math.cos(angle) + dy * math.sin(angle)
                v = -dx * math.sin(angle) + dy * math.cos(angle)
                if 0 <= u <= size and abs(v) <= 1.9 * math.sin(math.pi * u / size) + 0.2:
                    # The half of each leaf facing up catches the light, and so does its tip.
                    lit = v * math.cos(angle) < 0 or u > size * 0.7
                    leaf[y, x] = max(leaf[y, x], 3 if lit else 2)
    ex, ey = stem[-1]
    for j in range(4):
        x, y = int(round(ex - 2 + j)), int(round(ey - j * 0.6))
        if 0 <= y < h and 0 <= x < w:
            leaf[y, x] = 3
    solid = leaf > 0
    ring = np.zeros_like(solid)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            ring |= np.roll(np.roll(solid, dy, 0), dx, 1)
    ring &= ~solid
    img = np.zeros((h, w, 4), np.uint8)
    img[ring] = (*OUTLINE, 255)
    img[leaf == 2] = (*LEAF_MID, 255)
    img[leaf == 3] = (*LEAF_LIGHT, 255)
    img[leaf == 4] = (*LEAF_DARK, 255)
    pic = Image.fromarray(img, "RGBA")
    return pic.transpose(Image.FLIP_LEFT_RIGHT) if flip else pic


def shade(mask):
    """Gold letters with a carved edge, depth below and a dark outline, as an RGBA image."""
    h, w = mask.shape
    pad = 2
    H, W = h + DEPTH + pad * 2, w + pad * 2
    body = np.zeros((H, W), bool)
    body[pad:pad + h, pad:pad + w] = mask
    depth = np.zeros_like(body)
    for d in range(1, DEPTH + 1):
        depth[d:, :] |= body[:-d, :]
    depth &= ~body
    solid = body | depth
    ring = np.zeros_like(solid)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            ring |= np.roll(np.roll(solid, dy, 0), dx, 1)
    ring &= ~solid
    out = np.zeros((H, W, 4), np.uint8)
    out[ring] = (*OUTLINE, 255)
    rows = np.arange(H)[:, None].repeat(W, 1)
    out[depth & (rows % 2 == 0)] = (*DEPTH_DARK, 255)
    out[depth & (rows % 2 == 1)] = (*DEPTH_DARK, 255)
    # The depth is lit a little along its top edge, where it meets the letter face.
    above_body = np.zeros_like(depth)
    above_body[1:, :] = body[:-1, :]
    out[depth & above_body] = (*DEPTH_LIGHT, 255)
    band = np.clip(((rows - pad) * len(BANDS)) // max(1, h), 0, len(BANDS) - 1)
    for i, c in enumerate(BANDS):
        out[body & (band == i)] = (*c, 255)
    up_empty = np.zeros_like(body)
    up_empty[1:, :] = ~body[:-1, :]
    up_empty[0, :] = True
    left_empty = np.zeros_like(body)
    left_empty[:, 1:] = ~body[:, :-1]
    down_empty = np.zeros_like(body)
    down_empty[:-1, :] = ~body[1:, :]
    out[body & down_empty] = (*EDGE_LOW, 255)
    out[body & (up_empty | left_empty)] = (*EDGE_TOP, 255)
    return Image.fromarray(out, "RGBA")


def main():
    lines = [shade(glyph_line(t)) for t in LINES]
    width = max(l.width for l in lines)
    sprig_len = 34
    total_w = width + 2 * (sprig_len + 4)
    total_h = sum(l.height for l in lines) + LINE_GAP + 12
    logo = Image.new("RGBA", (total_w, total_h), (0, 0, 0, 0))
    y = 3
    tops = []
    for l in lines:
        logo.alpha_composite(l, ((total_w - l.width) // 2, y))
        tops.append((y, l))
        y += l.height + LINE_GAP
    # The name alone, without the laurel, for pictures too narrow for it.
    logo.crop(logo.getbbox()).save(PLAIN_OUT)
    # A sprig grows out from each side of the second line, the way a victor's laurel frames a name.
    y2, second = tops[1]
    left = sprig(sprig_len, True)
    right = sprig(sprig_len, False)
    mid = y2 + second.height - left.height + 6
    logo.alpha_composite(left, ((total_w - second.width) // 2 - left.width + 2, mid))
    logo.alpha_composite(right, ((total_w + second.width) // 2 - 2, mid))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    logo.save(OUT)
    print(f"logo: {OUT} ({logo.width} x {logo.height} game pixels)")


if __name__ == "__main__":
    main()
