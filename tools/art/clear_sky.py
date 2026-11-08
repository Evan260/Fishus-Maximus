"""Takes painted clouds and sky out of a row of land, so the game's own drifting sky shows there instead. The land is
what joins the picture's bottom once the pale colours of cloud are left out, and in each column everything above the
land's top is cleared. `clear_painted` does the same for a whole scene, such as the town street seen under its roof:
the sky there is whatever is near one of the sky's own colours, lying together above the horizon.
Usage: python tools/art/clear_sky.py PATH [PATH...]   (writes each picture back in place)"""
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

# Painted cloud is paler than any land in the far rows it is used on.
PALE = 185
# How near a colour must be to one of the sky's own, over red, green and blue together, and how many such pixels must
# lie together to be sky rather than a pale patch of a building.
NEAR_SKY = 30
SKY_AREA = 4
# Paint left in pieces this small, with the sky cleared from round them, was the sky's own edge.
SPECK = 12


def clear_painted(arr: np.ndarray, palette, below: int) -> np.ndarray:
    """The scene with its painted sky taken out: the pixels above row `below` near one of the `palette` colours, in
    patches of at least SKY_AREA, and the specks of paint left floating where they were."""
    out = arr.copy()
    rgb = arr[:, :, :3].astype(np.int32)
    # Sky painted on past a scene's edges has blues of its own, so any light blue counts as well.
    near = (rgb[:, :, 2] >= rgb[:, :, 0] + 18) & (rgb[:, :, 2] >= rgb[:, :, 1]) & (rgb @ np.array([30, 59, 11]) > 14000)
    for c in palette:
        near |= np.abs(rgb - np.array(c, dtype=np.int32)).sum(axis=2) <= NEAR_SKY
    near &= arr[:, :, 3] > 16
    near[below:] = False
    n, labels, stats, _c = cv2.connectedComponentsWithStats(near.astype(np.uint8), connectivity=4)
    sky = np.isin(labels, [i for i in range(1, n) if stats[i][cv2.CC_STAT_AREA] >= SKY_AREA])
    out[sky, 3] = 0
    solid = out[:, :, 3] > 16
    n, labels, stats, _c = cv2.connectedComponentsWithStats(solid.astype(np.uint8), connectivity=8)
    around = cv2.dilate(sky.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    for i in range(1, n):
        if stats[i][cv2.CC_STAT_AREA] < SPECK and around[labels == i].all():
            out[labels == i, 3] = 0
    return out


def clear(arr: np.ndarray) -> np.ndarray:
    out = arr.copy()
    solid = arr[:, :, 3] > 16
    light = arr[:, :, :3].astype(np.float32) @ np.array([0.3, 0.59, 0.11], dtype=np.float32)
    land = solid & (light <= PALE)
    _n, labels = cv2.connectedComponents(land.astype(np.uint8), connectivity=8)
    grounded = np.unique(labels[-3:][land[-3:]])
    body = np.isin(labels, grounded) & land
    top = np.argmax(body, axis=0)
    keep = body.any(axis=0)[None, :] & (np.arange(arr.shape[0])[:, None] >= top[None, :])
    out[~keep, 3] = 0
    return out


def main(paths):
    for p in paths:
        before = np.array(Image.open(p).convert("RGBA"))
        after = clear(before)
        Image.fromarray(after).save(p)
        print(f"cleared {int(((before[:, :, 3] > 0) & (after[:, :, 3] == 0)).sum())} pixels of sky from {Path(p).name}")


if __name__ == "__main__":
    main(sys.argv[1:])
