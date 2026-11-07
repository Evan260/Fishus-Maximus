"""Paints the shore where the ponds and the garum works are: the view above the terrace and the terrace wall the
ponds are cut into. Writes game/assets/art/shore/back.png and wall.png. Usage: python tools/art/make_shore.py"""
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "assets" / "art" / "shore"
WORK = Path(__file__).with_name("shore_parts")
STYLE = "cozy pixel art, soft warm golden afternoon light, gentle shading, no outlines"
PICTURES = {
    "back": ("a sunny rocky shore on the Bay of Naples seen exactly from the side: on the left the calm sea and a far "
             "green coast under a blue sky with soft clouds, umbrella pines on the rocks, on the right the stone building "
             "of a Roman garum works with an open colonnaded front, rows of stone tanks and clay amphorae stacked outside, "
             "the bottom of the picture is a flat stone terrace edge", "480x136"),
    "wall": ("a long straight terrace wall of big cut pale limestone blocks seen straight on, mossy joints, a little "
             "seaweed at the bottom, flat even wall filling the whole picture, no openings, no doors", "480x136"),
}


def run(args):
    failures = 0
    while failures < 4:
        r = subprocess.run([sys.executable, str(Path(__file__).with_name("pixellab.py"))] + args, cwd=ROOT,
                           capture_output=True, text=True, timeout=900)
        if "cost:" in r.stdout:
            return True
        said = (r.stdout + r.stderr)[-300:]
        if "429" in said:
            time.sleep(25)
            continue
        failures += 1
        print("  retry:", said.strip())
        time.sleep(10)
    return False


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(exist_ok=True)
    for name, (prompt, size) in PICTURES.items():
        raw = WORK / f"{name}.png"
        if not raw.exists():
            run(["pixen", f"{prompt}, {STYLE}", size, "--out", str(raw.relative_to(ROOT)), "--raw", "--view", "side",
                 "--outline", "lineless", "--detail", "highly detailed"])
        if raw.exists():
            Image.open(raw).convert("RGBA").save(OUT / f"{name}.png")
            print("painted", name)
        else:
            print("FAILED", name)


if __name__ == "__main__":
    main()
