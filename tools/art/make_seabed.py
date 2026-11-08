"""Draws each place's sea floor strip without PixelLab: a smooth band of soft sand or mud in the place's own colour, with
gentle tonal variation, faint speckle and a lighter top edge, darkening into the ground below. It joins seamlessly onto
itself, since FloorView lays it along the seabed line again and again. The colour comes from "floor": {"sand": colour}
in tools/art/places/<id>.json. Usage: python tools/art/make_seabed.py [PLACE...]"""
import json
import sys
import zlib
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SPECS = Path(__file__).with_name("places")
ART = ROOT / "game" / "assets" / "art"
WIDTH, HEIGHT = 1024, 64
# Matches FloorView.SHADOW, the ground below the strip.
SHADOW = np.array([0x14, 0x22, 0x2A], dtype=np.float64) / 255
# How much lighter or darker each tone is than the sand's own colour.
STEP = 0.06
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.47


def wave(xs, rng, parts):
    """A sum of sines that each fit a whole number of times into the strip's width, so it joins onto itself."""
    out = np.zeros(len(xs))
    for amount, low, high in parts:
        out += amount * np.sin(2 * np.pi * rng.integers(low, high) * xs / WIDTH + rng.uniform(0, 2 * np.pi))
    return out


def tileable_noise(rng, cells_x, cells_y):
    """Smooth value noise over the strip, as many cells across as fit whole, wrapping round at its sides."""
    grid = rng.uniform(-1, 1, (cells_y + 2, cells_x))
    ys, xs = np.mgrid[0:HEIGHT, 0:WIDTH]
    gx = xs / WIDTH * cells_x
    gy = ys / HEIGHT * cells_y
    x0, y0 = np.floor(gx).astype(int), np.floor(gy).astype(int)
    tx, ty = gx - x0, gy - y0
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    x1 = (x0 + 1) % cells_x
    top = grid[y0, x0 % cells_x] * (1 - tx) + grid[y0, x1] * tx
    bottom = grid[y0 + 1, x0 % cells_x] * (1 - tx) + grid[y0 + 1, x1] * tx
    return top * (1 - ty) + bottom * ty


def paint(out: Path, sand: str, surface: int = 6, seed: str = ""):
    rng = np.random.default_rng(zlib.crc32((seed or out.parent.name).encode()))
    base = np.array([int(sand[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float64) / 255
    xs = np.arange(WIDTH)
    tops = surface + np.round(wave(xs, rng, [(1.4, 3, 6), (0.9, 11, 17), (0.4, 29, 41)])).astype(int)
    ys = np.arange(HEIGHT)[:, None]
    below = ys - tops[None, :]
    # Soft strata that wander a little across, and broad patches of lighter and darker sand.
    drift = wave(xs, rng, [(2.0, 2, 5), (1.0, 7, 12)])[None, :]
    strata = 0.35 * np.sin(2 * np.pi * (below + drift) / rng.uniform(9, 13))
    level = strata + 0.8 * tileable_noise(rng, 16, 3)
    level[below == 0] = 2.0
    level[below == 1] = 1.0
    # A few grains a shade darker or lighter, never bright enough to read as a pebble.
    speckle = rng.random((HEIGHT, WIDTH))
    level = np.where((speckle < 0.025) & (below > 2), level - 1, level)
    level = np.where((speckle > 0.993) & (below > 2), level + 0.4, level)
    tone = np.round(level + BAYER[ys % 4, xs[None, :] % 4] * 0.9)
    # Only the top edge is as light as two shades up, so no grain in the sand below can shine like a shell.
    tone = np.where(below > 1, np.clip(tone, -2, 1), tone)
    colour = base[None, None, :] * (1 + STEP * tone[:, :, None])
    # Down into the ground the sand darkens to the shadow, in dithered steps.
    sink = np.clip((below - 18) / (HEIGHT - surface - 20), 0, 1) ** 1.1
    sink = np.clip(np.round(sink * 16 + BAYER[ys % 4, xs[None, :] % 4]) / 16, 0, 1)
    colour = colour * (1 - sink[:, :, None]) + SHADOW[None, None, :] * sink[:, :, None]
    alpha = np.where(below >= 0, 255, 0)
    img = np.dstack([np.clip(colour * 255, 0, 255).round(), alpha]).astype(np.uint8)
    out.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(img, "RGBA").save(out)


def make(pid: str):
    spec = json.loads((SPECS / f"{pid}.json").read_text(encoding="utf-8"))
    floor = spec["floor"]
    paint(ART / "places" / pid / "floor.png", floor["sand"], int(floor.get("surface", 6)), pid)
    print("drew", pid, "floor")


if __name__ == "__main__":
    for pid in sys.argv[1:] or [p.stem for p in sorted(SPECS.glob("*.json"))]:
        make(pid)
