class_name Idle
## The fisherman fishing on his own, with the bait and depth last used: slower than fishing by hand, never a legend
## and never anything alive, and he stops when the hold is full.


static func catches(minutes: float, place: String, depth: float, bait: String, hold_room: int, rng: RandomNumberGenerator,
		hour := 12.0, season := "summer", weather := "clear", water := INF) -> Array:
	var expected := maxf(0.0, minutes) * Data.num("idle.active_rate", 1.0) * Data.num("idle.rate", 0.33)
	var count := int(floorf(expected)) + (1 if rng.randf() < expected - floorf(expected) else 0)
	count = mini(count, maxi(0, hold_room))
	var kinds := Catalog.available(place, depth, hour, season, weather, "line", water)
	var biting := kinds.filter(func(id): return bait in Data.fish[id]["baits"])
	var pool: Array = biting if not biting.is_empty() else Array(kinds)
	var out := []
	if pool.is_empty():
		return out
	for i in count:
		out.append(Pick.catch_of(Pick.by_bite(pool, rng), rng, false))
	return out
