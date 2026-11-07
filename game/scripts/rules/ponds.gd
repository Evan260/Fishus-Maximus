class_name Ponds
## The fish ponds cut into the rocks along the shore. A fish is happy when its pond has its water, every feature it
## needs, room and a meal today; happy fed fish grow, past any size caught wild, and happy pairs have young.


static func room(pond: Dictionary) -> int:
	return int(Data.ponds["sizes"][pond["size"]]["room"])


static func room_used(pond: Dictionary) -> int:
	var used := 0
	for f in pond["fish"]:
		used += int(Data.fish[f["fish"]].get("pond", {}).get("room", 2))
	return used


## From 0 to 1: one share each for the right water, every feature the kind needs, room to swim and being fed today.
static func happiness(pond: Dictionary, fish: Dictionary) -> float:
	var needs: Dictionary = Data.fish[fish["fish"]].get("pond", {"water": "sea", "features": [], "room": 2})
	var shares: int = 3 + needs["features"].size()
	var met := 0
	if needs["water"] == pond["water"]:
		met += 1
	for feature in needs["features"]:
		if feature in pond["features"]:
			met += 1
	if room_used(pond) <= room(pond):
		met += 1
	if fish.get("fed", false):
		met += 1
	return float(met) / shares


## A day in every pond: fed fish grow, happy pairs breed, and everyone is hungry again by morning.
static func day(state: Dictionary, rng: RandomNumberGenerator) -> void:
	for pond in state["ponds"]:
		var bonus := 0.0
		for feature in pond["features"]:
			bonus += float(Data.ponds["growth_bonus"].get(feature, 0.0))
		for f in pond["fish"]:
			var kind: Dictionary = Data.fish[f["fish"]]
			var lo := float(kind["pounds"][0])
			var hi := float(kind["pounds"][1])
			if f.get("fed", false):
				var grow := Data.num("ponds.growth", 0.04) * (hi - lo) * happiness(pond, f) * (1.0 + bonus)
				f["pounds"] = snappedf(minf(hi * Data.num("ponds.max_size", 1.3), float(f["pounds"]) + grow), 0.01)
			f["age_days"] = int(f.get("age_days", 0)) + 1
		_breed(pond, rng)
		for f in pond["fish"]:
			f["fed"] = false


static func _breed(pond: Dictionary, rng: RandomNumberGenerator) -> void:
	var breeding: Dictionary = pond.get("breeding", {})
	var kinds := {}
	for f in pond["fish"]:
		if int(f["age_days"]) >= int(Data.num("ponds.adult_days", 5)) and happiness(pond, f) >= Data.num("ponds.breed_happiness", 0.7):
			kinds[f["fish"]] = int(kinds.get(f["fish"], 0)) + 1
	for kind in breeding.keys():
		if int(kinds.get(kind, 0)) < 2:
			breeding.erase(kind)
	for kind in kinds:
		if int(kinds[kind]) < 2:
			continue
		breeding[kind] = int(breeding.get(kind, 0)) + 1
		var need: int = int(Data.fish[kind].get("pond", {}).get("room", 2))
		if breeding[kind] >= int(Data.num("ponds.breed_days", 5)) and room_used(pond) + need <= room(pond):
			pond["fish"].append({"fish": kind, "pounds": float(Data.fish[kind]["pounds"][0]), "name": "", "finery": "",
				"age_days": 0, "fed": false})
			breeding[kind] = 0
	pond["breeding"] = breeding


## How many ponds may be cut by now, as the chapters open the shore up.
static func allowed(state: Dictionary) -> int:
	return int(Story.unlocks(int(state["chapter"]))["ponds"])


static func site_of(state: Dictionary, site: int) -> int:
	for i in state["ponds"].size():
		if int(state["ponds"][i]["site"]) == site:
			return i
	return -1


static func build(state: Dictionary, site: int, size: String) -> bool:
	var price := int(Data.ponds["sizes"][size]["price"])
	if site_of(state, site) >= 0 or state["ponds"].size() >= allowed(state) or int(state["denarii"]) < price:
		return false
	state["denarii"] = int(state["denarii"]) - price
	state["ponds"].append({"site": site, "size": size, "water": Data.ponds["sites"][site]["water"], "features": [], "fish": []})
	return true


static func feature(id: String) -> Dictionary:
	for f in Data.ponds["features"]:
		if f["id"] == id:
			return f
	return {}


static func add_feature(state: Dictionary, index: int, id: String) -> bool:
	var pond: Dictionary = state["ponds"][index]
	var f := feature(id)
	if f.is_empty() or id in pond["features"] or int(state["denarii"]) < int(f["price"]):
		return false
	if f.has("needs") and not f["needs"] in pond["features"]:
		return false
	state["denarii"] = int(state["denarii"]) - int(f["price"])
	pond["features"].append(id)
	return true


## Moves a live fish from the boat's well into a pond.
static func stock(state: Dictionary, index: int, well_index: int) -> bool:
	if well_index < 0 or well_index >= state["live_well"].size():
		return false
	var f: Dictionary = state["live_well"][well_index]
	if not Data.fish[f["fish"]].has("pond"):
		return false
	state["live_well"].remove_at(well_index)
	state["ponds"][index]["fish"].append({"fish": f["fish"], "pounds": float(f["pounds"]), "name": "", "finery": "",
		"age_days": 5, "fed": false})
	return true


static func feed(state: Dictionary, index: int) -> void:
	for f in state["ponds"][index]["fish"]:
		f["fed"] = true


static func name_fish(state: Dictionary, index: int, fish_index: int, name: String) -> void:
	state["ponds"][index]["fish"][fish_index]["name"] = name.strip_edges().left(16)


static func dress(state: Dictionary, index: int, fish_index: int, finery: String) -> bool:
	if not finery in state.get("finery", []):
		return false
	var f: Dictionary = state["ponds"][index]["fish"][fish_index]
	if f.get("finery", "") != "":
		state["finery"].append(f["finery"])
	state["finery"].erase(finery)
	f["finery"] = finery
	return true


## Sells a pond fish live to the villas at Baiae, for half again its worth fresh from the sea.
static func sell_live(state: Dictionary, index: int, fish_index: int) -> int:
	var f: Dictionary = state["ponds"][index]["fish"][fish_index]
	var paid := int(Catalog.value(f["fish"], float(f["pounds"]), 1.0) * 1.5)
	state["denarii"] = int(state["denarii"]) + paid
	if f.get("finery", "") != "":
		state["finery"].append(f["finery"])
	state["ponds"][index]["fish"].remove_at(fish_index)
	return paid


## The pond show's judging: each pond fish counts for its size and happiness, more when named and dressed.
static func show_score(state: Dictionary) -> float:
	var score := 0.0
	for pond in state["ponds"]:
		for f in pond["fish"]:
			var s := Catalog.share(f["fish"], float(f["pounds"]))
			score += (2.0 + 10.0 * s) * (0.5 + happiness(pond, f)) * (1.3 if f.get("name", "") != "" else 1.0) \
				* (1.3 if f.get("finery", "") != "" else 1.0)
	return snappedf(score, 0.1)


## The year's show against the rival widow's ponds; says what you won.
static func show(state: Dictionary) -> Dictionary:
	var year := int(float(state["time"]) / (Clock.minutes_per_day() * int(Data.num("time.season_days", 7)) * 4))
	var rivals: Array = Data.ponds["show"]["rival"]
	var bar := float(rivals[mini(year, rivals.size() - 1)])
	var score := show_score(state)
	var won := score > bar
	var prize := int(Data.ponds["show"]["prize"][mini(year, rivals.size() - 1)]) if won else 0
	if won:
		state["denarii"] = int(state["denarii"]) + prize
		Story.add_reputation(state, int(Data.ponds["show"]["reputation"]))
		state["stats"]["shows_won"] = int(state["stats"].get("shows_won", 0)) + 1
	return {"score": score, "bar": bar, "won": won, "prize": prize}
