"""Paints the harbour town seen side on like the fishing places: an empty waterfront street, then each of its five
buildings painted straight into it inside a building-shaped outline, so every one shares the street's angle, light and
style. The street is then painted on past each edge of its 480 by 270 scene (widen.py), so a window of another shape
shows more street, and any part of a building that came out wrong is painted again on the wide picture. Wall and
paving painted inside an outline are given back to the street, so each building ends at its own edges, the painted sky
is cleared so the game's own sky shows above the wall, and each building is cut out to be clicked and lit when the
mouse is over it. Writes game/assets/art/town/street.png (the scene with MARGIN more on every side), <id>.png for each
building, and town.json with where each stands in the scene.
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
}
# The painted sky's own colours, the last the bluish edge of the rigging against it, and the row of the wall's top.
SKY = [(127, 174, 239), (142, 188, 246), (162, 208, 250), (227, 236, 255), (198, 217, 250), (139, 150, 166)]
HORIZON = 110
# Parts painted past the scene a shade lighter than the scene beside them, in the scene's own pixels, each evened out
# row by row with the eight columns to its right.
EVEN = [(-16, 199, 4, 267)]


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


def hover_shape(keep: np.ndarray) -> np.ndarray:
    """Where the mouse finds a building and its gold outline is drawn: its shape with the ragged edges smoothed and the
    holes filled, which changes nothing on screen since the picture there is the street's own either way."""
    k = cv2.morphologyEx(keep.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    filled = np.pad(k, 1)
    cv2.floodFill(filled, None, (0, 0), 2)
    k = (filled[1:-1, 1:-1] != 2).astype(np.uint8)
    return cv2.morphologyEx(k, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8)) > 0


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
    keeps = {}
    for bid in BUILDINGS:
        if bid not in done:
            continue
        outline = np.array(shape_mask(final.shape[1::-1], outline_of(bid), MARGIN)) > 0
        keep = settle(painted, empty, outline)
        final[outline & ~keep] = empty[outline & ~keep]
        keeps[bid] = keep
    final = clear_sky.clear_painted(final, SKY, HORIZON + my)
    spots = {}
    for bid, keep in keeps.items():
        shape = hover_shape(keep)
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
