"""Draws a larger, more detailed copy of every fish for the catch banner, into game/assets/art/fish_banner/<id>.png.

The logbook and the sea keep the small pictures in game/assets/art/fish/, so the player learns one look for each fish;
the banner shows the same fish bigger. Each small picture is blown up with whole pixels to the size the banner gives it.
A tiny fish is redrawn there by PixelLab's edit, twice over, with finer scales, fins and eyes; edits keep a larger fish's
doubled pixels, so a larger one is painted afresh by Pro Flash styled on the blown up picture. Every try is kept in
tools/art/fish_banner_raw/<id>_<n>.png, so a fish is only painted again when asked; PICK names the try used, RECOLOUR
the tries whose colours are moved back to the small picture's, and KEEP the fish still enlarged from the small picture
with a dither, where no painting came out better.
Usage:
  python tools/art/make_banner_fish.py paint [ID...]   paint a first try for each fish that has none
  python tools/art/make_banner_fish.py again ID...     paint one more try for each fish from the start
  python tools/art/make_banner_fish.py more ID...      edit each fish's latest try once more as a new try
  python tools/art/make_banner_fish.py flash ID...     paint one more try afresh with Pro Flash, which costs
  python tools/art/make_banner_fish.py mend ID...      inpaint the latest try's flat blocks of doubled pixels as a new try
  python tools/art/make_banner_fish.py build [ID...]   write the banner pictures from the chosen tries"""
import json
import subprocess
import sys
import time
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from make_fish import FLATFISH, LOOKS  # noqa: E402
from soften_outlines import soften  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SMALL = ROOT / "game" / "assets" / "art" / "fish"
OUT = ROOT / "game" / "assets" / "art" / "fish_banner"
RAW = Path(__file__).with_name("fish_banner_raw")
# The room on the banner's cloth (CatchCard.INSIDE, 154 by 113) left for the fish under a name on one line or on two,
# with the weight, the note and the gaps between them; these match CatchCard in catch_card.gd.
WIDE = 152
TALL = {1: 75, 2: 61}
# The fish whose names CatchCard._title breaks onto two lines.
TWO_LINES = {"bream", "white_bream", "octopus", "golden_mullet", "bonito", "horse_mackerel", "weever", "slipper_lobster",
             "red_scorpionfish", "carteia_octopus", "tiberius_mullet", "hortensius_moray", "orata_bream",
             "claudius_parrotfish", "misenum_swordfish", "wreck_conger", "numbing_ray", "sleeping_sunfish",
             "neptune_lobster"}
# How much larger a fish is drawn, and a tiny one no longer than this many texels.
SCALE = 2.0
TINY, TINY_SCALE = 16, 4.0
BAYER = np.array([[0, 2], [3, 1]]) / 4.0 - 0.375
MARGIN = 4
# Only the kind of animal is named for an edit, since PixelLab follows colours in words over those in the picture.
OWN_LOOKS = {"bream": "a gilt-head sea bream fish", "sardine": "a small sardine fish", "octopus": "a common octopus",
             "grouper": "a dusky grouper fish", "tuna": "a bluefin tuna fish",
             "crab": "a shore crab with its claws raised, seen from the front", "urchin": "a sea urchin covered in spines",
             "damselfish": "a tiny damselfish", "scorpionfish": "a scorpionfish", "carteia_octopus": "a gigantic old octopus",
             "oyster": "a rough oyster shell"}
# Pro Flash is told the colours too, since it paints afresh rather than over the picture.
FLASH_LOOKS = {"bream": "a gilt-head sea bream fish, silver body with a gold stripe, a gold band between the eyes and dark fins",
               "sardine": "a small sardine fish, silver body with a blue-grey back",
               "octopus": "a common octopus with mottled reddish-brown skin and curling arms",
               "grouper": "a dusky grouper fish, dark brown with pale blotches and a big mouth",
               "tuna": "a bluefin tuna fish, dark blue back, warm pale silver belly, small orange finlets",
               "slipper_lobster": "a slipper lobster with a mottled grey-blue and orange shell and banded orange legs",
               "crab": "a golden-brown shore crab with its claws raised, seen from the front"}
# The shape of a small picture Pro Flash first painted otherwise.
SHAPES = {"grey_mullet": "a deep rounded body and a dark patch behind the gill",
          "golden_mullet": "a deep rounded body", "salema": "a deep oval body", "eel": "its body lying straight",
          "thornback": "its body turned diagonally, the long thorny tail pointing up to the top left and its head at the bottom right",
          "forkbeard": "a deep rounded body and one long thin barbel from its chin",
          "carteia_octopus": "its arms curling out to both sides and down, the whole animal inside the picture",
          "wreck_conger": "the whole eel, head and tail, inside the picture with empty space round it",
          "sleeping_sunfish": "one tall fin straight up from its back and one tall fin straight down from its belly",
          "neptune_lobster": "two big claws held forward, its body low and long, antennae swept up and back",
          "lobster": "two big claws held forward, its body low and long, antennae swept up and back"}
# The animals pictured from the front or above rather than from the side.
FACING_US = {"crab", "urchin", "oyster", "octopus", "carteia_octopus"}
# How much larger than the fish the canvas Pro Flash paints on is.
ROOM = 1.2
SHELLED = {"crab", "lobster", "slipper_lobster", "neptune_lobster", "urchin", "oyster"}
SOFT = {"octopus", "carteia_octopus", "cuttlefish", "squid"}
# The try used for each fish where it is not the first.
PICK = {"mullet": 2, "grey_mullet": 3, "bream": 3, "white_bream": 3, "salema": 3, "bogue": 3, "sole": 2, "cuttlefish": 3,
        "squid": 2, "crab": 3, "eel": 2, "moray": 2, "scorpionfish": 3, "comber": 2, "lobster": 3, "urchin": 2,
        "dentex": 2, "conger": 2, "oyster": 2, "sea_bass": 3, "sand_smelt": 2, "flounder": 2, "golden_mullet": 2,
        "tuna": 2, "john_dory": 2, "parrotfish": 2, "forkbeard": 2, "slipper_lobster": 2, "red_scorpionfish": 2,
        "carteia_octopus": 3, "orata_bream": 2, "claudius_parrotfish": 2, "goby": 5}
# The fish kept as the dithered enlargement, where every painting was cut off by its canvas, too small or short of a fin.
KEEP = {"amberjack", "thornback", "great_tuna", "misenum_swordfish", "wreck_conger", "numbing_ray", "sleeping_sunfish",
        "neptune_lobster"}
# The fish whose painting drifted from the small picture's colours, so the small picture's colours are laid back on.
RECOLOUR = {"oyster", "sand_smelt", "weever", "cardinalfish"}


def scale_for(fid: str, im: Image.Image) -> float:
    s = TINY_SCALE if max(im.size) <= TINY else SCALE
    return min(s, WIDE / im.width, TALL[2 if fid in TWO_LINES else 1] / im.height)


def target_size(fid: str, im: Image.Image) -> tuple[int, int]:
    s = scale_for(fid, im)
    return round(im.width * s), round(im.height * s)


def look_of(fid: str) -> str:
    return OWN_LOOKS.get(fid) or LOOKS[fid][0].split(",")[0]


def prompt_for(fid: str) -> str:
    if fid in SHELLED:
        detail = "fine detail on its shell, joints, spines and legs"
    elif fid in SOFT:
        detail = "fine detail on its skin, spots, suckers and arms"
    else:
        detail = "tiny scales, thin fin rays, a gill cover line and a small eye"
    return (f"redraw the whole picture as crisp detailed pixel art at one pixel size, no blocky doubled pixels: the same "
            f"{look_of(fid)}, with exactly the colours, markings, shape and facing in the picture; add {detail}; "
            f"soft lineless pixel art with no dark outline, transparent background")


def reference(fid: str) -> Path:
    """The small picture blown up with whole pixels to the banner's size, on a clear canvas a multiple of 4 a side."""
    im = Image.open(SMALL / f"{fid}.png").convert("RGBA")
    w, h = target_size(fid, im)
    big = im.resize((w, h), Image.NEAREST)
    cw, ch = (w + 2 * MARGIN + 3) // 4 * 4, (h + 2 * MARGIN + 3) // 4 * 4
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    canvas.paste(big, ((cw - w) // 2, (ch - h) // 2))
    path = RAW / f"{fid}_ref.png"
    canvas.save(path)
    return path


def tries(fid: str) -> list[Path]:
    return sorted((p for p in RAW.glob(f"{fid}_[0-9]*.png") if p.stem.rsplit("_", 1)[1].isdigit()),
                  key=lambda p: int(p.stem.rsplit("_", 1)[1]))


def edit(source: Path, fid: str, out: Path) -> bool:
    for _ in range(4):
        r = subprocess.run([sys.executable, str(Path(__file__).with_name("pixellab.py")), "edit",
                            str(source.relative_to(ROOT)), prompt_for(fid), "--out", str(out.relative_to(ROOT))],
                           cwd=ROOT, capture_output=True, text=True, timeout=600)
        if out.exists():
            return True
        said = (r.stdout + r.stderr).strip()[-200:]
        print("  retry", fid, said)
        time.sleep(25 if "429" in said else 3)
    print("FAILED", fid)
    return False


def more(fid: str) -> None:
    """One more try: the latest try edited again, for one that came out partly blocky."""
    done = tries(fid)
    if not done:
        return paint(fid)
    if edit(done[-1], fid, RAW / f"{fid}_{len(done) + 1}.png"):
        print("painted", fid, len(done) + 1)


def flash(fid: str) -> None:
    """One try painted afresh by Pro Flash, styled on the blown up picture, on a canvas a little larger than the fish."""
    ref = reference(fid)
    w, h = Image.open(ref).size
    # The canvas is never larger than the room on the cloth, so whatever is painted on it fits there.
    tall = TALL[2 if fid in TWO_LINES else 1]
    cw, ch = min(WIDE // 4 * 4, round(w * ROOM / 4) * 4), min(tall // 4 * 4, round(h * ROOM / 4) * 4)
    out = RAW / f"{fid}_{len(tries(fid)) + 1}.png"
    view = "" if fid in FACING_US else ", seen from above lying flat, head to the right" if fid in FLATFISH         else ", seen exactly from the side facing right"
    r = subprocess.run([sys.executable, str(Path(__file__).with_name("pixellab.py")), "proflash",
                        f"{FLASH_LOOKS.get(fid) or LOOKS[fid][0]}{view}{', with ' + SHAPES[fid] if fid in SHAPES else ''}, nearly filling the picture but whole, with a little empty space on every side, detailed pixel art, "
                        f"no outline, alone on an empty background", f"{cw}x{ch}", "--transparent",
                        "--style", str(ref.relative_to(ROOT)),
                        "--style-use", "this exact animal: copy its shape, colours, markings and facing, drawn larger "
                                       "with finer detail", "--out", str(out.relative_to(ROOT))],
                       cwd=ROOT, capture_output=True, text=True, timeout=600)
    print("painted", fid, out.stem if out.exists() else "FAILED " + (r.stdout + r.stderr)[-200:])


def flat_blocks(im: Image.Image) -> np.ndarray:
    """Every pixel in a solid square of three by three of one colour, with a pixel round it: the doubled pixels left."""
    a = np.array(im.convert("RGBA")).astype(int)
    h, w = a.shape[:2]
    out = np.zeros((h, w), np.uint8)
    for y in range(h - 2):
        for x in range(w - 2):
            b = a[y:y + 3, x:x + 3]
            if b[..., 3].min() > 127 and (np.abs(b - b[0, 0]).max(-1) <= 6).all():
                out[y:y + 3, x:x + 3] = 1
    return cv2.dilate(out, np.ones((3, 3), np.uint8)) & (a[..., 3] > 127)


def mend(fid: str) -> None:
    """One more try: the latest try with only its flat blocks inpainted, so the rest of the fish stays as it was."""
    done = tries(fid)
    blocks = flat_blocks(Image.open(done[-1]))
    if not blocks.any():
        return print("no flat blocks left in", done[-1].stem)
    n = len(done) + 1
    mask = RAW / f"{fid}_{n}_mask.png"
    Image.fromarray(blocks * 255).save(mask)
    out = RAW / f"{fid}_{n}.png"
    w, h = Image.open(done[-1]).size
    subprocess.run([sys.executable, str(Path(__file__).with_name("pixellab.py")), "inpaint", str(done[-1].relative_to(ROOT)),
                    str(mask.relative_to(ROOT)), f"{look_of(fid)} seen from the side: fine single-pixel scales, speckles "
                    f"and fin rays in the same colours as the rest of the fish, crisp pixel art at one pixel size, no "
                    f"blocky doubled pixels, no outline", "--out", str(out.relative_to(ROOT)), "--transparent",
                    "--tile", f"{w // 4 * 4}x{h // 4 * 4}"], cwd=ROOT, timeout=600)
    print("painted", fid, out.stem if out.exists() else "FAILED")


def edits(fid: str) -> None:
    """One try: the blown up picture edited, then the edit edited again, since one pass often leaves parts blocky."""
    n = len(tries(fid)) + 1
    first = RAW / f"{fid}_{n}_first.png"
    if (first.exists() or edit(reference(fid), fid, first)) and edit(first, fid, RAW / f"{fid}_{n}.png"):
        print("painted", fid, n)


def paint(fid: str) -> None:
    # PixelLab's edit redraws a tiny fish blown up four times finely, but keeps a larger one's doubled pixels.
    small = Image.open(SMALL / f"{fid}.png")
    (edits if max(small.size) <= TINY else flash)(fid)


def lone_pixels_cleared(solid: np.ndarray) -> np.ndarray:
    p = np.pad(solid, 1)
    around = sum(np.roll(np.roll(p, dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx)[1:-1, 1:-1]
    return solid & (around >= 2)


def cleaned(im: Image.Image) -> Image.Image:
    """The painting with its edge made fully solid or fully clear, specks off it cleared, trimmed to the fish."""
    a = np.array(im.convert("RGBA"))
    solid = lone_pixels_cleared(a[..., 3] > 127)
    a[..., 3] = solid * 255
    a[~solid] = 0
    out = Image.fromarray(a)
    return out.crop(out.getbbox())


def recoloured(im: Image.Image, ref: Image.Image) -> Image.Image:
    """The painting's colours moved so their spread matches the small picture's, keeping all its shading and detail."""
    o, r = np.array(im.convert("RGBA")), np.array(ref.convert("RGBA"))
    solid, ref_solid = o[..., 3] > 127, r[..., 3] > 127
    lab = lambda rgb: cv2.cvtColor(np.ascontiguousarray(rgb, np.uint8), cv2.COLOR_RGB2LAB).astype(np.float32)
    own, theirs = lab(o[..., :3]), lab(r[..., :3])[ref_solid]
    mine = own[solid]
    own[solid] = np.clip((mine - mine.mean(0)) / (mine.std(0) + 1e-3) * theirs.std(0) + theirs.mean(0), 0, 255)
    o[..., :3] = cv2.cvtColor(own.astype(np.uint8), cv2.COLOR_LAB2RGB)
    o[~solid] = 0
    return Image.fromarray(o)


def doubled_edges(im: Image.Image) -> Image.Image:
    """Scale2x: each pixel becomes four, rounding off stair steps where its neighbours agree, so edges stay crisp."""
    a = np.array(im)
    p = np.pad(a, ((1, 1), (1, 1), (0, 0)), mode="edge")
    same = lambda x, y: (x == y).all(-1)[..., None]
    mid, up, right, left, down = p[1:-1, 1:-1], p[:-2, 1:-1], p[1:-1, 2:], p[1:-1, :-2], p[2:, 1:-1]
    out = np.zeros((a.shape[0] * 2, a.shape[1] * 2, 4), np.uint8)
    out[0::2, 0::2] = np.where(same(left, up) & ~same(left, down) & ~same(up, right), up, mid)
    out[0::2, 1::2] = np.where(same(up, right) & ~same(up, left) & ~same(right, down), right, mid)
    out[1::2, 0::2] = np.where(same(down, left) & ~same(down, right) & ~same(left, up), left, mid)
    out[1::2, 1::2] = np.where(same(right, down) & ~same(right, up) & ~same(down, left), down, mid)
    return Image.fromarray(out)


def enlarge(im: Image.Image, s: float) -> Image.Image:
    """The small picture resized smoothly and laid back onto its own colours with a fine ordered dither."""
    im = im.convert("RGBA")
    # A tiny fish has too few pixels to resize smoothly, so its edges and eye are doubled crisply first.
    if s > 2.0:
        im, s = doubled_edges(im), s / 2.0
    a = np.array(im).astype(np.float32)
    pal = np.unique(a[a[..., 3] > 127][:, :3], axis=0)
    w, h = round(im.width * s), round(im.height * s)
    # Colours are resized premultiplied, so the edge does not pick up the black of the clear pixels round it.
    a[..., :3] *= a[..., 3:4] / 255.0
    big = np.array(Image.fromarray(a.astype(np.uint8)).resize((w, h), Image.LANCZOS)).astype(np.float32)
    alpha = np.array(im.getchannel("A").resize((w, h), Image.BICUBIC)).astype(np.float32)
    flat = np.clip(big[..., :3] / np.maximum(big[..., 3:4], 1.0) * 255.0, 0, 255).reshape(-1, 3)
    order = ((flat[:, None] - pal[None]) ** 2).sum(-1).argsort(1)
    near, next_ = pal[order[:, 0]], pal[order[:, 1]]
    # Between its two nearest colours, a pixel takes the second where the dither's threshold says it is past halfway.
    v = next_ - near
    t = np.clip(((flat - near) * v).sum(1) / np.maximum((v * v).sum(1), 1e-6), 0, 1)
    threshold = np.tile(BAYER, (h // 2 + 1, w // 2 + 1))[:h, :w].reshape(-1) + 0.5
    out = np.where((t > threshold)[:, None], next_, near).reshape(h, w, 3)
    solid = lone_pixels_cleared(alpha > 127)
    big = Image.fromarray(np.dstack([out, solid * 255]).astype(np.uint8))
    return big.crop(big.getbbox())


def build(fid: str) -> None:
    im = Image.open(SMALL / f"{fid}.png").convert("RGBA")
    painted = tries(fid)
    if fid in KEEP or not painted:
        big = enlarge(im, scale_for(fid, im))
    else:
        big = Image.open(RAW / f"{fid}_{PICK.get(fid, 1)}.png")
        if fid in RECOLOUR:
            big = recoloured(big, Image.open(reference(fid)))
        big = cleaned(big)
    big.save(OUT / f"{fid}.png")
    if fid not in KEEP and painted:
        soften(OUT / f"{fid}.png")
    print(fid, im.size, "->", big.size, "kept" if fid in KEEP or not painted else f"try {PICK.get(fid, 1)}")


def main(cmd: str, ids: list[str]) -> None:
    RAW.mkdir(exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    every = [f["id"] for f in json.loads((ROOT / "game" / "data" / "fish.json").read_text(encoding="utf-8"))]
    for fid in ids or every:
        if cmd == "paint" and not tries(fid):
            paint(fid)
        elif cmd == "again":
            paint(fid)
        elif cmd == "more":
            more(fid)
        elif cmd == "flash":
            flash(fid)
        elif cmd == "mend":
            mend(fid)
        elif cmd == "build":
            build(fid)


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in ("paint", "again", "more", "flash", "mend", "build"):
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2:])
