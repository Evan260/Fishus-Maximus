"""Writes the six place specs read by make_places.py. Kept as a script so the shared wording lives in one place."""
import json
from pathlib import Path

D = Path(__file__).parent
LAND = "seen from the sea, side view, flat straight bottom edge where it meets the sea, no water"
LOW_ENDS = "low at the far left and far right ends"
FAR = "faded by distance and haze, flat straight bottom edge, nothing below the mountains"
WHOLE = "a single object on its own, nothing behind it, empty transparent background, no water, no frame, no border, no scene"
# A piece of the harbour town, so land painted to match it shares the town's palette, light and soft natural rock.
LIKE_TOWN = "tools/art/places/style_land.png"
# The harbour's cape, whose olive scrub, pale limestone and dark pines every row of land is painted and toned to match.
LIKE_CAPE = "game/assets/art/places/harbour/cape.png"
# How each row of land is toned to the cape by tone_land.py: a little more haze the farther back it lies.
FAR_TONE = {"haze": 0.3, "far": True}
MID_TONE = {"haze": 0.14}
NEAR_TONE = {"haze": 0.0}
ROCK = "natural weathered rock with soft rounded shading and no outlines, empty transparent background"
# Land with nothing painted above it, so the game's own drifting sky shows there.
NO_SKY = "natural shapes with soft shading and no outlines, nothing in the sky, no clouds, no sun, empty transparent background"
# A built-up hill painted to the picture's sides gets cut by the taper, so it is asked to stand clear of them.
ALONE = "the hill sloping down to rocks at the water on both sides and ending well inside the picture, empty space on the left and right"


def bands(far, mid, near=None):
    out = [{"band": far, "at": [0, 106], "factor": [0.12, 0.12], "z": -19},
           {"band": mid, "at": [0, 116], "factor": [0.3, 0.3], "z": -17}]
    if near:
        out.append({"band": near, "at": [0, 136], "factor": [0.55, 0.55], "z": -15})
    return out


def far(prompt, w):
    return {"file": "far.png", "prompt": prompt + ", " + FAR, "size": f"{w}x72", "at": [-20, 36], "factor": [0.12, 0.12], "z": -18,
            "land": True, "haze": ["#b4c4cc", 0.35], "tone": FAR_TONE}


def mid(prompts, w, style=None, gap=0):
    out = {"file": "mid.png", "strip": [{"prompt": f"{p}, {LOW_ENDS}, {LAND}", "size": f"{w}x80"} for p in prompts],
           "land": True, "haze": ["#a9bcc4", 0.18], "at": [-16, 38], "factor": [0.3, 0.3], "z": -16, "tone": MID_TONE}
    if style:
        out["style"] = style
    if gap:
        out["gap"] = gap
    return out


def near(prompts, w, h=112, style=None, gap=0):
    out = {"file": "near.png", "strip": [{"prompt": f"{p}, {LOW_ENDS}, {LAND}", "size": f"{w}x{h}"} for p in prompts],
           "land": True, "at": [-16, 136 - h + 2], "factor": [0.55, 0.55], "z": -14, "tone": NEAR_TONE}
    if style:
        out["style"] = style
    if gap:
        out["gap"] = gap
    return out


def floor(sand):
    # Drawn by make_seabed.py in this colour, one smooth strip that joins onto itself along the whole coast.
    return {"sand": sand, "surface": 6}


def bed(pid, file, prompt, size, xs, sink=6, use=None, sway=False):
    """One seabed piece set into the sand at each x, every other one mirrored; it is painted once and reused. A plant
    sways in the water."""
    out = []
    for i, x in enumerate(xs):
        l = {"file": file, "on_bed": x, "sink": sink, "z": -9}
        if i % 2 == 1:
            l["mirror"] = True
        if sway:
            l["sway"] = True
        if i == 0 and not use:
            l["prompt"] = f"{prompt}, {WHOLE}"
            l["size"] = size
        else:
            l["use"] = use or f"places/{pid}/{file}"
        out.append(l)
    return out


def front(name, edge, x, factor=1.6, mirror=False):
    """A dark plant right in front of the view (make_front.py), hanging from its top edge or standing on its bottom one,
    in front of the place x along the coast and sliding faster than the boat."""
    l = {"file": f"{name}.png", "use": f"front/{name}.png", "front": edge, "x": x, "factor": [factor, 1.3], "z": 5}
    if mirror:
        l["mirror"] = True
    return l


specs = {}

p = "harbour"
specs[p] = {
    "width": 1440, "seabed": [[0, 60], [200, 68], [360, 96], [600, 128], [850, 168], [1050, 214], [1250, 262], [1440, 294]],
    "floor": floor("#706a60"),
    "layers": bands("#8fa0a8", "#6f93a0", "#4f8494") + [
        {"file": "far.png", "strip": [{"prompt": f"{p}, {FAR}, {NO_SKY}", "size": "224x72"} for p in (
            "the distant mountains of the Sorrento peninsula across the bay, soft olive green slopes with pale limestone crags",
            "Mount Vesuvius far off across the bay before it ever erupted, one broad flat-topped green mountain with vineyards and woods on its slopes",
            "low distant hills along the far shore of the bay, olive green scrub and a few pale limestone cliffs")],
         "style": LIKE_CAPE, "land": True, "at": [-40, 36], "factor": [0.12, 0.12], "z": -18, "tone": FAR_TONE},
        mid([f"low hills at a middle distance covered in olive scrub and olive groves, umbrella pines along the top, a small white Roman farmhouse with a red tiled roof, pale golden limestone rocks at the water, {NO_SKY}",
             f"a green headland at a middle distance with pale golden limestone cliffs down to the water, dark olive scrub and two umbrella pines on top, {NO_SKY}",
             f"a low hill at a middle distance with a white Roman villa with red tiled roofs among cypresses and umbrella pines, olive scrub on its slopes and pale rocks at the water, {ALONE}, {NO_SKY}"],
            256, style=LIKE_CAPE, gap=32),
        {"file": "town.png", "from": "coast/town.png", "land": True, "at": [-190, 28], "factor": [0.55, 0.55], "z": -14, "tone": {"haze": 0.0, "rock": 0.0}},
        {"file": "cape.png", "prompt": f"a green headland seen from the sea with pale golden limestone cliffs down to the water, grass and scrub on top, two umbrella pines and a small round ancient Roman stone watchtower, {LOW_ENDS}, {LAND}, {ROCK}",
         "size": "256x100", "style": LIKE_TOWN, "land": True, "at": [700, 38], "factor": [0.55, 0.55], "z": -14},
    ] + bed(p, "seagrass.png", "a wide clump of tall green Posidonia seagrass ribbons growing up from the sand", "96x48", [250, 560, 830, 1120], sway=True)
      + bed(p, "tuft.png", "a small tuft of short green seagrass with a few pale stones on the sand", "64x40", [420, 700, 980], sway=True)
      + bed(p, "amphora.png", "a broken ancient clay amphora lying half buried on its side in the sand", "48x32", [480])
      + bed(p, "urchins.png", "two spiny dark purple sea urchins resting on a small pale stone", "48x32", [640, 1200])
      + bed(p, "anchor.png", "an old Roman anchor with a lead stock and a wooden shank lying on the sand, encrusted with weed", "64x48", [940])
      + bed(p, "reef.png", "a big natural rough rounded sea rock with an irregular lumpy outline, covered in red sea fans, orange sponges and green weed", "160x112", [1150], sink=10)
      + bed(p, "boulders.png", "a few big rounded boulders with brown seaweed in dim light, sitting on the sand", "128x64", [1320, 60], sink=8)
      + [{"file": "jetty.png", "use": "places/harbour/jetty.png", "world": [0, -22], "z": -9, "through": True}],

}

p = "rocky_shore"
specs[p] = {
    "width": 1920, "seabed": [[0, 56], [220, 92], [480, 150], [760, 220], [1040, 288], [1380, 350], [1640, 396], [1920, 416]],
    "spots": {"wreck": 1380},
    "floor": floor("#64605a"),
    "layers": bands("#8fa0a8", "#6f93a0", "#4f8494") + [
        far("distant mountains across the bay of Naples, the green cone of Mount Vesuvius in the middle, low hills on both sides", 704),
        mid([f"a row of low green coastal hills at a middle distance with umbrella pines, olive groves and a small white Roman farmhouse, {NO_SKY}",
             f"a wooded headland of pale grey limestone at a middle distance with pines and scrub and rocks down to the water, {NO_SKY}",
             f"gentle green hills at a middle distance with vineyards, cypresses and a small white Roman villa, {NO_SKY}",
             f"a low rocky point of pale limestone at a middle distance with umbrella pines, {ALONE}, {NO_SKY}"],
            256, style=LIKE_TOWN, gap=48),
        near([f"tall pale golden limestone sea cliffs with a dark cave mouth at the waterline, green scrub and umbrella pines on top, {ROCK}",
              f"a rocky headland of weathered pale golden and grey limestone with a small round ancient Roman stone watchtower and pines on top, {ROCK}",
              f"rugged pale limestone sea cliffs with a deep cave at the waterline and wild fig trees growing from the rock, {ROCK}",
              f"a low rocky point of pale limestone with green scrub, a few pines and a small stone fisherman's hut, {ROCK}"],
             256, style=LIKE_TOWN, gap=96),
    ] + bed(p, "rock.png", "an underwater rock with ledges covered in green and brown seaweed, red sea fans and orange sponges, rounded on both sides, sitting on the sand", "160x96", [300, 1100], sink=10)
      + bed(p, "boulders.png", "a pile of big rounded underwater boulders with sea urchins and anemones, sitting on the sand", "128x80", [640, 1620], sink=8)
      + bed(p, "kelp.png", "a clump of tall brown kelp and green seaweed growing from the sand", "64x64", [480, 900, 1250, 1800], sway=True)
      + bed(p, "fans.png", "a few red sea fans and orange sponges on a small rock", "64x48", [820, 1480], sway=True)
      + bed(p, "wreck.png", "the wreck of a small ancient Roman merchant ship lying on the sea floor, broken wooden hull ribs, clay amphorae spilling onto the sand, seaweed", "256x112", [1270], sink=12)
      + [{"file": "stack.png", "prompt": "a tall rock pillar seen from the side, the whole rock from its wide weedy foot to its top: pale weathered limestone with a small pine on top, the lower half covered in green weed and barnacles, no water and no sea drawn anywhere, empty transparent background, natural soft shading, no outlines", "size": "112x208", "style": LIKE_TOWN, "world": [170, -70], "z": -7, "through": True}],
}

p = "lucrine"
specs[p] = {
    "width": 1440, "seabed": [[0, 40], [260, 78], [520, 118], [700, 138], [900, 168], [1160, 212], [1440, 254]],
    "spots": {"oyster_beds": 700},
    "floor": floor("#5c564e"),
    "layers": bands("#93a4a8", "#78a0a0", "#5a8f94") + [
        far("distant low green volcanic hills seen across a lake", 640),
        mid([f"low wooded hills at a middle distance around a lake, dark umbrella pines, oaks and olive scrub, pale rocks at the water, {NO_SKY}",
             f"the low rounded crater rim of Lake Avernus at a middle distance seen from the side, covered in dark woods and olive scrub, {NO_SKY}",
             f"gentle hills at a middle distance with terraced vineyards and a small white Roman villa with a red tiled roof among cypresses and umbrella pines, {ALONE}, {NO_SKY}"],
            256, style=LIKE_CAPE, gap=32),
        near([f"the lakeside at Baiae: a grand ancient Roman bath house with a pale stone dome and white colonnades on a low bank, umbrella pines and olive scrub beside it, {ALONE}, {NO_SKY}",
              f"a low grassy bank by a lake with two small ancient Roman fishermen's cottages of pale stone with red tiled roofs, nets drying on poles, reeds at the water, {ALONE}, {NO_SKY}",
              f"a low rise above a lake with an ancient Roman villa with red tiled roofs and a walled garden, cypresses and umbrella pines, {ALONE}, {NO_SKY}",
              f"the reedy shore of a lake with wooden oyster sheds, a small stone jetty and an umbrella pine on a low grassy bank, {ALONE}, {NO_SKY}"],
             240, style=LIKE_CAPE, gap=32),
    ] + bed(p, "reeds.png", "a clump of green reeds and eelgrass growing up from the mud", "64x64", [110, 380, 1000, 1300], sway=True)
      + bed(p, "oysters.png", "a bed of rough grey oyster shells and blue mussels on the mud", "96x40", [520, 860])
      + bed(p, "basket.png", "an old sunken wicker fish basket lying on the mud", "48x40", [1150])
      + bed(p, "stones.png", "a few round mossy stones with green weed on the mud", "96x48", [250, 1220])
      + [{"file": "oyster_frames.png", "prompt": "an ancient Roman oyster farm seen from the side: a row of wooden posts standing in a lake with ropes hung with clusters of oysters between them, the tops of the posts above the water, the lower parts under the water, the posts reaching down into the mud at the bottom", "size": "192x208", "world": [620, -48], "z": -7, "through": True}],
}

p = "open_bay"
specs[p] = {
    "width": 2400, "seabed": [[0, 140], [400, 220], [800, 300], [1200, 378], [1600, 450], [2000, 520], [2400, 556]],
    "floor": floor("#736d64"),
    "layers": bands("#8fa6b0", "#6f98a8") + [
        far("distant mountains seen from the open sea, the large green cone of Mount Vesuvius with a wisp of cloud, the long rocky Sorrento peninsula on the right", 768),
        # The coast seen across the open bay is far off, so its bare hills are toned as distant land.
        dict(mid(["a distant low coastline seen from the open sea, green hills with small white towns and villas",
                  "a distant low coastline seen from the open sea, wooded hills and a small harbour town"], 544), tone={"haze": 0.14, "far": True}),
    ] + bed(p, "seagrass.png", "", "", [200, 520, 900, 2250], use="places/harbour/seagrass.png", sway=True)
      + bed(p, "fans.png", "a few red and yellow sea fans on a small rock", "64x48", [1300, 1900], sway=True)
      + bed(p, "pinnacle.png", "a tall underwater rock pinnacle rising from the sand, covered in sponges and sea fans, small dark holes", "128x160", [1520], sink=10)
      + bed(p, "boulders.png", "", "", [2080, 1100], sink=8, use="places/rocky_shore/boulders.png")
      + bed(p, "starfish.png", "a single red starfish lying flat, seen from the side", "48x32", [700, 1720]),
}

p = "capri"
specs[p] = {
    "width": 1920, "seabed": [[0, 110], [300, 168], [640, 248], [1000, 330], [1300, 398], [1500, 446], [1720, 488], [1920, 516]],
    "spots": {"deep_cave": 1500},
    "floor": floor("#7e7b74"),
    "layers": bands("#90a8b4", "#6a9cae", "#3f8aa0") + [
        far("the long green mountain ridge of the Sorrento peninsula, soft rounded green and grey-blue slopes, no snow", 704),
        mid(["the steep green slopes of the island of Capri at a middle distance with white ancient Roman villas, terraces and pines",
             "the rocky upper cliffs of Capri with the ruins of an imperial Roman villa on the summit and pines"], 480),
        near([f"towering pale golden limestone sea cliffs with a dark cave mouth at the waterline, olive scrub and umbrella pines on top, {ROCK}",
              f"three tall pale limestone rock stacks standing in a row, scrub and a small pine on the tallest, {ALONE}, {ROCK}",
              f"pale golden limestone sea cliffs with a natural rock arch at the water, olive scrub and umbrella pines on top, {ROCK}",
              f"a steep pale limestone headland with a small white Roman villa among umbrella pines on top, {ALONE}, {ROCK}",
              f"rugged pale limestone cliffs with a sea cave at the waterline and wild fig trees and pines growing from the rock, {ROCK}"],
             240, 128, style=LIKE_CAPE, gap=28),
    ] + bed(p, "white_rock.png", "a pale limestone underwater rock with red coral branches, purple sponges and sea fans, rounded on both sides, sitting on the sand", "160x96", [300, 1050], sink=10)
      + bed(p, "coral.png", "a cluster of bright red Mediterranean coral and white sea fans on a small rock", "64x48", [620, 1720])
      + bed(p, "cave.png", "a huge rough jagged pale limestone sea rock with an irregular natural outline and a dark cave opening in its side, blue light deep inside the opening, sponges and red coral on the rock", "224x160", [1380], sink=12)
      + bed(p, "seagrass.png", "", "", [150, 820], use="places/harbour/seagrass.png", sway=True)

}

p = "misenum"
specs[p] = {
    "width": 2400, "seabed": [[0, 160], [400, 280], [800, 400], [1200, 520], [1600, 640], [2000, 740], [2400, 796]],
    "floor": floor("#5a5651"),
    "layers": bands("#8fa4ae", "#6a94a6", "#4a8296") + [
        far("the distant islands of Procida and Ischia, the high green mountain of Ischia on the right", 768),
        mid([f"the long green headland of Cape Misenum at a middle distance with a small white Roman lighthouse tower and pines, {NO_SKY}",
             f"low green hills of the Phlegraean fields at a middle distance with a few white Roman villas and pines, {NO_SKY}",
             f"a small green hill at a middle distance standing in the sea with the little Roman town of Baiae on its top, white villas with red roofs and a domed bath house among pines, {ALONE}, {NO_SKY}",
             f"a low green wooded point at a middle distance with umbrella pines and a small white villa, {NO_SKY}"],
            256, style=LIKE_TOWN, gap=48),
        near([f"a small hill standing in the sea with the ancient Roman naval harbour town of Misenum on it: warehouses and houses with red tiled roofs climbing to the top, pines between them, a stone quay at its foot in the middle with one moored Roman war galley, first century, {ALONE}, {NO_SKY}",
              f"the steep green slopes of Cape Misenum with a tall white Roman lighthouse on a rocky top, a villa and pines, {NO_SKY}",
              f"a small green hill standing in the sea with white Roman villas among pines and cypresses on it, pale rocks down to the water, {ALONE}, {NO_SKY}",
              f"a rocky shore below the cape with grey limestone cliffs, a sea cave at the waterline and pines on top, {NO_SKY}"],
             256, style=LIKE_TOWN, gap=100),
    ] + bed(p, "column.png", "a toppled ancient white marble column broken in pieces lying on the sea floor, encrusted with weed", "128x48", [900])
      + bed(p, "dark_rock.png", "a dark volcanic underwater rock with pale sea fans and sponges, rounded on both sides, sitting on the sand", "160x96", [400, 1500, 2100], sink=10)
      + bed(p, "seapens.png", "a few tall pale sea pens and a sea star on dark sand", "64x48", [700, 1200, 1800], sway=True)
      + bed(p, "amphorae.png", "a heap of ancient clay amphorae from a sunken cargo half buried in dark sand", "96x48", [1650], sink=8),
}

# What each row of land has along the water, by weight: the cliffs get rocks, the lake reeds, the hills beaches.
SHORES = {
    "harbour": {"far.png": {"beach": 2, "rocks": 1, "bushes": 1, "plain": 2},
                "mid.png": {"beach": 2, "rocks": 2, "bushes": 3, "plain": 1},
                "town.png": {"rocks": 2, "plain": 3},
                "cape.png": {"rocks": 4, "plain": 1}},
    "rocky_shore": {"far.png": {"beach": 2, "rocks": 1, "bushes": 1, "plain": 2},
                    "mid.png": {"beach": 1, "rocks": 3, "bushes": 2},
                    "near.png": {"rocks": 4, "plain": 1}},
    "lucrine": {"far.png": {"reeds": 1, "beach": 1, "bushes": 2, "plain": 2},
                "mid.png": {"reeds": 3, "bushes": 2, "beach": 1},
                "near.png": {"reeds": 3, "beach": 2, "rocks": 1, "plain": 1}},
    "open_bay": {"far.png": {"beach": 1, "rocks": 1, "plain": 2},
                 "mid.png": {"beach": 2, "rocks": 2, "bushes": 2, "plain": 1}},
    "capri": {"far.png": {"rocks": 1, "beach": 1, "plain": 2},
              "mid.png": {"rocks": 3, "bushes": 1, "plain": 1},
              "near.png": {"rocks": 3, "bushes": 1, "plain": 1}},
    "misenum": {"far.png": {"rocks": 1, "beach": 1, "plain": 2},
                "mid.png": {"rocks": 2, "beach": 2, "bushes": 1, "plain": 1},
                "near.png": {"rocks": 3, "plain": 2}},
}
# The plants in front of each place's view, spread along it so the view is seldom without one and the boat passes each.
FRONTS = {
    "harbour": [front("pine_branch", "top", 430), front("oleander", "bottom", 760, 1.7),
                front("olive_branch", "top", 1060, 1.5, True), front("palm", "bottom", 1330)],
    "rocky_shore": [front("pine", "bottom", 520), front("fig_leaves", "top", 880, 1.5),
                    front("palm", "bottom", 1300, 1.7, True), front("pine_branch", "top", 1680, 1.6, True)],
    "lucrine": [front("rushes", "bottom", 360), front("olive_branch", "top", 700, 1.5),
                front("rushes", "bottom", 1020, 1.7, True), front("fig_leaves", "top", 1300, 1.6, True)],
    "open_bay": [front("pine_branch", "top", 520), front("olive_branch", "top", 1280, 1.5, True),
                 front("pine_branch", "top", 2050, 1.7, True)],
    "capri": [front("fig_leaves", "top", 430), front("palm", "bottom", 860),
              front("pine", "bottom", 1320, 1.7, True), front("olive_branch", "top", 1700, 1.5)],
    "misenum": [front("pine_branch", "top", 480), front("oleander", "bottom", 980, 1.6, True),
                front("pine", "bottom", 1560, 1.7), front("olive_branch", "top", 2080, 1.5, True)],
}
for pid, plants in FRONTS.items():
    specs[pid]["layers"] += plants

for pid, files in SHORES.items():
    for layer in specs[pid]["layers"]:
        if layer.get("file") in files and "at" in layer:
            layer["shore"] = files[layer["file"]]

for pid, spec in specs.items():
    (D / f"{pid}.json").write_text(json.dumps(spec, indent=1), encoding="utf-8")
print("wrote", list(specs))
