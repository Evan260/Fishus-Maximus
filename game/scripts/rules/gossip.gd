class_name Gossip
## What the town says about where fish are biting: a kind you can reach, where, when and on what bait.


static func habit(state: Dictionary, rng: RandomNumberGenerator) -> String:
	var places := Story.reachable(state)
	var kinds := Data.fish.keys().filter(func(id): return not Data.fish[id]["legend"] and "line" in Data.fish[id]["methods"] \
		and Data.fish[id]["places"].any(func(p): return p in places))
	if kinds.is_empty():
		return "The sea is quiet."
	var f: Dictionary = Data.fish[kinds[rng.randi() % kinds.size()]]
	var place: String = f["places"].filter(func(p): return p in places)[0]
	var when := "at night" if int(f["hours"][0]) >= 19 or int(f["hours"][0]) < 4 else ("in the morning" if int(f["hours"][1]) <= 12 else "by day")
	return "%s bite %s in %s, on %s." % [f["name"], when, str(Data.places[place]["name"]).to_lower(), str(Data.bait[f["baits"][0]]["name"]).to_lower()]
