class_name Rescue
## Old Rufus's help for a player left with no bait, too little money for any and nothing to sell, as Uncle Marcus helps
## in Farmus Maximus: a pot of worms from his garden, so nobody is ever stuck. In ordinary play this never happens.


static func stranded(state: Dictionary) -> bool:
	if state["bait"].values().any(func(n): return int(n) > 0):
		return false
	if not state["hold"].is_empty() or not state["live_well"].is_empty():
		return false
	var cheapest := INF
	for id in Data.bait:
		if Shop.on_sale(state, id):
			cheapest = minf(cheapest, float(Shop.price(id)))
	return float(state["denarii"]) < cheapest


## Gives a stranded player worms to fish with again, and leaves word of it for the screen to tell.
static func check(state: Dictionary) -> void:
	if not stranded(state):
		return
	var worms := int(Data.num("start.rescue_worms", 15))
	state["bait"]["worm"] = worms
	state["current_bait"] = "worm"
	state["_rescued"] = worms
