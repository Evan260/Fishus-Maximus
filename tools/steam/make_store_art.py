"""Make the Steam store page's pictures: the capsules, the library art, the page background, the icons and the
screenshots, all from the game's own renders.

Each capsule and the library hero is a scene the game renders at one window pixel to the game pixel, with no
interface and no plants in front of the view, then enlarged a whole number of times with no smoothing and cropped to
Steam's exact size, so its pixel art stays crisp. The logo is laid over it at the same pixel size as the scene (the
hero has none, since Steam lays the library logo over it). The page background is the deep water off Misenum at night,
darkened. The screenshots are moments of the trailer's recorded shots, 1920x1080 as the game draws them; any shot not
yet recorded is recorded first with tools/trailer/make_trailer.py.

Usage: python tools/steam/make_store_art.py
Everything it renders, crops or combines goes into a temporary folder that is removed afterwards; only the finished
files are written, to store/steam_page/ (see README.txt there for which file goes in which Steamworks slot).
"""
import math
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "store" / "steam_page"
GODOT = (Path.home() / "AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
         / "Godot_v4.7.2-stable_win64_console.exe")
TRAILER = ROOT / "tools" / "trailer"
LOGO = TRAILER / "logo.png"
# The name without its laurel, for pictures too narrow for the laurel.
PLAIN_LOGO = TRAILER / "logo_plain.png"
SHOTS = ROOT / "marketing" / "recordings" / "content" / "trailer_shots"
DESKTOP = ROOT / "marketing" / "desktop.png"
FPS = 30
sys.path.insert(0, str(TRAILER))
sys.path.insert(0, str(ROOT / "tools" / "art"))
from make_logo import compact_name  # noqa: E402
import make_icon  # noqa: E402

# The waterline's row in every render, with the camera at home.
WATERLINE = 160
# name: (trailer shot, seconds into it). Upload them in this order; the first few lead in the sidebar and in search.
SCREENSHOTS = {
    "01_the_harbour_at_dawn": ("dawn", 2.5),
    "02_a_dentex_on_the_line": ("cast", 8.9),
    "03_the_catch_banner": ("cast", 14.6),
    "04_on_your_desktop": ("strip", 6.0),
    "05_northern_lights_off_misenum": ("night", 5.5),
    "06_the_caves_of_capri": ("capri", 2.0),
    "07_the_logbook": ("logbook", 6.1),
    "08_the_harbour_town": ("town", 3.0),
    "09_the_big_boat_under_sail": ("sail", 6.0),
    "10_the_pond_at_home": ("pond", 6.0),
    "11_the_rocky_shore": ("rocky", 3.0),
    "12_misenum_at_dusk": ("misenum", 3.0),
    "13_a_wreck_in_the_open_bay": ("wreck", 4.0),
}
DESKTOP_SHOT = "04_on_your_desktop"

# The scenes the capsules are made from: the flags that set each up.
HARBOUR = ["--demo-state", "--boat=fishing_boat", "--screen=coast", "--place=harbour", "--hour=18.3", "--at=420"]
CAPRI = ["--max-state", "--boat=sailing_boat", "--screen=coast", "--place=capri", "--hour=17.5", "--at=500"]
OPEN_BAY = ["--max-state", "--screen=coast", "--place=open_bay", "--hour=18.0", "--at=900"]
NIGHT = ["--max-state", "--screen=coast", "--place=misenum", "--hour=23.2", "--aurora", "--at=700"]
# name: (Steam's size, the scene, screen pixels to the game pixel, the render's first row shown, the logo, the logo's top
# in game pixels or None to centre it).
CAPSULES = {
    "header_capsule_920x430.png": ((920, 430), HARBOUR, 2, 60, "full", WATERLINE + 12),
    "small_capsule_462x174.png": ((462, 174), HARBOUR, 2, WATERLINE + 16, "compact", None),
    "main_capsule_1232x706.png": ((1232, 706), HARBOUR, 2, 0, "full", 14),
    "vertical_capsule_748x896.png": ((748, 896), CAPRI, 2, 0, "full", WATERLINE + 30),
    "library_capsule_600x900.png": ((600, 900), CAPRI, 2, 0, "plain", WATERLINE + 34),
}


def render(tmp, name, flags, size):
    """The scene at one window pixel to the game pixel, once it has settled, at a fixed frame rate so it is the same
    every time."""
    path = tmp / f"{name}.png"
    subprocess.run([str(GODOT), "--path", str(ROOT / "game"), "--fixed-fps", "60", "--", "--no-save", "--seed=7", "--no-hud",
                    "--no-front", "--weather=clear", f"--window={size[0]}x{size[1]}", *flags, "--shot-at=5",
                    f"--shot={path}", "--quit"], capture_output=True)
    if not path.exists():
        sys.exit(f"the game did not render {name}")
    print("rendered", name)
    return Image.open(path).convert("RGB")


def enlarge(img, scale):
    return img.resize((img.width * scale, img.height * scale), Image.NEAREST)


def logo(kind):
    """The logo trimmed to its drawn pixels, at one pixel to the game pixel."""
    pic = compact_name() if kind == "compact" else Image.open(PLAIN_LOGO if kind == "plain" else LOGO).convert("RGBA")
    return pic.crop(pic.getbbox())


def make_capsules(tmp):
    for name, (size, scene, scale, top, kind, logo_top) in CAPSULES.items():
        w, h = math.ceil(size[0] / scale), math.ceil(size[1] / scale)
        # The game's view is never narrower than 400 game pixels, so a narrow capsule is cut from the middle of one.
        base = render(tmp, Path(name).stem, scene, (max(400, w), max(270, top + h)))
        left = (base.width - w) // 2
        base = base.crop((left, top, left + w, top + h)).convert("RGBA")
        mark = logo(kind)
        at = ((w - mark.width) // 2, (h - mark.height) // 2 if logo_top is None else logo_top - top)
        base.alpha_composite(mark, at)
        big = enlarge(base, scale)
        left, up = (big.width - size[0]) // 2, (big.height - size[1]) // 2
        big.crop((left, up, left + size[0], up + size[1])).convert("RGB").save(OUT / name)
    # Steam's library header is the same picture as the store's header capsule.
    Image.open(OUT / "header_capsule_920x430.png").save(OUT / "library_header_920x430.png")
    # The hero is the open bay at sunset four times its pixel size, with room left for the library logo.
    hero = enlarge(render(tmp, "hero", OPEN_BAY, (960, 310)), 4)
    hero.crop((0, 0, 3840, 1240)).save(OUT / "library_hero_3840x1240.png")


def make_page_background(tmp):
    """The deep water off Misenum under the northern lights, behind the store page's text, three times its pixel size
    and darkened."""
    night = enlarge(render(tmp, "night", NIGHT, (480, 270)), 3)
    left = (night.width - 1438) // 2
    night.crop((left, 0, left + 1438, 810)).point(lambda v: int(v * 0.5)).save(OUT / "page_background_1438x810.png")


def make_logo_and_icons():
    mark = logo("full")
    mark = enlarge(mark, 4)
    canvas = Image.new("RGBA", (1280, mark.height), (0, 0, 0, 0))
    canvas.alpha_composite(mark, ((1280 - mark.width) // 2, 0))
    canvas.save(OUT / "library_logo_1280_transparent.png")
    # The community icon is square, so the icon's tile is drawn without its rounded corners and its rim is cropped away.
    make_icon.CORNER = 0
    art = make_icon.tile()
    make_icon.leaping_fish(art)
    square = enlarge(Image.fromarray(art).convert("RGB"), 3)
    inset = (square.width - 184) // 2
    square.crop((inset, inset, inset + 184, inset + 184)).save(OUT / "community_icon_184x184.jpg", quality=95)
    (OUT / "app_icon.ico").write_bytes((ROOT / "game" / "icon.ico").read_bytes())


def make_screenshots():
    missing = sorted({shot for shot, _ in SCREENSHOTS.values() if not (SHOTS / shot / "f.wav").exists()})
    if missing:
        subprocess.run([sys.executable, str(TRAILER / "make_trailer.py"), "shots", *missing], check=True)
    folder = OUT / "screenshots"
    folder.mkdir(parents=True, exist_ok=True)
    # A screenshot no longer in the list is taken off the page.
    for old in folder.glob("*.png"):
        if old.stem not in SCREENSHOTS:
            old.unlink()
    for name, (shot, seconds) in SCREENSHOTS.items():
        frame = Image.open(SHOTS / shot / f"f{round(seconds * FPS):08d}.png")
        if name == DESKTOP_SHOT:
            # The strip is laid along the bottom of a desktop, above its taskbar, as it sits on a player's screen.
            from make_trailer import desktop_frame
            with tempfile.TemporaryDirectory() as tmp:
                desk, taskbar = desktop_frame(Path(tmp) / "desktop.png")
                picture = Image.open(desk).convert("RGBA")
            strip = frame.convert("RGBA")
            picture.alpha_composite(strip, ((picture.width - strip.width) // 2, picture.height - taskbar - strip.height))
            frame = picture
        frame.convert("RGB").save(folder / f"{name}.png")
        print(f"{name}: {shot} at {seconds} s")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as folder:
        tmp = Path(folder)
        make_capsules(tmp)
        make_page_background(tmp)
    make_logo_and_icons()
    make_screenshots()
    print("laid out", OUT)


if __name__ == "__main__":
    main()
