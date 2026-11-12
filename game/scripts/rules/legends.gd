class_name Legends
## The twelve legendary fish: each turns up only at its own place, hours, season, weather and event, and only until
## it is caught, or, when a client's story still asks for it, until it has been sold or handed over once.


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


## When a legend is about, as phrases for "Found %s.": its hours and depth, then its season, weather and event.
static func hints(legend: String) -> Array:
	var f: Dictionary = Data.fish[legend]
	var out := Catalog.habits(legend)
	var seasons := {"spring": "in spring", "summer": "in summer", "autumn": "in autumn", "winter": "in winter"}
	var weathers := {"clear": "in calm weather", "cloudy": "under cloud", "rain": "in the rain", "wind": "in the wind", "storm": "in storms"}
	for s in f["seasons"]:
		out.append(str(TranslationServer.translate(seasons[s])))
	for w in f.get("weather", []):
		out.append(str(TranslationServer.translate(weathers[w])))
	if f.get("event", null) == "tuna_run":
		out.append(str(TranslationServer.translate("during the tuna run")))
	return out


static func clue(legend: String) -> String:
	return str(Data.fish.get(legend, {}).get("clue", ""))


## Whether a client's story still has a step asking for this fish.
static func owed(state: Dictionary, legend: String) -> bool:
	return Data.clients.keys().any(func(c):
		var steps: Array = Data.clients[c]["steps"]
		return steps.slice(int(state["clients"].get(c, 0))).any(func(s): return s["fish"] == legend))


## Whether a legend once caught comes back: only for a client still owed it, before it has ever been sold or handed
## over, and while none is kept in the hold, the well or the pond.
static func still_wanted(state: Dictionary, legend: String) -> bool:
	if paid(state, legend) or not owed(state, legend):
		return false
	var kept: Array = state["hold"] + state["live_well"]
	kept += Ponds.of(state).get("fish", [])
	return not kept.any(func(f): return f["fish"] == legend)


static func paid(state: Dictionary, legend: String) -> bool:
	return legend in state.get("legends_paid", [])


## Notes that a fish leaving for money was a legend, so its big price is had only once.
static func pay(state: Dictionary, fish: String) -> void:
	if Data.fish.get(fish, {}).get("legend", false) and not paid(state, fish):
		state["legends_paid"] = state.get("legends_paid", []) + [fish]


## Whether the market takes this fish: not a legend a client's story still asks for, which is kept back for them.
static func sellable(state: Dictionary, fish: String) -> bool:
	return not Data.fish.get(fish, {}).get("legend", false) or not owed(state, fish)


static func catch(state: Dictionary, legend: String) -> void:
	if not state["legends"].has(legend):
		Story.add_reputation(state, 20)
	state["legends"][legend] = true
