"""Paints the harbour town seen side on like the fishing places: an empty waterfront street, then each of its five
buildings painted straight into it inside a building-shaped outline, so every one shares the street's angle, light and
style, and is cut out by that outline to be clicked and lit when the mouse is over it. Writes
game/assets/art/town/street.png, <id>.png for each building, and town.json with where each stands.
Usage: python tools/art/make_town.py"""
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

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
    "market": ([("rect", (10, 130, 166, PAVING)), ("ellipse", (34, 84, 142, 176)), ("rect", (82, 72, 94, 88))],
               f"the fish market of a Roman town {FRONT}: a round fish hall with a tiled dome on white columns, stone counters of fish under a striped awning, a marble water basin in front"),
    "netmaker": ([("rect", (174, 150, 256, PAVING)), ("poly", [(170, 152), (260, 152), (215, 122)])],
                 f"a small Roman netmaker's shop {FRONT} with a red tiled gable roof, an open front hung with fishing nets, rods leaning by the door, baskets of bait"),
    "boatwright": ([("rect", (264, 178, 356, PAVING)), ("poly", [(300, 180), (356, 180), (356, 150), (328, 136), (300, 150)])],
                   f"a Roman boatwright's yard {FRONT}: a wooden boat being built on trestles in front of a small timber shed with a tiled roof, planks and ropes"),
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
            if not run(["inpaint", str(town.relative_to(ROOT)), str(mask_path.relative_to(ROOT)), f"{prompt}, {STYLE}",
                        "--out", str(town.relative_to(ROOT))]):
                print("FAILED", bid)
                continue
            done.append(bid)
            done_path.write_text(json.dumps(done))
        im = np.array(Image.open(town).convert("RGBA"))
        m = np.array(mask) > 0
        im[:, :, 3] = np.where(m, 255, 0)
        ys, xs = np.where(m)
        Image.fromarray(im).crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)).save(OUT / f"{bid}.png")
        spots[bid] = [int(xs.min()), int(ys.min())]
        print("painted", bid)
    Image.open(town).convert("RGBA").crop((0, 0, 480, 270)).save(OUT / "street.png")
    (OUT / "town.json").write_text(json.dumps(spots, indent=1))
    print("town written")


if __name__ == "__main__":
    main()
