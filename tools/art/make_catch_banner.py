"""Draws the catch banner, a fisherman's linen banner, into game/assets/art/ui/banner_*.png.

Every picture is drawn here pixel by pixel at the size the game shows it, one texel to a game pixel: undyed linen with
a fine weave, a few slubbed threads and soft folds, hung by rope ties from a plain wooden pole on a rope looped over a
peg, a sea blue border stripe painted round it by hand, and a frayed foot. The parts are the ones the game moves apart:
the top (peg, rope, pole and ties), the cloth, the roll the cloth unfurls from, and the little painted starfish that
marks a new or legendary catch.
Usage: python tools/art/make_catch_banner.py"""
import random
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "game" / "assets" / "art" / "ui"

# The whole banner, and the cloth hanging under the pole from HANG; these match CatchCard in catch_card.gd.
SIZE = (184, 150)
HANG = (7, 13)
CLOTH = (170, 137)
# The cloth's hem, its stripe's inset, top, width and foot, and the row where the weave ends and the fraying starts.
HEM = 4
STRIPE_IN, STRIPE_TOP, STRIPE_W = 3, 5, 3
STRIPE_FOOT = 125
WOVEN = 132
# Columns of the cloth where a rope tie holds it to the pole.
TIES = (13, 61, 109, 156)
# Rows of the top picture: the peg's top and the pole's top row; the pole is POLE rows thick.
PEG_TOP, POLE_TOP, POLE = 0, 9, 5

LINEN = [(146, 128, 101), (165, 147, 116), (182, 165, 132), (197, 181, 147), (210, 195, 161), (221, 207, 174),
         (231, 219, 188)]
BLUE = [(44, 74, 88), (55, 90, 104), (67, 106, 118), (82, 121, 131), (99, 137, 145)]
OCHRE = [(132, 88, 42), (168, 118, 54), (198, 150, 72), (220, 180, 100)]
WOOD = [(62, 41, 30), (84, 57, 38), (107, 74, 48), (131, 94, 61), (152, 113, 75)]
ROPE = [(96, 74, 50), (128, 101, 66), (160, 131, 87), (189, 161, 112)]
# A 4 by 4 ordered dither, so soft shading is laid as a pattern of whole pixels.
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.47


def fold_shade(w, h):
    """The cloth's light: soft folds hanging from between the ties, darker toward the foot and the right."""
    x = np.arange(w)[None, :].astype(float)
    y = np.arange(h)[:, None].astype(float)
    v = np.zeros((h, w))
    for a, b in zip((0,) + TIES, TIES + (w - 1,)):
        mid = (a + b) / 2.0
        reach = 46.0 + (b - a) * 0.6
        fade = np.clip(1.0 - y / reach, 0.0, 1.0) ** 1.4
        u = (x - mid) / max(4.0, (b - a) * 0.16)
        v += (-1.9 * np.exp(-u ** 2) + 1.0 * np.exp(-(u + 1.7) ** 2)) * fade
        # A sag between two ties, just under the hem.
        v += -0.6 * np.exp(-((y - HEM - 2) / 3.0) ** 2) * np.exp(-((x - mid) / ((b - a) * 0.3)) ** 2)
    for fx, top, bottom, depth in ((38, 40, 112, 1.1), (122, 55, 112, 1.0), (83, 70, 114, 0.8)):
        grow = np.clip((y - top) / 18.0, 0.0, 1.0) * np.clip((bottom - y) / 10.0, 0.0, 1.0)
        u = (x - fx - (y - top) * 0.05) / 2.2
        v += (-depth * np.exp(-u ** 2) + depth * 0.55 * np.exp(-(u + 1.6) ** 2)) * grow
    v += -0.55 * (y / h) - 0.35 * (x / w) + 0.2
    return v


def weave(w, h, rng):
    """The weave's grain: a faint checker of crossing threads, with slubbed threads running across here and there."""
    x = np.arange(w)[None, :]
    y = np.arange(h)[:, None]
    v = np.where((x + 2 * y) % 4 == 0, -0.22, 0.0) + np.where((x % 2 == 1) & (y % 3 == 0), 0.12, 0.0)
    v = v + np.zeros((h, w))
    for _ in range(w * h // 260):
        r, c, n = rng.randrange(h), rng.randrange(w), rng.randrange(3, 11)
        v[r, c:c + n] += rng.choice((-0.55, 0.5))
    for _ in range(w // 18):
        c, r, n = rng.randrange(w), rng.randrange(h), rng.randrange(6, 20)
        v[r:r + n, c] += -0.35
    return v


def levels(v, ramp, base):
    """Turns light into the ramp's colours, dithered by whole pixels."""
    h, w = v.shape
    d = BAYER[np.arange(h)[:, None] % 4, np.arange(w)[None, :] % 4]
    return np.clip(np.floor(base + v + d * 0.85 + 0.5), 0, len(ramp) - 1).astype(int)


def paint(img, idx, mask, ramp, offset=0):
    h, w = idx.shape
    for yy in range(h):
        for xx in range(w):
            if mask[yy, xx]:
                img.putpixel((xx, yy), ramp[int(np.clip(idx[yy, xx] + offset, 0, len(ramp) - 1))] + (255,))


def stripe_mask(w, rng):
    """The painted border: a stripe round the cloth, its edges wavering a pixel as a brush would leave them."""
    m = np.zeros((WOVEN, w), bool)
    left, right = STRIPE_IN, w - 1 - STRIPE_IN
    top, foot = STRIPE_TOP, STRIPE_FOOT + STRIPE_W - 1
    m[top:top + STRIPE_W, left:right + 1] = True
    m[STRIPE_FOOT:foot + 1, left:right + 1] = True
    m[top:foot + 1, left:left + STRIPE_W] = True
    m[top:foot + 1, right - STRIPE_W + 1:right + 1] = True
    edges = []
    for xx in range(left + STRIPE_W, right - STRIPE_W + 1):
        edges += [(top + STRIPE_W, xx, 1), (top - 1, xx, 1), (STRIPE_FOOT - 1, xx, 1), (foot + 1, xx, 1)]
    for yy in range(top + STRIPE_W, STRIPE_FOOT):
        edges += [(yy, left + STRIPE_W, 1), (yy, left - 1, 1), (yy, right - STRIPE_W, 1), (yy, right + 1, 1)]
    for yy, xx, _ in edges:
        if rng.random() < 0.025:
            run = rng.randrange(2, 4)
            horizontal = yy in (top + STRIPE_W, top - 1, STRIPE_FOOT - 1, foot + 1)
            for k in range(run):
                a, b = (yy, xx + k) if horizontal else (yy + k, xx)
                if 0 <= a < WOVEN and 0 <= b < w:
                    m[a, b] = True
    for yy, xx in zip(*np.nonzero(m)):
        if rng.random() < 0.012 and (yy in (top, foot) or xx in (left, right)):
            m[yy, xx] = False
    return m


def cloth():
    rng = random.Random(7)
    w, h = CLOTH
    shade = fold_shade(w, h) + weave(w, h, rng)
    idx = levels(shade, LINEN, 4)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    body = np.zeros((h, w), bool)
    body[:WOVEN] = True
    # The selvedges and the hem fold read a shade darker, the hem's crease and its stitches darker still.
    idx[:, 0] -= 1
    idx[:, w - 1] -= 1
    idx[0] = np.minimum(idx[0], 2)
    idx[1:3] += 1
    idx[HEM - 1] -= 1
    idx[HEM - 1, 1::4] = 1
    paint(img, idx, body, LINEN)
    m = stripe_mask(w, rng)
    blue = idx.copy() - 2
    for yy, xx in zip(*np.nonzero(m)):
        if rng.random() < 0.07:
            blue[yy, xx] += 1
    paint(img, blue[:WOVEN], m, BLUE)
    fray(img, idx, rng)
    return img


def fray(img, idx, rng):
    """The foot where the weft has worn away: the last woven row uneven, and loose warp threads hanging in clumps."""
    w, h = CLOTH
    clump = 0
    for xx in range(1, w - 1):
        if rng.random() < 0.18:
            clump = rng.choice((0, 1, 2, 3, 4))
        if rng.random() < 0.12:
            img.putpixel((xx, WOVEN - 1), (0, 0, 0, 0))
            continue
        if rng.random() < 0.3:
            continue
        n = max(1, min(h - WOVEN, clump + rng.choice((-1, 0, 0, 1))))
        tone = 3 if xx % 2 else 4
        for k in range(n):
            t = tone - (1 if k == n - 1 else 0) - (1 if k > 2 else 0)
            img.putpixel((xx, WOVEN + k), LINEN[t] + (255,))


def roll():
    """The cloth rolled up tight under the pole, its painted stripe showing at both ends."""
    w = CLOTH[0]
    rows = [1, 3, 5, 4, 3, 1]
    img = Image.new("RGBA", (w, len(rows)), (0, 0, 0, 0))
    rng = random.Random(3)
    for yy, t in enumerate(rows):
        for xx in range(w):
            k = t - (1 if xx in (0, w - 1) else 0) - (1 if rng.random() < 0.08 else 0)
            col = LINEN[max(0, k)]
            if STRIPE_IN <= xx < STRIPE_IN + STRIPE_W or w - 1 - STRIPE_IN - STRIPE_W < xx <= w - 1 - STRIPE_IN:
                col = BLUE[max(0, min(4, k - 1))]
            img.putpixel((xx, yy), col + (255,))
    return img


def rope_line(img, a, b):
    """A thin twisted rope from a to b, a pixel thick, its strands light and dark in turn."""
    (x0, y0), (x1, y1) = a, b
    n = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(n + 1):
        x = round(x0 + (x1 - x0) * i / n)
        y = round(y0 + (y1 - y0) * i / n)
        img.putpixel((x, y), ROPE[(1, 2, 3, 2)[i % 4]] + (255,))
        img.putpixel((x, y + 1), ROPE[0] + (255,))


def coil(img, x, top, rows, width=3):
    """Rope wound round the pole: diagonal turns of light and shade."""
    for yy in range(top, top + rows):
        for k in range(width):
            turn = (k + yy) % 3
            img.putpixel((x + k, yy), ROPE[(3, 2, 1)[turn] - (1 if k == width - 1 else 0)] + (255,))


def top():
    rng = random.Random(11)
    w = SIZE[0]
    img = Image.new("RGBA", (w, HANG[1] + HEM + 1), (0, 0, 0, 0))
    mid = w // 2
    # The rope hung over the peg, from where it is tied near each end of the pole.
    rope_line(img, (4, POLE_TOP - 1), (mid - 2, PEG_TOP + 2))
    rope_line(img, (w - 5, POLE_TOP - 1), (mid + 1, PEG_TOP + 2))
    for xx, yy, t in ((mid - 2, 0, 2), (mid - 1, 0, 3), (mid, 0, 3), (mid + 1, 0, 2), (mid - 2, 1, 1), (mid - 1, 1, 1),
                      (mid, 1, 1), (mid + 1, 1, 0), (mid - 1, 2, 0), (mid, 2, 0)):
        img.putpixel((xx, yy), WOOD[t] + (255,))
    # The pole: a plain round length of wood, lit from above, with grain, a knot and worn ends.
    rows = [3, 4, 3, 2, 1]
    for yy in range(POLE):
        for xx in range(w):
            if xx in (0, w - 1) and yy in (0, POLE - 1):
                continue
            t = rows[yy]
            img.putpixel((xx, POLE_TOP + yy), WOOD[t] + (255,))
    for _ in range(26):
        yy, xx, n = rng.choice((1, 2, 3)), rng.randrange(2, w - 14), rng.randrange(5, 16)
        dark = rng.random() < 0.65
        for k in range(n):
            t = rows[yy] + (-1 if dark else 1)
            img.putpixel((xx + k, POLE_TOP + yy), WOOD[max(0, min(4, t))] + (255,))
    for kx in (33, 124):
        for (dx, dy, t) in ((0, 1, 0), (1, 1, 1), (0, 2, 1), (1, 2, 0), (-1, 2, 3), (2, 1, 3)):
            img.putpixel((kx + dx, POLE_TOP + dy), WOOD[t] + (255,))
    for xx in (0, w - 1):
        for yy, t in ((1, 4), (2, 3), (3, 2)):
            img.putpixel((xx, POLE_TOP + yy), WOOD[t] + (255,))
    coil(img, 2, POLE_TOP, POLE)
    coil(img, w - 5, POLE_TOP, POLE)
    # Each tie: rope wound round the pole and down through a hole in the cloth's hem.
    for c in TIES:
        x = HANG[0] + c - 1
        coil(img, x, POLE_TOP - 1, POLE + 1)
        for yy in range(POLE_TOP + POLE, HANG[1] + HEM - 1):
            for k in range(3):
                t = (2, 1, 0)[k] if yy % 2 else (3, 2, 1)[k]
                img.putpixel((x + k, yy), ROPE[t] + (255,))
        img.putpixel((x + 1, HANG[1] + HEM - 1), LINEN[0] + (255,))
        img.putpixel((x, HANG[1] + HEM - 1), ROPE[0] + (255,))
        img.putpixel((x + 2, HANG[1] + HEM - 1), ROPE[0] + (255,))
    return img


def star():
    """A little starfish painted in ochre, the mark of a new or legendary catch."""
    shape = ["...3...",
             "...2...",
             "32221..",
             ".22110.",
             "..211..",
             ".21.10.",
             ".1...0."]
    img = Image.new("RGBA", (7, 7), (0, 0, 0, 0))
    for yy, row in enumerate(shape):
        for xx, ch in enumerate(row):
            if ch != ".":
                img.putpixel((xx, yy), OCHRE[int(ch)] + (255,))
    img.putpixel((6, 2), OCHRE[1] + (255,))
    img.putpixel((5, 2), OCHRE[2] + (255,))
    return img


def main():
    parts = {"banner_top.png": top(), "banner_cloth.png": cloth(), "banner_roll.png": roll(), "banner_star.png": star()}
    for name, img in parts.items():
        img.save(OUT / name)
        print(name, img.size)


if __name__ == "__main__":
    main()
