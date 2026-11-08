"""Paints the harbour town seen side on like the fishing places: an empty waterfront street, then each of its five
buildings painted straight into it inside a building-shaped outline, so every one shares the street's angle, light and
style. The street is then painted on past each edge of its 480 by 270 scene (widen.py), so a window of another shape
shows more street, and any part of a building that came out wrong is painted again on the wide picture. Wall and
paving painted inside an outline are given back to the street, so each building ends at its own edges, the fish
market's right column is finished, the paving round the goldsmith is laid again from the street's own slabs, the hall's
post by the goldsmith is moved in front of it and down to the paving, so the goldsmith stands inside the hall, its
lantern hangs beside the post, the painted sky is cleared so the game's own sky shows above the wall, and each building
is cut out along the outline traced round it, to be clicked and outlined in gold when the mouse is over it. Writes
game/assets/art/town/street.png (the scene with MARGIN more on every side), <id>.png for each building, and town.json
with where each stands in the scene.
Usage: python tools/art/make_town.py [--no-paint]   (--no-paint only cuts out what is already painted)"""
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

import clear_sky
import widen

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "assets" / "art" / "town"
WORK = Path(__file__).with_name("town_parts")
STYLE = "cozy pixel art, soft warm golden afternoon light, gentle shading, no outlines"
FRONT = "seen exactly from the front as a flat elevation, no perspective"
STREET = ("the waterfront street of an ancient Roman harbour town seen exactly from the side as a flat elevation like a "
          "stage set: grey paving stones along the bottom, behind them a long low cream plastered wall with a terracotta "
          "tile coping, blue sky with soft white clouds above, the masts of moored ships showing over the wall, no buildings, "
          "no people, no perspective")
PAVING = 236
# id: (outline as shapes in street pixels, what is painted there)
BUILDINGS = {
    "market": ([("rect", (64, 121, 168, 210))],
               f"the front of a small Roman fish market hall {FRONT}, the building filling the whole shape: a white stone cornice along the top, a white column at each side, a striped blue and white awning between the columns, fish hanging under it over stone counters of fresh fish, its stone step at the bottom"),
    "netmaker": ([("rect", (174, 150, 256, PAVING)), ("poly", [(170, 152), (260, 152), (215, 122)])],
                 f"a small Roman netmaker's shop {FRONT} with a red tiled gable roof, an open front hung with fishing nets, rods leaning by the door, baskets of bait"),
    "boatwright": ([("rect", (266, 170, 356, 226)), ("poly", [(262, 172), (360, 172), (311, 140)])],
                   f"a Roman boatwright's open timber shed {FRONT}, the building filling the whole shape: a red tiled gable roof on a thick wooden post at each side, a small wooden boat on trestles inside, planks leaning on its back wall, coils of rope, its plank floor at the bottom"),
    "board": ([("rect", (362, 150, 404, PAVING))],
              f"a wooden notice board on two posts against the wall {FRONT}, wax tablets and scraps of papyrus pinned to it, a little tiled roof on top"),
    "goldsmith": ([("rect", (410, 116, 474, PAVING)), ("poly", [(406, 118), (478, 118), (442, 98)])],
                  f"a narrow Roman goldsmith's shop {FRONT} with a red awning over a small counter of gold earrings and rings, a tiled gable roof"),
}
# Each building as the street shows it, traced in the scene's pixels: the mouse finds it there and its outline hugs it.
SILHOUETTES = {
    "market": [("poly", [(64, 124), (73, 121), (162, 121), (171, 124), (171, 210), (64, 210)])],
    "netmaker": [("poly", [(173, 150), (213, 127), (218, 127), (257, 150), (254, 158), (254, 212), (175, 212),
                           (175, 158)])],
    "boatwright": [("poly", [(266, 172), (312, 140), (358, 171), (356, 177), (356, 210), (269, 210), (269, 178)])],
    "board": [("poly", [(367, 166), (402, 166), (402, 181), (400, 182), (400, 209), (367, 209), (367, 182),
                        (364, 181), (364, 172), (367, 171)])],
    "goldsmith": [("poly", [(422, 222), (422, 113), (446, 100), (479, 124), (474, 126), (474, 227), (470, 227),
                            (470, 222)])],
}
SCENE = (480, 270)
# How far the street is painted past the scene on each side, so a window of another shape still shows the whole scene;
# 512 by 336 is four of PixelLab's tiles, and as wide as a 2560 pixel window shows the scene.
MARGIN = (16, 33)
# What carries on past the scene, a corner at a time, in the scene's own pixels, running 4 pixels into it.
CEILING = ("the dark timber ceiling of the covered Roman street seen from below, heavy beams and planks in shadow, "
           "carrying on the beams already there")
PAVING_ROWS = ("grey stone paving slabs of the street in rows, carrying on the rows of slabs already there, no people")
SIDES = {
    "top_left": (f"{CEILING}, and at the left the side of an old stone building with a faded purple cloth awning",
                 [(-16, -33, 240, 4), (-16, 4, 4, 223)]),
    "top_right": (f"{CEILING}, and at the right a massive square pillar of grey cut stone blocks holding it up",
                  [(240, -33, 496, 4), (476, 4, 496, 223)]),
    "bottom_left": (f"{PAVING_ROWS}, and at the left the foot of an old stone building with a dark doorway",
                    [(-16, 223, 4, 303), (4, 266, 240, 303)]),
    "bottom_right": (f"{PAVING_ROWS}, and at the right the foot of a massive square stone pillar",
                     [(476, 223, 496, 303), (240, 266, 476, 303)]),
}
# Parts painted again on the wide picture, each once: (the building they belong to, if any, outline, what is painted
# there, how). Each outline starts on a multiple of 4 in the wide picture, where PixelLab's tiles start. "fresh" paints
# over a blur of the part, so the join it mends is not painted back, and "match" brings the part's colours to those
# round it.
MENDS = {
    "pillar": ("", [("rect", (445, -13, 496, 223))],
               "a massive square pillar of grey-brown cut stone blocks in even courses, the whole pillar from the dark "
               "timber ceiling beam it holds up down to the street, its left side catching the light, seen exactly "
               "from the side", ""),
    "paving_middle": ("", [("rect", (156, 263, 323, 302))],
                      "grey stone paving slabs of the street in rows, joining the rows of slabs on the left to those on "
                      "the right, no people", "match"),
    "paving_join": ("", [("rect", (216, 263, 267, 302))],
                    "grey stone paving slabs of the street in rows, carrying the joints of the slabs on the left and on "
                    "the right across, no people", "fresh match"),
    "boatwright_roof": ("boatwright", [("poly", [(260, 176), (362, 176), (311, 139)])],
                        f"the red tiled gable roof of a small timber shed {FRONT}, rows of round terracotta roof tiles, a "
                        "neat row of tiles running down both sloping edges and a ridge tile at the peak, its eaves "
                        "overhanging the posts, like the roof of the netmaker's shop beside it", ""),
    "goldsmith": ("goldsmith", [("rect", (410, 120, 474, PAVING)), ("poly", [(403, 122), (481, 122), (442, 99)])],
                  f"a narrow Roman goldsmith's shop {FRONT}, a whole small building standing in front of a stone pillar, "
                  "the building filling the whole shape: a red tiled gable roof with a neat row of tiles down both "
                  "sloping edges, dark wooden walls with a wooden post at each side, a red awning over a wooden counter "
                  "of gold earrings and rings, a small hanging lamp, a red banner, its wooden step at the bottom", ""),
    "goldsmith_peak": ("", [("poly", [(428, 99), (448, 99), (448, 102), (434, 109), (428, 109)])],
                       "the shadowed plastered wall and dark doorway of the tall house behind, carrying on down to the "
                       "top of the small tiled roof in front of it, no sky", ""),
}
# The paving's slanting joints run to this point in the scene, a slope of 0.4 apart, slope being columns per row down.
VANISH = (261, 152)
JOINT = 0.4
# The paving round the goldsmith is laid again from the street's own, past the joint of this slope.
CARRY_FROM = 1.86
# Where that paving starts, as (from this column on, the top row), since the goldsmith and the pillar stand on it.
CARRY_TOPS = [(0, 211), (410, 223), (470, 229)]
# The painted sky's own colours, the last the bluish edge of the rigging against it, and the row of the wall's top.
SKY = [(127, 174, 239), (142, 188, 246), (162, 208, 250), (227, 236, 255), (198, 217, 250), (139, 150, 166)]
HORIZON = 110
# Parts painted past the scene a shade lighter than the scene beside them, in the scene's own pixels, each evened out
# row by row with the eight columns to its right.
EVEN = [(-16, 199, 4, 267)]
# The market's right column ends at the box it was painted in, so it takes its left column's outer edge, turned round.
COLUMN_EDGE = (64, 3)
COLUMN_RIGHT = 171
COLUMN_ROWS = (121, 210)
# The hall's post by the goldsmith in the empty street, moved in front of the stall so the stall stands in the hall.
POST = (416, 434)
POST_ROWS = (45, 217)
POST_SHIFT = -12
POST_FOOT = 228
# The shadow under its foot, row by row: how dark, and how far past its right side.
POST_SHADOW = [(0.6, 4), (0.8, 2)]
# Where the post stood, the house's roof comes from its right, its wall repeats, and the coping comes from the left.
COPING = (75, 99)
# The goldsmith's lantern as painted, (row, first column, last column), which the post now covers.
LANTERN = [(156, 416, 417), (157, 416, 417), (158, 416, 417), (159, 416, 417), (160, 414, 418)] + \
          [(y, 413, 418) for y in range(161, 170)]
# Where it hangs instead, (columns, rows) from there: beside the post from the stall's awning.
LANTERN_SHIFTS = [(10, 0)]
# The iron it hangs from, (first row, last row, first column, last column): a chain up to the awning.
LANTERN_IRON = [(151, 155, 426, 426)]


def run(args):
    failures = 0
    while failures < 4:
        r = subprocess.run([sys.executable, str(Path(__file__).with_name("pixellab.py"))] + args, cwd=ROOT,
                           capture_output=True, text=True, timeout=900)
        if "cost:" in r.stdout:
            return True
        said = (r.stdout + r.stderr)[-300:]
        if "429" in said:
            time.sleep(25)
            continue
        failures += 1
        print("  retry:", said.strip())
        time.sleep(10)
    return False


def shape_mask(size, shapes, at=(0, 0)) -> Image.Image:
    """The shapes filled in white, moved by `at`."""
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    for kind, geo in shapes:
        if kind == "poly":
            d.polygon([(x + at[0], y + at[1]) for x, y in geo], fill=255)
        else:
            box = (geo[0] + at[0], geo[1] + at[1], geo[2] + at[0], geo[3] + at[1])
            if kind == "rect":
                d.rectangle(box, fill=255)
            else:
                d.ellipse(box, fill=255)
    return mask


def outline_of(bid):
    """A building's outline in the scene: its own shapes and those of any part of it painted again."""
    return BUILDINGS[bid][0] + [shape for b, shapes, _p, _h in MENDS.values() if b == bid for shape in shapes]


def even_rows(arr: np.ndarray, box) -> np.ndarray:
    """The picture with each row of the box shifted by how far its last eight columns differ from the eight beyond it,
    averaged over nine rows so the joints between slabs do not throw it."""
    x0, y0, x1, y1 = box
    out = arr.copy()
    rgb = arr[y0:y1, :, :3].astype(np.float32)
    off = rgb[:, x1:x1 + 8].mean(axis=1) - rgb[:, x1 - 8:x1].mean(axis=1)
    off = cv2.blur(off[:, None, :], (1, 9))[:, 0, :]
    out[y0:y1, x0:x1, :3] = np.clip(rgb[:, x0:x1] + off[:, None, :], 0, 255).astype(np.uint8)
    return out


def carry_paving(arr: np.ndarray) -> np.ndarray:
    """The picture with the paving round the goldsmith laid again from the street's own slabs four joints to the left,
    each row moved along the street's perspective so the joints meet those beside it, and each column toned to the
    paving just past the joint it starts at."""
    h, w = arr.shape[:2]
    vx, vy = VANISH[0] + MARGIN[0], VANISH[1] + MARGIN[1]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    slope = (xx - vx) / np.maximum(yy - vy, 1.0)
    top = np.zeros(w)
    for x0, y0 in CARRY_TOPS:
        top[x0 + MARGIN[0]:] = y0 + MARGIN[1]
    area = (slope > CARRY_FROM) & (yy >= top[None, :])
    laid = cv2.remap(arr, xx - 4 * JOINT * (yy - vy), yy, cv2.INTER_NEAREST)
    weights = np.array([0.3, 0.59, 0.11], dtype=np.float32)
    was, now = arr[:, :, :3].astype(np.float32) @ weights, laid[:, :, :3].astype(np.float32) @ weights
    past = (slope <= CARRY_FROM - 0.08) & (slope > CARRY_FROM - 0.6) & (yy >= top.max())
    gain = np.ones(w, dtype=np.float32)
    for x in range(int(np.argmax(area.any(axis=0))), w):
        rows = past[:, x]
        gain[x] = was[rows, x].mean() / max(now[rows, x].mean(), 1.0) if rows.sum() > 6 else gain[x - 1]
    gain = np.convolve(np.pad(gain, 12, mode="edge"), np.ones(25) / 25, "valid")
    out = arr.copy()
    toned = laid[:, :, :3].astype(np.float32) * gain[None, :, None]
    out[area, :3] = np.clip(toned[area], 0, 255).astype(np.uint8)
    return out


def finish_column(arr: np.ndarray) -> np.ndarray:
    """The picture with the fish market's right column given the outer edge of its left column, turned round."""
    mx, my = MARGIN
    out = arr.copy()
    rows = slice(COLUMN_ROWS[0] + my, COLUMN_ROWS[1] + my)
    for dx in range(COLUMN_EDGE[1]):
        out[rows, COLUMN_RIGHT - dx + mx] = arr[rows, COLUMN_EDGE[0] + dx + mx]
    return out


def hang_lanterns(arr: np.ndarray) -> np.ndarray:
    """The picture with the goldsmith's lantern hung again where LANTERN_SHIFTS puts it, each from its own iron."""
    mx, my = MARGIN
    out = arr.copy()
    iron = arr[LANTERN[0][0] + my, LANTERN[0][1] + mx]
    for (dx, dy), (y0, y1, x0, x1) in zip(LANTERN_SHIFTS, LANTERN_IRON):
        for y, a, b in LANTERN:
            out[y + dy + my, a + dx + mx:b + dx + 1 + mx] = arr[y + my, a + mx:b + 1 + mx]
        out[y0 + my:y1 + 1 + my, x0 + mx:x1 + 1 + mx] = iron
    return out


def set_post(arr: np.ndarray, bare: np.ndarray, empty: np.ndarray, stall: np.ndarray) -> np.ndarray:
    """The picture with the hall's post moved in front of the goldsmith's side wall and down to the paving in front of
    it, and the house behind carried over where it stood. `stall` is the goldsmith's silhouette."""
    mx, my = MARGIN
    out = arr.copy()
    width = POST[1] - POST[0]
    left, right = POST[0] + POST_SHIFT, POST[1] + POST_SHIFT
    lum = arr[:, :, :3].astype(np.float32) @ np.array([0.3, 0.59, 0.11], dtype=np.float32) / 255
    for x in range(right, POST[1] + 1):
        wx = x + mx
        # The stall's roof starts at the first light pixel under the coping, as the post and its shadow are dark.
        roof = next(y for y in range(COPING[1] + 1, POST_FOOT) if lum[y + my, wx] > 0.3 and stall[y + my, wx])
        for y in range(POST_ROWS[0] if x < POST[1] else COPING[1], roof):
            wy = y + my
            if y < COPING[0]:
                out[wy, wx] = arr[wy, wx + POST[1] - right]
            elif y < COPING[1]:
                out[wy, wx] = arr[wy, POST[1] + mx]
            else:
                out[wy, wx] = arr[wy, wx - width if x < POST[1] else wx + 1]
    # Anything of the stall left of the post is the street behind it.
    old = np.zeros(arr.shape[:2], bool)
    old[:, :left + mx] = True
    old &= np.array(shape_mask(arr.shape[1::-1], outline_of("goldsmith"), MARGIN)) > 0
    out[old] = empty[old]
    post = bare[POST_ROWS[0]:POST_ROWS[1] - 1, POST[0]:POST[1]]
    extra = POST_FOOT - 1 - (POST_ROWS[1] - 1)
    foot = (post[-1:].astype(np.float32) * [0.7, 0.7, 0.7, 1.0]).astype(np.uint8)
    post = np.concatenate([post, post[-extra:], foot])
    out[POST_ROWS[0] + my:POST_FOOT + my, left + mx:right + mx] = post
    for dy, (shade, past) in enumerate(POST_SHADOW):
        row = out[POST_FOOT + my + dy, left + mx:right + past + mx]
        row[:, :3] = (row[:, :3].astype(np.float32) * shade).astype(np.uint8)
    return out


def match_tone(before: np.ndarray, after: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """The picture with the colours of its masked part brought to the mean and spread of the band round it."""
    out = after.copy()
    ring = (cv2.dilate(mask.astype(np.uint8), np.ones((33, 33), np.uint8)) > 0) & ~mask
    part = after[mask][:, :3].astype(np.float32)
    near = before[ring][:, :3].astype(np.float32)
    toned = (part - part.mean(axis=0)) * (near.std(axis=0) / np.maximum(part.std(axis=0), 1.0)) + near.mean(axis=0)
    out[mask, :3] = np.clip(toned, 0, 255).astype(np.uint8)
    return out


# How close, over red, green and blue together, a painted pixel must be to the empty street's to count as street, and
# how close its surroundings must be on the pale wall and paving, where repainting keeps the colours but moves the cracks.
NEAR = 44
NEAR_AROUND = 36
PALE = 140
# Building left in pieces smaller than this after the street is given back is only stray paint.
SPECK = 16


def settle(town: np.ndarray, street: np.ndarray, outline: np.ndarray) -> np.ndarray:
    """The part of an outline that is really building: wall and paving painted inside it that run on from the street
    outside go back to the street, so the building ends at its own edges and never at the outline's straight sides."""
    a, b = town[:, :, :3].astype(np.float32), street[:, :, :3].astype(np.float32)
    around = np.abs(cv2.blur(a, (5, 5)) - cv2.blur(b, (5, 5))).sum(axis=2)
    pale = b @ np.array([0.3, 0.59, 0.11], dtype=np.float32) > PALE
    near = (np.abs(a - b).sum(axis=2) < NEAR) | ((around < NEAR_AROUND) & pale)
    open_ = (~outline | near).astype(np.uint8)
    _n, labels = cv2.connectedComponents(open_, connectivity=4)
    outside = np.unique(labels[~outline])
    keep = outline & ~np.isin(labels, outside)
    n, labels, stats, _c = cv2.connectedComponentsWithStats(keep.astype(np.uint8), connectivity=8)
    for i in range(1, n):
        if stats[i][cv2.CC_STAT_AREA] < SPECK:
            keep[labels == i] = False
    return keep


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(exist_ok=True)
    street = WORK / "street_side.png"
    if not street.exists():
        if not run(["pixen", f"{STREET}, {STYLE}", "480x272", "--out", str(street.relative_to(ROOT)), "--raw", "--view", "side",
                    "--outline", "lineless", "--detail", "highly detailed"]):
            sys.exit("could not paint the street")
    town = WORK / "town_side.png"
    if not town.exists():
        shutil.copy(street, town)
    done_path = WORK / "done_side.json"
    done = json.loads(done_path.read_text()) if done_path.exists() else []
    for bid, (shapes, prompt) in BUILDINGS.items():
        mask = shape_mask(Image.open(town).size, shapes)
        mask_path = WORK / f"{bid}_side_mask.png"
        mask.save(mask_path)
        if bid not in done:
            if "--no-paint" in sys.argv or not run(["inpaint", str(town.relative_to(ROOT)), str(mask_path.relative_to(ROOT)),
                                                    f"{prompt}, {STYLE}", "--out", str(town.relative_to(ROOT))]):
                print("not painted", bid)
                continue
            done.append(bid)
            done_path.write_text(json.dumps(done))
    mx, my = MARGIN
    wide = WORK / "town_wide.png"
    side = np.array(Image.open(town).convert("RGBA"))[:SCENE[1]]
    widen.widen(side, wide, SIDES, MARGIN, STYLE, paint="--no-paint" not in sys.argv)
    mended_path = WORK / "mended.json"
    mended = json.loads(mended_path.read_text()) if mended_path.exists() else []
    for name, (_bid, shapes, prompt, how) in MENDS.items():
        if name in mended or "--no-paint" in sys.argv:
            continue
        mask_path = WORK / f"{name}_mend_mask.png"
        mask = shape_mask(Image.open(wide).size, shapes, MARGIN)
        mask.save(mask_path)
        inside = np.array(mask) > 0
        before = np.array(Image.open(wide).convert("RGBA"))
        if "fresh" in how:
            Image.fromarray(np.where(inside[:, :, None], cv2.blur(before, (15, 15)), before)).save(wide)
        if not run(["inpaint", str(wide.relative_to(ROOT)), str(mask_path.relative_to(ROOT)), f"{prompt}, {STYLE}",
                    "--out", str(wide.relative_to(ROOT)), "--tile", "128x128"]):
            Image.fromarray(before).save(wide)
            print("not mended", name)
            continue
        after = np.array(Image.open(wide).convert("RGBA"))
        # PixelLab can draw a light line along a tile's outer side, here the picture's bottom row.
        after[-1][inside[-1]] = after[-2][inside[-1]]
        if "match" in how:
            after = match_tone(before, after, inside)
        Image.fromarray(after).save(wide)
        mended.append(name)
        mended_path.write_text(json.dumps(mended), newline="\n")
    painted = np.array(Image.open(wide).convert("RGBA"))
    for box in EVEN:
        painted = even_rows(painted, [box[0] + mx, box[1] + my, box[2] + mx, box[3] + my])
    # The empty street is the wide picture with the scene's own street put back, short of the edges joined to it.
    empty = painted.copy()
    bare = np.array(Image.open(street).convert("RGBA"))
    empty[my + 4:my + SCENE[1] - 4, mx + 4:mx + SCENE[0] - 4] = bare[4:SCENE[1] - 4, 4:SCENE[0] - 4]
    final = painted.copy()
    names = list(MENDS)
    built = [bid for bid in BUILDINGS if bid in done]
    for bid in built:
        # Street painted again after a building is already the street, so none of it is given back to the empty street.
        last = max([names.index(n) for n in names if MENDS[n][0] == bid], default=-1)
        restreeted = np.zeros(final.shape[:2], bool)
        for name in names[last + 1:]:
            if not MENDS[name][0]:
                restreeted |= np.array(shape_mask(final.shape[1::-1], MENDS[name][1], MARGIN)) > 0
        outline = np.array(shape_mask(final.shape[1::-1], outline_of(bid), MARGIN)) > 0
        back = outline & ~settle(painted, empty, outline) & ~restreeted
        final[back] = empty[back]
    stall = np.array(shape_mask(final.shape[1::-1], SILHOUETTES["goldsmith"], MARGIN)) > 0
    final = set_post(hang_lanterns(carry_paving(finish_column(final))), bare, empty, stall)
    final = clear_sky.clear_painted(final, SKY, HORIZON + my)
    spots = {}
    for bid in built:
        shape = np.array(shape_mask(final.shape[1::-1], SILHOUETTES[bid], MARGIN)) > 0
        if (shape & (final[:, :, 3] == 0)).any():
            print("sky shows inside", bid)
        im = final.copy()
        im[:, :, 3] = np.where(shape, im[:, :, 3], 0)
        ys, xs = np.where(shape)
        Image.fromarray(im).crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)).save(OUT / f"{bid}.png")
        spots[bid] = [int(xs.min()) - mx, int(ys.min()) - my]
        print("cut out", bid)
    Image.fromarray(final).save(OUT / "street.png")
    (OUT / "town.json").write_text(json.dumps(spots, indent=1), newline="\n")
    print("town written")


if __name__ == "__main__":
    main()
