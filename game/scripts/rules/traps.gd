class_name Traps
## Wicker pots on the seabed that fill over the hours with the place's trap fish, alive when their kind can be.


## Every kind a pot can take at this place and depth.
static func kinds(place: String, depth: float) -> Array:
	return Data.fish.keys().filter(func(id): return not Data.fish[id]["legend"] and place in Data.fish[id]["places"] \
		and "trap" in Data.fish[id]["methods"] and depth >= float(Data.fish[id]["depth"][0]) and depth <= float(Data.fish[id]["depth"][1]))


## Lets the hours pass for a pot: one catch every two hours, up to as many as it holds.
static func fill(trap: Dictionary, hours: float, rng: RandomNumberGenerator) -> void:
	trap["hours"] = float(trap.get("hours", 0.0)) + hours
	var wanted := mini(int(trap.get("size", 3)), int(floorf(trap["hours"] / Data.num("traps.hours_per_catch", 2.0))))
	var pool := kinds(str(trap["place"]), float(trap["depth"]))
	if pool.is_empty():
		return
	while trap["catch"].size() < wanted:
		var fish := Pick.by_rarity(pool, rng)
		trap["catch"].append(Pick.catch_of(fish, rng, alive(fish)))


## Whether a pot keeps this kind alive: urchins and the like are not kept in the live well.
static func alive(fish: String) -> bool:
	return bool(Data.fish[fish].get("live", false))


## Empties a pot into the well and the hold as far as there is room, leaving the rest in the pot; says what came out.
static func empty_into(state: Dictionary, trap: Dictionary) -> Array:
	var taken := []
	var left := []
	for c in trap["catch"]:
		if Hold.can_take(state, c):
			Catches.record(state, c["fish"], float(c["pounds"]), bool(c.get("live", true)) and alive(c["fish"]))
			taken.append(c)
		else:
			left.append(c)
	trap["catch"] = left
	# The pot's hours go back to what the catch left in it took, so the baskets just emptied fill again in time.
	trap["hours"] = left.size() * Data.num("traps.hours_per_catch", 2.0)
	return taken


## Brings a pot up: what was in it, and an empty pot that starts filling again.
static func pull(trap: Dictionary) -> Array:
	var got: Array = trap["catch"].duplicate(true)
	trap["catch"] = []
	trap["hours"] = 0.0
	return got
