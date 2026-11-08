"""Takes the dark outline off painted sprites the way pixel artists do by hand: each near-black pixel along the edge
of a sprite becomes a darker shade of the colour just inside it, so the edge reads without a black line round it.
Sprites with no dark rim are left as they are. With --lines it also takes off the near-black lines drawn inside a
picture, such as round each house of a row of town, each becoming a darker shade of the colours beside it, while
windows, doorways and other dark shapes at least two pixels thick stay as they are. Writes the pictures back in place.
Usage: python tools/art/soften_outlines.py [--lines] PATH [PATH...]   (files or folders of .png)"""
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

# How dark an edge pixel must be, absolutely and against the colour inside it, to count as outline.
DARK = 70.0
AGAINST = 0.62
# How much darker than the colour inside it a softened edge pixel is drawn.
SHADE = 0.74
# A line inside a picture: near-black but not the dark green of a tree's shade, and running at least this far.
LINE_DARK = 33.0
LINE_RUN = 5


def lum(rgb: np.ndarray) -> np.ndarray:
    return rgb[..., 0] * 0.3 + rgb[..., 1] * 0.59 + rgb[..., 2] * 0.11


def depth_from_edge(solid: np.ndarray, most: int) -> np.ndarray:
    """How many steps in from the sprite's edge each pixel is, up to `most`."""
    depth = np.where(solid, most + 1, 0)
    ring = solid.copy()
    for d in range(1, most + 1):
        pad = np.pad(ring, 1, constant_values=False)
        inner = pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:]
        depth[ring & ~inner] = d
        ring = ring & inner
    return depth


def soften(path: Path) -> int:
    im = np.array(Image.open(path).convert("RGBA")).astype(float)
    solid = im[:, :, 3] > 127
    if solid.sum() < 20:
        return 0
    rgb = im[:, :, :3]
    light = lum(rgb)
    depth = depth_from_edge(solid, 3)
    h, w = solid.shape
    changed = 0
    out = rgb.copy()
    for ring in (1, 2):
        ys, xs = np.nonzero(depth == ring)
        for y, x in zip(ys, xs):
            if light[y, x] > DARK:
                continue
            # Thin parts such as fin tips have no inside, so they take the nearest lighter colour a little further off.
            for reach in (2, 3):
                y0, y1, x0, x1 = max(0, y - reach), min(h, y + reach + 1), max(0, x - reach), min(w, x + reach + 1)
                near = (depth[y0:y1, x0:x1] > (ring if reach == 2 else 0)) & (light[y0:y1, x0:x1] > light[y, x] + 8)
                if near.any():
                    break
            if not near.any():
                continue
            inside = rgb[y0:y1, x0:x1][near]
            if light[y, x] > AGAINST * lum(inside.mean(axis=0)):
                continue
            out[y, x] = inside.mean(axis=0) * SHADE
            changed += 1
    if changed:
        im[:, :, :3] = np.clip(out, 0, 255)
        Image.fromarray(im.astype(np.uint8)).save(path)
    return changed


def soften_lines(arr: np.ndarray) -> tuple[np.ndarray, int]:
    """The picture with its near-black lines drawn in darker shades of the colours beside them, and how many pixels
    changed. A line is what a 2 by 2 block of dark cannot fit inside, so windows and doorways keep their dark."""
    rgb = arr[:, :, :3].astype(np.float32)
    solid = arr[:, :, 3] > 127
    dark = solid & (lum(rgb) < LINE_DARK) & (rgb[:, :, 1] <= rgb[:, :, 2] + 2)
    thin = dark & ~(cv2.morphologyEx(dark.astype(np.uint8), cv2.MORPH_OPEN, np.ones((2, 2), np.uint8)) > 0)
    n, labels, stats, _c = cv2.connectedComponentsWithStats(dark.astype(np.uint8), connectivity=8)
    w, h, area = stats[:, cv2.CC_STAT_WIDTH], stats[:, cv2.CC_STAT_HEIGHT], stats[:, cv2.CC_STAT_AREA]
    # A short dark mark such as a slit window stays; a long one, or a sprawling one, is a line.
    line = (np.maximum(w, h) >= LINE_RUN) & ((np.minimum(w, h) == 1) | (area < 0.5 * w * h))
    line[0] = False
    todo = thin & line[labels]
    H, W = dark.shape
    out = arr.copy()
    changed = 0
    for y, x in zip(*np.nonzero(todo)):
        for r in (1, 2):
            y0, y1, x0, x1 = max(0, y - r), min(H, y + r + 1), max(0, x - r), min(W, x + r + 1)
            near = solid[y0:y1, x0:x1] & ~dark[y0:y1, x0:x1]
            if near.any():
                break
        if near.any():
            out[y, x, :3] = np.clip(rgb[y0:y1, x0:x1][near].mean(axis=0) * SHADE, 0, 255)
            changed += 1
    return out, changed


def main(args):
    lines = "--lines" in args
    files = []
    for a in args:
        if a == "--lines":
            continue
        p = Path(a)
        files += sorted(p.rglob("*.png")) if p.is_dir() else [p]
    for f in files:
        n = soften(f)
        if n:
            print(f"softened {n:4d} edge pixels in {f}")
        if lines:
            arr, n = soften_lines(np.array(Image.open(f).convert("RGBA")))
            if n:
                Image.fromarray(arr).save(f)
                print(f"softened {n:4d} line pixels in {f}")


if __name__ == "__main__":
    main(sys.argv[1:])
