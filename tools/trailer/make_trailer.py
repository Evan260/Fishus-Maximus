"""Make the Steam trailer and the vertical shorts for YouTube Shorts, Reels and TikTok: record each scripted shot in
movie mode, then cut them together with the cards, captions, the end card and the music, all in Godot, and keep an .mp4
copy beside each .avi.

Usage:
  python tools/trailer/make_trailer.py              records any shot not yet recorded, then renders the trailer
  python tools/trailer/make_trailer.py shots cast   records just those shots again
  python tools/trailer/make_trailer.py render       renders from the shots already recorded
  python tools/trailer/make_trailer.py render 40    renders a preview from 40 seconds in, into recordings/content/
  Add --cut=NAME to any of these for one of the shorts named in SHORTS below, whose shots are recorded in a tall
  1080x1920 frame, the game drawn six screen pixels to the game pixel.

Each finished video goes to its own folder in marketing/recordings/videos/, beside its title, description and
thumbnail; the shot frames it is cut from are kept in marketing/recordings/content/, the trailer's in trailer_shots/ and
the shorts' in short_shots/, so a change to an edit renders again in a minute or two. Both are kept out of git. The
shots are scripted in game/tools/trailer/shots.gd and the edits, with their cards, captions and music, in
game/tools/trailer/edit.gd. Every shot plays a made-up game that is never saved.
"""
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VIDEOS = ROOT / "marketing" / "recordings" / "videos"
WORK = ROOT / "marketing" / "recordings" / "content"
DESKTOP = ROOT / "marketing" / "desktop.png"
FPS = 30
# The strip runs the full width of the frame at three screen pixels to the game pixel, 90 game pixels tall.
STRIP_SCALE = 3
# Screen rows at the bottom of a tall frame that phone apps cover with a video's caption and buttons.
PHONE_BOTTOM = 420
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
    "wreck": 10,
    "night": 14,
    "logbook": 12,
    "town": 9,
    "boatwright": 6,
    "sail": 10,
    "dog": 7,
    "pond": 10,
    "strip": 12,
    "endcard": 9,
    "legend": 30,
    "boat_skiff": 7,
    "boat_fishing": 7,
    "boat_sailing": 7,
    "boat_big": 8,
    "pet_hound": 6,
    "pet_molossian": 6,
    "pet_sighthound": 6,
    "pet_sheepdog": 6,
    "desk": 12,
    "idle": 7,
    "idle_dog": 6,
    "wreck_dive": 15,
    "pond_bell": 13,
    "rain": 9,
    "night_harbour": 8,
}
# Each cut's shots, its frame, where its shots are kept and where it is written.
CUTS = {
    "trailer": {"shots": ["dawn", "cast", "rocky", "capri", "misenum", "wreck", "night", "logbook", "town", "boatwright", "sail",
                          "dog", "pond", "strip", "endcard"],
                "size": (1920, 1080), "dir": WORK / "trailer_shots", "out": VIDEOS / "steam_trailer" / "steam_trailer.avi"},
}
# The shorts are all recorded in the tall frame and share their shots: cut name, its folder and its shots.
SHORTS = {
    "legend": ("legend", ["legend", "endcard"]),
    "first_vs_last": ("first_boat_vs_last", ["boat_skiff", "boat_fishing", "boat_sailing", "boat_big", "endcard"]),
    "cozy_sounds": ("cozy_sounds", ["dawn", "cast", "rain", "pond", "night_harbour", "endcard"]),
    "pet_the_dog": ("pet_the_dog", ["pet_hound", "pet_molossian", "pet_sighthound", "pet_sheepdog", "endcard"]),
    "on_my_desktop": ("on_my_desktop", ["desk", "idle", "idle_dog", "endcard"]),
    "shipwreck": ("shipwreck", ["wreck_dive", "endcard"]),
    "fish_by_name": ("fish_by_name", ["pond_bell", "endcard"]),
}
for _cut, (_folder, _shots) in SHORTS.items():
    CUTS[_cut] = {"shots": _shots, "size": (1080, 1920), "dir": WORK / "short_shots",
                  "out": VIDEOS / f"short_{_folder}" / f"short_{_folder}.avi"}


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


def record(name, cut):
    folder = cut["dir"] / name
    if folder.exists():
        shutil.rmtree(folder)
    folder.mkdir(parents=True)
    strip = name in ("strip", "desk")
    size = (cut["size"][0], 90 * STRIP_SCALE) if strip else cut["size"]
    shape = [f"--strip-scale={STRIP_SCALE}", f"--strip-width={size[0] // STRIP_SCALE}"] if strip else [f"--window={size[0]}x{size[1]}"]
    # A .png movie is written as numbered frames with the sound beside them in a .wav of the same name.
    godot(["--write-movie", str(folder / "f.png"), "--fixed-fps", str(FPS), "--quit-after", str(SHOTS[name] * FPS),
           "--", *shape, "--no-save", f"--trailer-shot={name}"], size)


def render(name, cut, start=0.0):
    """Renders the cut, or with a start time a preview from that moment on into the work folder."""
    out = WORK / "preview.avi" if start else cut["out"]
    out.parent.mkdir(parents=True, exist_ok=True)
    size = cut["size"]
    desk = desktop_frame(size, WORK / f"desktop_{size[0]}x{size[1]}.png")
    desk_args = [f"--desktop={desk[0]}", f"--taskbar={desk[1]}"] if desk else []
    # The edit quits when it ends; the frame limit only stops a run whose script failed to load from going on forever.
    godot(["--write-movie", str(out), "--fixed-fps", str(FPS), "--quit-after", str(200 * FPS), "res://tools/trailer/edit.tscn",
           "--", f"--window={size[0]}x{size[1]}", "--no-save", f"--shots={cut['dir']}", f"--cut={name}", f"--from={start}",
           *desk_args], size)
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


def desktop_frame(size, out):
    """The desktop screenshot, marketing/desktop.png, cut to the frame's shape from its bottom, where the strip sits, or
    from its middle for a tall frame, and scaled to fit. A tall frame keeps its bottom rows clear for the captions phone
    apps lay over a video, so the desktop fills the frame above them and its taskbar's colour runs on below it. Returns
    the path and how far up from the frame's bottom the taskbar's top is, or None without a screenshot."""
    if not DESKTOP.exists():
        return None
    from PIL import Image
    shot = Image.open(DESKTOP).convert("RGB")
    below = PHONE_BOTTOM if size[1] > size[0] else 0
    shown = (size[0], size[1] - below)
    tall = round(shot.width * shown[1] / shown[0])
    if tall <= shot.height:
        shot = shot.crop((0, shot.height - tall, shot.width, shot.height))
    else:
        wide = round(shot.height * shown[0] / shown[1])
        shot = shot.crop(((shot.width - wide) // 2, 0, (shot.width - wide) // 2 + wide, shot.height))
    taskbar = taskbar_height(shot)
    factor = shown[0] / shot.width
    frame = Image.new("RGB", tuple(size), shot.getpixel((shot.width // 2, shot.height - 1)))
    frame.paste(shot if shot.size == shown else shot.resize(shown, Image.LANCZOS), (0, 0))
    out.parent.mkdir(parents=True, exist_ok=True)
    frame.save(out)
    return out, round(taskbar * factor) + below


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
    name = "trailer"
    for a in args:
        if a.startswith("--cut="):
            name = a.split("=", 1)[1]
            if name not in CUTS:
                sys.exit(f"no cut named {name}; the cuts are {', '.join(CUTS)}")
    args = [a for a in args if not a.startswith("--cut=")]
    cut = CUTS[name]
    if args[:1] == ["shots"]:
        for shot in args[1:] or cut["shots"]:
            record(shot, cut)
        return
    if args[:1] != ["render"]:
        for shot in cut["shots"]:
            if not (cut["dir"] / shot / "f.wav").exists():
                record(shot, cut)
    render(name, cut, float(args[1]) if args[:1] == ["render"] and len(args) > 1 else 0.0)


if __name__ == "__main__":
    main()
