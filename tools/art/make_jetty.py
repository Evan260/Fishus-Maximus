"""Builds the harbour's jetty from the painted one in props/: every post carries on straight down past the sea floor,
continued by mirroring the post's own grain so it never shows a joint or a gap. The game draws the jetty behind the
sea floor, which hides the posts' feet. Usage: python tools/art/make_jetty.py"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "game" / "assets" / "art" / "props" / "jetty.png"
OUT = ROOT / "game" / "assets" / "art" / "places" / "harbour" / "jetty.png"
# The last painted row of the posts above their painted ends, and how many rows above it are the weedy foot of the post.
CUT = 55
GRAIN = 14
HEIGHT = 126


def main():
    src = np.array(Image.open(SRC).convert("RGBA"))
    out = np.zeros((HEIGHT, src.shape[1], 4), dtype=np.uint8)
    out[:CUT + 1] = src[:CUT + 1]
    posts = src[CUT, :, 3] > 0
    period = 2 * GRAIN
    for y in range(CUT + 1, HEIGHT):
        k = (y - CUT - 1) % period
        row = CUT - k if k < GRAIN else CUT - (period - 1 - k)
        out[y, posts] = src[row, posts]
    Image.fromarray(out).save(OUT)
    print("jetty built", out.shape[1], out.shape[0], "with", int(posts.sum()), "post columns")


if __name__ == "__main__":
    main()
