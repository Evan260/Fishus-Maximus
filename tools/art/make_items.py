"""Paints a small picture of each thing the shops sell and each kind of help for hire into game/assets/art/items/,
trimmed to its pixels with any dark rim softened, so the shops and the tackle can show pictures rather than words.
The ways of fishing get small pictures of their own for the boat's bar, the net's being the cast net's. A picture already painted is skipped.
Usage: python tools/art/make_items.py [ID...]"""
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "assets" / "art" / "items"
RAW = Path(__file__).with_name("items_raw")
STYLE = "realistic pixel art item, natural muted colours, soft daylight, gentle shading, not cartoon, no face, no eyes, no outlines, alone on an empty background, centred"

ITEMS = {
    "worm": "three thin wriggling earthworms, dull brownish pink, lying in a loose tangle",
    "shrimp": "one raw pink shrimp seen from the side, with its long feelers, legs and fanned tail",
    "bread": "a broken chunk of a round flat loaf of bread, brown crust and pale crumb, a plain food item",
    "squid": "one small raw pale squid with its tentacles",
    "sardine_strip": "a strip of raw sardine fillet, silver skin on one side",
    "live_sardine": "one small live silver sardine fish, curving as it wriggles",
    "salted_fish": "one small dried salted fish, pale and crusted with coarse white salt",
    "oyster": "one opened oyster shell with the oyster inside",
    "seaweed": "a small bunch of green sea lettuce seaweed leaves",
    "cane_rod": "an ancient fishing rod: one long straight tapering pole of plain pale cane, thick at the bottom left and thin at the top right, a short line hanging from the tip, nothing else on it, no reel, no spool, no crank, no rings",
    "ash_rod": "an ancient fishing rod: one long straight tapering pole of pale ash wood with a cord-wrapped grip, thick at the bottom left and thin at the top right, a short line hanging from the tip, nothing else on it, no reel, no spool, no crank, no rings",
    "yew_rod": "an ancient fishing rod: one long straight tapering pole of dark reddish yew wood with bronze bands, thick at the bottom left and thin at the top right, a short line hanging from the tip, nothing else on it, no reel, no spool, no crank, no rings",
    "masters_rod": "an ancient fishing rod: one long straight tapering pole of polished dark wood with gold bands, thick at the bottom left and thin at the top right, a short line hanging from the tip, nothing else on it, no reel, no spool, no crank, no rings",
    "flax_line": "a small coil of rough brown flax fishing line",
    "horsehair_line": "a small coil of dark braided horsehair fishing line",
    "twisted_line": "a small coil of tightly twisted pale flax cord",
    "fine_line": "a small wooden spool wound with fine shining silk thread",
    "bronze_hook": "a single plain bronze fishing hook",
    "barbed_hook": "a bronze fishing hook with a sharp barb",
    "iron_hook": "a strong dark iron fishing hook with a barb",
    "small_net": "a small bundled fishing net of brown cord with a few lead weights",
    "cast_net": "a round cast fishing net bundled up, brown mesh ringed with lead weights",
    "wide_net": "a big wide fishing net folded in a heap, brown mesh with many lead weights",
    "clay_lamp": "a small ancient Roman terracotta oil lamp with a little flame",
    "bronze_lamp": "an ancient Roman bronze oil lamp with a little flame, hanging from a short chain",
    "bait_box_2": "a small wooden box with a lid, for fishing bait",
    "bait_box_3": "a large wooden chest bound with bronze bands",
    "earrings": "a pair of small gold earrings with pearls",
    "gold_ring": "one gold ring",
    "pearl_collar": "a collar of white pearls on a thin gold band",
    "line": "a round natural cork fishing float with a short line below it and a small bronze hook at the end",
    "trap": "a round wicker fishing pot trap with a funnel mouth, woven from brown willow",
    "trident": "a fishing trident: a straight brown wooden shaft with three barbed golden-bronze prongs at its top, leaning diagonally, warm brown and bronze colours",
    "help_boy": "a cheerful ancient Roman errand boy in a short brown tunic carrying a basket, full figure",
    "help_feeder": "an ancient Roman young woman pond keeper in a green tunic holding a bowl of fish feed, full figure",
    "help_fisherman": "an ancient Roman fisherman in a brown tunic and straw hat with a net over his shoulder, full figure",
    "bay_map": "a parchment map half unrolled from a wooden roller, showing a blue bay with a green curving coastline drawn on it",
    "logbook": "a small closed book bound in brown leather with a bronze clasp and a ribbon bookmark",
    "settings": "a simple bronze cog wheel, a solid disc with six wide flat-topped teeth round its rim and a round hole in the centre, seen straight on",
    "menu": "a small Roman arched stone doorway with an open wooden door, warm light inside",
}

# The ways of fishing and the boat's own buttons are shown small on its bars, so they are painted at the size they are shown.
SIZES = {"line": "24x24", "trap": "24x24", "trident": "24x24", "bay_map": "24x24", "logbook": "24x24", "settings": "24x24", "menu": "24x24"}
# The gear comes out a pale bronze that fades into the pale wooden tile it sits on, so it is darkened by this share.
DARKEN = {"settings": 0.64}


def main(names):
    OUT.mkdir(parents=True, exist_ok=True)
    RAW.mkdir(exist_ok=True)
    for name, prompt in ITEMS.items():
        if names and name not in names:
            continue
        out, raw = OUT / f"{name}.png", RAW / f"{name}.png"
        if out.exists():
            continue
        failures = 0
        while not raw.exists() and failures < 4:
            r = subprocess.run([sys.executable, str(Path(__file__).with_name("pixellab.py")), "pixen", f"{prompt}, {STYLE}",
                                SIZES.get(name, "48x48" if name.endswith("_rod") else "32x32"), "--raw", "--view", "side", "--outline", "lineless", "--detail", "highly detailed",
                                "--out", str(raw.relative_to(ROOT)), "--transparent"], cwd=ROOT, capture_output=True,
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
            subprocess.run([sys.executable, str(Path(__file__).with_name("soften_outlines.py")), str(out)], cwd=ROOT)
            if name in DARKEN:
                im = Image.open(out).convert("RGBA")
                rgb = ImageEnhance.Color(ImageEnhance.Brightness(im.convert("RGB")).enhance(DARKEN[name])).enhance(1.25).convert("RGBA")
                rgb.putalpha(im.getchannel("A"))
                rgb.save(out)
            print("painted", name, Image.open(out).size)
        else:
            print("FAILED", name)


if __name__ == "__main__":
    main(sys.argv[1:])
