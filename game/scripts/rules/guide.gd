class_name Guide
## Old Rufus's lessons for a new player, from game/data/guide.json. The first lesson not yet learned is the one he
## gives, and a lesson once learned stays learned.


## The lesson to give now, or nothing when every lesson is learned or the next one must wait, such as the bay map
## until a second place opens.
static func step(state: Dictionary) -> Dictionary:
	var g := progress(state)
	if g.get("finished", false):
		return {}
	for s in Data.guide.get("steps", []):
		if s["id"] in g["done"]:
			continue
		if met(state, s["done"]):
			g["done"].append(s["id"])
			continue
		return s if met(state, s.get("when", {})) else {}
	return {}


## Whether every lesson is learned, or the guide was over before this save had one.
static func finished(state: Dictionary) -> bool:
	var g := progress(state)
	return g.get("finished", false) or Data.guide.get("steps", []).all(func(s): return s["id"] in g["done"])


## Whether he has yet to say goodbye: every lesson learned in this game, and the guide not over before it began.
static func farewell_due(state: Dictionary) -> bool:
	var g := progress(state)
	return not g.get("finished", false) and Data.guide.get("steps", []).all(func(s): return s["id"] in g["done"])


static func lesson(id: String) -> Dictionary:
	for s in Data.guide.get("steps", []):
		if s["id"] == id:
			return s
	return {}


static func met(state: Dictionary, cond: Dictionary) -> bool:
	if cond.has("stat"):
		return int(state["stats"].get(cond["stat"], 0)) >= int(cond.get("at", 1))
	if cond.has("logbook"):
		return state["logbook"].size() >= int(cond["logbook"])
	if cond.has("chapter"):
		return int(state["chapter"]) >= int(cond["chapter"])
	return true


static func progress(state: Dictionary) -> Dictionary:
	if not state.get("guide") is Dictionary:
		state["guide"] = {"done": [], "finished": false}
	return state["guide"]
