"""Builds the animated title from the approved sunset style test: the left shore carried down into the water as the
cliff's own rock, more sky above and sea floor below so a taller window shows no bars, the painted bubbles taken out
(the game draws rising ones), the sky cleared of its clouds so the whole ones and three painted to match can drift
across it, and a mask for the swaying trees and weed. Writes game/assets/art/title/. Usage: python tools/art/make_title.py"""
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "game" / "assets" / "art" / "style_test" / "background.png"
OUT = ROOT / "game" / "assets" / "art" / "title"
WORK = Path(__file__).with_name("title_parts")
PAD = 40
WATERLINE = 124
HORIZON = 86
SHADOW = np.array([0x14, 0x22, 0x2A], dtype=float)


# The first row under the lit line of the water's surface, and the rows of the cliff whose texture the bank copies.
SURFACE = 134
CLIFF_ROWS = (140, 172)
# Where the bank under the road meets the painted cliff's own edge.
JOIN = 178


def is_cliff(px) -> bool:
    r, g, b = int(px[0]), int(px[1]), int(px[2])
    return r < 80 and b >= r + 10 and r + g + b < 330


def cliff_edge(img: np.ndarray, y: int) -> int:
    """Where the painted cliff ends in a row, allowing the odd lighter pixel inside it."""
    x, last, gap = 0, 0, 0
    while x < img.shape[1] // 2:
        if is_cliff(img[y, x]):
            last, gap = x, 0
        else:
            gap += 1
            if gap > 3:
                break
        x += 1
    return last + 1


def land_end(img: np.ndarray) -> int:
    """How far the road and the quay reach along the row just above the water's surface."""
    y = SURFACE - 3
    x = 0
    while x < img.shape[1] and not (int(img[y, x, 2]) > int(img[y, x, 0]) + 20):
        x += 1
    return x


def with_bank(img: np.ndarray) -> np.ndarray:
    """Carries the left shore down into the sea: the land above the water goes on as the cliff's own rock, its lit rim
    sloping from the end of the road down to where the painted cliff takes over, textured by copying the cliff at the
    same distance from its edge."""
    src = img.copy()
    out = img.copy()
    edges = {y: cliff_edge(src, y) for y in range(CLIFF_ROWS[0], CLIFF_ROWS[1] + 1)}
    top = land_end(src)
    rng = np.random.default_rng(5)
    jitter = 0.0
    for y in range(SURFACE, JOIN):
        t = (y - SURFACE) / (JOIN - SURFACE)
        joint = cliff_edge(src, y) if y >= CLIFF_ROWS[0] else edges[CLIFF_ROWS[0]]
        jitter = float(np.clip(jitter + rng.normal(0, 0.7), -2, 2))
        right = int(round(joint + (top - joint) * (1 - t) ** 1.3 + jitter * (1 - t)))
        ys = CLIFF_ROWS[0] + int(t * (CLIFF_ROWS[1] - CLIFF_ROWS[0]))
        for x in range(0, right):
            d = right - 1 - x
            sx = edges[ys] - 1 - d
            if sx >= 0:
                out[y, x, :3] = src[ys, sx, :3]
            else:
                # Deep in the rock the cliff's own inner texture carries on, away from its lit rim.
                out[y, x, :3] = src[ys, sx % max(1, edges[ys] - 16), :3]
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


# The painting's sky is drawn in a few colours: these are its open sky, from the high dusky rose down to the glow
# round the sun, and these its clouds.
SKY = [(217, 157, 150), (247, 161, 100), (252, 190, 107), (254, 207, 132), (254, 232, 173), (254, 242, 194)]
CLOUD = [(181, 103, 102), (202, 122, 111), (208, 126, 111), (244, 157, 101), (249, 166, 101), (253, 220, 154),
         (251, 184, 115), (232, 145, 103)]
# Clouds painted for the title in the same colours, drifting with the painting's own whole clouds.
NEW_CLOUDS = [("cloud_a.png", 300, 6), ("cloud_b.png", 20, 14), ("cloud_c.png", 380, 30)]


def colours_in(rgb: np.ndarray, colours: list) -> np.ndarray:
    found = np.zeros(rgb.shape[:2], dtype=bool)
    for c in colours:
        found |= (rgb == c).all(axis=2)
    return found


def sky_mask(img: np.ndarray) -> np.ndarray:
    """The sky and its clouds: everything reached from the top edge through the sky's own colours, above the sea."""
    rgb = img[:, :, :3].astype(int)
    h, w = rgb.shape[:2]
    open_sky = colours_in(rgb, SKY + CLOUD)
    sky = np.zeros((h, w), dtype=bool)
    stack = [(0, x) for x in range(w) if open_sky[0, x]]
    while stack:
        y, x = stack.pop()
        if y < 0 or y >= HORIZON or x < 0 or x >= w or sky[y, x] or not open_sky[y, x]:
            continue
        sky[y, x] = True
        stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    return sky


def clear_sky(img: np.ndarray, sky: np.ndarray) -> np.ndarray:
    """The sky with its clouds taken out: each cloud pixel takes the commonest sky colour near it in its own row, so
    the sunset's bands carry on behind where the clouds were."""
    out = img.copy()
    rgb = img[:, :, :3].astype(int)
    cloud = sky & colours_in(rgb, CLOUD)
    open_sky = sky & ~cloud
    for y, x in zip(*np.nonzero(cloud)):
        for reach in (24, 60, 480):
            near = [tuple(rgb[y, k]) for k in range(max(0, x - reach), min(img.shape[1], x + reach + 1)) if open_sky[y, k]]
            if near:
                out[y, x, :3] = max(set(near), key=near.count)
                break
    return out


def whole_clouds(img: np.ndarray, sky: np.ndarray) -> list:
    """The painted clouds that can drift: those touching neither the picture's edge nor the land, as pictures with
    the row and column they were painted at."""
    rgb = img[:, :, :3].astype(int)
    cloud = (sky & colours_in(rgb, CLOUD)).astype(np.uint8)
    n, labels, stats, _ = cv2.connectedComponentsWithStats(cloud, connectivity=8)
    found = []
    for i in range(1, n):
        x, y, w, h, area = stats[i]
        if area < 100 or x == 0 or y == 0 or x + w >= img.shape[1]:
            continue
        shape = (labels == i).astype(np.uint8)
        if (cv2.dilate(shape, np.ones((3, 3), np.uint8)).astype(bool) & ~sky).any():
            continue
        # Sky showing through gaps inside the cloud stays part of it, so nothing behind shows through as it moves.
        filled = shape[y:y + h, x:x + w].copy()
        flood = np.pad(filled, 1)
        cv2.floodFill(flood, None, (0, 0), 2)
        solid = flood[1:-1, 1:-1] != 2
        piece = np.zeros((h, w, 4), dtype=np.uint8)
        piece[:, :, :3] = img[y:y + h, x:x + w, :3]
        piece[:, :, 3] = np.where(solid, 255, 0)
        found.append((piece, int(x), int(y)))
    return found


def painted_cloud(path: Path) -> np.ndarray:
    """A cloud painted for the title, with its colours matched to the painting's and its stray specks dropped."""
    im = np.array(Image.open(path).convert("RGBA"))
    solid = (im[:, :, 3] > 127).astype(np.uint8)
    n, labels, stats, _ = cv2.connectedComponentsWithStats(solid, connectivity=8)
    keep = np.zeros_like(solid, dtype=bool)
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_AREA] >= 6:
            keep |= labels == i
    palette = np.array(SKY + CLOUD, dtype=float)
    rgb = im[:, :, :3].astype(float)
    nearest = np.argmin(((rgb[:, :, None, :] - palette[None, None]) ** 2).sum(axis=3), axis=2)
    out = np.zeros_like(im)
    out[:, :, :3] = palette[nearest].astype(np.uint8)
    out[:, :, 3] = np.where(keep, 255, 0)
    ys, xs = np.nonzero(keep)
    return out[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


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
    for old in OUT.glob("cloud_*.png"):
        old.unlink()
    src = with_bank(np.array(Image.open(SRC).convert("RGBA")))
    sky = sky_mask(src)
    clouds = whole_clouds(src, sky)
    clear = clear_sky(src, sky)
    img = without_bubbles(taller(clear))
    tall_sky = np.zeros(img.shape[:2], dtype=bool)
    tall_sky[:PAD] = True
    tall_sky[PAD:PAD + sky.shape[0]] = sky
    land = img.copy()
    land[:, :, 3] = np.where(tall_sky, 0, 255)
    Image.fromarray(land).save(OUT / "land.png")
    Image.fromarray(sway_mask(img, tall_sky)).save(OUT / "sway.png")
    # The sky alone, each column's sky colour carried down over everything that is not sky, so whatever sways in front
    # of it shows sky behind and never a still copy of itself.
    only = img.copy()
    for x in range(img.shape[1]):
        last = img[0, x, :3]
        for y in range(img.shape[0]):
            if tall_sky[y, x]:
                last = img[y, x, :3]
            else:
                only[y, x, :3] = last
    Image.fromarray(only).save(OUT / "sky.png")
    drift = []
    for piece, x, y in clouds:
        drift.append((piece, x, y + PAD))
    for name, x, y in NEW_CLOUDS:
        drift.append((painted_cloud(WORK / name), x, y + PAD))
    listed = []
    for i, (piece, x, y) in enumerate(drift):
        Image.fromarray(piece).save(OUT / f"cloud_{i}.png")
        listed.append({"file": f"cloud_{i}.png", "x": x, "y": y})
    (OUT / "title.json").write_text(json.dumps({"waterline": WATERLINE + PAD, "pad": PAD, "horizon": HORIZON + PAD,
                                                "clouds": listed}))
    print("title written", img.shape[1], img.shape[0], "with", len(listed), "clouds")


if __name__ == "__main__":
    main()
