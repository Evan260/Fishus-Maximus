class_name Weather
## Each day's weather, the same for a given game and day, drawn from the season's mix; storms come only in autumn
## and winter.


static func for_day(seed: int, day: int) -> String:
	var mix: Dictionary = Data.weather.get(Clock.season(day), {"clear": 1})
	var rng := Seeds.rng(seed, "weather", day)
	var total := 0.0
	for k in mix:
		total += float(mix[k])
	var left := rng.randf() * total
	for k in mix:
		left -= float(mix[k])
		if left <= 0.0:
			return k
	return "clear"
