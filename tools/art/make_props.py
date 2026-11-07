"""Paints small props listed below into game/assets/art/props/, trimmed to their pixels; the rowing boats are painted
to match the first skiff's look, since its oar kept coming back from text alone. A prop already painted is skipped. Usage: python tools/art/make_props.py [NAME...]"""
import subprocess
import sys
import time
from pathlib import Path

import numpy as np
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
    "skiff": ("an empty small ancient Roman wooden rowing boat, a flat side elevation seen exactly from the side, bow to the right with a gently curved prow, plain wooden planks along the hull, a smooth solid keel, the boat is empty: nothing lies on it or across it, no oar, no paddle, no rope, no person, no water", "128x48", "tools/art/props_raw/style_skiff.png"),
    "fishing_boat": ("an empty ancient Roman wooden fishing boat with a small wooden cabin at the stern, a flat side elevation seen exactly from the side, bow to the right, plain wooden planks along the hull, a smooth solid keel, the boat is empty: nothing lies on it or across it, no oar, no paddle, no person, no water", "128x56", "tools/art/props_raw/style_skiff.png"),
    "sailing_boat": ("an ancient Roman sailing boat seen exactly from the side as a flat side elevation, only the outside of the hull showing, bow to the right, a single mast with a furled square sail, nobody in it, not tilted, not from above", "128x96"),
    "big_boat": ("a large ancient Roman fishing ship seen exactly from the side as a flat side elevation, only the outside of the hull showing, bow to the right, a tall mast with a furled square sail and a lamp post at the bow, nobody in it, not tilted, not from above", "160x112"),
    "jetty": ("a weathered wooden fishing jetty seen exactly from the side as a flat elevation: a plank walkway resting on a row of thick round wooden posts, the posts running straight down out of the bottom of the picture, no water, no ground, nothing behind it", "192x112"),
    "icon": ("a game icon: a shiny red mullet fish leaping in an arc over a small curling blue sea wave, a golden laurel leaf, bold simple shapes, centred", "64x64"),
    "amphorae": ("two clay amphorae with pointed bases standing upright side by side, propped against each other, seen from the side", "32x32"),
    "bollard": ("a short thick wooden mooring post with a rope coiled around it, seen from the side", "32x32"),
    "stake": ("a small wooden surveyor's stake driven into the ground with a length of rope tied to it, marking out a plot, seen from the side", "32x32"),
    "lamp": ("a small ancient Roman bronze oil lamp on an iron hook with a warm flame, seen from the side", "32x32"),
}


BOATS = {"skiff", "fishing_boat", "sailing_boat", "big_boat"}


def solid_hull(path: Path) -> None:
    """Fills the one-pixel gaps along a hull and drops the loose specks under its keel, so the water never shows
    through the boat."""
    im = np.array(Image.open(path).convert("RGBA"))
    solid = im[:, :, 3] > 127
    h, w = solid.shape
    for _ in range(2):
        for y in range(1, h - 1):
            for x in range(1, w - 1):
                if solid[y, x]:
                    continue
                across = solid[y, x - 1] and solid[y, x + 1]
                down = solid[y - 1, x] and solid[y + 1, x]
                if across or down:
                    im[y, x] = im[y - 1, x] if solid[y - 1, x] else im[y, x - 1]
                    solid[y, x] = True
    # Below the hull's last full rows, a run shorter than a few pixels is a speck, not keel.
    for y in range(h - 3, h):
        x = 0
        while x < w:
            if not solid[y, x]:
                x += 1
                continue
            end = x
            while end < w and solid[y, end]:
                end += 1
            if end - x < 4 and not solid[y - 1, x:end].all():
                im[y, x:end, 3] = 0
                solid[y, x:end] = False
            x = end
    Image.fromarray(im).save(path)


def main(names):
    OUT.mkdir(parents=True, exist_ok=True)
    RAW.mkdir(exist_ok=True)
    for name, spec in PROPS.items():
        prompt, size = spec[0], spec[1]
        if names and name not in names:
            continue
        out, raw = OUT / f"{name}.png", RAW / f"{name}.png"
        if out.exists():
            continue
        failures = 0
        while not raw.exists() and failures < 4:
            # A prop with a style picture is painted to match it, which keeps it free of what the text alone brings back.
            if len(spec) > 2:
                args = ["proflash", f"{prompt}, pixel art, no outline", size, "--style", spec[2], "--style-use",
                        "match this boat's wood colours, shading and pixel style, but leave out the oar"]
            else:
                args = ["pixen", f"{prompt}, {STYLE}", size, "--raw", "--view", "side", "--outline", "lineless",
                        "--detail", "highly detailed"]
            r = subprocess.run([sys.executable, str(Path(__file__).with_name("pixellab.py"))] + args +
                               ["--out", str(raw.relative_to(ROOT)), "--transparent"], cwd=ROOT, capture_output=True,
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
            if name in BOATS:
                solid_hull(out)
            print("painted", name, Image.open(out).size)
        else:
            print("FAILED", name)


if __name__ == "__main__":
    main(sys.argv[1:])
