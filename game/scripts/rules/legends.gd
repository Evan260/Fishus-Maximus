class_name Legends
## The twelve legendary fish: each turns up only at its own place, hours, season, weather and event, and only until
## it is caught.


static func can_appear(legend: String, place: String, hour: float, season: String, weather: String, state: Dictionary) -> bool:
	var f: Dictionary = Data.fish.get(legend, {})
	if f.is_empty() or not f["legend"] or (state["legends"].has(legend) and not still_wanted(state, legend)) or not place in f["places"]:
		return false
	if not Catalog.in_hours(hour, f["hours"]):
		return false
	if not f["seasons"].is_empty() and not season in f["seasons"]:
		return false
	if not f.get("weather", []).is_empty() and not weather in f["weather"]:
		return false
	if f.get("event", null) != null and not f["event"] in Events.on(Clock.day_of(float(state["time"]))):
		return false
	return true


## The legends that could be about here and now, by how they are caught.
static func here(place: String, hour: float, season: String, weather: String, state: Dictionary, method: String) -> Array:
	return Data.fish.keys().filter(func(id): return Data.fish[id]["legend"] and method in Data.fish[id]["methods"] \
		and can_appear(id, place, hour, season, weather, state))


static func clue(legend: String) -> String:
	return str(Data.fish.get(legend, {}).get("clue", ""))


## Whether a client's story still has to have a legend caught before, while none is kept in the hold, the well or the pond.
static func still_wanted(state: Dictionary, legend: String) -> bool:
	var wanted := Data.clients.keys().any(func(c):
		var steps: Array = Data.clients[c]["steps"]
		return steps.slice(int(state["clients"].get(c, 0))).any(func(s): return s["fish"] == legend))
	if not wanted:
		return false
	var kept: Array = state["hold"] + state["live_well"]
	kept += Ponds.of(state).get("fish", [])
	return not kept.any(func(f): return f["fish"] == legend)


static func catch(state: Dictionary, legend: String) -> void:
	if not state["legends"].has(legend):
		Story.add_reputation(state, 20)
	state["legends"][legend] = true
