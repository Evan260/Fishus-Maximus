"""Builds the harbour's quay from the shore's painted terrace wall: one piece of the same cut limestone, with each
course of stone ending at its own mortar joint, the upper courses shorter so the pier's seaward end steps down like
real masonry. It is solid stone from its top to the sea floor; the game tints the part below the waterline.
Usage: python tools/art/make_quay.py"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
WALL = ROOT / "game" / "assets" / "art" / "shore" / "wall.png"
OUT = ROOT / "game" / "assets" / "art" / "places" / "harbour" / "quay.png"
WIDTH = 176
HEIGHT = 136
# Where each course of stone should end, counted from the top; courses below the last listed end at the last value.
ENDS = [122, 138, 152]


def courses(lum: np.ndarray) -> list:
    """The rows between the wall's horizontal mortar lines, found as the darkest rows."""
    rows = lum.mean(axis=1)
    dark = rows < np.percentile(rows, 18)
    bounds = [0]
    for y in range(1, len(rows)):
        if dark[y] and not dark[y - 1] and y - bounds[-1] > 8:
            bounds.append(y)
    bounds.append(len(rows))
    return list(zip(bounds[:-1], bounds[1:]))


def main():
    wall = np.array(Image.open(WALL).convert("RGBA").crop((0, 0, WIDTH, HEIGHT)))
    lum = wall[:, :, :3].astype(float).mean(axis=2)
    alpha = np.zeros((HEIGHT, WIDTH), dtype=np.uint8)
    for i, (y0, y1) in enumerate(courses(lum)):
        target = ENDS[min(i, len(ENDS) - 1)]
        cols = lum[y0:y1].mean(axis=0)
        lo, hi = max(1, target - 20), min(WIDTH - 1, target + 8)
        joint = lo + int(np.argmin(cols[lo:hi]))
        alpha[y0:y1, :joint + 1] = 255
    wall[:, :, 3] = alpha
    # The top course is lit from above, so the pier reads as having a flat top.
    wall[0:2, :, :3] = np.clip(wall[0:2, :, :3].astype(int) + 40, 0, 255)
    Image.fromarray(wall).crop(Image.fromarray(alpha).getbbox()).save(OUT)
    print("quay built with", len(courses(lum)), "courses")


if __name__ == "__main__":
    main()
