"""Paints the harbour town: an empty street, and each building as its own cut-out standing on the street's paving,
so a building shows its own outline and can be clicked by it. Writes game/assets/art/town/street.png and
<id>.png for each building, with town.json giving where each one stands. Usage: python tools/art/make_town.py"""
import json
import subprocess
import sys
import time
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "assets" / "art" / "town"
WORK = Path(__file__).with_name("town_parts")
STYLE = "cozy pixel art, soft warm golden afternoon light, gentle shading, no outlines"
ALONE = ("a flat straight-on facade like a theatre backdrop, front elevation at eye level, side view, not isometric, no floor, no base, no platform, "
         "the whole building on its own, nothing behind it, empty transparent background, no sky")
STREET = ("a sunny empty street in an ancient Roman harbour town of the first century seen exactly from the side: "
          "grey stone paving along the bottom, behind it a long plain cream plastered wall with nothing on it, "
          "blue sky with soft white clouds above the wall, the masts of ships showing over the wall on the far left")
PAVING_Y = 236
# id: (left edge, size, what is painted)
BUILDINGS = {
    "market": (6, "160x176", "the front of the fish market of a Roman town: a round domed fish hall with columns, a marble water basin in front, fish laid out on stone counters, a striped awning"),
    "netmaker": (164, "96x128", "the front of a small Roman netmaker's shop, an open front with fishing nets hung to dry, rods leaning by the door, baskets of bait"),
    "boatwright": (256, "112x112", "a Roman boatwright's yard: a wooden boat being built on trestles, planks, ropes and a small timber shed with a tiled roof"),
    "board": (364, "48x96", "a Roman wooden notice board on two posts with pinned wax tablets and scraps of papyrus and a little tiled roof on top"),
    "goldsmith": (408, "72x128", "the front of a narrow Roman goldsmith's shop, a small counter of gold earrings and rings under a red awning"),
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


def boxed(path: Path) -> bool:
    a = np.array(Image.open(path).convert("RGBA"))[:, :, 3] > 16
    rows, cols = np.where(a.any(axis=1))[0], np.where(a.any(axis=0))[0]
    if not rows.size:
        return True
    a = a[rows[0]:rows[-1] + 1, cols[0]:cols[-1] + 1]
    return a[0].mean() > 0.7 or a[:, 0].mean() > 0.85 or a[:, -1].mean() > 0.85


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(exist_ok=True)
    street = WORK / "street.png"
    if not street.exists():
        if not run(["pixen", f"{STREET}, {STYLE}", "480x272", "--out", str(street.relative_to(ROOT)), "--raw", "--view", "side",
                    "--outline", "lineless", "--detail", "highly detailed"]):
            sys.exit("could not paint the street")
    Image.open(street).convert("RGBA").crop((0, 0, 480, 270)).save(OUT / "street.png")
    placed = {}
    for bid, (left, size, prompt) in BUILDINGS.items():
        raw = WORK / f"{bid}.png"
        for attempt in range(3):
            if raw.exists() and not boxed(raw):
                break
            raw.unlink(missing_ok=True)
            run(["pixen", f"{prompt}, {ALONE}, {STYLE}", size, "--out", str(raw.relative_to(ROOT)), "--transparent", "--raw",
                 "--view", "side", "--outline", "lineless", "--detail", "highly detailed"])
        if not raw.exists():
            print("FAILED", bid)
            continue
        im = Image.open(raw).convert("RGBA")
        im = im.crop(im.getbbox())
        im.save(OUT / f"{bid}.png")
        placed[bid] = [left, PAVING_Y - im.height]
        print("painted", bid, im.size)
    (OUT / "town.json").write_text(json.dumps(placed, indent=1))


if __name__ == "__main__":
    main()
