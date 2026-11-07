"""Finds pictures that would show a straight cut on screen. For each place it checks every layer as it is placed: an
edge whose opaque pixels run for more than 6 pixels fails if the camera can ever bring that edge into view and no
later layer of the same depth covers it. Seabed pieces count as covered below the ground shadow, above-water land
counts as covered along its bottom by its sea band, a repeated layer is checked as one long picture, and
tools/art/tiles.txt lists edges that join seamlessly onto a neighbour. Usage: python tools/art/check_edges.py [PLACE...]; exits 1 when anything fails."""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import places_json

ART = Path(__file__).resolve().parents[2] / "game" / "assets" / "art"
TILES = Path(__file__).with_name("tiles.txt")
RUN = 6
LOW_END = 6
SLOPE = 1.6
VIEW = (480, 270)
HOME_Y = -160


def allowed():
    """{file: set of edges} from tiles.txt, where each line is 'file edge [edge...]  # why'."""
    out = {}
    if TILES.exists():
        for line in TILES.read_text(encoding="utf-8").splitlines():
            line = line.split("#")[0].split()
            if line:
                out.setdefault(line[0], set()).update(line[1:])
    return out


def longest_run(mask):
    best = run = 0
    for v in mask:
        run = run + 1 if v else 0
        best = max(best, run)
    return best


def steep_ends(pid, file, a, visible):
    """A row of land that rises from its end like a wall shows where the picture was cut, however low its last column."""
    out = []
    h, w = a.shape
    heights = np.where(a.any(axis=0), h - np.argmax(a, axis=0), 0)
    for side in ("left", "right"):
        if not visible[side]:
            continue
        for t in range(min(80, w // 3)):
            x = t if side == "left" else w - 1 - t
            if heights[x] > LOW_END + SLOPE * t + 10:
                out.append(f"{pid}: {file} {side} end rises like a wall {t} pixels in")
                break
    return out


def depth_at(points, x):
    if x <= points[0][0]:
        return points[0][1]
    for a, b in zip(points, points[1:]):
        if x <= b[0]:
            return a[1] + (b[1] - a[1]) * (x - a[0]) / max(0.001, b[0] - a[0])
    return points[-1][1]


def check_place(place, tiles):
    failures = []
    width, depth = float(place["width"]), float(place["depth"]) + 40
    cam_x_max = max(0.0, width - VIEW[0])
    cam_y_max = max(HOME_Y, depth - VIEW[1])
    layers = [l for l in place.get("layers", []) if "file" in l]
    pictures = []
    for l in layers:
        if not (ART / l["file"]).exists():
            failures.append(f"{place['id']}: {l['file']} is missing")
            continue
        im = Image.open(ART / l["file"]).convert("RGBA")
        if l.get("mirror"):
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        f = l.get("factor", [1, 1])
        at = [l["world"][0], l["world"][1] - HOME_Y] if "world" in l else l["at"]
        alpha = np.array(im)[:, :, 3] > 16
        if int(l.get("repeat", 1)) > 1:
            alpha = np.tile(alpha, (1, int(l["repeat"])))
        # Checked against its painted pixels, so a scene painted inside a clear margin still shows its straight sides.
        rows, cols = np.where(alpha.any(axis=1))[0], np.where(alpha.any(axis=0))[0]
        margin = {"left": False, "right": False, "top": False, "bottom": False}
        if rows.size:
            margin = {"left": cols[0] > 0, "right": cols[-1] < alpha.shape[1] - 1, "top": rows[0] > 0,
                      "bottom": rows[-1] < alpha.shape[0] - 1}
            alpha = alpha[rows[0]:rows[-1] + 1, cols[0]:cols[-1] + 1]
            at = [at[0] + cols[0], at[1] + rows[0]]
        pictures.append((l, alpha, f, at, margin))
    for i, (l, a, f, at, margin) in enumerate(pictures):
        h, w = a.shape
        ok = tiles.get(l["file"], set())
        # Screen x of the picture's left edge runs from at.x (camera at the start) to at.x - cam_x_max * f.
        lo_x, hi_x = at[0] - cam_x_max * f[0], at[0]
        top_y = at[1]
        bottom_y = at[1] + h - (cam_y_max - HOME_Y) * f[1]
        visible = {
            "left": hi_x > 0,
            "right": lo_x + w < VIEW[0],
            "top": top_y > 0,
            "bottom": bottom_y < VIEW[1],
        }
        edges = {"left": a[:, 0], "right": a[:, -1], "top": a[0, :], "bottom": a[-1, :]}
        for edge, mask in edges.items():
            # A rounded thing inside its picture touches its own outline for a short way; a painted box for most of it.
            limit = max(RUN, 0.35 * len(mask)) if margin[edge] else RUN
            if edge in ok or not visible[edge] or longest_run(mask) <= limit:
                continue
            mask = mask.copy()
            if f == [1, 1] or (f[0] == 1 and f[1] == 1):
                wx, wy = at[0], at[1] + HOME_Y
                for k in np.where(mask)[0]:
                    px, py = (wx, wy + k) if edge in ("left", "right") else (wx + k, wy)
                    if edge == "right":
                        px = wx + w - 1
                    if edge == "bottom":
                        py = wy + h - 1
                    # Behind the sea floor the sand itself hides a piece; in front, the ground shadow does.
                    below = 2 if l.get("z", 0) < -8 else place.get("ground_below", 24) - 16
                    if py >= depth_at(place["seabed"], px) + below:
                        mask[k] = False
            if edge == "bottom" and f[1] < 1 and l.get("z", 0) < -10:
                continue
            # A later picture of the same depth drawn over this edge hides it.
            for l2, a2, f2, at2, _m in pictures[i + 1:]:
                if f2 != f or l2.get("z", 0) < l.get("z", 0):
                    continue
                for k in np.where(mask)[0]:
                    sx, sy = (at[0], at[1] + k) if edge in ("left", "right") else (at[0] + k, at[1])
                    if edge == "right":
                        sx = at[0] + w - 1
                    if edge == "bottom":
                        sy = at[1] + h - 1
                    qx, qy = int(sx - at2[0]), int(sy - at2[1])
                    if 0 <= qy < a2.shape[0] and 0 <= qx < a2.shape[1] and a2[qy, qx]:
                        mask[k] = False
            if longest_run(mask) > limit:
                failures.append(f"{place['id']}: {l['file']} {edge} edge shows a cut {longest_run(mask)} pixels long")
        if f[0] < 1 and -20 <= l.get("z", 0) <= -10:
            failures += steep_ends(place["id"], l["file"], a, visible)
    return failures


if __name__ == "__main__":
    wanted = sys.argv[1:]
    tiles = allowed()
    failures = []
    for p in places_json.load():
        if not wanted or p["id"] in wanted:
            failures += check_place(p, tiles)
    print("\n".join(failures) if failures else "no visible cut edges")
    sys.exit(1 if failures else 0)
