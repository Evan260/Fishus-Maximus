"""Builds the animated title from the approved sunset style test: the left shore carried down into the water as rock
so the road no longer stops at the waterline, more sky above and sea floor below so a taller window shows no bars, the
painted bubbles taken out (the game draws rising ones), and masks for the drifting clouds and the swaying trees and
weed. Writes game/assets/art/title/. Usage: python tools/art/make_title.py"""
import json
import shutil
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

import make_town as mt

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "game" / "assets" / "art" / "style_test" / "background.png"
OUT = ROOT / "game" / "assets" / "art" / "title"
WORK = Path(__file__).with_name("title_parts")
PAD = 40
WATERLINE = 124
HORIZON = 86
SHADOW = np.array([0x14, 0x22, 0x2A], dtype=float)


## The cliff's own colours, from its lit rim inwards.
BANDS = [(2, (52, 116, 120)), (6, (39, 100, 107)), (14, (18, 82, 90)), (30, (11, 52, 62)), (9999, (6, 28, 38))]


def with_bank(img: np.ndarray) -> np.ndarray:
    """Carries the left shore down into the sea: the rock of the cliff on the left continues under the road from the
    waterline and falls away to meet the cliff, shaded in the cliff's own bands parallel to its ragged edge."""
    out = img.copy()
    rng = np.random.default_rng(3)
    jitter = 0.0
    for y in range(WATERLINE + 1, WATERLINE + 92):
        k = (y - WATERLINE) / 91.0
        jitter = float(np.clip(jitter + rng.normal(0, 0.8), -3, 3))
        right = int(round(218 - 160 * (k ** 0.7) + jitter))
        for x in range(0, max(0, right)):
            d = right - x + (1 if (x * 7 + y * 3) % 11 == 0 else 0)
            colour = next(c for limit, c in BANDS if d <= limit)
            # Specks and short ledges in the deep rock, so it is stone and not a flat shape.
            if d > 14 and (rng.random() < 0.025 or (y % 11 == 0 and (x * 3 + y) % 29 < 9)):
                colour = (18, 82, 90) if d > 30 else (39, 100, 107)
            # Only the open water becomes rock; the painted cliff keeps its own detail.
            if out[y, x, :3].astype(int).sum() > 250:
                out[y, x, :3] = colour
    return out


def taller(img: np.ndarray) -> np.ndarray:
    """More sky above and sea floor below: the sky's colour carried up with the painted clouds fading into it, and the
    sand fading into the dark ground under the sea, so neither ends on a line."""
    h, w = img.shape[:2]
    out = np.zeros((h + 2 * PAD, w, 4), dtype=float)
    out[:, :, 3] = 255
    out[PAD:PAD + h] = img
    top = img[0:4, :, :3].astype(float).mean(axis=(0, 1))
    for y in range(PAD):
        out[y, :, :3] = top * (0.82 + 0.18 * y / PAD)
    fade = 14
    for k in range(fade):
        a = k / fade
        out[PAD + k, :, :3] = out[PAD - 1, :, :3] * (1 - a) + img[k, :, :3] * a
    bottom = img[h - 1, :, :3].astype(float)
    for k in range(PAD + 10):
        y = PAD + h - 10 + k
        if y >= out.shape[0]:
            break
        a = min(1.0, (k / (PAD * 0.7)) ** 1.2)
        src = img[min(h - 1, h - 10 + k), :, :3].astype(float) if k < 10 else bottom
        out[y, :, :3] = src * (1 - a) + SHADOW * a
    return out.astype(np.uint8)


def without_bubbles(img: np.ndarray) -> np.ndarray:
    """Paints out the small pale rings under the water, filling them from the water around them."""
    rgb = img[:, :, :3].copy()
    under = np.zeros(rgb.shape[:2], dtype=bool)
    under[WATERLINE + PAD + 6:, :] = True
    light = (rgb.min(axis=2) > 170) & under
    n, labels, stats, _ = cv2.connectedComponentsWithStats(light.astype(np.uint8), connectivity=8)
    mask = np.zeros(rgb.shape[:2], dtype=np.uint8)
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_AREA] <= 40 and stats[i, cv2.CC_STAT_WIDTH] <= 9 and stats[i, cv2.CC_STAT_HEIGHT] <= 9:
            mask[labels == i] = 255
    mask = cv2.dilate(mask, np.ones((3, 3), np.uint8))
    bgr = cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)
    fixed = cv2.cvtColor(cv2.inpaint(bgr, mask, 3, cv2.INPAINT_TELEA), cv2.COLOR_BGR2RGB)
    out = img.copy()
    out[:, :, :3] = fixed
    return out


def sky_mask(img: np.ndarray) -> np.ndarray:
    """The sky: everything reached from the top edge through sunset colours, down to the sea's horizon."""
    rgb = img[:, :, :3].astype(int)
    h, w = rgb.shape[:2]
    warm = (rgb[:, :, 0] > rgb[:, :, 2] + 10) | (rgb.sum(axis=2) > 600)
    sky = np.zeros((h, w), dtype=bool)
    stack = [(0, x) for x in range(w) if warm[0, x]]
    limit = HORIZON + PAD
    while stack:
        y, x = stack.pop()
        if y < 0 or y >= limit or x < 0 or x >= w or sky[y, x] or not warm[y, x]:
            continue
        sky[y, x] = True
        stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    return sky


def sway_mask(img: np.ndarray, sky: np.ndarray) -> np.ndarray:
    """How much each pixel sways: the trees on the left above the water, and the green weed below it."""
    rgb = img[:, :, :3].astype(int)
    h, w = rgb.shape[:2]
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    y = np.arange(h)[:, None]
    x = np.arange(w)[None, :]
    trees = (g > r + 12) & (g > b + 12) & ~sky & (y < WATERLINE + PAD - 6) & (x < 150)
    weed = (g > r + 30) & (g > b + 25) & (y > WATERLINE + PAD + 30)
    m = (trees | weed).astype(np.uint8) * 255
    m = cv2.dilate(m, np.ones((3, 3), np.uint8))
    return cv2.GaussianBlur(m, (3, 3), 0)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    img = without_bubbles(taller(with_bank(np.array(Image.open(SRC).convert("RGBA")))))
    Image.fromarray(img).save(OUT / "base.png")
    sky = sky_mask(img)
    land = img.copy()
    land[:, :, 3] = np.where(sky, 0, 255)
    Image.fromarray(land).save(OUT / "land.png")
    Image.fromarray(sway_mask(img, sky)).save(OUT / "sway.png")
    # The sky alone, with each column's lowest sky colour carried down behind the land, so whatever sways or drifts in
    # front of it shows sky behind.
    only = img.copy()
    for x in range(img.shape[1]):
        rows = np.where(sky[:, x])[0]
        if rows.size:
            only[rows[-1] + 1:, x, :3] = img[rows[-1], x, :3]
    Image.fromarray(only).save(OUT / "sky.png")
    (OUT / "title.json").write_text(json.dumps({"waterline": WATERLINE + PAD, "pad": PAD, "horizon": HORIZON + PAD}))
    print("title written", img.shape[1], img.shape[0])


if __name__ == "__main__":
    main()
