"""Paints the buildings whose own pictures came out at the wrong angle straight into the street, inside a
building-shaped outline, so they take the street's angle and light; each is then cut out by that outline.
Usage: python tools/art/make_town_shapes.py"""
import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import make_town as mt

SHAPES = {
    "market": ([("rect", (10, 138, 160, 236)), ("ellipse", (32, 96, 138, 180)), ("rect", (78, 86, 92, 100))],
               "the fish market of a Roman town: a round fish hall with a tiled dome on white columns, stone counters with fish under a striped awning, a marble water basin in front"),
    "boatwright": ([("rect", (262, 176, 358, 236)), ("poly", [(300, 178), (358, 178), (358, 150), (329, 136), (300, 150)])],
                   "a Roman boatwright's yard: a wooden boat being built on trestles in front of a small timber shed with a tiled roof, planks and ropes"),
    "netmaker": ([("rect", (166, 152, 254, 236)), ("poly", [(162, 154), (258, 154), (210, 124)])],
                 "a small Roman netmaker's shop with a red tiled gable roof, an open front with fishing nets hung to dry, rods by the door, baskets of bait"),
}


def main():
    street = mt.WORK / "street.png"
    canvas = mt.WORK / "shaped.png"
    if not canvas.exists():
        shutil.copy(street, canvas)
    spots = json.loads((mt.OUT / "town.json").read_text())
    for bid, (shapes, prompt) in SHAPES.items():
        # A building already painted into the street keeps its picture; delete its shape file to paint it again.
        if (mt.WORK / f"{bid}_shape.png").exists() and (mt.OUT / f"{bid}.png").exists():
            continue
        mask = Image.new("L", Image.open(canvas).size, 0)
        d = ImageDraw.Draw(mask)
        for kind, geo in shapes:
            if kind == "rect":
                d.rectangle(geo, fill=255)
            elif kind == "ellipse":
                d.ellipse(geo, fill=255)
            else:
                d.polygon(geo, fill=255)
        mask_path = mt.WORK / f"{bid}_shape.png"
        mask.save(mask_path)
        if not mt.run(["inpaint", str(canvas.relative_to(mt.ROOT)), str(mask_path.relative_to(mt.ROOT)), f"{prompt}, {mt.STYLE}",
                       "--out", str(canvas.relative_to(mt.ROOT))]):
            print("FAILED", bid)
            continue
        im = np.array(Image.open(canvas).convert("RGBA"))
        m = np.array(mask) > 0
        im[:, :, 3] = np.where(m, 255, 0)
        ys, xs = np.where(m)
        box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
        Image.fromarray(im).crop(box).save(mt.OUT / f"{bid}.png")
        spots[bid] = [int(box[0]), int(box[1])]
        print("painted", bid, box)
    (mt.OUT / "town.json").write_text(json.dumps(spots, indent=1))


if __name__ == "__main__":
    main()
