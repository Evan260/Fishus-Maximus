"""Draw the controller button pictures shown beside key hints while a gamepad is in use, pixel by pixel in the game's
interface colours, without PixelLab: the face buttons A, B, X and Y as round buttons in muted versions of the usual
green, red, blue and yellow, the shoulder buttons LB and RB, the D-pad with the pressed arm lit, and the two sticks.

Usage: python tools/art/make_pad_glyphs.py
Writes game/assets/art/ui/pad/<name>.png, each 10 pixels tall, the height of a line of the interface's text.
"""
from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "game" / "assets" / "art" / "ui" / "pad"
INK = (58, 38, 30, 255)
CREAM = (242, 230, 204, 255)
SHADE = (196, 176, 140, 255)
FACE = {"a": (92, 140, 70), "b": (168, 64, 52), "x": (60, 104, 150), "y": (206, 160, 56)}
GREY = (120, 104, 92)
# Each letter 3 pixels wide and 5 tall, '#' for ink.
LETTERS = {
    "A": [".#.", "#.#", "###", "#.#", "#.#"],
    "B": ["##.", "#.#", "##.", "#.#", "##."],
    "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
    "Y": ["#.#", "#.#", ".#.", ".#.", ".#."],
    "L": ["#..", "#..", "#..", "#..", "###"],
    "R": ["##.", "#.#", "##.", "#.#", "#.#"],
}


def darker(c, k=0.7):
    return tuple(int(v * k) for v in c[:3]) + (255,)


def disc(img, colour):
    """A round 10 by 10 button: ink rim, the colour inside, a lighter top and a darker bottom."""
    rows = ["...####...", ".##....##.", ".#......#.", "#........#", "#........#", "#........#", "#........#",
            ".#......#.", ".##....##.", "...####..."]
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "#":
                img.putpixel((x, y), INK)
            elif "#" in row[:x] and "#" in row[x:]:
                c = colour + (255,)
                if y <= 2:
                    c = tuple(min(255, int(v * 1.18)) for v in colour) + (255,)
                elif y >= 7:
                    c = darker(colour, 0.82)
                img.putpixel((x, y), c)


def letter(img, ch, x0, y0, colour=CREAM):
    for y, row in enumerate(LETTERS[ch]):
        for x, c in enumerate(row):
            if c == "#":
                img.putpixel((x0 + x, y0 + y), colour)


def face(name):
    img = Image.new("RGBA", (10, 10), (0, 0, 0, 0))
    disc(img, FACE[name])
    letter(img, name.upper(), 3, 3)
    return img


def shoulder(side):
    """A rounded tab 15 by 10 with LB or RB on it."""
    img = Image.new("RGBA", (15, 10), (0, 0, 0, 0))
    for y in range(1, 9):
        for x in range(0, 15):
            edge = y in (1, 8) or x in (0, 14)
            corner = (x in (0, 14)) and y in (1, 8)
            if corner:
                continue
            img.putpixel((x, y), INK if edge else (CREAM if y < 4 else SHADE))
    letter(img, "L" if side == "l" else "R", 3, 2, INK)
    letter(img, "B", 8, 2, INK)
    return img


def dpad(lit):
    """A 10 by 10 cross with the pressed arm lit gold."""
    img = Image.new("RGBA", (10, 10), (0, 0, 0, 0))
    shape = ["...####...", "...#..#...", "...#..#...", "####..####", "#........#", "#........#", "####..####",
             "...#..#...", "...#..#...", "...####..."]
    arms = {"up": (4, 1, 6, 4), "down": (4, 6, 6, 9), "left": (1, 4, 4, 6), "right": (6, 4, 9, 6)}
    for y, row in enumerate(shape):
        for x, ch in enumerate(row):
            if ch == "#":
                img.putpixel((x, y), INK)
        for x in range(10):
            if shape[y][x] != "#" and "#" in shape[y][:x] and "#" in shape[y][x:]:
                x0, y0, x1, y1 = arms[lit]
                c = (236, 196, 96, 255) if x0 <= x < x1 and y0 <= y < y1 else GREY + (255,)
                img.putpixel((x, y), c)
    return img


def stick(side):
    img = Image.new("RGBA", (10, 10), (0, 0, 0, 0))
    disc(img, GREY)
    letter(img, "L" if side == "l" else "R", 3, 3)
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    pictures = {name: face(name) for name in FACE}
    pictures["lb"] = shoulder("l")
    pictures["rb"] = shoulder("r")
    for d in ["up", "down", "left", "right"]:
        pictures["dpad_" + d] = dpad(d)
    pictures["lstick"] = stick("l")
    pictures["rstick"] = stick("r")
    for name, img in pictures.items():
        img.save(OUT / f"{name}.png")
    print(f"wrote {len(pictures)} pictures to {OUT}")


if __name__ == "__main__":
    main()
