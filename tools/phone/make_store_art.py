"""Make the phone app stores' pictures: the Google Play icon, feature graphic and phone and tablet screenshots, and
the App Store icon and iPhone and iPad screenshots, all from the game's own renders so the pixel art stays exact.

Screenshots are taken with the phone interface (--phone) at each store's exact size, so the game picks its own whole
number scale for that screen's shape, as it would on the device. Each is a still the game sets up with
--trailer-shot=store (game/tools/trailer/shots.gd): a made-up game some weeks in that is never saved, with every
achievement already earned so no card slides in, the day and weather the scene names, and the toasts hidden. The
feature graphic is the harbour at sunset rendered at one screen pixel to the game pixel and enlarged twice, with the
logo laid over the sky at the same pixel size, as the Steam capsules are. The icons are the game's icon tile without
its rounded corners and rim, enlarged a whole number of times.

Usage: python tools/phone/make_store_art.py
Writes store/google_play/ and store/app_store/ (see README.txt in each for which file goes where); the feature
graphic's render goes into a temporary folder that is removed afterwards.
"""
import ctypes
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PLAY = ROOT / "store" / "google_play"
APPLE = ROOT / "store" / "app_store"
GODOT = (Path.home() / "AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
         / "Godot_v4.7.2-stable_win64_console.exe")
LOGO = ROOT / "tools" / "trailer" / "logo.png"
sys.path.insert(0, str(ROOT / "tools" / "art"))
import make_icon  # noqa: E402

# name: flags. Each is one scene, taken at every size that lists it; --day sets the season (seven days to each) and
# --seed which fish swim by. The game leaves out any fish cut off by the picture's edge, behind a button or crossing
# another, and a scene with --clear waits for a moment when enough fish are wholly in view and none is turning, at
# most until --shot-at.
CLEAR = ["--clear-from=4", "--shot-at=150"]
SCENES = {
    "the_harbour_at_sunset": ["--place=harbour", "--hour=18.3", "--at=420", "--boat=fishing_boat", "--day=3",
                              "--seed=1", "--clear=3", *CLEAR],
    # The trailer's first cast, taken as the dentex leaps from the water; the plants in front break away while a fish is
    # on, so they are left out rather than caught half gone.
    "a_dentex_on_the_line": ["--like=cast", "--day=9", "--no-front", "--clear=0", "--leaping", "--clear-from=6",
                             "--shot-at=14"],
    # The banner hangs for a few seconds only, so its wait ends when it starts to roll up.
    "the_catch_banner": ["--place=open_bay", "--hour=17.6", "--at=300", "--day=17", "--seed=4", "--catch=dolphinfish",
                         "--catch-at=6", "--clear=0", "--clear-from=8.6", "--shot-at=10.6"],
    # The townsfolk stand where the street is clear of the buttons, with one client waiting by the fish market.
    "the_harbour_town": ["--screen=town", "--hour=9.5", "--day=16", "--clients=1", "--folk=86,166,206"],
    "the_pond_at_home": ["--screen=shore", "--hour=16.8", "--day=10", "--seed=6", "--clear=5", "--clear-from=3",
                         "--shot-at=90"],
    "capri_under_sail": ["--place=capri", "--hour=11.5", "--at=850", "--boat=sailing_boat", "--day=5", "--seed=5",
                         "--clear=0", *CLEAR],
    "rain_on_lake_lucrine": ["--place=lucrine", "--hour=15", "--weather=rain", "--at=400", "--boat=sailing_boat",
                             "--day=20", "--clear=2", *CLEAR],
    # The panel and the buttons would sit over the northern lights, so this one scene leaves them out.
    "northern_lights_over_the_harbour": ["--place=harbour", "--hour=21.5", "--aurora", "--at=600", "--day=24",
                                         "--seed=7", "--no-hud", "--clear=2", *CLEAR],
}
PHONE_ORDER = ["the_harbour_at_sunset", "a_dentex_on_the_line", "the_catch_banner", "the_harbour_town",
               "the_pond_at_home", "capri_under_sail", "rain_on_lake_lucrine", "northern_lights_over_the_harbour"]
# An iPad's squarer screen shows deep, empty water under Capri, so the lake in the rain takes its place.
IPAD_ORDER = ["the_harbour_at_sunset", "a_dentex_on_the_line", "the_harbour_town", "the_pond_at_home",
              "rain_on_lake_lucrine", "northern_lights_over_the_harbour"]
# A screen wide enough to show most of the pond keeps fewer of its fish, so five can be seen apart.
WIDE_POND = ["--seed=1", "--pond-fish=6"]
WIDEST_POND = ["--seed=1", "--pond-fish=5"]
# folder: (window size, scenes in upload order, extra flags per scene for that screen's shape).
SETS = {
    PLAY / "phone_screenshots": ((1920, 1080), PHONE_ORDER, {}),
    PLAY / "tablet_7_inch_screenshots": ((1920, 1080), PHONE_ORDER, {}),
    PLAY / "tablet_10_inch_screenshots": ((2560, 1440), PHONE_ORDER, {"the_pond_at_home": WIDE_POND}),
    APPLE / "iphone_6.9_inch_screenshots": ((2868, 1320), PHONE_ORDER, {"the_pond_at_home": WIDEST_POND}),
    APPLE / "ipad_13_inch_screenshots": ((2752, 2064), IPAD_ORDER, {}),
}
# The harbour at sunset behind the feature graphic's logo: the Steam main capsule's scene, at one window pixel to the
# game pixel and wide enough for the graphic's 512 by 250.
FEATURE_SCENE = ["--demo-state", "--boat=fishing_boat", "--screen=coast", "--place=harbour", "--hour=18.3", "--at=420",
                 "--seed=7", "--no-hud", "--no-front", "--weather=clear"]
FEATURE_TOP = 0
LOGO_TOP = 12


def godot(flags, size, path, timeout=60):
    """Runs the game in a window of the given size at a fixed frame rate, so each picture is the same every time."""
    subprocess.run([str(GODOT), "--path", str(ROOT / "game"), "--fixed-fps", "60", "--", "--no-save",
                    f"--window={size[0]}x{size[1]}", "--shot-at=4", *flags, f"--shot={path}", "--quit"],
                   capture_output=True, timeout=timeout)
    if not path.exists():
        sys.exit(f"the game did not render {path.name}")


def shoot(path, size, flags):
    godot(["--phone", "--trailer-shot=store", *flags], size, path, timeout=240)
    # The stores take no alpha channel in a screenshot.
    Image.open(path).convert("RGB").save(path)
    print("rendered", path.relative_to(ROOT))


def screenshots():
    jobs = []
    for folder, (size, names, extra) in SETS.items():
        folder.mkdir(parents=True, exist_ok=True)
        for old in folder.glob("*.png"):
            old.unlink()
        for k, name in enumerate(names, 1):
            jobs.append((folder / f"{k:02d}_{name}.png", size, SCENES[name] + extra.get(name, [])))
    with ThreadPoolExecutor(3) as pool:
        list(pool.map(lambda job: shoot(*job), jobs))


def feature_graphic(tmp):
    """The harbour at sunset with the logo over its sky, 1024x500 at two screen pixels to the game pixel."""
    path = tmp / "feature_scene.png"
    godot(FEATURE_SCENE + ["--shot-at=5"], (512, 270), path)
    scene = Image.open(path).convert("RGBA").crop((0, FEATURE_TOP, 512, FEATURE_TOP + 250))
    mark = Image.open(LOGO).convert("RGBA")
    mark = mark.crop(mark.getbbox())
    scene.alpha_composite(mark, ((scene.width - mark.width) // 2, LOGO_TOP))
    scene.resize((1024, 500), Image.NEAREST).convert("RGB").save(PLAY / "feature_graphic_1024x500.png")
    print("rendered the feature graphic")


def icons():
    """The icon's sea at sunset and leaping bream filling the square: Android's adaptive layers laid together and cut
    to the tile's 64 pixels, so the stores round the corners themselves."""
    back, front = make_icon.android_layers()
    back.alpha_composite(front)
    pad = (make_icon.ANDROID - make_icon.TILE) // 2
    tile = back.crop((pad, pad, pad + make_icon.TILE, pad + make_icon.TILE))
    tile.resize((512, 512), Image.NEAREST).save(PLAY / "icon_512.png")
    # Apple refuses an icon with an alpha channel, even a fully opaque one.
    tile.convert("RGB").resize((1024, 1024), Image.NEAREST).save(APPLE / "icon_1024.png")


def main():
    if sys.platform == "win32":
        # A pointer resting over a game window would light up a button, so it waits in the desktop's top corner.
        user32 = ctypes.windll.user32
        user32.SetCursorPos(user32.GetSystemMetrics(76), user32.GetSystemMetrics(77))
    PLAY.mkdir(parents=True, exist_ok=True)
    APPLE.mkdir(parents=True, exist_ok=True)
    icons()
    with tempfile.TemporaryDirectory() as tmp:
        feature_graphic(Path(tmp))
    screenshots()
    print("laid out", PLAY, "and", APPLE)


if __name__ == "__main__":
    main()
