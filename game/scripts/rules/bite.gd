class_name Bite
## Whether a fish takes a bait: only a bait it likes, and the closer the bait the likelier.


## The chance a fish takes the bait when it next looks at it; its first-liked bait is the surest, and rain makes fish
## bolder.
static func chance(fish: String, bait: String, distance: float, weather := "clear") -> float:
	var f: Dictionary = Data.fish.get(fish, {})
	var baits: Array = f.get("baits", [])
	var reach := Data.num("fishing.bite_reach", 40)
	if not bait in baits or distance >= reach:
		return 0.0
	var liking := 0.6 if baits.find(bait) == 0 else 0.45
	var boldness := 1.3 if weather in ["rain", "storm"] else 1.0
	return minf(0.95, liking * (1.0 - maxf(0.0, distance) / reach) * boldness)


static func window() -> float:
	return Data.num("fishing.strike_window", 1.0)
