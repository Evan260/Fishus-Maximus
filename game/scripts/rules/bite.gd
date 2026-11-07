class_name Bite
## Whether a fish takes a bait: only a bait it likes, and the closer the bait the likelier; a fish much smaller than
## the rod is built for is shy of it.


## The chance a fish takes the bait when it next looks at it; its first-liked bait is the surest, and rain makes fish
## bolder. The rod is the one in his hands unless another is named.
static func chance(fish: String, bait: String, distance: float, weather := "clear", rod := "") -> float:
	var f: Dictionary = Data.fish.get(fish, {})
	var baits: Array = f.get("baits", [])
	var reach := Data.num("fishing.bite_reach", 40)
	if not bait in baits or distance >= reach:
		return 0.0
	var liking := 0.6 if baits.find(bait) == 0 else 0.45
	var boldness := 1.3 if weather in ["rain", "storm"] else 1.0
	return minf(0.95, liking * (1.0 - maxf(0.0, distance) / reach) * boldness * rod_fit(fish, rod))


## How much a rod puts a fish off: not at all when the fish is the size it is built for or bigger, and by the share in
## balance.json when the fish is smaller than it is built for.
static func rod_fit(fish: String, rod := "") -> float:
	if rod == "" and not Game.state.is_empty():
		rod = str(Game.state["gear"].get("rod", ""))
	var best: Array = Data.gear.get(rod, {}).get("best", [])
	var size: Array = Data.fish.get(fish, {}).get("pounds", [1.0, 1.0])
	if best.is_empty() or (float(size[0]) + float(size[1])) / 2.0 >= float(best[0]):
		return 1.0
	return Data.num("fishing.rod_too_heavy", 0.5)


static func window() -> float:
	return Data.num("fishing.strike_window", 1.0)
