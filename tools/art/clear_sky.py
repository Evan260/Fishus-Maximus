"""Takes painted clouds and sky out of a row of land, so the game's own drifting sky shows there instead. The land is
what joins the picture's bottom once the pale colours of cloud are left out, and in each column everything above the
land's top is cleared. Usage: python tools/art/clear_sky.py PATH [PATH...]   (writes each picture back in place)"""
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

# Painted cloud is paler than any land in the far rows it is used on.
PALE = 185


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
