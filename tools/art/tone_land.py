"""Brings a row of land into the colours of the harbour's cape, so every place's land shares one look: its greens take
the cape's olive scrub and dark pines and its rock and earth the cape's limestone, each at the same lightness as in the
cape, keeping the picture's own shading and small differences of colour. A little haze then pales and blues the land
by its distance. Roofs, walls and anything else not green or rocky keep their colours under the haze.
Usage: python tools/art/tone_land.py SOURCE OUT [--haze 0.12] [--rock 0.8] [--green 1.0]
make_places.py runs it on every land layer with a "tone" in its spec, from a copy kept in parts/<place>/."""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
CAPE = ROOT / "game" / "assets" / "art" / "places" / "harbour" / "cape.png"
HAZE = np.array([0xb4, 0xc4, 0xcc], dtype=np.float32) / 255.0
BINS = 48


def to_oklab(rgb):
    c = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    m1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929], [0.2119034982, 0.6806995451, 0.1073969566],
                   [0.0883024619, 0.2817188376, 0.6299787005]])
    m2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468], [1.9779984951, -2.4285922050, 0.4505937099],
                   [0.0259040371, 0.7827717662, -0.8086757660]])
    return np.cbrt(c @ m1.T) @ m2.T


def from_oklab(lab):
    m2 = np.array([[1.0, 0.3963377774, 0.2158037573], [1.0, -0.1055613458, -0.0638541728],
                   [1.0, -0.0894841775, -1.2914855480]])
    m1 = np.array([[4.0767416621, -3.3077115913, 0.2309699292], [-1.2684380046, 2.6097574011, -0.3413193965],
                   [-0.0041960863, -0.7034186147, 1.7076147010]])
    c = np.clip((lab @ m2.T) ** 3 @ m1.T, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def kinds(rgb):
    """Which pixels are green growth and which rock or earth, from their hue, colourfulness and lightness."""
    mx, mn = rgb.max(-1), rgb.min(-1)
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    d = np.maximum(mx - mn, 1e-6)
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    wall = ((s < 0.3) & (mx > 0.8)) | ((s < 0.2) & (mx > 0.7))
    green = (h >= 42) & (h <= 175) & ((s > 0.16) | ((mx < 0.3) & (s > 0.08))) & ~wall
    roof = (h < 26) & (s > 0.42) & (mx > 0.35)
    rock = ~green & ~roof & ~wall
    return green, rock


def ramp(lab):
    """The mean colour of a set of pixels at each lightness, and the share of them at or below each lightness."""
    bins = np.clip((lab[:, 0] * BINS).astype(int), 0, BINS - 1)
    counts = np.bincount(bins, minlength=BINS).astype(np.float64)
    mean = np.zeros((BINS, 2))
    for k in (1, 2):
        mean[:, k - 1] = np.bincount(bins, lab[:, k], minlength=BINS) / np.maximum(counts, 1)
    have = counts > 0
    xs = np.arange(BINS)
    for k in range(2):
        mean[:, k] = np.interp(xs, xs[have], mean[have, k])
    return mean, np.sort(lab[:, 0])


def match(lab, theirs, strength, keep=0.6):
    """Moves pixels onto the cape's colours: lightness by rank, then the cape's colour at that lightness plus some of how
    far each pixel stood from its own picture's colour at its old lightness."""
    if not len(lab):
        return lab
    own_mean, own_sorted = ramp(lab)
    cape_mean, cape_sorted = theirs
    rank = np.searchsorted(own_sorted, lab[:, 0]) / max(1, len(own_sorted) - 1)
    light = np.interp(np.clip(rank, 0, 1), np.linspace(0, 1, len(cape_sorted)), cape_sorted)
    old = np.clip((lab[:, 0] * BINS).astype(int), 0, BINS - 1)
    new = np.clip((light * BINS).astype(int), 0, BINS - 1)
    ab = cape_mean[new] + keep * (lab[:, 1:] - own_mean[old])
    out = np.concatenate([light[:, None], ab], axis=1)
    return lab + (out - lab) * strength


def tone(src: Image.Image, haze=0.0, rock=0.8, green=1.0, far=False) -> Image.Image:
    """A far row's bare slopes take the cape's land as a whole, scrub and rock together, as distant hills show them."""
    arr = np.array(src.convert("RGBA")).astype(np.float32)
    rgb = arr[..., :3] / 255.0
    seen = arr[..., 3] > 0
    cape = np.array(Image.open(CAPE).convert("RGBA")).astype(np.float32)
    cape_rgb = cape[..., :3][cape[..., 3] > 200] / 255.0
    cape_green, cape_rock = kinds(cape_rgb)
    cape_lab = to_oklab(cape_rgb)
    lab = to_oklab(rgb)
    is_green, is_rock = kinds(rgb)
    bare = cape_lab[cape_green | cape_rock] if far else cape_lab[cape_rock]
    keep = 0.15 if far else 0.6
    for mask, ref, strength in ((is_green & seen, cape_lab[cape_green], green), (is_rock & seen, bare, rock)):
        if strength > 0 and mask.any():
            lab[mask] = match(lab[mask], ramp(ref), strength, keep)
    out = from_oklab(lab)
    out = out * (1 - haze) + HAZE * haze
    arr[..., :3] = np.where(seen[..., None], np.clip(out * 255 + 0.5, 0, 255), arr[..., :3])
    return Image.fromarray(arr.astype(np.uint8))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("source")
    ap.add_argument("out")
    ap.add_argument("--haze", type=float, default=0.0)
    ap.add_argument("--rock", type=float, default=0.8)
    ap.add_argument("--green", type=float, default=1.0)
    ap.add_argument("--far", action="store_true")
    a = ap.parse_args()
    tone(Image.open(a.source), a.haze, a.rock, a.green, a.far).save(a.out)
    print("toned", a.out)
