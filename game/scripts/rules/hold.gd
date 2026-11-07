class_name Hold
## The boat's hold for dead fish and its live well for live ones, and how fresh the fish in the hold stay.


static func room(state: Dictionary) -> int:
	return int(Data.boats[str(state["boat"])]["hold"]) - state["hold"].size()


static func well_room(state: Dictionary) -> int:
	return int(Data.boats[str(state["boat"])]["well"]) - state["live_well"].size()


static func can_take(state: Dictionary, fish: Dictionary) -> bool:
	return room(state) > 0 or (fish.get("live", false) and well_room(state) > 0)


## Puts a caught fish away: a live one in the well when there is room, otherwise in the hold, where it dies. Says
## where it went, or "full" when there is no room and the player must choose what to let go.
static func add(state: Dictionary, fish: Dictionary) -> String:
	var f := fish.duplicate(true)
	f["fresh"] = float(f.get("fresh", 1.0))
	if f.get("live", false) and well_room(state) > 0:
		state["live_well"].append(f)
		return "well"
	if room(state) > 0:
		f["live"] = false
		state["hold"].append(f)
		return "hold"
	return "full"


## Lets game minutes pass for the fish in the hold: they lose freshness every hour of the day, salted ones keep.
static func freshen(state: Dictionary, minutes: float) -> void:
	var hours := minutes * 24.0 / Clock.minutes_per_day()
	for f in state["hold"]:
		if f.get("salted", false):
			continue
		f["fresh"] = maxf(0.0, float(f["fresh"]) - Data.num("hold.fresh_loss_per_hour", 0.08) * hours)


static func salt(state: Dictionary, index: int) -> void:
	var f: Dictionary = state["hold"][index]
	f["salted"] = true
	f["fresh"] = minf(float(f["fresh"]), Data.num("hold.salted", 0.6))


static func release(state: Dictionary, index: int, from_well := false) -> void:
	var list: Array = state["live_well"] if from_well else state["hold"]
	if index >= 0 and index < list.size():
		list.remove_at(index)
