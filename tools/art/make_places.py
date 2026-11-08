"""Paints the six places from tools/art/places/<id>.json and writes their layers, floor and seabed into places.json.

Each layer in a spec is one of:
  {"band": colour, ...}                            the sea under a row of land, drawn in code
  {"file", "use": "places/harbour/seagrass.png"}   a picture already painted
  {"file", "prompt", "size", ...}                  one picture
  {"file", "strip": [{"prompt", "size"}, ...], "seam": text, ...}
                                                   pieces joined side by side, each join repainted across, or
                                                   for land, set "gap" pixels of sea apart
A picture or strip with "style": path is painted to match that picture, which keeps it in the look of the land
painted before it far better than words alone.
  {"file", "from": "coast/cape.png", "extend": {"left": text}, ...}
                                                   a copy of a picture, its cut sides painted on outwards
  {"on_bed": x, "sink": n, ...}                    a seabed piece whose bottom is set into the sand at x
A land layer with "shore": {"beach": 2, "rocks": 1, ...} gets a shore of those kinds along its bottom (shore.py), and
one with "tone": {"haze": 0.14, ...} is then brought into the harbour cape's colours (tone_land.py).
Pictures are painted once; delete a file (and its parts) to paint it again. Usage:
  python tools/art/make_places.py [PLACE...] [--place-only]
"""
import json
import math
import subprocess
import sys
import time
import zlib
from pathlib import Path

import numpy as np
from PIL import Image

import places_json
import shore
import tone_land

ROOT = Path(__file__).resolve().parents[2]
SPECS = Path(__file__).with_name("places")
PARTS = SPECS / "parts"
ART = ROOT / "game" / "assets" / "art"
STYLE = "cozy pixel art, soft warm golden afternoon light, gentle shading, no outlines"
SHADOW = np.array([0x14, 0x22, 0x2A], dtype=np.float32)
HOME_Y = -160
VIEW_W = 480


def run(args):
    """Runs one PixelLab command, waiting out the limit on jobs at once and retrying other failures a few times."""
    failures = 0
    while failures < 4:
        try:
            r = subprocess.run([sys.executable, str(Path(__file__).with_name("pixellab.py"))] + args, cwd=ROOT,
                               capture_output=True, text=True, timeout=900)
        except subprocess.TimeoutExpired:
            failures += 1
            continue
        if "cost:" in r.stdout:
            return True
        said = (r.stdout + r.stderr).strip()[-300:]
        if "429" in said:
            time.sleep(25)
            continue
        failures += 1
        print("  retry:", said)
        time.sleep(10)
    return False


def boxed(path: Path) -> bool:
    """True when a picture meant to stand alone came back as a little scene with a background filling its box."""
    a = np.array(Image.open(path).convert("RGBA"))[:, :, 3] > 16
    rows, cols = np.where(a.any(axis=1))[0], np.where(a.any(axis=0))[0]
    if not rows.size:
        return True
    a = a[rows[0]:rows[-1] + 1, cols[0]:cols[-1] + 1]
    return a.mean() > 0.8 or max(a[:, 0].sum(), a[:, -1].sum()) > 0.6 * a.shape[0] or a[0].sum() > 0.6 * a.shape[1]


LIKE = "match this picture's palette, soft shading, warm light and pixel style exactly, with no outlines"


def paint(out: Path, prompt: str, size: str, clear: bool, alone: bool = False, style: str = None):
    if out.exists():
        return True
    out.parent.mkdir(parents=True, exist_ok=True)
    if style:
        args = ["proflash", f"{prompt}, {STYLE}", size, "--out", str(out.relative_to(ROOT)), "--style", style,
                "--style-use", LIKE]
    else:
        args = ["pixen", f"{prompt}, {STYLE}", size, "--out", str(out.relative_to(ROOT)), "--raw", "--view", "side",
                "--outline", "lineless", "--detail", "highly detailed"]
    if clear:
        args.append("--transparent")
    for attempt in range(3):
        ok = run(args)
        if not ok or not alone or not boxed(out):
            break
        print("  boxed, painting again:", out.name)
        out.unlink()
        ok = False
    print(("painted " if ok else "FAILED ") + str(out.relative_to(ROOT)))
    return ok


def inpaint(path: Path, mask: Image.Image, prompt: str, clear: bool):
    mask_path = PARTS / "_mask.png"
    mask.save(mask_path)
    args = ["inpaint", str(path.relative_to(ROOT)), str(mask_path.relative_to(ROOT)), f"{prompt}, {STYLE}",
            "--out", str(path.relative_to(ROOT))]
    if clear:
        args.append("--transparent")
    return run(args)


def seam_mask(size, x, half=24):
    m = Image.new("L", size, 0)
    m.paste(255, (max(0, x - half), 0, min(size[0], x + half), size[1]))
    return m


LOW = 6
SLOPE = 1.6


def land_heights(alpha):
    h = alpha.shape[0]
    has = alpha.any(axis=0)
    return np.where(has, h - np.argmax(alpha, axis=0), 0)


def taper_ends(arr):
    """Makes a row of land end low at both sides: it is cut back to the outermost low point near each end, or where
    there is none, the end is carved into a slope down to the sea."""
    a = arr.copy()
    alpha = a[:, :, 3] > 0
    h, w = alpha.shape
    cols = np.where(alpha.any(axis=0))[0]
    if not cols.size:
        return a
    span = int((cols[-1] - cols[0]) * 0.3)
    for side in ("left", "right"):
        heights = land_heights(a[:, :, 3] > 0)
        end = cols[0] if side == "left" else cols[-1]
        if heights[end] <= LOW:
            continue
        step = 1 if side == "left" else -1
        scan = [end + step * k for k in range(span)]
        low = next((x for x in scan if heights[x] <= LOW), None)
        if low is not None:
            if side == "left":
                a[:, :low, 3] = 0
            else:
                a[:, low + 1:, 3] = 0
            continue
        n = min(48, span)
        inner = heights[end + step * n]
        for t in range(n):
            x = end + step * t
            allowed = int(round(inner * (t / n) ** 0.8))
            a[:h - allowed, x, 3] = 0
    # However each end was made low, the land may rise from it no more steeply than a hillside.
    for side in ("left", "right"):
        cols = np.where((a[:, :, 3] > 0).any(axis=0))[0]
        if not cols.size:
            break
        end = cols[0] if side == "left" else cols[-1]
        step = 1 if side == "left" else -1
        for t in range(span):
            x = end + step * t
            allowed = LOW + int(SLOPE * t)
            if allowed >= h:
                break
            a[:h - allowed, x, 3] = 0
    return a


def fade_top(arr, n=14):
    """Land that runs up to the picture's top edge fades into the sky over its last rows instead of ending on a line."""
    a = arr.astype(np.float32)
    touching = a[0, :, 3] > 0
    for k in range(n):
        a[k, touching, 3] *= k / n
    return a.astype(np.uint8)


def haze(path: Path, colour: str, amount: float):
    im = np.array(Image.open(path).convert("RGBA")).astype(np.float32)
    c = np.array([int(colour[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.float32)
    im[:, :, :3] = im[:, :, :3] * (1 - amount) + c * amount
    Image.fromarray(im.astype(np.uint8)).save(path)


def finish_land(pid, layer, path: Path):
    """Once per picture: tapers a land row's ends and hazes it by its distance."""
    mark = PARTS / pid / f"{path.stem}.finished"
    if mark.exists() or not path.exists():
        return
    arr = np.array(Image.open(path).convert("RGBA"))
    # A strip of land set apart by sea is tapered piece by piece, since its ends would be cut back to the first gap.
    if not layer.get("gap"):
        arr = taper_ends(arr)
    Image.fromarray(fade_top(arr)).save(path)
    if "haze" in layer:
        haze(path, layer["haze"][0], float(layer["haze"][1]))
    mark.parent.mkdir(parents=True, exist_ok=True)
    mark.write_text("done")


def shore_land(pid, layer, path: Path):
    """Once per picture: gives a land row its shore, sized by how far off it is. The picture as it was is kept in
    parts, so deleting the mark shores it again from there."""
    mark = PARTS / pid / f"{path.stem}.shore"
    if mark.exists() or not path.exists():
        return
    inland = PARTS / pid / f"{path.stem}_inland.png"
    mark.parent.mkdir(parents=True, exist_ok=True)
    if not inland.exists():
        Image.open(path).save(inland)
    f = layer["factor"][1]
    scale = 1 if f < 0.2 else 2 if f < 0.45 else 3
    rel = path.relative_to(ART).as_posix()
    shore.shore(Image.open(inland), scale, layer["shore"], zlib.crc32(rel.encode()), layer.get("haze")).save(path)
    mark.write_text("done")
    # A newly shored picture is toned again from itself.
    (PARTS / pid / f"{path.stem}.toned").unlink(missing_ok=True)
    (PARTS / pid / f"{path.stem}_untoned.png").unlink(missing_ok=True)
    print("shored", rel)


def tone(pid, layer, path: Path):
    """Once per picture: brings a row of land into the harbour cape's colours, hazed by its distance (tone_land.py).
    The picture as it was is kept in parts, so deleting the mark tones it again from there."""
    mark = PARTS / pid / f"{path.stem}.toned"
    if mark.exists() or not path.exists():
        return
    before = PARTS / pid / f"{path.stem}_untoned.png"
    mark.parent.mkdir(parents=True, exist_ok=True)
    if not before.exists():
        Image.open(path).save(before)
    t = layer["tone"]
    tone_land.tone(Image.open(before), float(t.get("haze", 0)), float(t.get("rock", 0.8)), far=bool(t.get("far"))).save(path)
    mark.write_text("done")
    print("toned", path.relative_to(ART).as_posix())


def make_strip(pid, layer, out: Path, clear: bool):
    """Paints the pieces and sets them side by side on their bottom edges. Land pieces each end low, so the sea shows
    between them; other strips are repainted across every join so they run on seamlessly."""
    if out.exists():
        return True
    pieces = []
    h = 0
    for i, piece in enumerate(layer["strip"]):
        part = PARTS / pid / f"{out.stem}_{i}.png"
        if not paint(part, piece["prompt"], piece["size"], clear, style=layer.get("style")):
            return False
        im = Image.open(part).convert("RGBA")
        h = max(h, im.height)
        if layer.get("land"):
            # Land painted above clear rows is set down onto the picture's bottom, where it meets the sea.
            im = im.crop((0, 0, im.width, (im.getbbox() or (0, 0, 0, im.height))[3]))
            im = Image.fromarray(taper_ends(np.array(im)))
        pieces.append(im)
    gap = int(layer.get("gap", 0))
    w = sum(p.width for p in pieces) + gap * (len(pieces) - 1)
    joined = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x = 0
    joins = []
    for p in pieces:
        joined.paste(p, (x, h - p.height))
        x += p.width + gap
        joins.append(x)
    work = PARTS / pid / f"{out.stem}_joined.png"
    joined.save(work)
    seam = layer.get("seam", "the scene carries on seamlessly")
    for j in joins[:-1] if not layer.get("land") else []:
        if not inpaint(work, seam_mask(joined.size, j), seam, clear):
            return False
    if layer.get("wrap"):
        im = Image.open(work)
        Image.fromarray(np.roll(np.array(im), im.width // 2, axis=1)).save(work)
        if not inpaint(work, seam_mask(im.size, im.width // 2), seam, clear):
            return False
        im = Image.open(work)
        Image.fromarray(np.roll(np.array(im), -(im.width // 2), axis=1)).save(work)
    out.parent.mkdir(parents=True, exist_ok=True)
    Image.open(work).save(out)
    print("joined", out.relative_to(ROOT))
    return True


PAD = 24


def extend(path: Path, sides: dict, pid: str) -> bool:
    """Widens a picture whose content runs off its edges and paints the missing part in, so the edge ends naturally."""
    pads = {"left": 0, "top": 0}
    for side, prompt in sides.items():
        im = Image.open(path).convert("RGBA")
        w, h = im.size
        grow = {"left": (PAD, 0, 0, 0), "right": (0, 0, PAD, 0), "top": (0, PAD, 0, 0), "bottom": (0, 0, 0, PAD)}[side]
        big = Image.new("RGBA", (w + grow[0] + grow[2], h + grow[1] + grow[3]), (0, 0, 0, 0))
        big.paste(im, (grow[0], grow[1]))
        big.save(path)
        mask = Image.new("L", big.size, 0)
        box = {"left": (0, 0, PAD + 8, big.height - 4), "right": (w - 8, 0, big.width, big.height - 4),
               "top": (0, 0, big.width, PAD + 8), "bottom": (0, h - 8, big.width, big.height)}[side]
        mask.paste(255, box)
        if not inpaint(path, mask, prompt + ", the edge of the picture is empty transparent background", True):
            return False
        pads["left"] += grow[0]
        pads["top"] += grow[1]
        fade_edge(path, side)
    (PARTS / pid / (path.stem.replace("_extended", "") + ".pads.json")).write_text(json.dumps(pads))
    return True


def fade_edge(path: Path, side: str, n: int = 12):
    """Clears whatever still touches an edge after painting, along a curve, as a last resort against a straight cut."""
    im = np.array(Image.open(path).convert("RGBA"))
    a = im[:, :, 3]
    h, w = a.shape
    if side in ("left", "right"):
        cols = range(n) if side == "left" else range(w - 1, w - 1 - n, -1)
        for t, x in enumerate(cols):
            keep = int((h - 4) * (1 - (t / n) ** 0.7))
            a[:keep, x] = 0
    else:
        rows = range(n) if side == "top" else range(h - 1, h - 1 - n, -1)
        for t, y in enumerate(rows):
            a[y, :] = (a[y, :] * (t / n)).astype(np.uint8)
    im[:, :, 3] = a
    Image.fromarray(im).save(path)


def shape_floor(path: Path, surface: int):
    """Clears the water above a gently wavy sand line and darkens the strip into the shadow below it."""
    im = np.array(Image.open(path).convert("RGBA")).astype(np.float32)
    h, w = im.shape[:2]
    xs = np.arange(w)
    wave = surface + np.round(1.5 * np.sin(xs * 2 * math.pi / w * 7) + np.sin(xs * 2 * math.pi / w * 19))
    for x in xs:
        top = int(wave[x])
        im[:top, x, 3] = 0
        im[top:, x, 3] = 255
    for y in range(h):
        k = np.clip((y - surface - 10) / max(1, h - surface - 14), 0, 1) ** 1.3
        im[y, :, :3] = im[y, :, :3] * (1 - k) + SHADOW * k
    Image.fromarray(im.astype(np.uint8)).save(path)


def depth_at(points, x):
    if x <= points[0][0]:
        return points[0][1]
    for a, b in zip(points, points[1:]):
        if x <= b[0]:
            return a[1] + (b[1] - a[1]) * (x - a[0]) / max(0.001, b[0] - a[0])
    return points[-1][1]


def build(pid, place_only=False):
    spec = json.loads((SPECS / f"{pid}.json").read_text(encoding="utf-8"))
    d = ART / "places" / pid
    out_layers = []
    for layer in spec["layers"]:
        layer = dict(layer)
        if "band" in layer:
            out_layers.append(layer)
            continue
        clear = layer.pop("clear", True)
        if "use" in layer:
            rel = layer.pop("use")
        else:
            rel = f"places/{pid}/{layer['file']}" if "/" not in layer["file"] else layer["file"]
            path = ART / rel
            if not place_only:
                if "from" in layer and not path.exists():
                    work = PARTS / pid / f"{path.stem}_extended.png"
                    work.parent.mkdir(parents=True, exist_ok=True)
                    Image.open(ART / layer["from"]).save(work)
                    if extend(work, layer.get("extend", {}), pid):
                        path.parent.mkdir(parents=True, exist_ok=True)
                        Image.open(work).save(path)
                elif "strip" in layer:
                    make_strip(pid, layer, path, clear)
                elif "prompt" in layer:
                    paint(path, layer["prompt"], layer["size"], clear, alone="on_bed" in layer, style=layer.get("style"))
        if layer.get("land") and not place_only:
            finish_land(pid, layer, ART / rel)
        if "shore" in layer and not place_only:
            shore_land(pid, layer, ART / rel)
        if "tone" in layer and not place_only:
            tone(pid, layer, ART / rel)
        for k in ("prompt", "size", "strip", "seam", "wrap", "from", "extend", "land", "haze", "shore", "style", "gap", "tone"):
            layer.pop(k, None)
        layer["file"] = rel
        pads = PARTS / pid / (Path(rel).stem + ".pads.json")
        if pads.exists():
            pad = json.loads(pads.read_text())
            key = "world" if "world" in layer else "at"
            layer[key] = [layer[key][0] - pad["left"], layer[key][1] - pad["top"]]
        if (ART / rel).exists():
            im = Image.open(ART / rel)
            if "on_bed" in layer:
                x = float(layer.pop("on_bed"))
                sink = float(layer.pop("sink", 6))
                bottom = max(depth_at(spec["seabed"], x + k) for k in range(0, im.width, 4)) + sink
                # A picture with clear rows under its painted base is lowered by them, so the base meets the sand.
                margin = im.height - (im.getbbox() or (0, 0, 0, im.height))[3]
                layer["world"] = [round(x), round(bottom - im.height + margin)]
            if "fit" in layer:
                # A row that must reach across the whole place repeats until it does.
                f = layer["factor"][0]
                need = VIEW_W + (spec["width"] - VIEW_W) * f - layer["at"][0]
                layer.pop("fit")
                n = math.ceil(need / im.width)
                if n > 1:
                    layer["repeat"] = n
        out_layers.append(layer)
    floor = dict(spec["floor"])
    floor_rel = f"places/{pid}/floor.png"
    if not place_only and not (ART / floor_rel).exists():
        part = PARTS / pid / "floor_0.png"
        if paint(part, floor["strip"][0]["prompt"], floor["strip"][0]["size"], False):
            # The piece is followed by its own mirror image, so the strip joins onto itself with no seam to repaint.
            piece = Image.open(part).convert("RGBA")
            strip = Image.new("RGBA", (piece.width * 2, piece.height))
            strip.paste(piece, (0, 0))
            strip.paste(piece.transpose(Image.FLIP_LEFT_RIGHT), (piece.width, 0))
            (ART / floor_rel).parent.mkdir(parents=True, exist_ok=True)
            strip.save(ART / floor_rel)
            shape_floor(ART / floor_rel, int(floor.get("surface", 6)))
    places = places_json.load()
    place = next(p for p in places if p["id"] == pid)
    place["layers"] = out_layers
    place["seabed"] = spec["seabed"]
    place["floor"] = {"file": floor_rel, "surface": int(floor.get("surface", 6))}
    place["ground_below"] = spec.get("ground_below", 40)
    if "spots" in spec:
        place["spots"] = spec["spots"]
    places_json.save(places)
    print("placed", pid, len(out_layers), "layers")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    ids = args or [p.stem for p in sorted(SPECS.glob("*.json"))]
    for pid in ids:
        build(pid, "--place-only" in sys.argv)
