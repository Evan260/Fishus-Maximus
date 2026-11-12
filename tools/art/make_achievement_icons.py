"""Make the Steam achievement icons: a 64 by 64 picture for each achievement, and a grey one for before it is earned.

Each icon is a square of the catch banner's linen with its sea blue stripe round the edge and its ochre starfish in
the two lower corners. On it is a fish, an item or a client's portrait from the game's own art, enlarged only by whole
steps so the pixel art stays crisp, or a window onto a place the game renders, filling the inside of the stripe. The
legends and boats too big for the tile at their own size were painted small for it with PixelLab, into
tools/art/achievements_raw/. Steamworks takes JPG files, so the tiles have no transparency.

Usage: python tools/art/make_achievement_icons.py
Writes store/achievements/<id>.jpg and <id>_locked.jpg, plus store/achievements/sheet.png to look them over. The
scenes are rendered into a temporary folder that is removed afterwards.
"""
import json
import math
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parents[2]
GAME = ROOT / "game"
ART_DIR = GAME / "assets" / "art"
RAW = Path(__file__).with_name("achievements_raw")
OUT = ROOT / "store" / "achievements"
GODOT = (Path.home() / "AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
         / "Godot_v4.7.2-stable_win64_console.exe")
SIZE = 64
# The inside of the stripe, and the room a picture may take, reaching one pixel onto the stripe on each side.
INSIDE = (3, 3, 61, 61)
ROOM = 60
STAR_AT = [(0, 57), (57, 57)]
SILVER = (196, 198, 204)
SILVER_LIGHT = (240, 240, 244)
SILVER_MID = (160, 162, 170)
SILVER_DARK = (104, 104, 116)

# Each picture is a kind (fish, item, portrait, art, new, scene or draw), its name, and "@<scale>" to enlarge it.
ART = {
    "first_fish": "fish:mullet",
    "chapter_2": "scene:rocky_shore",
    "chapter_3": "scene:lucrine",
    "chapter_4": "scene:capri",
    "chapter_5": "scene:misenum",
    "legend_carteia_octopus": "new:carteia_octopus",
    "legend_tiberius_mullet": "fish:tiberius_mullet",
    "legend_hortensius_moray": "new:hortensius_moray",
    "legend_great_tuna": "new:great_tuna",
    "legend_orata_bream": "new:orata_bream",
    "legend_claudius_parrotfish": "fish:claudius_parrotfish",
    "legend_misenum_swordfish": "new:misenum_swordfish",
    "legend_senator_grouper": "new:senator_grouper",
    "legend_wreck_conger": "new:wreck_conger",
    "legend_numbing_ray": "fish:numbing_ray",
    "legend_sleeping_sunfish": "fish:sleeping_sunfish",
    "legend_neptune_lobster": "new:neptune_lobster",
    "all_legends": "draw:legends",
    "logbook_10": "draw:logbook_1",
    "logbook_25": "draw:logbook_2",
    "logbook_full": "draw:logbook_3",
    "prize_all": "draw:catch",
    "first_pond": "scene:pond",
    "all_ponds": "scene:pond_full",
    "all_tanks": "scene:garum",
    "sociorum": "art:places/harbour/amphora@2",
    "pond_show": "item:pearl_collar@2",
    "neptunalia": "item:trident@2",
    "moray_earrings": "draw:moray_earrings",
    "fishing_boat": "new:fishing_boat",
    "sailing_boat": "new:sailing_boat",
    "big_boat": "new:big_boat",
    "orders_10": "art:town/board",
    "orders_50": "item:help_fisherman@2",
    "northern_lights": "scene:aurora",
    "rich": "draw:coins",
    "client_cook": "portrait:cook",
    "client_trimalchio": "portrait:trimalchio",
    "client_umbricius": "portrait:umbricius",
    "client_senator": "portrait:senator",
    "client_priest": "portrait:priest",
    "client_widow": "portrait:widow",
}

# Each scene: the game's flags for it, and the corner of the window cut from its 480 by 270 render.
SCENES = {
    "rocky_shore": (["--screen=coast", "--place=rocky_shore", "--hour=10"], (75, 90)),
    "lucrine": (["--screen=coast", "--place=lucrine", "--hour=10"], (60, 55)),
    "capri": (["--screen=coast", "--place=capri", "--hour=10"], (230, 45)),
    "misenum": (["--screen=coast", "--place=misenum", "--hour=10"], (30, 40)),
    "pond": (["--screen=shore", "--demo-state", "--hour=10"], (405, 150)),
    "pond_full": (["--screen=shore", "--demo-state", "--hour=10"], (270, 178)),
    "garum": (["--screen=shore", "--demo-state", "--hour=10"], (330, 62)),
    "aurora": (["--screen=coast", "--place=harbour", "--hour=1", "--aurora=curtains"], (410, 20)),
}


def load(path):
    img = Image.open(path).convert("RGBA")
    return img.crop(img.getbbox())


def enlarge(img, scale):
    return img.resize((img.width * scale, img.height * scale), Image.NEAREST)


def star():
    return Image.open(ART_DIR / "ui" / "banner_star.png").convert("RGBA")


def render(tmp, name):
    """The scene at one window pixel to the game pixel, at a fixed frame rate so it is the same every time."""
    flags, _ = SCENES[name]
    path = tmp / ("_".join(f.strip("-").replace("=", "-") for f in flags) + ".png")
    if not path.exists():
        subprocess.run([str(GODOT), "--path", str(GAME), "--fixed-fps", "60", "--", "--no-save", "--seed=7", "--no-hud",
                        "--no-front", "--weather=clear", "--window=480x270", *flags, "--shot-at=8", f"--shot={path}",
                        "--quit"], capture_output=True)
        if not path.exists():
            sys.exit(f"the game did not render {name}")
    return Image.open(path).convert("RGBA")


def scene(tmp, name):
    x, y = SCENES[name][1]
    w, h = INSIDE[2] - INSIDE[0], INSIDE[3] - INSIDE[1]
    return render(tmp, name).crop((x, y, x + w, y + h))


def ellipse(img, cx, cy, rx, ry, fill, edge):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if d <= 1.0:
                img.putpixel((x, y), (edge if d > 0.55 else fill) + (255,))


def stack(img, x, base, count):
    """A stack of silver denarii seen from the side, the top one showing its face."""
    for k in range(count):
        ellipse(img, x + 6, base - 3 * k, 6.5, 2.6, SILVER_MID, SILVER_DARK)
    top = base - 3 * (count - 1)
    ellipse(img, x + 6, top, 6.5, 2.6, SILVER, SILVER_DARK)
    for dx in range(3, 6):
        img.putpixel((x + dx, top - 1), SILVER_LIGHT + (255,))


def face_coin(img, x, y):
    """A denarius lying face up: a dark rim, a silver face and a worn head on it."""
    for py in range(15):
        for px in range(15):
            d = math.hypot(px - 7, py - 7)
            if d <= 7.3:
                inner = d <= 6.2
                head = math.hypot((px - 7) * 1.3, py - 6) < 3.0 or (6 <= px <= 8 and 9 <= py <= 11)
                colour = (SILVER_MID if head else SILVER) if inner else SILVER_DARK
                if inner and not head and px + py <= 6:
                    colour = SILVER_LIGHT
                img.putpixel((x + px, y + py), colour + (255,))


def drawing(name):
    canvas = Image.new("RGBA", (ROOM, ROOM), (0, 0, 0, 0))
    if name == "legends":
        # Twelve starfish in a ring, one for each legend, round the map of the bay.
        bay = load(ART_DIR / "items" / "bay_map.png")
        canvas.alpha_composite(bay, ((ROOM - bay.width) // 2, (ROOM - bay.height) // 2))
        for i in range(12):
            a = math.tau * i / 12 - math.pi / 2
            canvas.alpha_composite(star(), (round(ROOM / 2 + 23 * math.cos(a)) - 3, round(ROOM / 2 + 23 * math.sin(a)) - 3))
        return canvas
    if name.startswith("logbook_"):
        stars = int(name[-1])
        book = enlarge(load(ART_DIR / "items" / "logbook.png"), 2)
        mark = enlarge(star(), 2)
        top = (ROOM - (mark.height + 3 + book.height)) // 2
        left = (ROOM - (stars * mark.width + (stars - 1) * 2)) // 2
        for i in range(stars):
            canvas.alpha_composite(mark, (left + i * (mark.width + 2), top))
        canvas.alpha_composite(book, ((ROOM - book.width) // 2, top + mark.height + 3))
        return canvas
    if name == "catch":
        for fish, x, y in (("red_porgy", 2, 4), ("mullet", 12, 18), ("parrotfish", 6, 33)):
            pic = load(ART_DIR / "fish" / f"{fish}.png")
            canvas.alpha_composite(pic, (x, y))
        return canvas
    if name == "moray_earrings":
        moray = load(ART_DIR / "fish" / "moray.png")
        rings = load(ART_DIR / "items" / "earrings.png")
        top = (ROOM - (moray.height + 4 + rings.height)) // 2
        canvas.alpha_composite(moray, ((ROOM - moray.width) // 2, top))
        canvas.alpha_composite(rings, ((ROOM - rings.width) // 2, top + moray.height + 4))
        return canvas
    if name == "coins":
        for x, count in ((8, 6), (23, 9), (38, 5)):
            stack(canvas, x, 44, count)
        face_coin(canvas, 13, 40)
        face_coin(canvas, 33, 42)
        return canvas
    raise ValueError(name)


def picture(achievement_id, tmp):
    kind, _, what = ART[achievement_id].partition(":")
    what, _, scale = what.partition("@")
    if kind == "scene":
        return scene(tmp, what)
    if kind == "draw":
        return drawing(what)
    path = {"fish": ART_DIR / "fish" / f"{what}.png", "item": ART_DIR / "items" / f"{what}.png",
            "portrait": ART_DIR / "portraits" / f"{what}.png", "art": ART_DIR / f"{what}.png",
            "new": RAW / f"{what}.png"}[kind]
    img = enlarge(load(path), int(scale or 1))
    if img.width > ROOM or img.height > ROOM:
        sys.exit(f"{achievement_id}: its picture is {img.width} by {img.height}, more than the tile's {ROOM}")
    return img


def tile():
    """The catch banner's linen with its stripe, from the banner's four corners, so the stripe runs round the edge."""
    cloth = Image.open(ART_DIR / "ui" / "banner_cloth.png").convert("RGBA")
    img = Image.new("RGBA", (SIZE, SIZE))
    half = SIZE // 2
    for (sx, sy), (dx, dy) in (((3, 5), (0, 0)), ((135, 5), (half, 0)), ((3, 96), (0, half)), ((135, 96), (half, half))):
        img.paste(cloth.crop((sx, sy, sx + half, sy + half)), (dx, dy))
    return img


def icon(achievement_id, tmp):
    pic = picture(achievement_id, tmp)
    img = tile()
    if ART[achievement_id].startswith("scene:"):
        img.paste(pic, INSIDE[:2])
    elif ART[achievement_id].startswith("portrait:"):
        # The portrait's bust ends in a straight line, so it stands on the stripe at the foot of the tile.
        img.alpha_composite(pic, ((SIZE - pic.width) // 2, INSIDE[3] - pic.height))
    else:
        img.alpha_composite(pic, ((SIZE - pic.width) // 2, (SIZE - pic.height) // 2))
    for at in STAR_AT:
        img.alpha_composite(star(), at)
    return img.convert("RGB")


def locked(img):
    grey = ImageEnhance.Color(img).enhance(0.0)
    return ImageEnhance.Brightness(ImageEnhance.Contrast(grey).enhance(0.8)).enhance(0.55)


def main():
    ids = [a["id"] for a in json.loads((GAME / "data" / "achievements.json").read_text(encoding="utf-8"))]
    missing = [i for i in ids if i not in ART]
    if missing:
        raise SystemExit(f"no picture chosen for {missing}; add them to ART")
    OUT.mkdir(parents=True, exist_ok=True)
    cell = SIZE * 2 + 12
    sheet = Image.new("RGB", (4 * cell, ((len(ids) + 3) // 4) * (SIZE + 8)), (40, 30, 26))
    with tempfile.TemporaryDirectory() as tmp:
        for n, i in enumerate(ids):
            img = icon(i, Path(tmp))
            img.save(OUT / f"{i}.jpg", quality=95, subsampling=0)
            dim = locked(img)
            dim.save(OUT / f"{i}_locked.jpg", quality=95, subsampling=0)
            col, row = n % 4, n // 4
            sheet.paste(img, (col * cell, row * (SIZE + 8)))
            sheet.paste(dim, (col * cell + SIZE + 4, row * (SIZE + 8)))
    sheet.save(OUT / "sheet.png")
    print(f"wrote {len(ids) * 2} icons to {OUT}")


if __name__ == "__main__":
    main()
