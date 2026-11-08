"""Breaks up a long straight slope along the top of a picture of land into an uneven outline of rounded bulges and
dips, a few pixels high and a dozen or so across, like outcrops of rock and clumps of scrub. Each column's top band is
stretched up into a bulge or squeezed down into a dip, so its rock or scrub carries on unbroken and the edge keeps its
shading. Changes the picture again when run again, so run it once on a span.
Usage: python tools/art/break_edges.py PICTURE FIRST_COLUMN LAST_COLUMN [SEED]   (PICTURE under game/assets/art)"""
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ART = Path(__file__).resolve().parents[2] / "game" / "assets" / "art"
# How far the outline bulges out or dips in, how many columns a bulge spans, and how deep a band of each column is
# stretched or squeezed to make it.
AMPLITUDE = 4.0
WAVE = (10.0, 22.0)
BAND = 10


def tops(solid: np.ndarray) -> list:
    return [int(np.argmax(solid[:, x])) if solid[:, x].any() else -1 for x in range(solid.shape[1])]


def wobble(first: int, last: int, rng: random.Random) -> dict:
    """How far up (positive) or down each column's top moves: two waves of different lengths added together, fading to
    nothing at both ends of the span so it joins the outline beside it."""
    waves = [(rng.uniform(*WAVE), rng.uniform(0, math.tau), rng.uniform(0.5, 1.0)) for _ in range(2)]
    out = {}
    for x in range(first, last + 1):
        u = (x - first) / max(1, last - first)
        fade = math.sin(math.pi * u)
        v = sum(a * math.sin(math.tau * x / wl + ph) for wl, ph, a in waves) / 1.5
        out[x] = int(round(AMPLITUDE * v * fade))
    return out


def break_span(path: Path, first: int, last: int, seed: int) -> None:
    im = np.array(Image.open(path).convert("RGBA"))
    solid = im[:, :, 3] > 127
    old = tops(solid)
    h = im.shape[0]
    out = im.copy()
    for x, up in wobble(first, last, random.Random(seed)).items():
        o = old[x]
        if o < 0 or up == 0:
            continue
        bottom = min(h, o + BAND)
        top = max(0, o - up)
        out[min(o, top):bottom, x] = 0
        for y in range(top, bottom):
            out[y, x] = im[o + int((y - top) * (bottom - o) / (bottom - top)), x]
    Image.fromarray(out).save(path)
    print("broke the slope of", path.name, "from column", first, "to", last)


if __name__ == "__main__":
    a = sys.argv[1:]
    break_span(ART / a[0], int(a[1]), int(a[2]), int(a[3]) if len(a) > 3 else 1)
