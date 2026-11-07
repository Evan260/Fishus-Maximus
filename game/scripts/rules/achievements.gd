class_name Achievements
## The achievements, each with one condition read from data/achievements.json, and sent on to Steam when the game
## runs under it.

const CONDITIONS := ["logbook", "chapter", "legend", "legends", "logbook_full", "prize_all", "ponds", "tanks", "stat",
	"moray_earrings", "boat", "denarii", "client"]


static func has_condition(a: Dictionary) -> bool:
	return CONDITIONS.filter(func(k): return a.has(k)).size() == 1


static func find(id: String) -> Dictionary:
	for a in Data.achievements:
		if a["id"] == id:
			return a
	return {}


static func met(id: String, state: Dictionary) -> bool:
	var a := find(id)
	if a.has("logbook"):
		return state["logbook"].size() >= int(a["logbook"])
	if a.has("chapter"):
		return int(state["chapter"]) >= int(a["chapter"])
	if a.has("legend"):
		return state["legends"].has(a["legend"])
	if a.has("legends"):
		return state["legends"].size() >= int(a["legends"])
	if a.has("logbook_full"):
		return _ordinary().all(func(f): return state["logbook"].has(f))
	if a.has("prize_all"):
		return _ordinary().all(func(f): return state["logbook"].has(f) and Catalog.grade(f, float(state["logbook"][f]["best"])) == "prize")
	if a.has("ponds"):
		return state["ponds"].size() >= int(a["ponds"])
	if a.has("tanks"):
		return state["tanks"].filter(func(t): return t["restored"]).size() >= int(a["tanks"])
	if a.has("stat"):
		return int(state["stats"].get(a["stat"], 0)) >= int(a["at_least"])
	if a.has("moray_earrings"):
		return state["ponds"].any(func(p): return p["fish"].any(func(f): return f["fish"] == "moray" and f.get("name", "") != "" and f.get("finery", "") == "earrings"))
	if a.has("boat"):
		return Story.boat_rank(str(state["boat"])) >= Story.boat_rank(a["boat"])
	if a.has("denarii"):
		return int(state["denarii"]) >= int(a["denarii"])
	if a.has("client"):
		var c: Dictionary = Data.clients[a["client"]]
		return int(state["clients"].get(a["client"], 0)) >= c["steps"].size()
	return false


static func _ordinary() -> Array:
	return Data.fish.keys().filter(func(f): return not Data.fish[f]["legend"])


## Earns every achievement newly met and says which; each is earned once.
static func check(state: Dictionary) -> Array:
	var got := []
	for a in Data.achievements:
		if not a["id"] in state["achievements"] and met(a["id"], state):
			state["achievements"].append(a["id"])
			got.append(a["id"])
			if Engine.has_singleton("Steam"):
				var steam := Engine.get_singleton("Steam")
				steam.call("setAchievement", a["id"])
				steam.call("storeStats")
	return got
