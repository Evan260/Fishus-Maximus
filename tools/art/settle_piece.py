"""Settles a seabed piece painted on flat sand onto a sloping seabed: each column is moved down by whole pixels as far
as the seabed falls under it, so the piece lies along the slope on its own sand, as a wreck that came to rest there
would, instead of sinking into the slope at its shallow end. The deeper end is on the right; --mirror puts it on the
left. Usage: python tools/art/settle_piece.py RAW OUT --drop N [--mirror]"""
import argparse

import numpy as np
from PIL import Image


def settle(raw: Image.Image, drop: int, mirror: bool = False) -> Image.Image:
    a = np.array(raw.convert("RGBA"))
    h, w = a.shape[:2]
    out = np.zeros((h + drop, w, 4), dtype=np.uint8)
    for x in range(w):
        k = (w - 1 - x) if mirror else x
        down = int(round(drop * k / max(1, w - 1)))
        out[down:down + h, x] = a[:, x]
    return Image.fromarray(out)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("raw")
    p.add_argument("out")
    p.add_argument("--drop", type=int, required=True, help="how many rows deeper the seabed is under the deep end")
    p.add_argument("--mirror", action="store_true")
    a = p.parse_args()
    settle(Image.open(a.raw), a.drop, a.mirror).save(a.out)
    print("settled", a.out)


if __name__ == "__main__":
    main()
