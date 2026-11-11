"""Draws a larger, more detailed copy of every fish for the catch banner, into game/assets/art/fish_banner/<id>.png.

The logbook and the sea keep the small pictures in game/assets/art/fish/, so the player learns one look for each fish;
the banner shows the same fish bigger. Each is resized smoothly, then laid back onto the small picture's own colours with
a fine ordered dither, so its shading and scales read as finer pixel work rather than as doubled pixels. A fish is drawn
twice as large, four times for the tiniest, or as large as the banner's cloth has room for. Usage:
python tools/art/make_banner_fish.py [ID...]"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SMALL = ROOT / "game" / "assets" / "art" / "fish"
OUT = ROOT / "game" / "assets" / "art" / "fish_banner"
# The room on the banner's cloth (CatchCard.INSIDE, 154 by 113) left for the fish under a name on one line or on two,
# with the weight, the note and the gaps between them; these match CatchCard in catch_card.gd.
WIDE = 152
TALL = {1: 75, 2: 61}
# The fish whose names CatchCard._title breaks onto two lines.
TWO_LINES = {"bream", "white_bream", "octopus", "golden_mullet", "bonito", "horse_mackerel", "weever", "slipper_lobster",
             "red_scorpionfish", "carteia_octopus", "tiberius_mullet", "hortensius_moray", "orata_bream",
             "claudius_parrotfish", "misenum_swordfish", "wreck_conger", "numbing_ray", "sleeping_sunfish",
             "neptune_lobster"}
# How much larger a fish is drawn, and a tiny one no longer than this many texels.
SCALE = 2.0
TINY, TINY_SCALE = 16, 4.0
BAYER = np.array([[0, 2], [3, 1]]) / 4.0 - 0.375


def scale_for(fid: str, im: Image.Image) -> float:
    s = TINY_SCALE if max(im.size) <= TINY else SCALE
    return min(s, WIDE / im.width, TALL[2 if fid in TWO_LINES else 1] / im.height)


def colours(a: np.ndarray) -> np.ndarray:
    return np.unique(a[a[..., 3] > 127][:, :3], axis=0).astype(np.float32)


def resized(im: Image.Image, w: int, h: int):
    # Colours are resized premultiplied, so the edge does not pick up the black of the clear pixels round it.
    a = np.array(im).astype(np.float32)
    a[..., :3] *= a[..., 3:4] / 255.0
    big = np.array(Image.fromarray(a.astype(np.uint8)).resize((w, h), Image.LANCZOS)).astype(np.float32)
    alpha = np.array(im.getchannel("A").resize((w, h), Image.BICUBIC)).astype(np.float32)
    rgb = big[..., :3] / np.maximum(big[..., 3:4], 1.0) * 255.0
    return np.clip(rgb, 0, 255), alpha


def lone_pixels_cleared(solid: np.ndarray) -> np.ndarray:
    p = np.pad(solid, 1)
    around = sum(np.roll(np.roll(p, dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx)[1:-1, 1:-1]
    return solid & (around >= 2)


def doubled_edges(im: Image.Image) -> Image.Image:
    """Scale2x: each pixel becomes four, rounding off stair steps where its neighbours agree, so edges stay crisp."""
    a = np.array(im)
    p = np.pad(a, ((1, 1), (1, 1), (0, 0)), mode="edge")
    same = lambda x, y: (x == y).all(-1)[..., None]
    mid, up, right, left, down = p[1:-1, 1:-1], p[:-2, 1:-1], p[1:-1, 2:], p[1:-1, :-2], p[2:, 1:-1]
    out = np.zeros((a.shape[0] * 2, a.shape[1] * 2, 4), np.uint8)
    out[0::2, 0::2] = np.where(same(left, up) & ~same(left, down) & ~same(up, right), up, mid)
    out[0::2, 1::2] = np.where(same(up, right) & ~same(up, left) & ~same(right, down), right, mid)
    out[1::2, 0::2] = np.where(same(down, left) & ~same(down, right) & ~same(left, up), left, mid)
    out[1::2, 1::2] = np.where(same(right, down) & ~same(right, up) & ~same(down, left), down, mid)
    return Image.fromarray(out)


def enlarge(im: Image.Image, s: float) -> Image.Image:
    im = im.convert("RGBA")
    # A tiny fish has too few pixels to resize smoothly, so its edges and eye are doubled crisply first.
    if s > 2.0:
        im, s = doubled_edges(im), s / 2.0
    pal = colours(np.array(im))
    w, h = round(im.width * s), round(im.height * s)
    rgb, alpha = resized(im, w, h)
    flat = rgb.reshape(-1, 3)
    order = ((flat[:, None] - pal[None]) ** 2).sum(-1).argsort(1)
    near, next_ = pal[order[:, 0]], pal[order[:, 1]]
    # Between its two nearest colours, a pixel takes the second where the dither's threshold says it is past halfway.
    v = next_ - near
    t = np.clip(((flat - near) * v).sum(1) / np.maximum((v * v).sum(1), 1e-6), 0, 1)
    threshold = np.tile(BAYER, (h // 2 + 1, w // 2 + 1))[:h, :w].reshape(-1) + 0.5
    out = np.where((t > threshold)[:, None], next_, near).reshape(h, w, 3)
    solid = lone_pixels_cleared(alpha > 127)
    return Image.fromarray(np.dstack([out, solid * 255]).astype(np.uint8))


def main(ids):
    OUT.mkdir(parents=True, exist_ok=True)
    fish = json.loads((ROOT / "game" / "data" / "fish.json").read_text(encoding="utf-8"))
    for f in fish:
        fid = f["id"]
        if ids and fid not in ids:
            continue
        im = Image.open(SMALL / f"{fid}.png").convert("RGBA")
        big = enlarge(im, scale_for(fid, im))
        big = big.crop(big.getbbox())
        big.save(OUT / f"{fid}.png")
        print(fid, im.size, "->", big.size)


if __name__ == "__main__":
    main(sys.argv[1:])
