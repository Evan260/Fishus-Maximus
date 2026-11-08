"""Paints the dark plants that stand right in front of the coast's view (places.json layers with "front"), each in the
harbour cape's style: branches hanging from the top edge and plants standing up from the bottom one. Each is painted
once into parts/front/, then cut so its stem or stalks run off the edge it stands on, toned to the cape's greens and
darkened to a near silhouette, with clear pixels on its other three sides. Usage:
  python tools/art/make_front.py [NAME...]   (delete game/assets/art/front/NAME.png to finish it again from its part)"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import make_places
import tone_land

ROOT = Path(__file__).resolve().parents[2]
PARTS = Path(__file__).with_name("places") / "parts" / "front"
OUT = ROOT / "game" / "assets" / "art" / "front"
CAPE = "game/assets/art/places/harbour/cape.png"
ALONE = "seen from the side, nothing else in the picture, empty transparent background, no ground, no sky"
# How light the plants are left, and the cool shadow colour they are drawn toward, so they read as near silhouettes.
LIGHT = 0.3
SHADE = np.array([0x10, 0x1a, 0x1c], dtype=np.float32)
# Each plant: the edge it stands on, its size, how much of it is cut away at that edge, and what to paint.
PLANTS = {
    "pine_branch": ("top", "224x112", 0.18, "a long bough of an umbrella pine reaching down into the picture from its top edge, a twisted reddish brown branch with flat dark green clouds of long pine needles"),
    "olive_branch": ("top", "192x112", 0.15, "an olive tree branch hanging down into the picture from its top edge, a grey twisted bough with many narrow grey-green olive leaves and a few small dark olives"),
    "fig_leaves": ("top", "160x112", 0.15, "a fig tree branch hanging down into the picture from its top edge, with big broad lobed fig leaves and two green figs"),
    "rushes": ("bottom", "128x144", 0.12, "a clump of tall reeds and grasses with feathery seed heads growing up from the bottom edge of the picture"),
    "oleander": ("bottom", "160x128", 0.12, "an oleander bush growing up from the bottom edge of the picture, narrow dark green leaves and clusters of pink flowers"),
    "palm": ("bottom", "144x128", 0.12, "a Mediterranean dwarf fan palm growing up from the bottom edge of the picture, stiff spiky fan shaped leaves on short stalks"),
    "pine": ("bottom", "128x240", 0.06, "a young umbrella pine tree, its bare reddish brown trunk rising from the bottom edge of the picture to a flat dark green canopy of pine needles"),
}


def finish(part: Path, edge: str, cut: float) -> Image.Image:
    a = np.array(Image.open(part).convert("RGBA"))
    a[a[:, :, 3] < 128] = 0
    a[:, :, 3] = np.where(a[:, :, 3] > 0, 255, 0)
    rows, cols = np.where(a[:, :, 3].any(axis=1))[0], np.where(a[:, :, 3].any(axis=0))[0]
    a = a[rows[0]:rows[-1] + 1, cols[0]:cols[-1] + 1]
    # The stem end is cut off, so what is left runs on past the edge of the view.
    n = int(round(a.shape[0] * cut))
    a = a[n:] if edge == "top" else a[:a.shape[0] - n]
    toned = np.array(tone_land.tone(Image.fromarray(a), rock=0.5)).astype(np.float32)
    toned[:, :, :3] = SHADE + (toned[:, :, :3] - SHADE) * LIGHT
    a = toned.astype(np.uint8)
    # One clear column at each side and a clear row at the free end, so the plant ends inside its picture there.
    h, w = a.shape[:2]
    out = np.zeros((h + 1, w + 2, 4), dtype=np.uint8)
    if edge == "top":
        out[:h, 1:-1] = a
    else:
        out[1:, 1:-1] = a
    return Image.fromarray(out)


def main(names):
    OUT.mkdir(parents=True, exist_ok=True)
    for name in names or PLANTS:
        edge, size, cut, prompt = PLANTS[name]
        part = PARTS / f"{name}.png"
        if not make_places.paint(part, f"{prompt}, {ALONE}", size, True, style=CAPE):
            continue
        out = OUT / f"{name}.png"
        if not out.exists():
            finish(part, edge, cut).save(out)
            print("finished", out.relative_to(ROOT).as_posix())


if __name__ == "__main__":
    main(sys.argv[1:])
