class_name Market
## The fish market: a fish's price is its worth by kind, size and freshness, times the day's demand for that kind,
## which falls with each one sold and climbs back overnight.


static func demand(state: Dictionary, fish: String) -> float:
	return float(state["market"].get(fish, 1.0))


static func price(state: Dictionary, fish: String, pounds: float, fresh: float) -> int:
	return maxi(1, int(roundf(Catalog.value(fish, pounds, fresh) * demand(state, fish))))


## Sells the fish in that basket of the hold and says what it fetched.
static func sell(state: Dictionary, index: int) -> int:
	var f: Dictionary = state["hold"][index]
	var paid := price(state, f["fish"], float(f["pounds"]), float(f.get("fresh", 1.0)))
	state["denarii"] = int(state["denarii"]) + paid
	state["market"][f["fish"]] = maxf(Data.num("market.floor", 0.4), demand(state, f["fish"]) - Data.num("market.drop", 0.08))
	state["hold"].remove_at(index)
	state["stats"]["sold"] = int(state["stats"].get("sold", 0)) + 1
	return paid


static func new_day(state: Dictionary) -> void:
	for k in state["market"].keys():
		state["market"][k] = minf(1.0, float(state["market"][k]) + Data.num("market.recover", 0.3))
		if state["market"][k] >= 1.0:
			state["market"].erase(k)
