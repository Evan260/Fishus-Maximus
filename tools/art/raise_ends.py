"""Raises a rowing boat's stern and bow post a few pixels, the most at the very end and none where the gunwale runs
level, by stretching each end column's top down to its near rail, so the shading and the rail's highlight stay whole.
The picture gains rows at the top for a post that rises past it. Run it once on a boat: a second run raises it again.
Usage: python tools/art/raise_ends.py"""
from pathlib import Path

import numpy as np
from PIL import Image

PROPS = Path(__file__).resolve().parents[2] / "game" / "assets" / "art" / "props"
# For each boat: (first column of the stern's rise, how many rows its end rises), (first column of the bow's rise,
# rows), and the row of the near rail the stretch reaches down to.
RAISE = {"skiff": ((24, 6), (100, 2), 25), "fishing_boat": (None, (103, 2), 24)}


def raise_ends(path: Path, stern, bow, rail: int) -> None:
    im = np.array(Image.open(path).convert("RGBA"))
    w = im.shape[1]
    lifts = np.zeros(w, dtype=int)
    if stern:
        for x in range(stern[0]):
            lifts[x] = round(stern[1] * (1.0 - x / stern[0]) ** 1.3)
    if bow:
        for x in range(bow[0], w):
            lifts[x] = round(bow[1] * (x - bow[0]) / max(1, w - 1 - bow[0]))
    tops = np.argmax(im[:, :, 3] > 127, axis=0)
    pad = int(max(0, (lifts - tops).max()))
    im = np.concatenate([np.zeros((pad, w, 4), dtype=im.dtype), im])
    rail += pad
    solid = im[:, :, 3] > 127
    out = im.copy()
    for x in range(w):
        k = int(lifts[x])
        if k <= 0 or not solid[:, x].any():
            continue
        top = int(np.argmax(solid[:, x]))
        if top >= rail:
            continue
        for y in range(top - k, rail):
            src = top + int((y - (top - k)) * (rail - top) / (rail - top + k))
            out[y, x] = im[src, x]
    Image.fromarray(out).save(path)
    print("raised", path.name, "by", pad, "rows at the top")


def main():
    for name, (stern, bow, rail) in RAISE.items():
        raise_ends(PROPS / f"{name}.png", stern, bow, rail)


if __name__ == "__main__":
    main()
