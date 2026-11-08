class_name Supply
## Finding a fish to hand over for an order or a client's request: for a live one the live well first, then a pond's
## plainest fish before a named or dressed one; for a dead one the hold first, then the well.


## Where a suitable fish is, as {"where": "well"|"pond"|"hold", "index", "pond"}, or an empty dictionary.
static func find(state: Dictionary, want: Dictionary) -> Dictionary:
	var alive: bool = want.get("alive", false)
	if not alive:
		for i in state["hold"].size():
			if Orders.suits(want, state["hold"][i], false):
				return {"where": "hold", "index": i}
	for i in state["live_well"].size():
		if Orders.suits(want, state["live_well"][i], true):
			return {"where": "well", "index": i}
	if not alive:
		return {}
	var pet := {}
	for p in state["ponds"].size():
		var fish: Array = state["ponds"][p]["fish"]
		for i in fish.size():
			if Orders.suits(want, fish[i], true):
				if str(fish[i].get("name", "")) == "" and str(fish[i].get("finery", "")) == "":
					return {"where": "pond", "pond": p, "index": i}
				if pet.is_empty():
					pet = {"where": "pond", "pond": p, "index": i}
	return pet


## Takes the fish from where it was found, or nothing when it is no longer there.
static func take(state: Dictionary, at: Dictionary) -> Dictionary:
	var list: Array
	match str(at.get("where", "")):
		"well":
			list = state["live_well"]
		"hold":
			list = state["hold"]
		"pond":
			if int(at["pond"]) >= state["ponds"].size():
				return {}
			list = state["ponds"][int(at["pond"])]["fish"]
		_:
			return {}
	var i := int(at["index"])
	if i < 0 or i >= list.size():
		return {}
	var f: Dictionary = list[i]
	list.remove_at(i)
	if f.get("finery", "") != "":
		state["finery"].append(f["finery"])
	return f
