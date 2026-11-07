"""Paints every fish in game/data/fish.json without outlines in the sea bass's natural look, trims it to its pixels
and halves the smallest, into game/assets/art/fish/<id>.png. A fish already painted is skipped. Usage: python tools/art/make_fish.py [ID...]"""
import json
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "assets" / "art" / "fish"
RAW = Path(__file__).with_name("fish_raw")
REUSE = {"bream": "bream", "sardine": "sardine", "octopus": "octopus", "grouper": "grouper",
         "tuna": "tuna"}
SIDE = "seen exactly from the side facing right, realistic and natural, not cartoon"
FLAT = "seen from above lying flat, head to the right, realistic and natural, not cartoon"
STYLE = "cozy pixel art, soft daylight, gentle shading, no outlines"
STYLE_REF = "game/assets/art/fish/sea_bass.png"

# id: (look, canvas, halve)
LOOKS = {
    "mullet": ("a red mullet fish, soft rose-pink body with a faint yellow stripe along its side, two short chin barbels and a small eye", "48x32", False),
    "moray": ("a Mediterranean moray eel, long body in dark brown mottled with small pale yellow flecks, its mouth a little open", "64x32", False),
    "grey_mullet": ("a grey mullet fish, silver-grey body with faint dark stripes along its sides, blunt head", "48x32", False),
    "white_bream": ("a white sea bream fish, silver body with dark vertical bands and a black spot near the tail", "48x32", False),
    "salema": ("a salema fish, silver body with thin golden stripes along its length", "48x32", False),
    "anchovy": ("a tiny anchovy fish, slim silver body with a blue-green back", "32x32", True),
    "bogue": ("a small bogue fish, slim silvery body with faint golden lines and big eyes", "32x32", True),
    "sole": ("a common sole flatfish, oval sandy brown body with a frilled fin all round", "48x32", False),
    "cuttlefish": ("a cuttlefish, broad mottled brown and cream body with a frilled fin skirt and short arms", "48x32", False),
    "squid": ("a squid, long pinkish translucent body with a pointed fin end and trailing tentacles", "48x32", False),
    "crab": ("a green-brown shore crab with its claws raised, seen from the front", "32x32", False),
    "eel": ("a European eel, long slender olive-brown body with a yellowish belly", "64x32", False),
    "wrasse": ("a small ornate wrasse fish, bright green and orange zigzag stripes with blue lines", "32x32", True),
    "scorpionfish": ("a brown scorpionfish, mottled spiny body with a big head and fin spines", "48x32", False),
    "comber": ("a comber fish, reddish-brown body with pale vertical bands", "48x32", False),
    "lobster": ("a spiny lobster, reddish-brown spiny shell, long thick antennae, no big claws", "64x32", False),
    "urchin": ("a dark purple sea urchin covered in long spines", "32x32", False),
    "dentex": ("a large common dentex fish, silvery grey body with a faint pink tinge, small dark spots and a strong jaw", "64x32", False),
    "damselfish": ("a tiny dark brown damselfish with a forked tail", "32x32", True),
    "picarel": ("a tiny picarel fish, slim silvery body with a dark spot on its side", "32x32", True),
    "conger": ("a conger eel, long thick grey body with a dark-edged fin along its back", "64x32", False),
    "oyster": ("a rough grey oyster shell, closed", "32x32", False),
    "sea_bass": ("a European sea bass fish, sleek silver body with a dark grey back", "64x32", False),
    "sand_smelt": ("a tiny sand smelt fish, slim translucent body with a silver stripe", "32x32", True),
    "goby": ("a tiny goby fish, sandy brown speckled body with big eyes", "32x32", True),
    "flounder": ("a flounder flatfish, oval mottled brown body with both eyes on top", "48x32", False),
    "golden_mullet": ("a golden grey mullet fish, silver body with a golden spot on its gill cover", "48x32", False),
    "mackerel": ("a mackerel fish, slim body with blue-green wavy stripes on its back and a silver belly", "48x32", False),
    "bonito": ("an Atlantic bonito fish, sleek body with dark slanted stripes on a blue back and a silver belly", "64x32", False),
    "amberjack": ("a greater amberjack fish, large sleek silver body with a golden stripe and a dark band through the eye", "96x48", False),
    "garfish": ("a garfish, very long slim green-silver body with a long thin beak of a mouth", "64x32", False),
    "horse_mackerel": ("a horse mackerel fish, silver body with a row of bony scutes along its side and big eyes", "48x32", False),
    "dolphinfish": ("a dolphinfish, muted olive-green back fading to a pale yellow belly with small dark flecks, a steep blunt forehead and a long back fin", "64x32", False),
    "john_dory": ("a John Dory fish, tall flat body in muted olive-grey and dull gold with one dark spot on its side and long spiny back fins", "48x48", False),
    "weever": ("a greater weever fish, slim pale sandy body with faint thin grey slanted lines and a small black spiny back fin", "48x32", False),
    "thornback": ("a thornback ray, wide diamond-shaped mottled brown body with a long thorny tail", "64x48", False),
    "parrotfish": ("a Mediterranean parrotfish, muted grey-red body with large scales, a small eye and a beak-like mouth", "48x32", False),
    "cardinalfish": ("a tiny cardinalfish, dull orange-brown body with a small dark spot near the tail", "32x32", True),
    "brown_meagre": ("a brown meagre fish, deep bronze-brown body with pale-edged fins", "48x32", False),
    "forkbeard": ("a forkbeard fish, long brown body with a long thin chin barbel and forked fin feelers", "48x32", False),
    "slipper_lobster": ("a slipper lobster, flat broad shell in brown and orange with flat plate-like antennae", "48x32", False),
    "red_scorpionfish": ("a red scorpionfish lying still, mottled dull red-brown and cream body with spiny fins and small skin flaps, camouflaged like a rock, a small eye", "48x32", False),
    "swordfish": ("a swordfish, long dark blue-grey body with a silver belly, a tall sickle back fin and a long flat sword", "96x48", False),
    "hake": ("a hake fish, long slim silver-grey body with a dark back and a big mouth", "64x32", False),
    "red_porgy": ("a red porgy fish, soft pinkish silver body with faint small spots and a small eye", "48x32", False),
    "carteia_octopus": ("a gigantic old octopus with deep red mottled skin, huge arms curling, scarred and ancient", "96x48", False),
    "tiberius_mullet": ("a large old red mullet fish, deep rose-red body with a faint gold stripe and two short chin barbels, a small eye", "64x32", False),
    "hortensius_moray": ("a huge old Mediterranean moray eel, dark brown body mottled with dull gold flecks, wearing small gold earrings on its gills", "96x48", False),
    "great_tuna": ("an enormous bluefin tuna fish, gleaming dark blue back with a silver belly and golden finlets", "96x48", False),
    "orata_bream": ("a large gilt-head sea bream fish, silver body that shines gold all over with a bright gold band between the eyes", "64x32", False),
    "claudius_parrotfish": ("a large old Mediterranean parrotfish, deep muted red-brown body with grey edges to its scales and a beak-like mouth", "64x32", False),
    "misenum_swordfish": ("an enormous swordfish, deep midnight blue with a shining silver belly and a very long sword", "96x48", False),
    "senator_grouper": ("an enormous old dusky grouper fish, dark brown with pale blotches, a vast mouth and a stern look", "96x48", False),
    "wreck_conger": ("a gigantic conger eel, dark grey-black, thick as a mast, with pale eyes", "96x48", False),
    "numbing_ray": ("an electric torpedo ray, round smooth body in muted sandy brown with five small dark spots ringed in dull blue, seen from above", "64x48", False),
    "sleeping_sunfish": ("an enormous ocean sunfish, tall rounded grey body with rough mottled skin, a small eye and small mouth, a tall fin above and below and a short frilled rear edge instead of a tail", "96x48", False),
    "neptune_lobster": ("a huge spiny lobster, deep blue and gold shell with very long antennae", "96x48", False),
}
FLATFISH = {"sole", "flounder", "thornback", "numbing_ray"}


def trim(im: Image.Image) -> Image.Image:
    box = im.getbbox()
    return im.crop(box) if box else im


def main(ids):
    OUT.mkdir(parents=True, exist_ok=True)
    RAW.mkdir(exist_ok=True)
    fish = json.loads((ROOT / "game" / "data" / "fish.json").read_text(encoding="utf-8"))
    for f in fish:
        fid = f["id"]
        if ids and fid not in ids:
            continue
        out = OUT / f"{fid}.png"
        if out.exists():
            continue
        if fid in REUSE:
            Image.open(ROOT / "game" / "assets" / "art" / "coast" / f"{REUSE[fid]}.png").save(out)
            print("reused", fid)
            continue
        look, canvas, halve = LOOKS[fid]
        raw = RAW / f"{fid}.png"
        if not raw.exists():
            view = FLAT if fid in FLATFISH else SIDE
            failures = 0
            while failures < 4 and not raw.exists():
                # A natural fish already in the game sets the look, since a text prompt alone drifts towards cartoon.
                r = subprocess.run([sys.executable, str(Path(__file__).with_name("pixellab.py")), "proflash",
                                    f"{look}, {view}, alone on an empty background, {STYLE}", canvas,
                                    "--out", str(raw.relative_to(ROOT)), "--transparent", "--style", STYLE_REF,
                                    "--style-use", "match this fish's natural colours, soft shading and pixel style, with no dark outline"],
                                   cwd=ROOT, capture_output=True, text=True, timeout=600)
                if "cost:" in r.stdout:
                    break
                said = (r.stdout + r.stderr).strip()[-200:]
                if "429" in said:
                    time.sleep(25)
                    continue
                failures += 1
                print("  retry", fid, said)
            if not raw.exists():
                print("FAILED", fid)
                continue
        im = trim(Image.open(raw).convert("RGBA"))
        if halve:
            im = im.resize((max(4, im.width // 2), max(3, im.height // 2)), Image.NEAREST)
        im.save(out)
        print("painted", fid, im.size)


if __name__ == "__main__":
    main(sys.argv[1:])
