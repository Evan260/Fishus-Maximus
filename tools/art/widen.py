"""Paints a screen's picture on past its edges, so a window of another shape shows more of the same place rather than
a mirrored or stretched copy. The picture is set in a canvas `margin` pixels larger on every side, its edge colours
carried out as a hint, and the frame round it is painted with PixelLab a corner at a time, each part running a few
pixels into the old picture and painted in a full 256 pixel tile, so it sees plenty of the picture it carries on. A
canvas up to 512 by 512 is four tiles. Progress is kept beside the work picture, so a run that stops picks up where it
left off. Used by make_town.py."""
import json
import subprocess
import sys
import time
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def run(args):
    failures = 0
    while failures < 4:
        r = subprocess.run([sys.executable, str(Path(__file__).with_name("pixellab.py"))] + args, cwd=ROOT,
                           capture_output=True, text=True, timeout=900)
        if "cost:" in r.stdout:
            print(" ", r.stdout.strip().splitlines()[-1])
            return True
        said = (r.stdout + r.stderr)[-300:]
        if "429" in said:
            time.sleep(25)
            continue
        failures += 1
        print("  retry:", said.strip())
        time.sleep(10)
    return False


def canvas(arr: np.ndarray, margin) -> np.ndarray:
    """The picture in the middle of a canvas `margin` larger on each side, its edge colours carried outwards and
    softened, since streaks of colour are painted back as stripes."""
    mx, my = margin
    out = cv2.copyMakeBorder(arr, my, my, mx, mx, cv2.BORDER_REPLICATE)
    soft = cv2.blur(out, (31, 31))
    soft[my:my + arr.shape[0], mx:mx + arr.shape[1]] = arr
    return soft


def widen(arr: np.ndarray, work: Path, sides: dict, margin, style: str, paint=True) -> np.ndarray:
    """The picture painted on past its edges. `sides` maps a name to (what is painted there, boxes), each box in the
    old picture's own pixels, so a band past its left edge starts at -margin; each side's boxes lie within one 256 by
    256 tile. Writes `work` and `work`.json as it goes."""
    done_path = work.with_suffix(".json")
    done = json.loads(done_path.read_text()) if done_path.exists() else []
    hint = canvas(arr, margin)
    if not work.exists():
        Image.fromarray(hint).save(work)
    mx, my = margin
    for side, (prompt, boxes) in sides.items():
        if side in done:
            continue
        size = Image.open(work).size
        mask = Image.new("L", size, 0)
        for x0, y0, x1, y1 in boxes:
            mask.paste(255, (x0 + mx, y0 + my, x1 + mx, y1 + my))
        mask_path = work.with_name(f"{work.stem}_{side}_mask.png")
        mask.save(mask_path)
        # A side painted again starts from the hint rather than from what came out wrong before.
        start = Image.open(work).convert("RGBA")
        start.paste(Image.fromarray(hint), (0, 0), mask)
        start.save(work)
        if not paint or not run(["inpaint", str(work.relative_to(ROOT)), str(mask_path.relative_to(ROOT)),
                                 f"{prompt}, {style}", "--out", str(work.relative_to(ROOT)), "--tile", "256x256"]):
            print("not painted past the", side, "edge")
            continue
        done.append(side)
        done_path.write_text(json.dumps(done), newline="\n")
        print("painted past the", side, "edge")
    out = np.array(Image.open(work).convert("RGBA"))
    # PixelLab can draw a grey line along a tile's outer side, which a window as wide as the picture would show.
    for side in done:
        mask = np.array(Image.open(work.with_name(f"{work.stem}_{side}_mask.png"))) > 0
        for edge, inner in (((slice(None), 0), (slice(None), 1)), ((slice(None), -1), (slice(None), -2)),
                            ((0, slice(None)), (1, slice(None))), ((-1, slice(None)), (-2, slice(None)))):
            line = out[edge]
            line[mask[edge]] = out[inner][mask[edge]]
    return out
