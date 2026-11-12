class_name Ponds
## The estate's one fish pond, cut into the rock by the shore and widened stage by stage as the chapters open the
## estate up. A fish is happy when the pond has its water, every feature it needs, room and a meal today; happy fed
## fish grow, past any size caught wild, and happy pairs have young.

## Room in each of the six pond sites of old saves, by the size they were dug.
const OLD_ROOM := {"small": 6, "large": 14}


## The pond as kept in the game, or an empty dictionary before it is dug.
static func of(state: Dictionary) -> Dictionary:
	return state.get("pond", {})


static func dug(state: Dictionary) -> bool:
	return not of(state).is_empty()


## How far the pond is dug: 0 before it is dug, then 1 up to the number of stages in ponds.json.
static func stage(state: Dictionary) -> int:
	return int(of(state).get("stage", 0))


static func stages() -> int:
	return Data.ponds["stages"].size()


static func room(pond: Dictionary) -> int:
	var at := clampi(int(pond.get("stage", 1)), 1, stages())
	return int(Data.ponds["stages"][at - 1]["room"])


static func room_used(pond: Dictionary) -> int:
	var used := 0
	for f in pond.get("fish", []):
		used += int(Data.fish[f["fish"]].get("pond", {}).get("room", 2))
	return used


## Whether the pond has the water a kind needs: sea water everywhere, and brackish water by the spring once it is led in.
static func has_water(pond: Dictionary, water: String) -> bool:
	return water == "sea" or (water == "brackish" and "spring" in pond.get("features", []))


## From 0 to 1: one share each for the right water, every feature the kind needs, room to swim and being fed today.
static func happiness(pond: Dictionary, fish: Dictionary) -> float:
	var needs: Dictionary = Data.fish[fish["fish"]].get("pond", {"water": "sea", "features": [], "room": 2})
	var shares: int = 3 + needs["features"].size()
	var met := 0
	if has_water(pond, needs["water"]):
		met += 1
	for feature in needs["features"]:
		if feature in pond["features"]:
			met += 1
	if room_used(pond) <= room(pond):
		met += 1
	if fish.get("fed", false):
		met += 1
	return float(met) / shares


## A day in the pond: fed fish grow, happy pairs breed, and everyone is hungry again by morning.
static func day(state: Dictionary, rng: RandomNumberGenerator) -> void:
	var pond := of(state)
	if pond.is_empty():
		return
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
		f["kept_days"] = kept_days(f) + 1
	_breed(pond, rng)
	for f in pond["fish"]:
		f["fed"] = false


static func _breed(pond: Dictionary, _rng: RandomNumberGenerator) -> void:
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
				"age_days": 0, "kept_days": 0, "fed": false})
			breeding[kind] = 0
	pond["breeding"] = breeding


## The furthest stage the pond may be dug to by now, as the chapters open the estate up.
static func allowed(state: Dictionary) -> int:
	return mini(stages(), int(Story.unlocks(int(state["chapter"]))["pond"]))


## What digging the pond, or widening it to its next stage, costs; -1 once it is as wide as it goes.
static func next_price(state: Dictionary) -> int:
	var at := stage(state)
	return int(Data.ponds["stages"][at]["price"]) if at < stages() else -1


## Digs the pond, or widens it by a stage, while the chapter allows and the money is there.
static func widen(state: Dictionary) -> bool:
	var price := next_price(state)
	if price < 0 or stage(state) >= allowed(state) or int(state["denarii"]) < price:
		return false
	state["denarii"] = int(state["denarii"]) - price
	if not dug(state):
		state["pond"] = {"stage": 0, "features": [], "fish": [], "breeding": {}}
	state["pond"]["stage"] = stage(state) + 1
	return true


static func feature(id: String) -> Dictionary:
	for f in Data.ponds["features"]:
		if f["id"] == id:
			return f
	return {}


static func add_feature(state: Dictionary, id: String) -> bool:
	var pond := of(state)
	var f := feature(id)
	if pond.is_empty() or f.is_empty() or id in pond["features"] or int(state["denarii"]) < int(f["price"]):
		return false
	if f.has("needs") and not f["needs"] in pond["features"]:
		return false
	state["denarii"] = int(state["denarii"]) - int(f["price"])
	pond["features"].append(id)
	return true


## Moves a live fish from the boat's well into the pond.
static func stock(state: Dictionary, well_index: int) -> bool:
	if not dug(state) or well_index < 0 or well_index >= state["live_well"].size():
		return false
	var f: Dictionary = state["live_well"][well_index]
	if not Data.fish[f["fish"]].has("pond"):
		return false
	state["live_well"].remove_at(well_index)
	of(state)["fish"].append({"fish": f["fish"], "pounds": float(f["pounds"]), "name": "", "finery": "",
		"age_days": 5, "kept_days": 0, "fed": false})
	return true


static func feed(state: Dictionary) -> void:
	for f in of(state).get("fish", []):
		f["fed"] = true


static func name_fish(state: Dictionary, fish_index: int, name: String) -> void:
	of(state)["fish"][fish_index]["name"] = name.strip_edges().left(16)


static func dress(state: Dictionary, fish_index: int, finery: String) -> bool:
	if not finery in state.get("finery", []):
		return false
	var f: Dictionary = of(state)["fish"][fish_index]
	if f.get("finery", "") != "":
		state["finery"].append(f["finery"])
	state["finery"].erase(finery)
	f["finery"] = finery
	return true


## How many mornings a fish has spent in the pond; one from a save before this was counted is taken as settled.
static func kept_days(f: Dictionary) -> int:
	return int(f.get("kept_days", Data.num("ponds.settled_days", 3)))


## Whether a pond fish has lived there long enough for the villas to pay its keeping bonus.
static func settled(f: Dictionary) -> bool:
	return kept_days(f) >= int(Data.num("ponds.settled_days", 3))


## What the villas at Baiae pay for a pond fish: its worth fresh from the sea, and half again once it is settled.
static func live_price(f: Dictionary) -> int:
	return int(Catalog.value(f["fish"], float(f["pounds"]), 1.0) * (Data.num("ponds.settled_bonus", 1.5) if settled(f) else 1.0))


## Sells a pond fish live to the villas at Baiae for `live_price`.
static func sell_live(state: Dictionary, fish_index: int) -> int:
	var fish: Array = of(state)["fish"]
	var f: Dictionary = fish[fish_index]
	if not Legends.sellable(state, f["fish"]):
		return 0
	var paid := live_price(f)
	Legends.pay(state, f["fish"])
	state["denarii"] = int(state["denarii"]) + paid
	if f.get("finery", "") != "":
		state["finery"].append(f["finery"])
	fish.remove_at(fish_index)
	return paid


## The pond show's judging: each pond fish counts for its size and happiness, more when named and dressed.
static func show_score(state: Dictionary) -> float:
	var pond := of(state)
	var score := 0.0
	for f in pond.get("fish", []):
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


## The one pond an old save's six pond sites become: every fish, every feature, the brackish site's water as the
## spring, and dug as wide as the stage whose room holds all the old ponds' room together.
static func from_sites(sites: Array) -> Dictionary:
	if sites.is_empty():
		return {}
	var pond := {"stage": 1, "features": [], "fish": [], "breeding": {}}
	var old_room := 0
	for p in sites:
		old_room += int(OLD_ROOM.get(str(p.get("size", "small")), 6))
		for id in p.get("features", []):
			if not id in pond["features"]:
				pond["features"].append(id)
		if str(p.get("water", "sea")) == "brackish" and not "spring" in pond["features"]:
			pond["features"].append("spring")
		pond["fish"].append_array(p.get("fish", []))
		var breeding: Dictionary = p.get("breeding", {})
		for kind in breeding:
			pond["breeding"][kind] = maxi(int(pond["breeding"].get(kind, 0)), int(breeding[kind]))
	while pond["stage"] < stages() and room(pond) < old_room:
		pond["stage"] += 1
	return pond
