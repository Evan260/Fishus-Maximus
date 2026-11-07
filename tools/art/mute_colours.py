"""Tones down over-bright sprites: each pixel's colour is drawn towards its own grey by a factor, keeping its
lightness, so a garish fish turns into a natural one without losing its markings. Writes the pictures back in place,
so run it once on a picture: a second run mutes it again.
Usage: python tools/art/mute_colours.py KEEP PATH [PATH...]   (KEEP is how much colour stays, such as 0.65)"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image


def mute(path: Path, keep: float) -> None:
    im = np.array(Image.open(path).convert("RGBA")).astype(float)
    rgb = im[:, :, :3]
    grey = (rgb * [0.3, 0.59, 0.11]).sum(axis=2, keepdims=True)
    im[:, :, :3] = np.clip(grey + (rgb - grey) * keep, 0, 255)
    Image.fromarray(im.astype(np.uint8)).save(path)


def main(args):
    keep = float(args[0])
    for a in args[1:]:
        mute(Path(a), keep)
        print("muted", a)


if __name__ == "__main__":
    main(sys.argv[1:])
