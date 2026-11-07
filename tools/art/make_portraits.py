"""Paints the six clients' portraits for their visits, from game/data/clients.json, and old Rufus's for the guide,
from game/data/townsfolk.json, into game/assets/art/portraits/. Each is painted to match the person's own figure in the
street (people/<id>/south.png, painted by make_people.py), so the face in a visit is the one standing outside, then its
dark rim is softened. Usage: python tools/art/make_portraits.py [ID...]"""
import json
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image

import soften_outlines

ROOT = Path(__file__).resolve().parents[2]
RAW = Path(__file__).with_name("people_raw")
PEOPLE = ROOT / "game" / "assets" / "art" / "people"
LIKENESS = ("the same person as in this picture, with the same face, hair, beard, clothes and colours, in the same soft "
            "pixel art style and light, with no dark outline")


# The townsman who guides a new player.
GUIDE = "rufus"


def paint(out: Path, prompt: str, size: str, style: Path) -> bool:
    failures = 0
    while not out.exists() and failures < 4:
        r = subprocess.run([sys.executable, str(Path(__file__).with_name("pixellab.py")), "proflash", prompt, size,
                            "--out", str(out.relative_to(ROOT)), "--transparent", "--style", str(style.relative_to(ROOT)),
                            "--style-use", LIKENESS], cwd=ROOT, capture_output=True, text=True, timeout=900)
        said = (r.stdout + r.stderr)[-200:]
        if "cost:" in r.stdout:
            break
        if "429" in said:
            time.sleep(25)
            continue
        failures += 1
    return out.exists()


def main(ids):
    RAW.mkdir(exist_ok=True)
    data = ROOT / "game" / "data"
    people = json.loads((data / "clients.json").read_text(encoding="utf-8"))
    people += [p for p in json.loads((data / "townsfolk.json").read_text(encoding="utf-8")) if p["id"] == GUIDE]
    for c in people:
        out = ROOT / "game" / "assets" / "art" / "portraits" / f"{c['id']}.png"
        if out.exists() or (ids and c["id"] not in ids):
            continue
        out.parent.mkdir(parents=True, exist_ok=True)
        raw = RAW / f"portrait_{c['id']}.png"
        prompt = (f"head and shoulders portrait of {c['look']}, facing slightly left, soft gentle shading, no outlines, "
                  "plain empty transparent background")
        if paint(raw, prompt, "64x64", PEOPLE / c["id"] / "south.png"):
            Image.open(raw).save(out)
            soften_outlines.soften(out)
            print("painted portrait", c["id"])


if __name__ == "__main__":
    main(sys.argv[1:])
