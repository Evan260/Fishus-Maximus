"""Takes the dark outline off painted sprites the way pixel artists do by hand: each near-black pixel along the edge
of a sprite becomes a darker shade of the colour just inside it, so the edge reads without a black line round it.
Sprites with no dark rim are left as they are. Writes the pictures back in place.
Usage: python tools/art/soften_outlines.py PATH [PATH...]   (files or folders of .png)"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

# How dark an edge pixel must be, absolutely and against the colour inside it, to count as outline.
DARK = 70.0
AGAINST = 0.62
# How much darker than the colour inside it a softened edge pixel is drawn.
SHADE = 0.74


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


def main(args):
    files = []
    for a in args:
        p = Path(a)
        files += sorted(p.rglob("*.png")) if p.is_dir() else [p]
    for f in files:
        n = soften(f)
        if n:
            print(f"softened {n:4d} edge pixels in {f}")


if __name__ == "__main__":
    main(sys.argv[1:])
