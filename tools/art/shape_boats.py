"""Shapes the two rowing boats from their paintings as make_props.py left them (kept in props_raw as
<boat>_painted.png): the hull made thicker along its whole length by doubling rows of its planks, its flat bottom
rounded into a keel curving gently up to bow and stern, and the bow post raised two pixels. Writes the boats to
game/assets/art/props/; running it again gives the same pictures.
Usage: python tools/art/shape_boats.py"""
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

from round_keels import round_keel

ROOT = Path(__file__).resolve().parents[2]
RAW = Path(__file__).with_name("props_raw")
PROPS = ROOT / "game" / "assets" / "art" / "props"
# The plank rows doubled to thicken each hull, how many rows its keel rises at the ends, the first column of the bow's
# rise and how many rows it rises, and the row of the near rail the bow's stretch reaches down to.
BOATS = {
    "skiff": {"double": [28, 31, 32, 34, 37], "rise": 7, "bow": (100, 2), "rail": 25},
    "fishing_boat": {"double": [27, 31, 32, 34, 36], "rise": 7, "bow": (103, 2), "rail": 24},
}


def thicken(path: Path, rows: list) -> None:
    im = np.array(Image.open(path).convert("RGBA"))
    for r in sorted(rows, reverse=True):
        im = np.concatenate([im[:r + 1], im[r:r + 1], im[r + 1:]])
    Image.fromarray(im).save(path)


def raise_bow(path: Path, start: int, rows: int, rail: int) -> None:
    """Raises the bow post, the most at the very end, by stretching each end column's top down to the near rail, so its
    shading stays whole; the picture gains rows at the top for a post that rises past it."""
    im = np.array(Image.open(path).convert("RGBA"))
    w = im.shape[1]
    lifts = np.zeros(w, dtype=int)
    for x in range(start, w):
        lifts[x] = round(rows * (x - start) / max(1, w - 1 - start))
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
            out[y, x] = im[top + int((y - (top - k)) * (rail - top) / (rail - top + k)), x]
    Image.fromarray(out).save(path)


def main():
    for name, spec in BOATS.items():
        out = PROPS / f"{name}.png"
        shutil.copy(RAW / f"{name}_painted.png", out)
        thicken(out, spec["double"])
        round_keel(out, spec["rise"])
        raise_bow(out, spec["bow"][0], spec["bow"][1], spec["rail"])
        print("shaped", name, Image.open(out).size)


if __name__ == "__main__":
    main()
