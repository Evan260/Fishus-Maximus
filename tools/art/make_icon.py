"""Builds the game's icon from a painted scene in the title's sunset style, as Farmus Maximus has its villa: the boat
with the fisherman and his dog on the bay, the lighthouse and a quiet Vesuvius behind. Writes game/icon.png and
game/icon.ico with every size Windows asks for. Usage: python tools/art/make_icon.py"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PAINTED = Path(__file__).with_name("icon_parts") / "icon_2.png"
SIZES = [16, 24, 32, 48, 64, 128, 256]


def main():
    art = Image.open(PAINTED).convert("RGBA")
    big = art.resize((256, 256), Image.NEAREST)
    big.save(ROOT / "game" / "icon.png")
    # The large sizes keep the pixels crisp; the small ones are averaged down so the boat still reads.
    frames = [art.resize((s, s), Image.NEAREST if s >= art.width else Image.LANCZOS) for s in SIZES]
    frames[-1].save(ROOT / "game" / "icon.ico", sizes=[(s, s) for s in SIZES], append_images=frames[:-1])
    print("icon written", SIZES)


if __name__ == "__main__":
    main()
