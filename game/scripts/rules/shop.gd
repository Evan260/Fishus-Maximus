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
		# Pots come one more at a time, so each step of the ladder is paid for.
		if Data.gear[id]["kind"] == "trap" and int(Data.gear[id]["count"]) > int(state["gear"].get("traps", 2)) + 1:
			return false
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
			var kind := str(g["kind"])
			var held := str(state["gear"].get("rod_best", state["gear"].get(kind, ""))) if kind == "rod" else str(state["gear"].get(kind, ""))
			var have: Dictionary = Data.gear.get(held, {})
			return not have.is_empty() and int(have["price"]) >= int(g["price"])


static func buy(state: Dictionary, id: String) -> bool:
	if not on_sale(state, id) or owned(state, id) or int(state["denarii"]) < price(id):
		return false
	if Data.bait.has(id) and bait_count(state) + int(Data.bait[id]["per"]) > bait_capacity(state):
		return false
	state["denarii"] = int(state["denarii"]) - price(id)
	state["stats"]["bought"] = int(state["stats"].get("bought", 0)) + 1
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
				# The best rod bought is remembered apart from the one in his hands, which he can swap for a lighter one.
				if g["kind"] == "rod":
					state["gear"]["rod_best"] = id
	return true


## How much bait the box holds: 30 at the start, more in a bigger box.
static func bait_capacity(state: Dictionary) -> int:
	return int(Data.gear.get(str(state["gear"].get("bait_box", "")), {}).get("capacity", 30))


static func bait_count(state: Dictionary) -> int:
	var n := 0
	for b in state["bait"]:
		n += int(state["bait"][b])
	return n
