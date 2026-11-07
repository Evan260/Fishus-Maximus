"""Paints the harbour town seen side on like the fishing places: an empty waterfront street, then each of its five
buildings painted straight into it inside a building-shaped outline, so every one shares the street's angle, light and
style. Wall and paving painted inside an outline are given back to the street, so each building ends at its own edges,
and what is left is cut out to be clicked and lit when the mouse is over it. Writes
game/assets/art/town/street.png, <id>.png for each building, and town.json with where each stands.
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


def shape_mask(size, shapes) -> Image.Image:
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    for kind, geo in shapes:
        if kind == "rect":
            d.rectangle(geo, fill=255)
        elif kind == "ellipse":
            d.ellipse(geo, fill=255)
        else:
            d.polygon(geo, fill=255)
    return mask


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
    spots = {}
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
    painted = np.array(Image.open(town).convert("RGBA"))
    empty = np.array(Image.open(street).convert("RGBA"))
    final = painted.copy()
    for bid, (shapes, _prompt) in BUILDINGS.items():
        if bid not in done:
            continue
        outline = np.array(shape_mask(final.shape[1::-1], shapes)) > 0
        keep = settle(painted, empty, outline)
        final[outline & ~keep] = empty[outline & ~keep]
        shape = hover_shape(keep)
        im = final.copy()
        im[:, :, 3] = np.where(shape, 255, 0)
        ys, xs = np.where(shape)
        Image.fromarray(im).crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)).save(OUT / f"{bid}.png")
        spots[bid] = [int(xs.min()), int(ys.min())]
        print("cut out", bid)
    Image.fromarray(final).crop((0, 0, 480, 270)).save(OUT / "street.png")
    (OUT / "town.json").write_text(json.dumps(spots, indent=1))
    print("town written")


if __name__ == "__main__":
    main()
