"""Builds the game's icon: the game's own gilt-head bream, big and bold, leaping clear of the sea at sunset on a
rounded tile, so it still reads at the taskbar's tiny sizes, where a whole painted scene turns to mush. The tile is
drawn at 64 pixels; the big sizes are whole multiples of it and the small ones averaged down from it. Writes
game/icon.png and game/icon.ico with every size Windows asks for, marketing/profile_picture.png, and Android's
launcher icons in game/assets/art/ui/: the tile at three times, and the adaptive icon's two layers and its themed
shape at four.
Usage: python tools/art/make_icon.py"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
FISH = ROOT / "game" / "assets" / "art" / "fish" / "bream.png"
SIZES = [16, 24, 32, 48, 64, 128, 256]
TILE = 64
# Android's adaptive icon square, drawn at four times to its 432 pixels, and where its pictures go.
ANDROID = 108
UI = ROOT / "game" / "assets" / "art" / "ui"
# The tile's corner rounding, the row of the horizon, and the colours of the sky, the ripples and the sea.
CORNER = 11
HORIZON = 40
SKY = [(250, 196, 120), (236, 132, 92)]
RIPPLE = (120, 182, 200)
SEA = [(70, 140, 168), (28, 70, 98)]
EDGE = (38, 34, 48)
SPRAY = (240, 248, 250)


def inside(x: float, y: float, size: int, corner: int) -> bool:
    cx = min(max(x, corner), size - 1 - corner)
    cy = min(max(y, corner), size - 1 - corner)
    return (x - cx) ** 2 + (y - cy) ** 2 <= corner ** 2


def mix(a, b, t: float):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def tile() -> np.ndarray:
    out = np.zeros((TILE, TILE, 4), np.uint8)
    for y in range(TILE):
        for x in range(TILE):
            if not inside(x, y, TILE, CORNER):
                continue
            if y < HORIZON:
                c = mix(SKY[0], SKY[1], y / HORIZON)
            else:
                c = mix(SEA[0], SEA[1], (y - HORIZON) / (TILE - HORIZON))
                # A few soft ripples spreading from where the fish broke the surface.
                for row, half in ((HORIZON + 6, 14), (HORIZON + 12, 20)):
                    if y == row and 3 <= abs(x - 32) <= half and abs(x - 32) % 7 < 4:
                        c = RIPPLE
            out[y, x] = (*c, 255)
    # A dark rim one pixel in from the rounded edge, so the tile stands out on a light or dark taskbar.
    solid = out[:, :, 3] > 0
    for y in range(TILE):
        for x in range(TILE):
            if solid[y, x] and not all(0 <= y + dy < TILE and 0 <= x + dx < TILE and solid[y + dy, x + dx]
                                       for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out[y, x] = (*EDGE, 255)
    return out


def leaping_fish(canvas: np.ndarray) -> None:
    fish = np.array(Image.open(FISH).convert("RGBA"))
    h, w = fish.shape[:2]
    x0, y0 = (TILE - w) // 2, HORIZON - h - 3
    solid = fish[:, :, 3] > 127
    # The fish is ringed in the rim's dark colour, so its shape holds against the sun and the sea at small sizes.
    ring = np.zeros((h + 2, w + 2), bool)
    for dy in range(3):
        for dx in range(3):
            ring[dy:dy + h, dx:dx + w] |= solid
    for y, x in zip(*np.nonzero(ring)):
        canvas[y0 + y - 1, x0 + x - 1, :3] = EDGE
    canvas[y0:y0 + h, x0:x0 + w][solid] = fish[solid]
    # A crown of spray thrown up from the water under it as it leaps clear.
    for dx, dy in [(-9, 0), (-8, -1), (-6, -2), (-5, 0), (-3, -1), (-1, 0), (1, -2), (2, 0), (4, -1), (6, 0), (7, -2), (9, -1), (10, 0)]:
        canvas[HORIZON + dy, TILE // 2 + dx, :3] = SPRAY
    for dx in range(-11, 13):
        if dx % 3 != 0:
            canvas[HORIZON + 1, TILE // 2 + dx, :3] = SPRAY


def android_layers() -> tuple:
    """Android's adaptive icon: the sea at sunset carried out to the square's edges as the background and the leaping
    fish as the foreground, drawn on a 108 pixel square whose middle 72 the launcher's mask always shows."""
    pad = (ANDROID - TILE) // 2
    back = np.zeros((ANDROID, ANDROID, 4), np.uint8)
    for y in range(ANDROID):
        row = y - pad
        if row < HORIZON:
            c = mix(SKY[0], SKY[1], max(0, row) / HORIZON)
        else:
            c = mix(SEA[0], SEA[1], min(1.0, (row - HORIZON) / (TILE - HORIZON)))
        back[y, :] = (*c, 255)
    for row, half in ((HORIZON + 6, 14), (HORIZON + 12, 20)):
        for x in range(ANDROID):
            if 3 <= abs(x - pad - 32) <= half and abs(x - pad - 32) % 7 < 4:
                back[row + pad, x, :3] = RIPPLE
    fish = np.zeros((TILE, TILE, 4), np.uint8)
    leaping_fish(fish)
    # The spray is drawn into the colour alone, so it is made solid here like the fish.
    fish[:, :, 3] = np.where(fish[:, :, :3].any(axis=2), 255, 0)
    front = np.zeros((ANDROID, ANDROID, 4), np.uint8)
    front[pad:pad + TILE, pad:pad + TILE] = fish
    return Image.fromarray(back), Image.fromarray(front)


def main():
    canvas = tile()
    leaping_fish(canvas)
    art = Image.fromarray(canvas)
    frames = [art.resize((s, s), Image.NEAREST if s >= TILE else Image.LANCZOS) for s in SIZES]
    frames[-1].save(ROOT / "game" / "icon.png")
    frames[-1].save(ROOT / "game" / "icon.ico", sizes=[(s, s) for s in SIZES], append_images=frames[:-1])
    art.resize((TILE * 16, TILE * 16), Image.NEAREST).save(ROOT / "marketing" / "profile_picture.png")
    art.resize((TILE * 3, TILE * 3), Image.NEAREST).save(UI / "android_icon.png")
    back, front = android_layers()
    back.resize((ANDROID * 4, ANDROID * 4), Image.NEAREST).save(UI / "android_background.png")
    front.resize((ANDROID * 4, ANDROID * 4), Image.NEAREST).save(UI / "android_foreground.png")
    # Android draws a themed icon in the phone's own colour from the fish's shape alone.
    shape = np.array(front)
    shape[:, :, :3] = 255
    Image.fromarray(shape).resize((ANDROID * 4, ANDROID * 4), Image.NEAREST).save(UI / "android_monochrome.png")
    print("icon written", SIZES, "and Android's launcher icons")


if __name__ == "__main__":
    main()
