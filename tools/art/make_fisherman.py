"""Builds the fisherman from his PixelLab character in tools/art/props_raw/fisherman_char/: the seated pose he fishes
in, an eight-frame rowing stroke and a nine-frame cast, all on one 64 pixel canvas, with stray specks and dark edges
taken out, and where his hands are in every frame, so the game can put the oar and the rod in them. Writes
game/assets/art/fisherman/. Usage: python tools/art/make_fisherman.py"""
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

import soften_outlines

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(__file__).with_name("props_raw") / "fisherman_char"
OUT = ROOT / "game" / "assets" / "art" / "fisherman"
# The rows of the canvas where he sits on the bench, and where his body's middle is, for seating him in a boat.
HIP = 40
MIDDLE = 28
# Frames where the hands are hidden in the pose or lost against the knees, set by eye.
HANDS_BY_EYE = {("row", 0): (38, 25), ("row", 8): (32, 29), ("cast", 0): (38, 25), ("cast", 1): (38, 25),
                ("cast", 2): (33, 21)}


def without_specks(im: np.ndarray) -> np.ndarray:
    """Drops the little marks drawn beside a moving arm, which are not part of him."""
    solid = (im[:, :, 3] > 127).astype(np.uint8)
    n, labels, stats, _ = cv2.connectedComponentsWithStats(solid, connectivity=8)
    keep = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    out = im.copy()
    for i in range(1, n):
        if i != keep and stats[i, cv2.CC_STAT_AREA] < 12:
            out[labels == i] = 0
    return out


def find_hands(im: np.ndarray) -> list:
    """The arm's skin farthest from his head, leaving out the straw hat, his face and his knees."""
    a = im.astype(int)
    solid = a[:, :, 3] > 127
    r, g = a[:, :, 0], a[:, :, 1]
    straw = solid & (r > 185) & (g > 0.72 * r) & (g < 0.82 * r)
    skin = solid & (r > 200) & (g < 0.72 * r) & (g > 0.6 * r)
    ys, xs = np.nonzero(straw[:22])
    left, right, brim = xs.min(), xs.max(), ys.max()
    middle = (left + right) / 2.0
    skin[:brim + 1] = False
    skin[34:] = False
    skin[brim + 1:brim + 9, int(middle - 4):int(middle + 6)] = False
    ys, xs = np.nonzero(skin)
    far = np.argmax((xs - middle) ** 2 + (ys - brim - 4) ** 2)
    return [int(xs[far]), int(ys[far])]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    hands = {}
    first = np.array(Image.open(SRC / "row_east" / "frame_00.png").convert("RGBA"))
    Image.fromarray(first).save(OUT / "sit.png")
    soften_outlines.soften(OUT / "sit.png")
    hands["sit"] = [list(HANDS_BY_EYE[("row", 0)])]
    for move, frames in (("row", range(1, 9)), ("cast", range(0, 9))):
        hands[move] = []
        for k, i in enumerate(frames):
            im = without_specks(np.array(Image.open(SRC / f"{move}_east" / f"frame_{i:02d}.png").convert("RGBA")))
            Image.fromarray(im).save(OUT / f"{move}_{k:02d}.png")
            soften_outlines.soften(OUT / f"{move}_{k:02d}.png")
            hands[move].append(list(HANDS_BY_EYE.get((move, i), find_hands(im))))
    (OUT / "fisherman.json").write_text(json.dumps({"size": 64, "hip": HIP, "middle": MIDDLE, "hands": hands}, indent=1))
    print("fisherman written:", {m: len(h) for m, h in hands.items()})


if __name__ == "__main__":
    main()
