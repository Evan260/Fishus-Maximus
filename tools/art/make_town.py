"""Paints the harbour town seen side on like the fishing places: an empty waterfront street, then each of its five
buildings painted straight into it inside a building-shaped outline, so every one shares the street's angle, light and
style. The street is then painted on past each edge of its 480 by 270 scene (widen.py), so a window of another shape
shows more street, and any part of a building that came out wrong is painted again on the wide picture. Last, the
right of the street is cleared of the board, the goldsmith and the hall's right post, the stone pillar carried down to
the paving and the paving laid again from the street's own slabs, and the goldsmith is painted again there as a stall
along the wall. Wall and paving painted inside an outline are given back to the street, so each building ends at its
own edges, the fish market's right column is finished, the goldsmith's first lantern hangs on the hall's left post, the
harbour board, painted turned to face the street, stands on the paving in front of that post, the painted sky is
cleared so the game's own sky shows above the wall, and each building is cut out along the outline traced round it, to
be clicked and outlined in gold when the mouse is over it. Writes game/assets/art/town/street.png (the scene with
MARGIN more on every side), <id>.png for each building, and town.json with where each stands in the scene.
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
    "board": [("poly", [(15, 182), (19, 182), (55, 191), (61, 197), (61, 199), (56, 200), (56, 234), (50, 234),
                        (50, 228), (27, 228), (23, 229), (22, 237), (24, 238), (22, 239), (17, 239), (14, 238),
                        (16, 237), (16, 228), (15, 227), (15, 198), (13, 194), (10, 193), (9, 191), (14, 184)])],
    "goldsmith": [("poly", [(413, 132), (415, 132), (442, 151), (442, 153), (437, 153), (437, 214), (426, 214),
                            (426, 215), (403, 215), (403, 214), (385, 214), (384, 161), (379, 157), (379, 155)])],
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
# over a blur of the part, so the join it mends is not painted back, "match" brings the part's colours to those round
# it, and "clear" first clears the right of the street (clear_right).
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
    "goldsmith_stall": ("goldsmith", [("rect", (369, 150, 437, 220)), ("poly", [(364, 152), (442, 152), (403, 119)])],
                        f"a small Roman goldsmith's stall {FRONT}, standing against the plastered wall like the "
                        "netmaker's and boatwright's stalls beside it, the building filling the whole shape: a red "
                        "tiled gable roof with a neat row of tiles down both sloping edges, dark wooden walls with a "
                        "wooden post at each side, a red awning over a wooden counter of gold earrings and rings, a "
                        "small hanging lamp, a red banner, its wooden step at the bottom", "clear"),
}
# The paving's slanting joints run to this point in the scene, a slope of 0.4 apart, slope being columns per row down.
VANISH = (261, 152)
JOINT = 0.4
# The paving on the right of the street is laid again from the street's own, past the joint of this slope.
CARRY_FROM = 1.86
# Where that paving starts, as (from this column on, the top row), since the pillar stands on it.
CARRY_TOPS = [(0, 211), (447, 230)]
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
# Cleared of the board, the goldsmith as first painted and the hall's right post, for the goldsmith's stall.
CLEAR = (360, 49, 447, 236)
# Where the post stood, each band of rows comes from beside it: (first row, end row, first column, columns repeated).
POST = (416, 434)
POST_FILL = [(49, 63, 398, 18), (63, 73, 434, 13), (73, 98, 407, 9), (98, 122, 386, 30), (122, 211, 434, 13)]
# The pillar's courses repeat down to its foot: (first column, first row, end row), and (joint row, rows repeated).
PILLAR = (447, 91, 230)
COURSES = (34, 57)
# The goldsmith's lantern as first painted, (row, first column, last column), kept in lantern.png.
LANTERN = [(156, 416, 417), (157, 416, 417), (158, 416, 417), (159, 416, 417), (160, 414, 418)] + \
          [(y, 413, 418) for y in range(161, 170)]
# Its top left corner on the hall's left post, and the iron arm it hangs from, (row, first column, last column).
LANTERN_AT = (37, 150)
LANTERN_ARM = (149, 40, 44)
# The board's top left corner, its shadow as (row from the line between its feet, how dark), and how far that runs past.
BOARD = "board_turned.png"
BOARD_AT = (6, 178)
BOARD_SHADOW = [(-1, 0.75), (0, 0.6), (1, 0.7), (2, 0.85)]
SHADOW_PAST = (3, 5)


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


def clear_right(arr: np.ndarray, bare: np.ndarray) -> np.ndarray:
    """The wide picture with the right of the street cleared: the empty street's wall and paving put back, with the
    hall's right post taken out and each band of what stands behind it carried across, the stone pillar's courses
    carried down to its foot, and the paving laid again from the street's own slabs."""
    mx, my = MARGIN
    street = bare.copy()
    for top, end, src, cols in POST_FILL:
        for x in range(*POST):
            street[top:end, x] = bare[top:end, src + (x - POST[0]) % cols]
    out = arr.copy()
    x0, y0, x1, y1 = CLEAR
    out[y0 + my:y1 + my, x0 + mx:x1 + mx] = street[y0:y1, x0:x1]
    column, top, foot = PILLAR
    courses = arr[COURSES[0] + my:COURSES[0] + COURSES[1] + my, column + mx:].copy()
    # A speck of painted sky on the pillar's edge would repeat all the way down, so it takes the stone beside it.
    sky = np.abs(courses[:, :, None, :3].astype(int) - np.array(SKY)).sum(axis=3).min(axis=2) < 30
    for y, x in zip(*np.where(sky)):
        courses[y, x] = courses[y, x + 1]
    for y in range(top, foot):
        out[y + my, column + mx:] = courses[(y - top) % COURSES[1]]
    return carry_paving(out)


def cut_lantern(arr: np.ndarray) -> Image.Image:
    """The goldsmith's lantern as first painted, on a clear picture of its own."""
    mx, my = MARGIN
    x0 = min(a for _y, a, _b in LANTERN)
    out = np.zeros((len(LANTERN), max(b for _y, _a, b in LANTERN) - x0 + 1, 4), np.uint8)
    for y, a, b in LANTERN:
        out[y - LANTERN[0][0], a - x0:b - x0 + 1] = arr[y + my, a + mx:b + 1 + mx]
    return Image.fromarray(out)


def hang_lantern(arr: np.ndarray) -> np.ndarray:
    """The picture with the goldsmith's lantern hung on the hall's left post from an iron arm."""
    mx, my = MARGIN
    lantern = np.array(Image.open(WORK / "lantern.png").convert("RGBA"))
    out = arr.copy()
    x, y = LANTERN_AT
    h, w = lantern.shape[:2]
    spot = out[y + my:y + h + my, x + mx:x + w + mx]
    spot[lantern[:, :, 3] > 0] = lantern[lantern[:, :, 3] > 0]
    row, a, b = LANTERN_ARM
    out[row + my, a + mx:b + 1 + mx] = lantern[0, lantern[0, :, 3].argmax()]
    return out


def board_feet(solid: np.ndarray) -> list:
    """Where the board's two legs meet the ground in its picture, (column, row), the near leg first."""
    feet = []
    for half in (slice(0, solid.shape[1] // 2), slice(solid.shape[1] // 2, None)):
        part = np.zeros_like(solid)
        part[:, half] = solid[:, half]
        row = int(np.where(part.any(axis=1))[0].max())
        feet.append((int(np.where(part[row])[0].mean()), row))
    return feet


def stand_board(arr: np.ndarray) -> np.ndarray:
    """The picture with the harbour board standing on the paving at BOARD_AT, its shadow along the ground between and
    round its feet."""
    mx, my = MARGIN
    board = np.array(Image.open(WORK / BOARD).convert("RGBA"))
    solid = board[:, :, 3] > 127
    h, w = board.shape[:2]
    x, y = BOARD_AT[0] + mx, BOARD_AT[1] + my
    (c0, f0), (c1, f1) = board_feet(solid)
    shade = np.ones(arr.shape[:2], np.float32)
    for c in range(c0 - SHADOW_PAST[0], c1 + SHADOW_PAST[1] + 1):
        ground = int(round(f0 + (f1 - f0) * (c - c0) / (c1 - c0)))
        for dy, dark in BOARD_SHADOW:
            shade[y + ground + dy, x + c] = dark
    out = arr.copy()
    out[:, :, :3] = (arr[:, :, :3] * shade[:, :, None]).astype(np.uint8)
    spot = out[y:y + h, x:x + w]
    spot[solid] = board[solid]
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
    bare = np.array(Image.open(street).convert("RGBA"))
    cleared = WORK / "town_clear.png"
    for name, (_bid, shapes, prompt, how) in MENDS.items():
        if name in mended or "--no-paint" in sys.argv:
            continue
        mask_path = WORK / f"{name}_mend_mask.png"
        mask = shape_mask(Image.open(wide).size, shapes, MARGIN)
        mask.save(mask_path)
        inside = np.array(mask) > 0
        before = np.array(Image.open(wide).convert("RGBA"))
        if "clear" in how:
            if not (WORK / "lantern.png").exists():
                cut_lantern(before).save(WORK / "lantern.png")
            before = clear_right(before, bare)
            Image.fromarray(before).save(cleared)
            Image.fromarray(before).save(wide)
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
    # The empty street is the wide picture with the scene's own street put back, short of the edges joined to it, and
    # the right of the street as it was cleared for the goldsmith.
    empty = painted.copy()
    empty[my + 4:my + SCENE[1] - 4, mx + 4:mx + SCENE[0] - 4] = bare[4:SCENE[1] - 4, 4:SCENE[0] - 4]
    if cleared.exists():
        empty[:, CLEAR[0] + mx:] = np.array(Image.open(cleared).convert("RGBA"))[:, CLEAR[0] + mx:]
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
    final = stand_board(hang_lantern(finish_column(final)))
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
