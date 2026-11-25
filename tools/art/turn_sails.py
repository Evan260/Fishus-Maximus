"""Turns a sailing boat's square sail from facing us to set across the hull, as a sail running before the wind is. Seen
from the side it is turned well away from us: a narrow sheet hanging from a short yard angled towards the bow, its belly
filled and bulging out towards the bow, the way the boat goes. The old sail, its yards and the ropes tied to them are
cleared from the boat's picture as make_props.py and round_keels.py left it (kept in props_raw as <boat>_square_sail.png
the first time), keeping the hull, the mast and its flag, and the new sail is drawn pixel by pixel in the old sail's own
colours: the cloth shaded by how it faces the light from the upper left, its reinforcing bands following the curve of
the cloth, the yard in the old yard's colours and the ropes drawn again to the masthead, the yard and the sail's lower
corners. A flag painted streaming aft is turned round its masthead to stream towards the bow, as the wind behind the
sail blows it. Prints the sail's corners for boats.json, the box the sail shader moves. Writes the boats to
game/assets/art/props/; running it again gives the same pictures. With --icons it turns the two boats' achievement
icons, painted small in tools/art/achievements_raw/ (their originals kept there as <boat>_square_sail.png), in the same
way at their own size, for make_achievement_icons.py.
Usage: python tools/art/turn_sails.py [--icons] [--out DIR] [BOAT...]"""
import math
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
RAW = Path(__file__).with_name("props_raw")
ICON_RAW = Path(__file__).with_name("achievements_raw")
PROPS = ROOT / "game" / "assets" / "art" / "props"
# The light, from the upper left and in front: x towards the bow, y up, z towards us.
LIGHT = np.array([-0.62, 0.55, 0.56])
# How many samples to a pixel side the cloth is worked out on before each pixel takes the cloth that covers most of it.
SS = 4

# Per boat, from its old sail's own pixels: the cloth from lit to shaded, its bands and edges from light to dark, the
# yard from its top row down and its ends, and a rope's shades, a rope `wide` being drawn three pixels across, dark,
# light and dark. Then the mast's columns, the rows of it drawn again in the colours of a row it shows bare
# (`mast_rows`: the first and the bare one), and the row its yard crosses it; the sail's width and height as if laid
# flat, how far it is turned from pointing straight at us, how much lower its near end sits for every pixel nearer us,
# and how deep its belly is; the cells of its bands across and down. What is cleared: either every column down to its
# solid run up from the keel, with the boxes in `keep` kept, or the polygons in `clear` and the ropes inside the boxes
# in `clear_ropes`. Last the ropes, each from a pixel of the hull to a point on the mast, a yardarm or a lower corner of
# the sail, and a flag to turn round: its top and bottom rows and the first and last columns of the masthead it flies
# from.
BOATS = {
    "sailing_boat": {
        "cloth": [(238, 219, 192), (231, 209, 177), (221, 199, 162), (213, 190, 152), (205, 180, 142),
                  (199, 170, 132), (190, 157, 123)],
        "band": [(199, 170, 132), (190, 157, 123), (184, 146, 116), (180, 137, 110), (173, 128, 101), (160, 112, 86)],
        "yard": [(140, 78, 53), (207, 121, 80), (103, 39, 35)], "yard_end": (99, 35, 31),
        "rope": [(66, 25, 25), (76, 29, 28)], "wide": False,
        "mast": (61, 64), "mast_rows": (8, 60), "cross": 10.0,
        "width": 70.0, "height": 44.0, "turn": 14.0, "tilt": 0.12, "belly": 18.0, "cells": (4, 5),
        "keep": [(60, 0, 71, 6)],
        "ropes": [((36, 68), "mast", (60, 7)), ((22, 60), "near_arm", None), ((52, 70), "near_clew", None),
                  ((77, 70), "far_clew", None)],
    },
    "big_boat": {
        "cloth": [(246, 212, 155), (234, 200, 144), (219, 185, 128), (208, 174, 119), (196, 162, 107),
                  (190, 156, 102), (175, 143, 94)],
        "band": [(196, 162, 107), (175, 143, 94), (162, 131, 89), (149, 121, 84), (131, 108, 81), (118, 96, 70)],
        "yard": [(100, 56, 32), (143, 76, 44), (105, 67, 40)], "yard_end": (77, 45, 30),
        "rope": [(114, 99, 87), (155, 135, 118), (194, 173, 151)], "wide": True,
        "mast": (69, 73), "mast_rows": (12, 66), "cross": 16.0,
        "width": 60.0, "height": 42.0, "turn": 14.0, "tilt": 0.12, "belly": 17.0, "cells": (4, 5),
        "clear": [[(50, 9), (66, 9), (66, 12), (78, 12), (91, 21), (91, 31), (87, 57), (87, 62), (50, 62)],
                  [(74, 59), (83, 61), (83, 64), (74, 64)]],
        "clear_ropes": [(40, 12, 108, 58), (48, 59, 67, 69)],
        "ropes": [((41, 59), "mast", (68, 14)), ((102, 58), "mast", (75, 15)), ((108, 54), "mast", (91, 40)),
                  ((57, 70), "near_clew", None), ((88, 62), "far_clew", None)],
        "flag": (0, 4, 70, 73),
    },
}


# The icons' boats are about half the game's size, so each sail is too, with fewer bands and thinner ropes.
ICONS = {
    "sailing_boat": {
        "cloth": [(229, 199, 157), (224, 193, 149), (214, 179, 135), (203, 166, 121), (192, 153, 110)],
        "band": [(192, 153, 110), (184, 143, 100), (173, 130, 90), (159, 114, 80), (144, 84, 56)],
        "yard": [(141, 65, 40), (103, 47, 34)], "yard_end": (81, 37, 28),
        "rope": [(159, 114, 80), (173, 130, 90)], "wide": False,
        "mast": (28, 29), "mast_rows": (5, 15), "cross": 9.0,
        "width": 35.0, "height": 16.0, "turn": 14.0, "tilt": 0.12, "belly": 9.0, "cells": (3, 4),
        "clear": [[(6, 4), (27, 4), (27, 30), (13, 30), (13, 29), (6, 29)],
                  [(30, 5), (48, 5), (48, 21), (46, 21), (46, 29), (44, 29), (44, 30), (30, 30)]],
        "clear_ropes": [],
        "ropes": [((18, 30), "mast", (27, 5)), ((11, 29), "near_arm", None), ((26, 30), "near_clew", None),
                  ((38, 30), "far_clew", None)],
    },
    "big_boat": {
        "cloth": [(249, 230, 191), (236, 213, 171), (221, 198, 153), (204, 178, 130), (190, 163, 119)],
        "band": [(190, 163, 119), (178, 140, 92), (153, 124, 85), (126, 92, 54), (108, 58, 25)],
        "yard": [(177, 111, 46), (108, 58, 25)], "yard_end": (68, 27, 7),
        "rope": [(135, 131, 134), (164, 167, 175)], "wide": False,
        "mast": (28, 29), "mast_rows": (5, 29), "cross": 8.0,
        "width": 30.0, "height": 16.0, "turn": 14.0, "tilt": 0.12, "belly": 8.0, "cells": (3, 4),
        "clear": [[(17, 5), (44, 5), (44, 26), (17, 26)], [(19, 27), (27, 27), (27, 30), (19, 30)],
                  [(30, 27), (37, 27), (37, 30), (30, 30)]],
        "clear_ropes": [(12, 5, 50, 30)],
        "ropes": [((14, 24), "mast", (27, 7)), ((48, 25), "mast", (30, 7)), ((25, 30), "near_clew", None),
                  ((39, 30), "far_clew", None)],
    },
}


def lum(c) -> float:
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def is_rope(c) -> bool:
    """A rope of the big boat's rigging, as BoatView.is_rope finds it."""
    r, g, b, a = (float(v) / 255.0 for v in c)
    return a > 0.5 and r > 0.28 and r - g < 0.1 and r - b < 0.2


def kept_part(im: np.ndarray, spec: dict) -> np.ndarray:
    """The hull, mast and flag: what is left once the old sail, its yards and its ropes are cleared."""
    h, w = im.shape[:2]
    solid = im[:, :, 3] > 127
    if "clear" in spec:
        gone = Image.new("L", (w, h), 0)
        for poly in spec["clear"]:
            ImageDraw.Draw(gone).polygon(poly, fill=255)
        mask = solid & (np.array(gone) == 0)
        for x0, y0, x1, y1 in spec["clear_ropes"]:
            for y in range(y0, y1 + 1):
                for x in range(x0, x1 + 1):
                    if is_rope(im[y, x]):
                        mask[y, x] = False
        return mask
    mask = np.zeros((h, w), bool)
    for x in range(w):
        ys = np.nonzero(solid[:, x])[0]
        y = ys[-1] if len(ys) else -1
        while y >= 0 and solid[y, x]:
            mask[y, x] = True
            y -= 1
    for x0, y0, x1, y1 in spec["keep"]:
        mask[y0:y1 + 1, x0:x1 + 1] |= solid[y0:y1 + 1, x0:x1 + 1]
    return mask


class Sail:
    """The turned sail as a surface: u across it from its far edge (-1) to its near edge (1), v down from the yard.
    Its near edge is turned aft, so we see the outside of its belly."""

    def __init__(self, spec: dict):
        self.s = spec
        self.mx = (spec["mast"][0] + spec["mast"][1] + 1) / 2.0
        self.half = spec["width"] / 2.0
        self.th = math.radians(spec["turn"])

    def point(self, u, v):
        """The point in the world (x towards the bow, y up, z towards us) and on the picture."""
        s = self.s
        f = np.sin(np.pi * np.clip(v, 0, 1) * 0.85)
        # The belly is deepest in the middle, and the edges, held only at the corners, belly out a little too.
        g = (0.22 + 0.78 * (1.0 - u ** 2)) * f
        x = -u * self.half * math.sin(self.th) + s["belly"] * g * math.cos(self.th)
        z = u * self.half * math.cos(self.th) + s["belly"] * g * math.sin(self.th)
        y = -v * s["height"]
        return x, y, z, self.mx + x, s["cross"] + 2.0 - y + s["tilt"] * z

    def yard_at(self, k: float):
        """A point along the yard, from its far end (-1) to its near end (1), on the picture."""
        reach = (self.half + 3.0) * k
        return self.mx - reach * math.sin(self.th), self.s["cross"] + self.s["tilt"] * reach * math.cos(self.th)

    def corner(self, u: float, v: float):
        _, _, _, sx, sy = self.point(np.array([u]), np.array([v]))
        return float(sx[0]), float(sy[0])


def render(sail: Sail, shape: tuple):
    """The frontmost cloth on a grid SS times finer than the picture: its depth, u, v and how lit it is."""
    h, w = shape
    n = 900
    u, v = np.meshgrid(np.linspace(-1, 1, n), np.linspace(0, 1, n))
    x, y, z, sx, sy = sail.point(u, v)
    pos = np.stack([x, y, z])
    nrm = np.cross(np.gradient(pos, axis=2), np.gradient(pos, axis=1), axis=0)
    nrm /= np.linalg.norm(nrm, axis=0) + 1e-9
    nrm *= np.where(nrm[2] < 0, -1.0, 1.0)
    lit = np.tensordot(LIGHT / np.linalg.norm(LIGHT), nrm, axes=1)
    gx = np.floor(sx * SS).astype(int).ravel()
    gy = np.floor(sy * SS).astype(int).ravel()
    ok = (gx >= 0) & (gy >= 0) & (gx < w * SS) & (gy < h * SS)
    order = np.argsort(z.ravel()[ok])
    idx = (gy[ok] * w * SS + gx[ok])[order]
    layers = []
    for a, empty in ((z, -np.inf), (u, 0.0), (v, 0.0), (lit, 0.0)):
        out = np.full(h * w * SS * SS, empty)
        out[idx] = a.ravel()[ok][order]
        layers.append(out.reshape(h * SS, w * SS))
    return layers


def curve(sail: Sail, depth: np.ndarray, us, vs) -> list:
    """The pixels a line on the cloth passes through where it is the frontmost cloth, one pixel thick."""
    _, _, z, sx, sy = sail.point(us, vs)
    h, w = depth.shape
    runs, run = [], []
    for px, py, pz in zip(sx, sy, z):
        gx, gy = int(math.floor(px * SS)), int(math.floor(py * SS))
        if not (0 <= gx < w and 0 <= gy < h) or pz < depth[gy, gx] - 0.6:
            if run:
                runs.append(run)
            run = []
            continue
        p = (int(math.floor(px)), int(math.floor(py)))
        if not run or run[-1] != p:
            run.append(p)
    if run:
        runs.append(run)
    out = []
    for run in runs:
        thin = []
        for p in run:
            # A corner pixel between two that touch diagonally is dropped, so the line keeps one pixel thick.
            if len(thin) >= 2:
                a, b = thin[-2], thin[-1]
                if abs(p[0] - a[0]) <= 1 and abs(p[1] - a[1]) <= 1 and (b[0] == a[0] or b[1] == a[1]) \
                        and (b[0] == p[0] or b[1] == p[1]):
                    thin.pop()
            thin.append(p)
        out.extend(thin)
    return out


def line(a, b) -> list:
    """A one-pixel line from a to b with a pixel in every row (or column, if it is flatter than steep)."""
    (x0, y0), (x1, y1) = a, b
    pts = []
    if abs(y1 - y0) >= abs(x1 - x0):
        step = 1 if y1 >= y0 else -1
        for y in range(int(round(y0)), int(round(y1)) + step, step):
            t = (y - y0) / (y1 - y0) if y1 != y0 else 0.0
            pts.append((int(round(x0 + (x1 - x0) * t)), y))
    else:
        step = 1 if x1 >= x0 else -1
        for x in range(int(round(x0)), int(round(x1)) + step, step):
            t = (x - x0) / (x1 - x0)
            pts.append((x, int(round(y0 + (y1 - y0) * t))))
    return pts


def turn(boat: str, out_dir: Path, icon: bool = False) -> dict:
    spec, folder = (ICONS[boat], ICON_RAW) if icon else (BOATS[boat], RAW)
    raw = folder / f"{boat}_square_sail.png"
    if not raw.exists():
        shutil.copyfile((ICON_RAW if icon else PROPS) / f"{boat}.png", raw)
    old = np.array(Image.open(raw).convert("RGBA"))
    h, w = old.shape[:2]
    pic = np.where(kept_part(old, spec)[:, :, None], old, 0).astype(np.uint8)
    if "flag" in spec:
        y0, y1, c0, c1 = spec["flag"]
        rows = pic[y0:y1 + 1].copy()
        pic[y0:y1 + 1] = 0
        for x in range(max(0, c0 + c1 - w + 1), min(w, c0 + c1 + 1)):
            pic[y0:y1 + 1, x] = rows[:, c0 + c1 - x]
    m0, m1 = spec["mast"]
    # The mast is drawn again from its top down where the old sail hid it or darkened its edge.
    top, bare = spec["mast_rows"]
    for y in range(top, bare):
        pic[y, m0:m1 + 1] = old[bare, m0:m1 + 1]
    mast = np.zeros((h, w), bool)
    mast[:, m0:m1 + 1] = pic[:, m0:m1 + 1, 3] > 127

    sail = Sail(spec)
    depth, uu, vv, ll = render(sail, (h, w))
    cov = (depth > -np.inf).reshape(h, SS, w, SS)
    count = cov.sum(axis=(1, 3))
    cloth = count >= SS * SS // 2

    def mean(a):
        return np.where(cov, a.reshape(h, SS, w, SS), 0.0).sum(axis=(1, 3)) / np.maximum(count, 1)

    v, lit, z = mean(vv), mean(ll), mean(np.where(depth > -np.inf, depth, 0.0))
    cloth_c, band_c = spec["cloth"], spec["band"]
    nu, nv = spec["cells"]
    lo, hi = np.percentile(lit[cloth], [4, 96])
    # Each panel puffs out a little between its bands, lit on its upper side.
    shade = 1.0 - np.clip((lit - lo) / max(1e-6, hi - lo), 0, 1) + 0.12 * (v * nv % 1.0 - 0.5)
    tone = np.clip(np.round(shade * (len(cloth_c) - 1)), 0, len(cloth_c) - 1).astype(int)
    for y, x in zip(*np.nonzero(cloth)):
        near = [tone[y + dy, x + dx] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                if 0 <= x + dx < w and 0 <= y + dy < h and cloth[y + dy, x + dx]]
        if len(near) == 4 and tone[y, x] not in near and len(set(near)) == 1:
            tone[y, x] = near[0]

    layer = np.zeros((h, w, 4), np.uint8)
    for y, x in zip(*np.nonzero(cloth)):
        # The yard shades the row of cloth just under it.
        under_yard = y > 0 and not cloth[y - 1, x]
        layer[y, x] = (*cloth_c[min(len(cloth_c) - 1, tone[y, x] + (2 if under_yard else 0))], 255)

    def band(pts, darker=0):
        for x, y in pts:
            if 0 <= x < w and 0 <= y < h and cloth[y, x]:
                layer[y, x, :3] = band_c[min(len(band_c) - 1, max(0, tone[y, x] - 1 + darker))]

    t = np.linspace(0, 1, 3000)
    for i in range(1, nu):
        band(curve(sail, depth, np.full_like(t, -1 + 2 * i / nu), t))
    for j in range(1, nv):
        band(curve(sail, depth, t * 2 - 1, np.full_like(t, j / nv)))
    for y, x in zip(*np.nonzero(cloth)):
        if any(not (0 <= x + dx < w and 0 <= y + dy < h) or not cloth[y + dy, x + dx]
               for dx, dy in ((1, 0), (-1, 0), (0, 1))):
            layer[y, x, :3] = band_c[min(len(band_c) - 1, tone[y, x] + 1)]
    band(curve(sail, depth, np.full_like(t, -1.0), t), 1)
    band(curve(sail, depth, np.full_like(t, 1.0), t), 1)
    band(curve(sail, depth, t * 2 - 1, np.full_like(t, 1.0)), 1)

    # The mast stands at depth 0: the cloth nearer us covers it and the cloth further away goes behind it.
    over = (layer[:, :, 3] > 0) & (~mast | (z > 0))
    pic[over] = layer[over]

    # The yard, its near half in front of the mast and its far half behind it.
    far, near = sail.yard_at(-1.0), sail.yard_at(1.0)
    for i, colour in enumerate(spec["yard"]):
        for x, y in line((far[0], far[1] + i - 1), (near[0], near[1] + i - 1)):
            if 0 <= x < w and 0 <= y < h and not (mast[y, x] and x > sail.mx):
                pic[y, x] = (*colour, 255)
    for end in (far, near):
        x = int(round(end[0]))
        for i in range(3):
            y = int(round(end[1])) + i - 1
            if 0 <= y < h and pic[y, x, 3]:
                pic[y, x] = (*spec["yard_end"], 255)

    # The ropes, over the cloth.
    tops = {"far_arm": (far[0], far[1] + 1), "near_arm": (near[0], near[1] + 1),
            "near_clew": sail.corner(1.0, 1.0), "far_clew": sail.corner(-1.0, 1.0)}
    rope = spec["rope"]
    for foot, kind, at in spec["ropes"]:
        for i, (x, y) in enumerate(line(foot, at if kind == "mast" else tops[kind])):
            if spec["wide"]:
                strand = [(x - 1, rope[0]), (x, rope[2] if i % 3 == 0 else rope[1]), (x + 1, rope[0])]
            else:
                strand = [(x, rope[(i // 2) % 2])]
            for sx, colour in strand:
                if 0 <= sx < w and 0 <= y < h and not mast[y, sx]:
                    pic[y, sx] = (*colour, 255)

    Image.fromarray(pic).save(out_dir / f"{boat}.png")
    return {"sail": corners(cloth, near, far, sail.mx)}


def corners(cloth: np.ndarray, near, far, mx: float) -> list:
    """The sail's corners for boats.json, the box the sail shader moves: from the near side of the cloth to its far
    side, its top just under the yard and its foot below every pixel of cloth, as close under it at the mast as a
    straight line can be, so the mast showing below the sail stays still as the cloth fills."""
    ys, xs = np.nonzero(cloth)
    left, right = int(xs.min()), int(xs.max()) + 1
    top_slope = (far[1] - near[1]) / (far[0] - near[0])
    top_at = min(ys - top_slope * xs)
    best = None
    for slope in np.linspace(-1.0, 0.5, 301):
        offset = max(ys + 1 - slope * xs)
        at_left = math.ceil(offset + slope * left)
        at_right = math.ceil(offset + slope * right)
        if any(ys + 1 > at_left + (at_right - at_left) * (xs - left) / (right - left)):
            continue
        gap = at_left + (at_right - at_left) * (mx - left) / (right - left)
        if best is None or gap < best[0]:
            best = (gap, at_left, at_right)
    return [[left, int(math.floor(top_at + top_slope * left))], [right, int(math.floor(top_at + top_slope * right))],
            [right, best[2]], [left, best[1]]]


def main() -> None:
    args = sys.argv[1:]
    icon = "--icons" in args
    args = [a for a in args if a != "--icons"]
    out_dir = ICON_RAW if icon else PROPS
    if "--out" in args:
        i = args.index("--out")
        out_dir = Path(args[i + 1])
        del args[i:i + 2]
    for boat in args or list(BOATS):
        print(boat, turn(boat, out_dir, icon))


if __name__ == "__main__":
    main()
