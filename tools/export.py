"""Build the game for Windows, macOS and Linux into builds/<platform>/, each with "Credits and licences.txt" beside it.
Windows also gets the launcher that opens a game with everything unlocked, which never saves. The macOS build is
Godot's .zip with the .app inside, which keeps the app's file permissions; it is copied as it is to ~/MacShare/Fishus
Maximus/ when that folder exists, for testing on a Mac.

Usage: python tools/export.py [windows] [macos] [linux]   (no names builds all three; GODOT may name the Godot console
exe, otherwise the WinGet install is used)
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = "Fishus Maximus"
GODOT = os.environ.get("GODOT", str(Path.home() / "AppData/Local/Microsoft/WinGet/Packages"
    / "GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe"))
CREDITS = "Credits and licences.txt"
# The Godot export preset and the file it writes, for each platform.
PLATFORMS = {
    "windows": ("Windows", f"{GAME}.exe"),
    "macos": ("macOS", f"{GAME}.zip"),
    "linux": ("Linux", f"{GAME}.x86_64"),
}
MAC_SHARE = Path.home() / "MacShare" / GAME
LAUNCHER_NAME = f"{GAME} - everything unlocked.bat"
LAUNCHER = f"""@echo off
rem Starts {GAME} with every chapter open and the best of everything. It never saves, so your own games stay as they are.
start "" "%~dp0{GAME}.exe" -- --max-state --screen=coast
"""


def godot(*args):
    if subprocess.run([GODOT, "--headless", "--path", str(ROOT / "game"), *args]).returncode != 0:
        sys.exit(f"Godot failed: {' '.join(args)}")


def export(platform, folder):
    """Exports one platform into folder, with the credits, and the launcher on Windows; returns the built file."""
    preset, name = PLATFORMS[platform]
    folder.mkdir(parents=True, exist_ok=True)
    built = folder / name
    godot("--export-release", preset, str(built))
    if not built.exists():
        sys.exit(f"the {platform} export wrote nothing")
    # The licences of Godot and the libraries built into the game ask for their notices to ship with it.
    godot("--script", "res://tools/write_credits.gd", "--", f"--out={folder / CREDITS}")
    if platform == "windows":
        (folder / LAUNCHER_NAME).write_text(LAUNCHER.replace("\n", "\r\n"), encoding="ascii", newline="")
    return built


def main():
    names = sys.argv[1:] or list(PLATFORMS)
    for name in names:
        if name not in PLATFORMS:
            sys.exit(f"unknown platform {name}; choose from {', '.join(PLATFORMS)}")
    godot("--import")
    for name in names:
        folder = ROOT / "builds" / name
        built = export(name, folder)
        print(f"built {built}")
        if name == "macos" and MAC_SHARE.parent.is_dir():
            MAC_SHARE.mkdir(exist_ok=True)
            for f in (built, folder / CREDITS):
                shutil.copy2(f, MAC_SHARE / f.name)
            print(f"copied to {MAC_SHARE}")


if __name__ == "__main__":
    main()
