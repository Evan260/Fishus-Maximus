"""Make the YouTube channel banner from a picture of the harbour at sunset the game renders itself.

The banner is 2560x1440, but computers and phones show only a strip across its middle (1546x423 at the narrowest,
2560x423 at the widest) and only televisions show the whole of it. The game draws the harbour 1280 game pixels wide at
two window pixels to the game pixel, which is the banner's width, and the picture is placed so the strip holds the sky,
the town, the cape and the boat, with the logo in the sky above them at the same pixel size. Above the picture the sky
carries on up into the dusk, and below it the sea darkens into the deep, both in bands a game pixel tall, for
televisions.

Usage: python tools/trailer/make_banner.py
Writes marketing/youtube_banner.png; the logo comes from tools/trailer/make_logo.py.
"""
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GODOT = (Path.home() / "AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
         / "Godot_v4.7.2-stable_win64_console.exe")
LOGO = HERE / "logo.png"
OUT = ROOT / "marketing" / "youtube_banner.png"
SIZE = (2560, 1440)
SCALE = 2
STRIP = (508, 931)
# The plants in front of the view are left out, since the picture's edges would cut them. Where the camera stands along
# the harbour, the hour, and the row of the render's waterline.
AT = 700
HOUR = 18.6
WATERLINE = 160
# The banner row the waterline falls on, at the strip's foot, so the strip holds the boat whole on the water.
WATER_AT = 926
DUSK = np.array([66, 60, 118], np.float32)
DEEP = np.array([10, 22, 34], np.float32)
# How many banner rows above the picture's foot the sea starts darkening, dark by its foot.
FADE = 200


def shoot(path: Path) -> None:
    subprocess.run([str(GODOT), "--path", str(ROOT / "game"), "--", "--screen=coast", "--demo-state", "--no-save", "--no-hud", "--no-front",
                    f"--window={SIZE[0]}x{270 * SCALE}", f"--at={AT}", f"--hour={HOUR}", "--weather=clear",
                    "--shot-at=4", f"--shot={path}", "--quit"], check=True, capture_output=True)


def main():
    with tempfile.TemporaryDirectory() as tmp:
        shot = Path(tmp) / "harbour.png"
        shoot(shot)
        render = np.array(Image.open(shot).convert("RGB")).astype(np.float32)
    top = WATER_AT - WATERLINE * SCALE
    banner = np.zeros((SIZE[1], SIZE[0], 3), np.float32)
    banner[top:top + render.shape[0]] = render
    # The sky above the picture deepens from its own top row into the dusk, a game pixel at a time.
    sky = np.median(render[0], axis=0)
    for y in range(0, top, SCALE):
        t = 1.0 - y / top
        banner[y:y + SCALE] = sky * (1.0 - t) + DUSK * t
    # The sea darkens into the deep over the picture's last rows, so the sea floor fades out rather than stopping at its
    # edge, a game pixel at a time, and the deep fills the rest.
    bottom = top + render.shape[0]
    fade = bottom - FADE
    for y in range(fade, SIZE[1], SCALE):
        t = min(1.0, (y - fade) / FADE)
        banner[y:y + SCALE] = banner[y:y + SCALE] * (1.0 - t) + DEEP * t
    out = Image.fromarray(np.clip(banner, 0, 255).astype(np.uint8))
    logo = Image.open(LOGO).convert("RGBA")
    logo = logo.resize((logo.width * SCALE, logo.height * SCALE), Image.NEAREST)
    out.paste(logo, ((SIZE[0] - logo.width) // 2, STRIP[0] + 6), logo)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT)
    print("banner:", OUT)


if __name__ == "__main__":
    main()
