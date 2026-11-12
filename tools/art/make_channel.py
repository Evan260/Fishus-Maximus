"""The pond's sea channel: an arched stone culvert with a sluice gate through the stone wall below the garum works,
painted into a piece of the bank with PixelLab and cut out as a picture laid over the bank when the pond has it.

  python tools/art/make_channel.py prepare   writes the piece of the bank, its mask filled with the wall's average colour
  (then inpaint it with --no-context, and inpaint seam_mask.png over the result for the joins)
  python tools/art/make_channel.py build     writes game/assets/art/estate/channel.png from the chosen try
"""
import sys
from pathlib import Path

import numpy as np
import scipy.ndimage as nd
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
PARTS = ROOT / "tools" / "art" / "estate_parts" / "channel"
BANK = ROOT / "game" / "assets" / "art" / "estate" / "bank.png"
OUT = ROOT / "game" / "assets" / "art" / "estate" / "channel.png"
# Where the piece is cut from the bank, the last row of the bank's wall, and the try that was kept.
AT = (512, 96)
SIZE = 64
FOOT = 54
PICK = "try2.png"


def prepare() -> None:
    bank = Image.open(BANK).convert("RGBA")
    crop = bank.crop((AT[0], AT[1], AT[0] + SIZE, AT[1] + SIZE))
    mask = Image.new("L", (SIZE, SIZE), 0)
    d = ImageDraw.Draw(mask)
    d.rectangle((22, 40, 45, FOOT), fill=255)
    d.ellipse((22, 30, 45, 52), fill=255)
    m = np.asarray(mask) > 0
    a = np.asarray(crop).astype(float)
    ring = nd.binary_dilation(m, iterations=3) & ~m & (a[..., 3] > 200)
    a[m] = a[ring].mean(axis=0)
    a[m, 3] = 255
    Image.fromarray(a.astype(np.uint8)).save(PARTS / "crop_filled.png")
    crop.save(PARTS / "crop.png")
    mask.save(PARTS / "mask.png")
    seam = nd.binary_dilation(m, iterations=2) & ~nd.binary_erosion(m, iterations=1)
    seam[FOOT:] = False
    Image.fromarray((seam * 255).astype(np.uint8)).save(PARTS / "seam_mask.png")


def build() -> None:
    painted = np.asarray(Image.open(PARTS / PICK).convert("RGBA")).copy()
    bank = np.asarray(Image.open(PARTS / "crop.png").convert("RGBA"))
    m = np.asarray(Image.open(PARTS / "mask.png")) > 0
    near = nd.binary_dilation(m, iterations=3)
    changed = np.any(painted.astype(int) != bank.astype(int), axis=2)
    keep = near & changed & (bank[..., 3] > 0)
    keep[FOOT:] = False
    painted[~keep] = 0
    Image.fromarray(painted).save(OUT)


if __name__ == "__main__":
    {"prepare": prepare, "build": build}[sys.argv[1]]()
