"""Builds the harbour's row of town from coast/town.png with its lighthouse whole. The lighthouse stands near the row's
end, where land must slope down to the sea no more steeply than a hillside, so its shaft is shortened by rows from the
middle rather than having its side cut away; then the row's ends are tapered and its shore painted on as
make_places.py does. Writes game/assets/art/places/harbour/town.png. Usage: python tools/art/make_harbour_town.py"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

import make_places

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "game" / "assets" / "art"
SRC = ART / "coast" / "town.png"
OUT = ART / "places" / "harbour" / "town.png"
PARTS = Path(__file__).with_name("places") / "parts" / "harbour"
# The lighthouse's columns, and the rows of its plain shaft taken out between the upper window and the house roofs.
TOWER = (412, 441)
SHAFT = (40, 63)


def shorten(arr: np.ndarray) -> np.ndarray:
    out = arr.copy()
    x0, x1 = TOWER
    y0, y1 = SHAFT
    k = y1 - y0
    out[k:y1, x0:x1] = arr[:y0, x0:x1]
    out[:k, x0:x1] = 0
    return out


def main():
    arr = shorten(np.array(Image.open(SRC).convert("RGBA")))
    arr = make_places.fade_top(make_places.taper_ends(arr))
    Image.fromarray(arr).save(OUT)
    for done in ("town.shore", "town_inland.png"):
        (PARTS / done).unlink(missing_ok=True)
    spec = json.loads((Path(__file__).with_name("places") / "harbour.json").read_text(encoding="utf-8"))
    layer = next(l for l in spec["layers"] if l.get("file") == "town.png")
    make_places.shore_land("harbour", layer, OUT)
    print("harbour town built", arr.shape[1], arr.shape[0])


if __name__ == "__main__":
    main()
