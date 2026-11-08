"""Makes a smaller, hazier copy of the part of a prop that stands above the water, to stand further back in a band of
the far water, where the game mirrors it in the sea. The prop's own pixels are kept, picked by nearest, and blended a
share of the way to the band's sea colour, as the land at that distance is; any piece cut by the picture's sides is
left out, so no straight cut shows.
Usage: python tools/art/set_back.py SOURCE WATERLINE_ROW SCALE BAND_COLOUR HAZE OUT   (paths under game/assets/art)"""
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ART = Path(__file__).resolve().parents[2] / "game" / "assets" / "art"


def set_back(source: Path, waterline: int, scale: float, band: str, haze: float, out: Path) -> None:
    im = Image.open(source).convert("RGBA").crop((0, 0, Image.open(source).width, waterline))
    w, h = max(1, round(im.width * scale)), max(1, round(im.height * scale))
    small = np.array(im.resize((w, h), Image.NEAREST)).astype(np.float32)
    sea = np.array([int(band[i:i + 2], 16) for i in (1, 3, 5)], np.float32)
    small[:, :, :3] = small[:, :, :3] * (1.0 - haze) + sea * haze
    small[:, :, 3] = np.where(small[:, :, 3] > 127, 255, 0)
    _n, labels = cv2.connectedComponents((small[:, :, 3] > 0).astype(np.uint8), connectivity=8)
    for cut in set(labels[:, 0]) | set(labels[:, -1]):
        if cut:
            small[labels == cut] = 0
    Image.fromarray(small.astype(np.uint8)).save(out)
    print("set back", source.name, "as", out.name, (w, h))


if __name__ == "__main__":
    a = sys.argv[1:]
    set_back(ART / a[0], int(a[1]), float(a[2]), a[3], float(a[4]), ART / a[5])
