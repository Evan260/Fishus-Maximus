class_name Shop
## Buying from the town: bait by the pack, gear, boats and the goldsmith's finery, each only once its chapter is open.


## Whether the town sells this yet: bait, gear and boats open by chapter; the starting things are never for sale.
static func on_sale(state: Dictionary, id: String) -> bool:
	var open := Story.unlocks(int(state["chapter"]))
	if Data.bait.has(id):
		return Data.bait[id].get("shop", false) and id in open["bait"]
	if Data.boats.has(id):
		return id in open["boats"]
	if Data.gear.has(id):
		return Data.gear[id]["kind"] == "finery" or id in open["gear"]
	return false


static func price(id: String) -> int:
	for table in [Data.bait, Data.gear, Data.boats]:
		if table.has(id):
			return int(table[id]["price"])
	return 0


static func owned(state: Dictionary, id: String) -> bool:
	if Data.boats.has(id):
		return Story.boat_rank(str(state["boat"])) >= Story.boat_rank(id)
	if not Data.gear.has(id):
		return false
	var g: Dictionary = Data.gear[id]
	match str(g["kind"]):
		"trap":
			return int(state["gear"].get("traps", 2)) >= int(g["count"])
		"finery":
			return false
		_:
			# Gear of a kind you already have something better of counts as owned, so it is never sold to you.
			var have: Dictionary = Data.gear.get(str(state["gear"].get(g["kind"], "")), {})
			return not have.is_empty() and int(have["price"]) >= int(g["price"])


static func buy(state: Dictionary, id: String) -> bool:
	if not on_sale(state, id) or owned(state, id) or int(state["denarii"]) < price(id):
		return false
	state["denarii"] = int(state["denarii"]) - price(id)
	if Data.bait.has(id):
		state["bait"][id] = int(state["bait"].get(id, 0)) + int(Data.bait[id]["per"])
	elif Data.boats.has(id):
		state["boat"] = id
	else:
		var g: Dictionary = Data.gear[id]
		match str(g["kind"]):
			"trap":
				state["gear"]["traps"] = int(g["count"])
			"finery":
				state["finery"] = state.get("finery", []) + [id]
			_:
				state["gear"][g["kind"]] = id
	return true
