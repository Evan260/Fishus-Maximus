class_name Catalog
## Which fish can be found where and when, and what a caught fish weighs, grades and sells for.

const GRADES := [[0.25, "small"], [0.6, "good"], [0.9, "fine"], [1.01, "prize"]]


## Every ordinary fish (no legends) that lives at this place and depth, at this hour, season and weather, and can be
## taken this way, over water `water` pixels deep down to the seabed.
static func available(place: String, depth: float, hour: float, season: String, weather: String, method: String, water := INF) -> Array[String]:
	var out: Array[String] = []
	for id in Data.fish:
		var f: Dictionary = Data.fish[id]
		if f["legend"] or not place in f["places"] or not method in f["methods"]:
			continue
		if depth < float(f["depth"][0]) or depth > float(f["depth"][1]) or water_needed(id) > water:
			continue
		if not in_hours(hour, f["hours"]):
			continue
		if not f["seasons"].is_empty() and not season in f["seasons"]:
			continue
		if not f.get("weather", []).is_empty() and not weather in f["weather"]:
			continue
		out.append(id)
	return out


## How deep the water must be, down to the seabed, for a fish to swim there: the bigger the fish, the deeper.
static func water_needed(id: String) -> float:
	var r: Array = Data.fish[id]["pounds"]
	var rule: Array = Data.value("fishing.deep_water", [40, 30])
	return maxf(0.0, float(rule[0]) + float(rule[1]) * log((float(r[0]) + float(r[1])) / 2.0) / log(2.0))


## True when the hour falls in [from, to), wrapping past midnight when from is later than to.
static func in_hours(hour: float, hours: Array) -> bool:
	var from := float(hours[0])
	var to := float(hours[1])
	if from <= to:
		return hour >= from and hour < to
	return hour >= from or hour < to


## A caught fish's weight: anywhere in its range, but small ones far more often than prize ones.
static func roll_pounds(fish: String, rng: RandomNumberGenerator) -> float:
	var r: Array = Data.fish[fish]["pounds"]
	var k := rng.randf()
	return snappedf(float(r[0]) + (float(r[1]) - float(r[0])) * k * k, 0.01)


static func share(fish: String, pounds: float) -> float:
	var r: Array = Data.fish[fish]["pounds"]
	return clampf((pounds - float(r[0])) / maxf(0.001, float(r[1]) - float(r[0])), 0.0, 1.0)


static func grade(fish: String, pounds: float) -> String:
	var s := share(fish, pounds)
	for g in GRADES:
		if s < g[0]:
			return g[1]
	return "prize"


## What a fish sells for at the market's usual price: by the pound, rising with the square of how big it is for its
## kind, and less the staler it is.
static func value(fish: String, pounds: float, fresh: float) -> int:
	var s := share(fish, pounds)
	var price := float(Data.fish[fish]["price"]) * pounds * (1.0 + Data.num("market.prize_bonus", 3.0) * s * s)
	return maxi(1, roundi(price * lerpf(Data.num("market.stale_floor", 0.4), 1.0, clampf(fresh, 0.0, 1.0))))
