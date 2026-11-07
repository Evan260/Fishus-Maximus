"""Paints the six clients' portraits for their visits, from game/data/clients.json, and old Rufus's for the guide,
from game/data/townsfolk.json, into game/assets/art/portraits/. The townsfolk and the clients standing in the street
are painted by make_people.py. Usage: python tools/art/make_portraits.py"""
import json
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RAW = Path(__file__).with_name("people_raw")
STYLE = "cozy pixel art, soft warm daylight, gentle shading, no outlines"


# The townsman who guides a new player.
GUIDE = "rufus"


def paint(out: Path, prompt: str, size: str) -> bool:
    failures = 0
    while not out.exists() and failures < 4:
        r = subprocess.run([sys.executable, str(Path(__file__).with_name("pixellab.py")), "pixen", f"{prompt}, {STYLE}", size,
                            "--out", str(out.relative_to(ROOT)), "--transparent", "--raw", "--view", "side",
                            "--outline", "lineless", "--detail", "highly detailed"], cwd=ROOT, capture_output=True, text=True,
                           timeout=900)
        said = (r.stdout + r.stderr)[-200:]
        if "cost:" in r.stdout:
            break
        if "429" in said:
            time.sleep(25)
            continue
        failures += 1
    return out.exists()


def main():
    RAW.mkdir(exist_ok=True)
    data = ROOT / "game" / "data"
    people = json.loads((data / "clients.json").read_text(encoding="utf-8"))
    people += [p for p in json.loads((data / "townsfolk.json").read_text(encoding="utf-8")) if p["id"] == GUIDE]
    for c in people:
        out = ROOT / "game" / "assets" / "art" / "portraits" / f"{c['id']}.png"
        if out.exists():
            continue
        out.parent.mkdir(parents=True, exist_ok=True)
        raw = RAW / f"portrait_{c['id']}.png"
        if paint(raw, f"head and shoulders portrait of {c['look']}, facing slightly left, plain empty background", "64x64"):
            Image.open(raw).save(out)
            print("painted portrait", c["id"])


if __name__ == "__main__":
    main()
