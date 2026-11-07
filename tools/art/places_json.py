"""Reads and writes game/data/places.json, keeping one line per layer so the file stays readable in a diff."""
import json
from pathlib import Path

PATH = Path(__file__).resolve().parents[2] / "game" / "data" / "places.json"


def load():
    return json.loads(PATH.read_text(encoding="utf-8"))


def save(places):
    out = ["["]
    for i, p in enumerate(places):
        head = ", ".join(f"{json.dumps(k)}: {json.dumps(v)}" for k, v in p.items() if k not in ("layers", "seabed"))
        out.append("\t{" + head + ",")
        out.append("\t\t\"seabed\": " + json.dumps(p.get("seabed", [])) + ",")
        layers = p.get("layers", [])
        if layers:
            out.append("\t\t\"layers\": [")
            out += ["\t\t\t" + json.dumps(l) + ("," if j < len(layers) - 1 else "") for j, l in enumerate(layers)]
            out.append("\t\t]")
        else:
            out.append("\t\t\"layers\": []")
        out.append("\t}" + ("," if i < len(places) - 1 else ""))
    out.append("]")
    PATH.write_text("\n".join(out) + "\n", encoding="utf-8")
