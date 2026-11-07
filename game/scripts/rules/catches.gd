class_name Catches
## What happens to a fish once it is landed: it goes in the logbook, with the heaviest of each kind kept, and then in
## the well or the hold.


## Records a catch; says whether the kind was new to the logbook and where the fish went ("full" when it needs room).
static func record(state: Dictionary, fish: String, pounds: float, live := false) -> Dictionary:
	var log: Dictionary = state["logbook"]
	var is_new := not log.has(fish)
	var entry: Dictionary = log.get(fish, {"count": 0, "best": 0.0})
	entry["count"] = int(entry["count"]) + 1
	entry["best"] = maxf(float(entry["best"]), pounds)
	log[fish] = entry
	if Data.fish[fish]["legend"]:
		Legends.catch(state, fish)
	var where := Hold.add(state, {"fish": fish, "pounds": pounds, "fresh": 1.0, "live": live})
	return {"new": is_new, "where": where, "fish": {"fish": fish, "pounds": pounds, "fresh": 1.0, "live": live}}
