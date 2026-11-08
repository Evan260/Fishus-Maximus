"""Cuts the game's sea sounds out of CC0 Freesound recordings in tools/audio/recordings (each named by its preview id)
into game/assets/audio: short effects, and ambience loops whose end is blended into their start so they loop without
a gap. Needs ffmpeg on the path. Usage: python tools/audio/cut_sounds.py"""
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
RAW = Path(__file__).with_name("recordings")
SFX = ROOT / "game" / "assets" / "audio" / "sfx"
AMBIENCE = ROOT / "game" / "assets" / "audio" / "ambience"
RATE = 44100

# name: (recording, start, end, high-pass in Hz, loudness target in LUFS)
EFFECTS = {
    "oars_1": ("585316_12458758", 3.2, 4.9, 80, -20),
    "oars_2": ("585316_12458758", 8.2, 9.9, 80, -20),
    "oars_3": ("585316_12458758", 12.7, 14.4, 80, -20),
    "reel": ("507078_8682843", 0.5, 2.6, 120, -18),
    "splash_small": ("178736_2596329", 2.3, 2.95, 180, -18),
    "splash_big": ("507091_8682843", 1.0, 2.7, 100, -16),
    "creak_1": ("145721_981371", 31.0, 34.0, 110, -22),
    "creak_2": ("145721_981371", 55.0, 58.0, 110, -22),
}
LOOPS = {
    "gulls": ("571033_12425327", 0.5, 19.0, 200, -26),
    "cicadas": ("539790_2396346", 4.0, 44.0, 300, -28),
    "market": ("514624_11298770", 2.0, 50.0, 120, -26),
    "wind": ("659004_11673893", 8.0, 50.0, 40, -26),
}


def decode(name: str, start: float, end: float, highpass: int, lufs: int) -> np.ndarray:
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "cut.wav"
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-ss", str(start), "-to", str(end), "-i", str(RAW / f"{name}.mp3"),
                        "-af", f"highpass=f={highpass},loudnorm=I={lufs}:TP=-2", "-ac", "1", "-ar", str(RATE), str(out)], check=True)
        with wave.open(str(out)) as w:
            return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0


def encode(clip: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / "clip.wav"
        with wave.open(str(src), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes((np.clip(clip, -1, 1) * 32767).astype(np.int16).tobytes())
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(src), "-c:a", "libvorbis", "-q:a", "4", str(path)], check=True)


def fade(clip: np.ndarray, seconds: float = 0.03) -> np.ndarray:
    n = min(len(clip) // 4, int(seconds * RATE))
    ramp = np.linspace(0, 1, n)
    clip[:n] *= ramp
    clip[-n:] *= ramp[::-1]
    return clip


def blend_loop(clip: np.ndarray, seconds: float = 2.0) -> np.ndarray:
    """Overlaps the last seconds onto the first with an equal-power crossfade, so the end runs into the start."""
    n = int(seconds * RATE)
    head, body, tail = clip[:n], clip[n:-n], clip[-n:]
    k = np.linspace(0, np.pi / 2, n)
    joined = tail * np.cos(k) + head * np.sin(k)
    return np.concatenate([joined, body])


def main():
    for name, spec in EFFECTS.items():
        encode(fade(decode(*spec), 0.08 if name.startswith("splash") else 0.03), SFX / f"{name}.ogg")
        print("cut", name)
    for name, spec in LOOPS.items():
        encode(blend_loop(decode(*spec)), AMBIENCE / f"{name}.ogg")
        print("looped", name)


if __name__ == "__main__":
    main()
