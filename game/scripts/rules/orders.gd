class_name Orders
## The harbour board: each morning it fills up with orders for fish you can reach, each paying denarii and raising
## your name, and each taken down when its day has passed.


static func board_size(state: Dictionary) -> int:
	return int(Data.num("orders.board", 3)) + int(state["chapter"]) - 1 + (2 if _feast(state) else 0)


## The Saturnalia, when the town orders fish for its feasts.
static func _feast(state: Dictionary) -> bool:
	return "saturnalia" in Events.on(Clock.day_of(float(state["time"])))


static func new_day(state: Dictionary, rng: RandomNumberGenerator) -> void:
	expire(state)
	var places := Story.reachable(state)
	var legends_open := int(state["chapter"]) >= 5
	var season := Clock.season(Clock.day_of(float(state["time"])))
	# Only fish he can catch now: with a way of fishing open and the gear for it, and in their season.
	var ways: Array = Story.unlocks(int(state["chapter"]))["methods"].filter(func(m): return m in ["line", "trap"] \
		or (m == "net" and str(state["gear"].get("net", "")) != "") or (m == "trident" and str(state["gear"].get("lamp", "")) != ""))
	var kinds := Data.fish.keys().filter(func(id): return (not Data.fish[id]["legend"] or (legends_open and not state["legends"].has(id) \
		and _legend_about_today(state, id))) and Data.fish[id]["places"].any(func(p): return p in places) and Data.fish[id]["methods"].any(func(m): return m in ways) \
		and (Data.fish[id]["seasons"].is_empty() or season in Data.fish[id]["seasons"]))
	if kinds.is_empty():
		return
	var today := Clock.day_of(float(state["time"]))
	var tries := 0
	while state["orders"].size() < board_size(state) and tries < 50:
		tries += 1
		var fish: String = Pick.by_rarity(kinds, rng)
		if state["orders"].any(func(o): return o["fish"] == fish):
			continue
		var f: Dictionary = Data.fish[fish]
		var lo := float(f["pounds"][0])
		var hi := float(f["pounds"][1])
		# A small fish's weight is asked to the hundredth, or it would round to nothing or to its very biggest.
		var min_lb := snappedf(lo + (hi - lo) * rng.randf_range(0.05, 0.4), 0.01 if hi < 1.0 else 0.1)
		var catchable_alive: bool = f.get("live", false) and f["methods"].any(func(m): return m in ["line", "trap"])
		var alive: bool = catchable_alive and Hold.well_room(state) + state["live_well"].size() > 0 and rng.randf() < 0.3
		var worth := Catalog.value(fish, min_lb, 1.0)
		var feast := _feast(state)
		state["orders"].append({"fish": fish, "min_pounds": min_lb, "alive": alive, "feast": feast,
			"reward": (int(worth * (2.4 if alive else 1.8)) + 4) * (2 if feast else 1), "reputation": clampi(11 - int(f["rarity"]), 1, 8),
			"due": today + rng.randi_range(0, 2)})


## Whether today brings the weather or the event a legend needs, so one asked for can be caught before it is due.
static func _legend_about_today(state: Dictionary, id: String) -> bool:
	var f: Dictionary = Data.fish[id]
	var today := Clock.day_of(float(state["time"]))
	return (f.get("weather", []).is_empty() or Weather.for_day(int(state["seed"]), today) in f["weather"]) \
		and (f.get("event", null) == null or f["event"] in Events.on(today))


## Whether a caught fish meets a request: the right kind, heavy enough, and alive when it must be.
static func suits(want: Dictionary, fish: Dictionary, from_well: bool) -> bool:
	return fish["fish"] == want["fish"] and float(fish["pounds"]) >= minf(float(want["min_pounds"]), Units.need_pounds(float(want["min_pounds"])) - 0.0001) \
		and (not want.get("alive", false) or from_well)


## Fills an order with the fish found for it by Supply.find.
static func fill_from(state: Dictionary, order_index: int, at: Dictionary) -> bool:
	if order_index < 0 or order_index >= state["orders"].size() or at.is_empty():
		return false
	var o: Dictionary = state["orders"][order_index]
	if Supply.find(state, o) != at:
		return false
	Legends.pay(state, Supply.take(state, at).get("fish", ""))
	state["orders"].remove_at(order_index)
	state["denarii"] = int(state["denarii"]) + int(o["reward"])
	Story.add_reputation(state, int(o["reputation"]))
	state["stats"]["orders"] = int(state["stats"].get("orders", 0)) + 1
	return true


static func fill(state: Dictionary, order_index: int, hold_index: int, from_well := false) -> bool:
	if order_index < 0 or order_index >= state["orders"].size():
		return false
	var list: Array = state["live_well"] if from_well else state["hold"]
	if hold_index < 0 or hold_index >= list.size():
		return false
	var o: Dictionary = state["orders"][order_index]
	if not suits(o, list[hold_index], from_well):
		return false
	Legends.pay(state, list[hold_index]["fish"])
	list.remove_at(hold_index)
	state["orders"].remove_at(order_index)
	state["denarii"] = int(state["denarii"]) + int(o["reward"])
	Story.add_reputation(state, int(o["reputation"]))
	state["stats"]["orders"] = int(state["stats"].get("orders", 0)) + 1
	return true


static func expire(state: Dictionary) -> void:
	var today := Clock.day_of(float(state["time"]))
	state["orders"] = state["orders"].filter(func(o): return int(o["due"]) >= today)
