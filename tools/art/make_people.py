"""Paints the town's people the way Farmus Maximus paints its own: a character in the style of the Farmus dog, then
an eight-frame walk for the townsfolk. Clients stand facing the street. Writes game/assets/art/people/<id>/ with
east.png, south.png and walk_east/frame_NN.png. Usage: python tools/art/make_people.py [ID...]"""
import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "assets" / "art" / "people"
STYLE = "game/assets/art/dogs/hound/east.png"
WALKERS = ["rufus", "prima", "tertius", "secunda", "livia", "decimus"]


def run(args) -> bool:
    failures = 0
    while failures < 4:
        r = subprocess.run([sys.executable, str(Path(__file__).with_name("pixellab.py"))] + args, cwd=ROOT,
                           capture_output=True, text=True, timeout=1500)
        if "cost:" in r.stdout:
            return True
        said = (r.stdout + r.stderr)[-300:]
        if "429" in said:
            time.sleep(30)
            continue
        failures += 1
        print("  retry:", said.strip())
        time.sleep(10)
    return False


def person(pid: str, look: str, walk: bool) -> None:
    out = OUT / pid
    if not (out / "east.png").exists():
        if not run(["character", f"{look}, natural proportions, full body, soft shading, no dark outline", "48x48", "--template", "mannequin", "--style", STYLE,
                    "--out-dir", str(out.relative_to(ROOT))]):
            print("FAILED", pid)
            return
    if walk and not (out / "walk_east" / "frame_00.png").exists():
        cid = json.loads((out / "character.json").read_text())["character_id"]
        if not run(["animate", cid, "walking calmly at a relaxed pace", "--frames", "8", "--direction", "east",
                    "--out-dir", str((out / "walk_east").relative_to(ROOT))]):
            print("FAILED walk", pid)
            return
    print("painted", pid)


def main(ids):
    data = ROOT / "game" / "data"
    folk = {f["id"]: f for f in json.loads((data / "townsfolk.json").read_text(encoding="utf-8"))}
    clients = {c["id"]: c for c in json.loads((data / "clients.json").read_text(encoding="utf-8"))}
    for pid in WALKERS:
        if not ids or pid in ids:
            person(pid, folk[pid]["look"], True)
    for cid, c in clients.items():
        if not ids or cid in ids:
            person(cid, c["look"], False)


if __name__ == "__main__":
    main(sys.argv[1:])
