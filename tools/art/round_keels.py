"""Rounds each boat's hull underneath: level along most of its length, so it sits in the water from bow to stern, and
curving up only towards the ends, as a real hull does. A column deeper than the curve has its lower rows squeezed into
it, and one shallower has the plank rows just above its keel repeated down to it, so the planks run on and the dark
keel stays at the edge. Writes the boats in place; a second run leaves them as they are.
Usage: python tools/art/round_keels.py"""
from pathlib import Path

import numpy as np
from PIL import Image

PROPS = Path(__file__).resolve().parents[2] / "game" / "assets" / "art" / "props"
# How many rows the keel rises at the very ends, and how many rows above that the squeeze starts.
RISE = {"sailing_boat": 13, "big_boat": 15}
ABOVE = 4
SHAPE = 2.0
# How much of the hull either side of amidships runs level before the keel starts to rise, and how many rows of keel
# are moved down when a column is deepened.
FLAT = {"sailing_boat": 0.7, "big_boat": 0.8}
KEEL = 2


def bottoms(solid: np.ndarray) -> np.ndarray:
    h = solid.shape[0]
    rows = np.arange(h)[:, None]
    return np.where(solid.any(axis=0), (rows * solid).max(axis=0), -1)


def round_keel(path: Path, rise: int) -> None:
    im = np.array(Image.open(path).convert("RGBA"))
    solid = im[:, :, 3] > 127
    low = bottoms(solid)
    lowest = int(low.max())
    span = np.nonzero(low >= lowest - rise)[0]
    mid = (span[0] + span[-1]) / 2.0
    half = max(1.0, (span[-1] - span[0]) / 2.0)
    start = lowest - rise - ABOVE
    out = im.copy()
    for x in span:
        t = max(0.0, (min(1.0, abs(x - mid) / half) - FLAT[path.stem]) / (1.0 - FLAT[path.stem]))
        target = lowest - int(round(rise * t ** SHAPE))
        b = int(low[x])
        if b < target:
            gap = target - b
            for y in range(b - KEEL + 1, target + 1):
                out[y, x] = im[y - gap, x]
            continue
        if b == target:
            continue
        for y in range(start, b + 1):
            out[y, x] = 0
        for y in range(start, target + 1):
            src = start + int(round((y - start) * (b - start) / max(1, target - start)))
            out[y, x] = im[src, x]
    Image.fromarray(out).save(path)
    print("rounded", path.name)


def main():
    for name, rise in RISE.items():
        round_keel(PROPS / f"{name}.png", rise)


if __name__ == "__main__":
    main()
