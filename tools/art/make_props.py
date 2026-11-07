"""Paints small props listed below into game/assets/art/props/, trimmed to their pixels. A prop already painted is
skipped. Usage: python tools/art/make_props.py [NAME...]"""
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "assets" / "art" / "props"
RAW = Path(__file__).with_name("props_raw")
STYLE = "cozy pixel art, soft daylight, gentle shading, no outlines, alone on an empty background"

PROPS = {
    "trap": ("a round ancient wicker fishing pot trap with a funnel mouth, woven from brown willow, seen from the side", "32x32"),
    "buoy": ("an ancient fishing float: one solid rounded lump of natural pale brown cork, no hole, unpainted, with a twine loop on top and a short rope hanging straight down below it, seen from the side", "32x32"),
    "net": ("a round cast fishing net spread wide open in the air, fine brown mesh with small lead weights around its edge, seen from the side", "64x32"),
    "trident": ("a fishing trident spear with three bronze barbed prongs and a long wooden shaft, lying horizontal, point to the right", "64x32"),
    "dolphin": ("a common dolphin leaping in an arc, grey back and pale belly, seen exactly from the side facing right", "64x32"),
    "skiff": ("a small ancient Roman wooden rowing skiff seen exactly from the side as a flat side elevation, only the outside of the hull showing, bow to the right with a gently curved prow, an oar resting along its side, nobody in it, not tilted, not from above", "112x48"),
    "fishing_boat": ("an ancient Roman wooden fishing boat seen exactly from the side as a flat side elevation, only the outside of the hull showing, bow to the right, a little cabin at the stern, nobody in it, not tilted, not from above", "128x56"),
    "sailing_boat": ("an ancient Roman sailing boat seen exactly from the side as a flat side elevation, only the outside of the hull showing, bow to the right, a single mast with a furled square sail, nobody in it, not tilted, not from above", "128x96"),
    "big_boat": ("a large ancient Roman fishing ship seen exactly from the side as a flat side elevation, only the outside of the hull showing, bow to the right, a tall mast with a furled square sail and a lamp post at the bow, nobody in it, not tilted, not from above", "160x112"),
    "jetty": ("a weathered wooden fishing jetty seen exactly from the side as a flat elevation: a plank walkway resting on a row of thick round wooden posts, the posts running straight down out of the bottom of the picture, no water, no ground, nothing behind it", "192x112"),
    "icon": ("a game icon: a shiny red mullet fish leaping in an arc over a small curling blue sea wave, a golden laurel leaf, bold simple shapes, centred", "64x64"),
    "fisherman": ("a Roman fisherman in a brown tunic and straw hat sitting down, seen exactly from the side facing right, both hands held out in front as if holding a fishing rod, no rod", "32x32"),
    "amphorae": ("two clay amphorae with pointed bases standing upright side by side, propped against each other, seen from the side", "32x32"),
    "bollard": ("a short thick wooden mooring post with a rope coiled around it, seen from the side", "32x32"),
    "stake": ("a small wooden surveyor's stake driven into the ground with a length of rope tied to it, marking out a plot, seen from the side", "32x32"),
    "lamp": ("a small ancient Roman bronze oil lamp on an iron hook with a warm flame, seen from the side", "32x32"),
}


def main(names):
    OUT.mkdir(parents=True, exist_ok=True)
    RAW.mkdir(exist_ok=True)
    for name, (prompt, size) in PROPS.items():
        if names and name not in names:
            continue
        out, raw = OUT / f"{name}.png", RAW / f"{name}.png"
        if out.exists():
            continue
        failures = 0
        while not raw.exists() and failures < 4:
            r = subprocess.run([sys.executable, str(Path(__file__).with_name("pixellab.py")), "pixen", f"{prompt}, {STYLE}",
                                size, "--out", str(raw.relative_to(ROOT)), "--transparent", "--raw", "--view", "side",
                                "--outline", "lineless", "--detail", "highly detailed"], cwd=ROOT, capture_output=True,
                               text=True, timeout=900)
            said = (r.stdout + r.stderr)[-200:]
            if "cost:" in r.stdout:
                break
            if "429" in said:
                time.sleep(25)
                continue
            failures += 1
        if raw.exists():
            im = Image.open(raw).convert("RGBA")
            im.crop(im.getbbox()).save(out)
            print("painted", name, Image.open(out).size)
        else:
            print("FAILED", name)


if __name__ == "__main__":
    main(sys.argv[1:])
