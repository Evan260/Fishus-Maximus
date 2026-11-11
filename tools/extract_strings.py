"""Collect every player-facing string into game/translations/strings.csv for translators.

The interface wraps most of its text in tr("...") or TranslationServer.translate("..."), and words kept to be read
later in Ui.say("..."). Other text sits in the scripts' own tables, such as the ways of fishing or the dogs' coats, and
Godot translates it where a label or button shows it, so every string literal that reads like words is collected too;
a row nobody sees costs nothing. Names, lines and lessons come from game/data/*.json, and the forms the game builds
from them (a name inside a sentence, a legend's short name) are added as their own rows, since other languages change
the words round them. Existing translations are kept, new strings are added with the English filled in, and rows for
text the game no longer has are dropped.
Usage: python tools/extract_strings.py
"""
import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "game"
OUT = ROOT / "translations" / "strings.csv"
# Fields of game/data/*.json that the player reads. "look" describes a portrait for the art tools and is never shown.
DATA_FIELDS = {"name", "short", "lower", "where", "title", "text", "thanks", "clue", "lines", "praise", "farewell"}
# Fields that are in the data but never shown: a place's own description, the townsfolk's names and the credits.
UNSHOWN = {"places.json": {"text"}, "townsfolk.json": {"name"}, "credits.json": DATA_FIELDS}

LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')
# Lines that pass strings to the engine rather than to the player.
ENGINE_LINE = re.compile(r"Audio\.|AudioServer|get_node|res://|user://|push_|print|has_method|connect\(|add_theme|"
                         r"set_stylebox|set_color|set_constant|set_icon|set_font|set_type_variation|find_children|Engine\.|"
                         r"\.bus\b|path_join|InputMap|is_action|load\(|\.name = |Dev\.|has_node|has_meta|set_meta|get_meta|"
                         r"find_child|Seeds\.rng")
# Names that stay as they are in every language: the game's own, the default names, theme names and buses.
KEEP = {"Fishus Maximus", "FISHUS MAXIMUS", "Steam", "Marcus", "Fidus", "Aurata", "Hortensia", "Heading", "Title",
        "LightHeading", "LightLabel", "MutedLabel", "InfoPanel", "Master", "Window", "Closing", "Hant"}
# Scripts whose text only the developer sees.
DEV_SCRIPTS = {"dev.gd"}


def unescape(s):
    """The string as GDScript reads it: escapes such as \\n and \\" undone, and letters such as ñ left alone."""
    return s.encode("latin-1", "backslashreplace").decode("unicode_escape")


def reads_like_words(s):
    """True for a string a player could read: a capitalised word or phrase, or a phrase of lower-case words, and never
    an engine class name such as VBoxContainer or a pixel pattern such as osffffffffo."""
    if s in KEEP or s != s.strip() or not re.search(r"[a-z]{2,}", s):
        return False
    if re.match(r"[A-Z]", s):
        return " " in s or not re.search(r"[A-Z]", s[1:])
    return " " in s and not re.search(r"[_/]|\.png|\.gd", s)


def from_scripts():
    found = []
    pattern = re.compile(r'\b(?:tr|TranslationServer\.translate|say)\(\s*"((?:[^"\\]|\\.)*)"')
    for f in sorted((ROOT / "scripts").rglob("*.gd")):
        text = f.read_text(encoding="utf-8")
        if f.name in DEV_SCRIPTS:
            continue
        for m in pattern.finditer(text):
            found.append(unescape(m.group(1)))
        for line in text.splitlines():
            if line.lstrip().startswith("#") or ENGINE_LINE.search(line):
                continue
            for m in LITERAL.finditer(line.split(" # ")[0]):
                s = unescape(m.group(1))
                if reads_like_words(s):
                    found.append(s)
    return found


def native_names():
    """The language picker shows each language in its own words, so those names are never translated."""
    text = (ROOT / "scripts" / "ui" / "settings_panel.gd").read_text(encoding="utf-8")
    block = re.search(r"const NATIVE_NAMES := \{(.*?)\}", text, re.S).group(1)
    return set(re.findall(r':\s*"([^"]+)"', block))


def read(name):
    return json.loads((ROOT / "data" / name).read_text(encoding="utf-8"))


def from_data():
    found = []

    def walk(node, fields, key=""):
        if isinstance(node, dict):
            for k, v in node.items():
                walk(v, fields, k)
        elif isinstance(node, list):
            for v in node:
                walk(v, fields, key)
        elif isinstance(node, str) and key in fields:
            found.append(node)

    for f in sorted((ROOT / "data").glob("*.json")):
        walk(json.loads(f.read_text(encoding="utf-8")), DATA_FIELDS - UNSHOWN.get(f.name, set()))
    return [f for f in found if f and f not in KEEP]


def lower_key(entry):
    """A name as it reads inside a sentence, as Data.lower_key makes it."""
    if "lower" in entry:
        return entry["lower"]
    return entry["name"][:1].lower() + entry["name"][1:]


def derived():
    """The forms the game builds from names, and the single lower-case words it looks up: seasons, weather and grades."""
    found = []
    for name in ["fish.json", "bait.json", "places.json", "boats.json"]:
        found += [lower_key(e) for e in read(name)]
    found += [lower_key(g) for g in read("gear.json") if g["kind"] == "finery"]
    found += [lower_key(g) for g in read("garum.json")["grades"]]
    clock = (ROOT / "scripts" / "rules" / "clock.gd").read_text(encoding="utf-8")
    found += re.findall(r'"(\w+)"', re.search(r"const SEASONS.*", clock).group(0))
    found += sorted({w for season in read("weather.json").values() for w in season})
    catalog = (ROOT / "scripts" / "rules" / "catalog.gd").read_text(encoding="utf-8")
    found += re.findall(r'"(\w+)"', re.search(r"const GRADES.*", catalog).group(0))
    # The word typed to delete a game.
    found.append("delete")
    return found


def main():
    rows = {}
    languages = ["en"]
    if OUT.exists():
        with OUT.open(encoding="utf-8", newline="") as f:
            reader = csv.reader(f)
            header = next(reader)
            languages = header[1:]
            for r in reader:
                rows[r[0]] = r[1:]
    wanted = set(from_scripts() + from_data() + derived()) - native_names()
    # A line of only punctuation and spaces, such as "+ ", is put together in code and needs no row.
    wanted = {s for s in wanted if re.search(r"[^\W\d_]|%|\{", s)}
    rows = {k: v for k, v in rows.items() if k in wanted}
    for s in wanted:
        if s not in rows:
            rows[s] = [s] + [""] * (len(languages) - 1)
    OUT.parent.mkdir(exist_ok=True)
    with OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["keys"] + languages)
        for key in sorted(rows):
            w.writerow([key] + rows[key])
    print(f"{len(rows)} strings in {OUT.relative_to(ROOT.parent)} for {', '.join(languages)}")


if __name__ == "__main__":
    main()
