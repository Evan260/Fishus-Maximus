"""Paints the dark plants that stand right in front of the coast's view (places.json layers with "front"), each in the
harbour cape's style: branches hanging from the top edge and plants standing up from the bottom one. Each is painted
once into parts/front/, then cut so its stem or stalks run off the edge it stands on, toned to the cape's greens and
darkened to a near silhouette, with clear pixels on its other three sides. A plant standing up from below grows out of
a bank of near shore cut from parts/front/bank_rock.png, a rounded grassy crown just above the water and a rock face
running down DEPTH rows below its waterline, so the game sets that row on the waterline and the plant stands on land.
Usage:
  python tools/art/make_front.py [NAME...]   (delete game/assets/art/front/NAME.png to finish it again from its part)"""
import sys
import zlib
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
BANK = PARTS / "bank_rock.png"
BANK_PROMPT = ("a steep bank of rough pale limestone rock and brown earth seen close up from the side, cracked rock ledges "
               "with clumps of dark olive green grass and small scrub growing in the cracks, the rock face filling the whole "
               "picture edge to edge, no sky, no water")
# How light the plants are left, and the cool shadow colour they are drawn toward, so they read as near silhouettes.
LIGHT = 0.3
SHADE = np.array([0x10, 0x1a, 0x1c], dtype=np.float32)
# Rows of bank below its waterline (ParallaxLayers.FRONT_DEPTH): the 110 seen with the camera at home, and the 24 it dips.
DEPTH = 140
# The bank under the water is drawn toward the sea's own dark colour, the more so the deeper it reaches.
WATER = np.array([0x1c, 0x3c, 0x42], dtype=np.float32)
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


def darken(im: Image.Image, rock: float = 0.5) -> np.ndarray:
    toned = np.array(tone_land.tone(im, rock=rock)).astype(np.float32)
    toned[:, :, :3] = SHADE + (toned[:, :, :3] - SHADE) * LIGHT
    return toned


def plant(part: Path, edge: str, cut: float) -> np.ndarray:
    a = np.array(Image.open(part).convert("RGBA"))
    a[a[:, :, 3] < 128] = 0
    a[:, :, 3] = np.where(a[:, :, 3] > 0, 255, 0)
    rows, cols = np.where(a[:, :, 3].any(axis=1))[0], np.where(a[:, :, 3].any(axis=0))[0]
    a = a[rows[0]:rows[-1] + 1, cols[0]:cols[-1] + 1]
    # The stem end is cut off, so what is left runs on past the edge of the view.
    n = int(round(a.shape[0] * cut))
    a = a[n:] if edge == "top" else a[:a.shape[0] - n]
    return darken(Image.fromarray(a)).astype(np.uint8)


def wobble(rng, n: int, amp: float) -> np.ndarray:
    """A smooth irregular line n long, wandering about amp either way, with the small steps of broken rock in it."""
    x = np.arange(n, dtype=np.float32)
    line = np.zeros(n, dtype=np.float32)
    for k, f in enumerate((1.0, 2.3, 5.1)):
        line += amp / (k + 1) * np.sin(x * f * 2 * np.pi / max(n, 40) + rng.uniform(0, 2 * np.pi))
    steps, at = np.zeros(n, dtype=np.float32), 0
    while at < n:
        span = int(rng.integers(3, 9))
        steps[at:at + span] = rng.uniform(-0.6, 0.6) * amp * 0.5
        at += span
    return line + steps


def ledges(rng, h: int, wl: int) -> np.ndarray:
    """How far a bank's side stands out past its crown at each row under the water: rock faces leaning out a little,
    broken by ledges stepping out and hollows cutting in."""
    out = np.zeros(h, dtype=np.float32)
    x, rows = 0.0, 0
    step = 0.0
    for y in range(wl, h):
        if rows == 0:
            roll = rng.random()
            step, rows = (1.4, int(rng.integers(2, 6))) if roll < 0.08 else (-1.2, int(rng.integers(2, 5))) if roll < 0.14 else (0.05, 1)
        x = float(np.clip(x + step, -5.0, 14.0))
        rows -= 1
        out[y] = x
    # The shoulder curves on down from the crown before the face begins.
    down = np.clip(np.arange(h) - wl, 0, None)
    out += 6.0 * (1.0 - np.exp(-down / 5.0))
    return np.convolve(out, np.ones(3) / 3, mode="same") + wobble(rng, h, 3.0)


def stand(a: np.ndarray, name: str) -> np.ndarray:
    """Sets a plant standing up from below on its own bank of near shore, grassy on its rounded crown and rock below,
    the bank's waterline DEPTH rows above the picture's bottom."""
    rng = np.random.default_rng(zlib.crc32(name.encode()))
    ph, pw = a.shape[:2]
    base = np.where(a[-6:, :, 3].any(axis=0))[0]
    centre = (base[0] + base[-1]) / 2.0
    half = max(26.0, (base[-1] - base[0]) / 2.0 + 10.0)
    sides = half + rng.uniform(-4.0, 10.0, 2)
    rise = float(np.clip(half * 0.4, 12.0, 15.0))
    w = int(max(pw, 2 * (sides.max() + 24))) + 2
    shift = (w - pw) // 2
    c = centre + shift
    xs = np.arange(w, dtype=np.float32)
    # The crown: a rounded mound over the water, bumpy as grass and rock are, its shoulders curving down into the sea.
    t = np.clip(np.where(xs < c, (xs - c) / sides[0], (xs - c) / sides[1]), -1.0, 1.0)
    crown = -rise * (1.0 - t ** 2) ** 0.7 + 1.0 + wobble(rng, w, 2.2)
    crown = np.where(np.abs(t) < 1.0, crown, np.inf)
    # The plant sinks a few rows into the bank, so the crown covers where its stems were cut.
    sit = int(np.ceil(crown[shift + base[0]:shift + base[-1] + 1].max())) + 3
    wl = ph - sit
    h = wl + DEPTH
    ys = np.arange(h, dtype=np.float32)[:, None] - wl
    left = c - sides[0] - ledges(rng, h, wl)[:, None]
    right = c + sides[1] + ledges(rng, h, wl)[:, None]
    under = (ys >= 0) & (xs[None, :] >= left) & (xs[None, :] <= right)
    land = under | (ys >= crown[None, :])
    land[:, 0] = land[:, -1] = False
    # Blades of grass stand a row or two up from the crown here and there.
    grass = np.zeros_like(land)
    surface = np.argmax(land, axis=0)
    for x in range(1, w - 1):
        if land[:, x].any() and ys[surface[x], 0] < 0 and rng.random() < 0.45:
            tall = int(rng.integers(1, 3))
            grass[max(0, surface[x] - tall):surface[x], x] = True
    top = int(np.where((land | grass).any(axis=1))[0][0])
    rock = Image.open(BANK).convert("RGBA")
    ox = int(rng.integers(0, max(1, rock.width - w)))
    oy = int(rng.integers(0, max(1, rock.height - (h - top))))
    tex = np.zeros((h, w, 4), dtype=np.float32)
    tex[top:] = darken(rock.crop((ox, oy, ox + w, oy + h - top)), rock=0.8)
    out = np.zeros((h, w, 4), dtype=np.uint8)
    region = out[:ph, shift:shift + pw]
    take = a[:, :, 3] > 0
    region[take] = a[take]
    deep = np.clip(ys / 110.0, 0, 1)
    shade = np.where(ys >= 0, 0.5 + 0.25 * deep, 0.0)[..., None]
    rgb = tex[:, :, :3] * (1 - shade) + WATER * shade
    green = np.array([0x22, 0x2c, 0x1e], dtype=np.float32) + rng.uniform(-4, 4, (h, w, 1))
    # Grass covers the crown a few rows deep above the water.
    cover = (land & (ys < 0) & (np.cumsum(land, axis=0) <= 4))[..., None]
    rgb = np.where(cover, rgb * 0.4 + green * 0.6, rgb)
    rgb = np.where(grass[..., None], green, rgb)
    # The water laps along the bank's waterline in a broken pale line.
    lap = (np.abs(ys[:, 0]) < 0.5)[:, None] & (rng.random((h, w)) < 0.7)
    rgb = np.where(lap[..., None] & land[..., None], rgb * 0.7 + np.array([0x5a, 0x7e, 0x80]) * 0.3, rgb)
    paint = land | grass
    out[paint, :3] = np.clip(rgb[paint], 0, 255).astype(np.uint8)
    out[paint, 3] = 255
    rows = np.where(out[:, :, 3].any(axis=1))[0]
    out = out[rows[0]:]
    # A clear row along the top, so the plant ends inside its picture there.
    return np.concatenate([np.zeros((1, w, 4), dtype=np.uint8), out])


def finish(part: Path, edge: str, cut: float, name: str = "") -> Image.Image:
    a = plant(part, edge, cut)
    if edge == "bottom":
        return Image.fromarray(stand(a, name))
    # One clear column at each side and a clear row at the free end, so the plant ends inside its picture there.
    h, w = a.shape[:2]
    out = np.zeros((h + 1, w + 2, 4), dtype=np.uint8)
    out[:h, 1:-1] = a
    return Image.fromarray(out)


def main(names):
    OUT.mkdir(parents=True, exist_ok=True)
    if not make_places.paint(BANK, BANK_PROMPT, "192x192", False, style=CAPE):
        return
    for name in names or PLANTS:
        edge, size, cut, prompt = PLANTS[name]
        part = PARTS / f"{name}.png"
        if not make_places.paint(part, f"{prompt}, {ALONE}", size, True, style=CAPE):
            continue
        out = OUT / f"{name}.png"
        if not out.exists():
            finish(part, edge, cut, name).save(out)
            print("finished", out.relative_to(ROOT).as_posix())


if __name__ == "__main__":
    main(sys.argv[1:])
