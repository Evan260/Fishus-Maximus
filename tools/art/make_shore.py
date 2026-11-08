"""Paints the shore where the ponds and the garum works are: the view above the terrace, the ground the ponds are cut
into, and the terrace wall that lines them. The view and the ground are laid together as one scene, painted on past
its edges (widen.py) so a window of another shape still shows all six ponds, the deep earth below carried on in its own
flat colour, the painted sky cleared so the game's own sky shows, and the near-black cracks in the earth softened.
Writes game/assets/art/shore/shore.png (the scene with MARGIN more on every side), and wall.png when it is missing.
Usage: python tools/art/make_shore.py [--no-paint]"""
import subprocess
import sys
import time
from collections import Counter
from pathlib import Path

import numpy as np
from PIL import Image

import clear_sky
import soften_outlines
import widen

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "assets" / "art" / "shore"
WORK = Path(__file__).with_name("shore_parts")
STYLE = "cozy pixel art, soft warm golden afternoon light, gentle shading, no outlines"
PICTURES = {
    "back": ("a sunny rocky shore on the Bay of Naples seen exactly from the side: on the left the calm sea and a far "
             "green coast under a blue sky with soft clouds, umbrella pines on the rocks, on the right the stone building "
             "of a Roman garum works with an open colonnaded front, rows of stone tanks and clay amphorae stacked outside, "
             "the bottom of the picture is a flat stone terrace edge", "480x136"),
    "ground": ("cross-section of the ground seen exactly from the side: a strip of short green grass with a few small "
               "flowers along the very top edge, under it brown earth with small stones, roots and darker layers of soil, "
               "flat even texture filling the whole picture, no sky", "480x136"),
    "wall": ("a long straight terrace wall of big cut pale limestone blocks seen straight on, mossy joints, a little "
             "seaweed at the bottom, flat even wall filling the whole picture, no openings, no doors", "480x136"),
}
SCENE = (480, 270)
# Where the ground's picture lies in the scene: its grass stands in front of the terrace at the view's bottom.
GROUND_Y = 121
# Below this row of the scene the earth is one flat dark colour, so it carries on without painting.
DEEP = 229
# How far the scene is painted past each side: as wide as a 2560 pixel window shows it, and as tall as a 2560 by 1600
# one, which keeps the building's top and its right side within one of PixelLab's 256 pixel tiles.
MARGIN = (16, 27)
# The row where the sky meets the sea, and the column where the garum works' roof begins.
HORIZON = 89
WORKS_X = 276
SIDES = {
    "works": ("the upper wall of pale cut limestone blocks and the red tiled roof of a Roman garum works building, and "
              "below at the right more of the building's wall, then short green grass over brown earth with roots, "
              "seen exactly from the side, blue sky",
              [(WORKS_X, -27, 496, 4), (476, 4, 496, DEEP)]),
    "sea": ("the calm blue sea meeting a sandy beach and a flat stone terrace edge, and below it short green grass over "
            "brown earth with small stones and roots, seen exactly from the side, blue sky",
            [(-16, 77, 4, DEEP)]),
}
# The painted sky's own colours.
SKY = [(146, 177, 224), (212, 222, 235), (174, 207, 230), (251, 240, 223)]


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


def scene(back: np.ndarray, ground: np.ndarray, earth) -> np.ndarray:
    """The view and the ground laid together as the 480 by 270 scene, the deep earth below the ground in its colour."""
    out = np.zeros((SCENE[1], SCENE[0], 4), np.uint8)
    out[:back.shape[0], :, :] = back
    out[GROUND_Y + ground.shape[0]:, :, :3] = earth
    out[GROUND_Y + ground.shape[0]:, :, 3] = 255
    part = out[GROUND_Y:GROUND_Y + ground.shape[0]]
    a = ground[:, :, 3:4].astype(np.float32) / 255.0
    part[:, :, :3] = (ground[:, :, :3] * a + part[:, :, :3] * (1 - a)).astype(np.uint8)
    part[:, :, 3] = np.maximum(part[:, :, 3], ground[:, :, 3])
    # The deep earth's faint stripes, a shade either side of its colour, would end where the flat earth below begins.
    deep = out[DEEP:, :, :3]
    flat = np.abs(deep.astype(np.int32) - np.array(earth)).max(axis=2) <= 4
    deep[flat] = earth
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(exist_ok=True)
    for name, (prompt, size) in PICTURES.items():
        raw = WORK / f"{name}.png"
        if not raw.exists():
            run(["pixen", f"{prompt}, {STYLE}", size, "--out", str(raw.relative_to(ROOT)), "--raw", "--view", "side",
                 "--outline", "lineless", "--detail", "highly detailed"])
        if not raw.exists():
            sys.exit(f"could not paint the {name}")
    if not (OUT / "wall.png").exists():
        Image.open(WORK / "wall.png").convert("RGBA").save(OUT / "wall.png")
    # The view and the ground as softened for the game, the ground's grass cut out, are kept as <name>_soft.png.
    back = np.array(Image.open(WORK / "back_soft.png").convert("RGBA"))
    ground = np.array(Image.open(WORK / "ground_soft.png").convert("RGBA"))
    deep = ground[DEEP - GROUND_Y:, :, :3].reshape(-1, 3)
    earth = Counter(map(tuple, deep)).most_common(1)[0][0]
    arr = scene(back, ground, earth)
    mx, my = MARGIN
    work = WORK / "shore_wide.png"
    if not work.exists():
        hint = widen.canvas(arr, MARGIN)
        hint[my + DEEP:, :mx, :3] = earth
        hint[my + DEEP:, -mx:, :3] = earth
        hint[my + SCENE[1]:, :, :3] = earth
        Image.fromarray(hint).save(work)
    wide = widen.widen(arr, work, SIDES, MARGIN, STYLE, paint="--no-paint" not in sys.argv)
    # Above the horizon left of the garum works, past the scene, there is only sky.
    wide[:my + HORIZON, :mx, 3] = 0
    wide[:my, :WORKS_X + mx, 3] = 0
    wide = clear_sky.clear_painted(wide, SKY, my + HORIZON)
    # The earth's cracks are drawn two and three pixels thick in places, and each pass softens their outer pixels.
    for _pass in range(3):
        wide, _n = soften_outlines.soften_lines(wide)
    Image.fromarray(wide).save(OUT / "shore.png")
    print("shore written", wide.shape[1], wide.shape[0])


if __name__ == "__main__":
    main()
