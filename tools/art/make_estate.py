"""The estate's pond screen: the far bank of the pond and the beach the sea washes up.

The bank is laid together from pieces PixelLab painted in the cape's style (estate_parts/*_raw.png): the villa on its
rise at the left, the garum works and a grassy rise at the right, and in front of them all, along the pond's far edge,
one stone wall painted once and joined onto itself. The rocks and the den on the pond's floor are painted at the
pond's size, which is smaller than the open sea's pieces. The beach is drawn without PixelLab, as the seabed sand is: warm
sand with faint speckle, ripples and shells, joining onto itself; the game washes the sea up it.

Usage: python tools/art/make_estate.py [wall|bank|pieces|beach|all]
`wall` joins the painted wall onto itself with one PixelLab inpaint, only when estate_parts/wall.png is missing.
"""
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PARTS = Path(__file__).with_name("estate_parts")
OUT = ROOT / "game" / "assets" / "art" / "estate"
PIXELLAB = Path(__file__).with_name("pixellab.py")

## The bank's size, and the screen column its left edge is at with the camera at home in a 480 wide view.
BANK_W, BANK_H = 768, 160
BANK_X = -144
## Where the wall's foot, the pond's waterline in the bank, lies in the bank picture, and the rows of the painted
## wall that stand above it: the grass, the capstones and the top of the blocks below them.
FOOT = 150
WALL_ROWS = (3, 30)
## The first row of the kept wall below its grass.
STONE_FROM = 11
## The painted wall without its cut ends, and the rows of it kept.
WALL_CROP = (28, 8, 228, 44)
## Each piece standing behind the wall: its file, its left column in the bank and its foot row in the bank.
PIECES = [("villa_raw.png", 80, 140), ("rise_raw.png", 600, 132), ("garum_raw.png", 432, 140)]
BEACH_W, BEACH_H = 512, 56
SAND = np.array([0xd9, 0xc4, 0x98], dtype=np.float32)


def wall():
    target = PARTS / "wall.png"
    if target.exists():
        return
    raw = Image.open(PARTS / "coping2_raw.png").convert("RGBA").crop(WALL_CROP)
    w, h = raw.size
    arr = np.roll(np.asarray(raw), w // 2, axis=1).copy()
    mid = w // 2
    # The cut ends meet in the middle, covered by the stretch of wall whose ends best match the stones either side.
    best = min((s for s in range(10, w - 60) if abs(s - (mid - 20)) >= 50),
               key=lambda s: np.abs(arr[:, s].astype(int) - arr[:, mid - 21].astype(int)).sum()
               + np.abs(arr[:, s + 41].astype(int) - arr[:, mid + 20].astype(int)).sum())
    arr[:, mid - 20:mid + 20] = arr[:, best + 1:best + 41]
    filled = PARTS / "wall_seam_filled.png"
    Image.fromarray(arr).save(filled)
    mask = np.zeros((h, w), np.uint8)
    mask[:, mid - 24:mid - 14] = 255
    mask[:, mid + 14:mid + 24] = 255
    Image.fromarray(mask).save(PARTS / "wall_seam_mask.png")
    # The whole strip is the tile sent, so PixelLab sees the stones beside each join without copies of a wider scene.
    subprocess.run([sys.executable, str(PIXELLAB), "inpaint", str(filled.relative_to(ROOT)),
                    str((PARTS / "wall_seam_mask.png").relative_to(ROOT)),
                    "weathered Roman wall of cut golden tufa blocks with mossy joints, flat grey capstones on top, "
                    "short grass along the top, pixel art, no outlines",
                    "--out", str(target.relative_to(ROOT)), "--transparent", "--no-context", "--tile", f"{w}x{h}"],
                   check=True, cwd=ROOT)


def bank():
    """The pieces standing on the land behind the pond, then the wall along the pond's edge in front of them all."""
    out = Image.new("RGBA", (BANK_W, BANK_H))
    for name, x, foot in PIECES:
        piece = Image.open(PARTS / name).convert("RGBA")
        bottom = np.where((np.asarray(piece)[:, :, 3] > 0).any(1))[0].max() + 1
        out.alpha_composite(piece, (x, foot - bottom))
    strip = np.asarray(Image.open(PARTS / "wall.png").convert("RGBA"))[WALL_ROWS[0]:WALL_ROWS[1]].copy()
    # The stone below the grass is solid, so the odd clear pixel PixelLab left in it takes the colour above it.
    for y in range(STONE_FROM, len(strip)):
        hole = strip[y, :, 3] < 255
        strip[y, hole] = strip[y - 1, hole]
        strip[y, :, 3] = 255
    strip = Image.fromarray(strip)
    wall_layer = Image.new("RGBA", (BANK_W, BANK_H))
    for x in range(0, BANK_W, strip.width):
        wall_layer.alpha_composite(strip, (x, FOOT - strip.height))
    out.alpha_composite(wall_layer)
    walls = np.asarray(wall_layer)
    arr = np.asarray(out).copy()
    arr[FOOT:] = 0
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(arr).save(OUT / "bank.png")
    subprocess.run([sys.executable, str(Path(__file__).with_name("soften_outlines.py")), str(OUT / "bank.png")], check=True)
    # The garum works' own pixels, less the wall in front of it, which the mouse and its gold outline go by.
    works = Image.new("RGBA", (BANK_W, BANK_H))
    name, x, foot = next(p for p in PIECES if p[0] == "garum_raw.png")
    piece = Image.open(PARTS / name).convert("RGBA")
    works.alpha_composite(piece, (x, foot - np.where((np.asarray(piece)[:, :, 3] > 0).any(1))[0].max() - 1))
    mask = (np.asarray(works)[:, :, 3] > 127) & ~(walls[:, :, 3] > 0)
    alpha = np.where(mask, 255, 0).astype(np.uint8)
    Image.fromarray(np.dstack([np.full_like(alpha, 255)] * 3 + [alpha]), "RGBA").save(OUT / "garum_mask.png")
    print("saved", OUT / "garum_mask.png")


def pieces():
    """The rocks and the den laid on the pond's floor for its features, painted at the pond's size."""
    OUT.mkdir(parents=True, exist_ok=True)
    for name in ("pond_rocks", "pond_cave"):
        Image.open(PARTS / f"{name}_raw.png").convert("RGBA").save(OUT / f"{name}.png")
    subprocess.run([sys.executable, str(Path(__file__).with_name("soften_outlines.py")), str(OUT / "pond_rocks.png"),
                    str(OUT / "pond_cave.png")], check=True)


def beach():
    """Sand lighter and finer far off, coarser and warmer near, with wind ripples, pebbles and shells."""
    rng = np.random.default_rng(72)
    y = np.arange(BEACH_H, dtype=np.float32)[:, None]
    x = np.arange(BEACH_W, dtype=np.float32)[None, :]
    near = y / BEACH_H
    tone = 1.0 - 0.06 * near
    tau = 2 * np.pi / BEACH_W
    ripple = np.sin(x * tau * 24 + np.sin(x * tau * 3) * 3 + y * 0.9) * np.sin(x * tau * 5 + 1.3)
    tone = tone + np.where(ripple > 0.55, 0.035, np.where(ripple < -0.7, -0.03, 0.0)) * (0.4 + near)
    speck = rng.random((BEACH_H, BEACH_W))
    tone = tone + np.where(speck > 0.985, 0.06, 0.0) - np.where(speck < 0.02 + 0.02 * near, 0.07, 0.0)
    rgb = SAND[None, None, :] * tone[..., None]
    rgb = rgb * (1.0 + np.array([0.0, -0.01, -0.035]) * near[..., None])
    for _ in range(70):
        px, py = rng.integers(0, BEACH_W), rng.integers(8, BEACH_H)
        shade = rng.choice([0.72, 0.8, 1.12])
        rgb[py, px] *= shade
        if rng.random() < 0.4:
            rgb[py, (px + 1) % BEACH_W] *= shade
    out = np.dstack([np.clip(rgb, 0, 255), np.full((BEACH_H, BEACH_W), 255)]).astype(np.uint8)
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(out, "RGBA").save(OUT / "beach.png")
    print("saved", OUT / "beach.png")


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("wall", "all"):
        wall()
    if what in ("bank", "all"):
        bank()
    if what in ("pieces", "all"):
        pieces()
    if what in ("beach", "all"):
        beach()
