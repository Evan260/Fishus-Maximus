"""Make the Steam trailer: record each scripted shot in movie mode, then cut them together with the cards, the end card
and the music, all in Godot, and keep an .mp4 copy beside the .avi.

Usage:
  python tools/trailer/make_trailer.py              records any shot not yet recorded, then renders the trailer
  python tools/trailer/make_trailer.py shots cast   records just those shots again
  python tools/trailer/make_trailer.py render       renders from the shots already recorded
  python tools/trailer/make_trailer.py render 40    renders a preview from 40 seconds in, into recordings/content/

The trailer goes to marketing/recordings/videos/steam_trailer/, beside its title, description and thumbnail; the shot
frames it is cut from are kept in marketing/recordings/content/trailer_shots/, so a change to the edit renders again in
a minute or two. Both are kept out of git. The shots are scripted in game/tools/trailer/shots.gd and the edit, with its
cards and music, in game/tools/trailer/edit.gd. Every shot plays a made-up game that is never saved.
"""
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VIDEOS = ROOT / "marketing" / "recordings" / "videos"
WORK = ROOT / "marketing" / "recordings" / "content"
SHOTS_DIR = WORK / "trailer_shots"
OUT = VIDEOS / "steam_trailer" / "steam_trailer.avi"
DESKTOP = ROOT / "marketing" / "desktop.png"
FPS = 30
SIZE = (1920, 1080)
# The strip runs the full width of a 1080p screen at three screen pixels to the game pixel, a quarter of its height.
STRIP_SCALE = 3
STRIP_SIZE = (1920, 90 * STRIP_SCALE)
GODOT = (Path.home() / "AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
         / "Godot_v4.7.2-stable_win64_console.exe")
FFMPEG = (Path.home() / "AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe"
          / "ffmpeg-9.0.2-full_build/bin/ffmpeg.exe")
# name: seconds to record. The edit takes its part of each from edit.gd; a shot starts a moment early so its screen has
# opened and settled before the part that is used.
SHOTS = {
    "dawn": 12,
    "cast": 34,
    "rocky": 7,
    "capri": 7,
    "misenum": 7,
    "night": 14,
    "logbook": 12,
    "town": 9,
    "boatwright": 6,
    "sail": 10,
    "dog": 7,
    "pond": 10,
    "strip": 12,
    "endcard": 9,
}


def godot(args, size):
    """Runs Godot at the given window size, which movie mode takes from the project's window setting when it starts."""
    override = ROOT / "game" / "override.cfg"
    if override.exists():
        sys.exit(f"{override} already exists; move it aside first")
    override.write_text(f"[display]\n\nwindow/size/window_width_override={size[0]}\nwindow/size/window_height_override={size[1]}\n\n"
                        "[editor]\n\nmovie_writer/mjpeg_quality=0.95\n")
    try:
        subprocess.run([str(GODOT), "--path", str(ROOT / "game"), *args], check=True)
    finally:
        override.unlink()


def record(name):
    folder = SHOTS_DIR / name
    if folder.exists():
        shutil.rmtree(folder)
    folder.mkdir(parents=True)
    strip = name == "strip"
    size = STRIP_SIZE if strip else SIZE
    shape = [f"--strip-scale={STRIP_SCALE}", f"--strip-width={STRIP_SIZE[0] // STRIP_SCALE}"] if strip else [f"--window={size[0]}x{size[1]}"]
    # A .png movie is written as numbered frames with the sound beside them in a .wav of the same name.
    godot(["--write-movie", str(folder / "f.png"), "--fixed-fps", str(FPS), "--quit-after", str(SHOTS[name] * FPS),
           "--", *shape, "--no-save", f"--trailer-shot={name}"], size)


def render(start=0.0):
    """Renders the trailer, or with a start time a preview from that moment on into the work folder."""
    out = WORK / "preview.avi" if start else OUT
    out.parent.mkdir(parents=True, exist_ok=True)
    desk = desktop_frame(WORK / f"desktop_{SIZE[0]}x{SIZE[1]}.png")
    desk_args = [f"--desktop={desk[0]}", f"--taskbar={desk[1]}"] if desk else []
    # The edit quits when it ends; the frame limit only stops a run whose script failed to load from going on forever.
    godot(["--write-movie", str(out), "--fixed-fps", str(FPS), "--quit-after", str(200 * FPS), "res://tools/trailer/edit.tscn",
           "--", f"--window={SIZE[0]}x{SIZE[1]}", "--no-save", f"--shots={SHOTS_DIR}", f"--from={start}", *desk_args], SIZE)
    if not start:
        mp4_copy(out)
    print(f"ready: {out}")


def mp4_copy(avi):
    """Writes an .mp4 beside the .avi: about a tenth of its size, and the format Steam and most upload pages want, with
    its sound brought to the loudness video sites play at. Skipped without ffmpeg."""
    if not FFMPEG.exists():
        print("no ffmpeg, so no .mp4 copy")
        return
    subprocess.run([str(FFMPEG), "-y", "-loglevel", "error", "-i", str(avi), "-c:v", "libx264", "-preset", "slow", "-crf", "16",
                    "-pix_fmt", "yuv420p", "-af", "loudnorm=I=-16:TP=-1.5:LRA=11", "-ar", "48000", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", str(avi.with_suffix(".mp4"))],
                   check=True)


def desktop_frame(out):
    """The desktop screenshot, marketing/desktop.png, cut to the frame's shape from its bottom, where the strip sits, and
    scaled to fit. Returns the path and how tall the taskbar is in it, or None without a screenshot."""
    if not DESKTOP.exists():
        return None
    from PIL import Image
    shot = Image.open(DESKTOP).convert("RGB")
    tall = round(shot.width * SIZE[1] / SIZE[0])
    if tall <= shot.height:
        shot = shot.crop((0, shot.height - tall, shot.width, shot.height))
    else:
        wide = round(shot.height * SIZE[0] / SIZE[1])
        shot = shot.crop(((shot.width - wide) // 2, 0, (shot.width - wide) // 2 + wide, shot.height))
    taskbar = taskbar_height(shot)
    factor = SIZE[0] / shot.width
    out.parent.mkdir(parents=True, exist_ok=True)
    (shot if shot.size == SIZE else shot.resize(SIZE, Image.LANCZOS)).save(out)
    return out, round(taskbar * factor)


def taskbar_height(shot):
    """How tall the taskbar along the screenshot's bottom is: the rows up from the bottom that keep the bottom row's
    dark, even colour. A row's median is used, so the app icons on the taskbar do not break it up."""
    import numpy as np
    rows = np.median(np.asarray(shot.convert("L"), dtype=float), axis=1)
    base = rows[-1]
    height = 0
    while height < len(rows) // 4 and abs(rows[-1 - height] - base) < 12:
        height += 1
    return height


def main():
    args = sys.argv[1:]
    if args[:1] == ["shots"]:
        for shot in args[1:] or SHOTS:
            record(shot)
        return
    if args[:1] != ["render"]:
        for shot in SHOTS:
            if not (SHOTS_DIR / shot / "f.wav").exists():
                record(shot)
    render(float(args[1]) if args[:1] == ["render"] and len(args) > 1 else 0.0)


if __name__ == "__main__":
    main()
