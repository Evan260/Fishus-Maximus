"""The fisherman at rest with his rod laid down: his seated frame with the raised forearm taken off and drawn again
lying along his thigh, the hand resting on his knee. Writes game/assets/art/fisherman/rest.png and its hands."""
import json
from pathlib import Path

from PIL import Image

MAN = Path(__file__).resolve().parents[2] / "game" / "assets" / "art" / "fisherman"
CLEAR = "......"
TUNIC = (0x85, 0x5A, 0x33)
TUNIC_EDGE = (0x65, 0x48, 0x31)
LIGHT = (0xE9, 0xA5, 0x62)
MID = (0xDF, 0x99, 0x59)
SHADE = (0xD5, 0x91, 0x52)
DARK = (0xC4, 0x81, 0x49)
DEEP = (0xB5, 0x76, 0x41)
# The forearm and hand from the elbow forward, as rows of letters from column 33 at row 31.
ARM = [
    "L.......",
    "LLLLLM..",
    "MLLLLLM.",
    "DSSSMLLM",
    "..DDDEEE",
]
COLOURS = {"L": LIGHT, "M": MID, "S": SHADE, "D": DARK, "E": DEEP}
ARM_AT = (33, 31)
HANDS = [39, 33]


def main() -> None:
    img = Image.open(MAN / "sit.png").convert("RGBA")
    px = img.load()
    # The raised forearm and hands come off, leaving the tunic's front edge behind them.
    for y in range(24, 33):
        for x in range(34, 44):
            r, g, b, a = px[x, y]
            if a and r > 0xA0:
                px[x, y] = (0, 0, 0, 0)
    for y in range(29, 32):
        px[34, y] = TUNIC + (255,)
    px[35, 31] = TUNIC_EDGE + (255,)
    for dy, row in enumerate(ARM):
        for dx, c in enumerate(row):
            if c in COLOURS:
                px[ARM_AT[0] + dx, ARM_AT[1] + dy] = COLOURS[c] + (255,)
    img.save(MAN / "rest.png")
    info_path = MAN / "fisherman.json"
    info = json.loads(info_path.read_text())
    info["hands"]["rest"] = [HANDS]
    info_path.write_text(json.dumps(info, indent=1), newline="\n")


if __name__ == "__main__":
    main()
