class_name World
## Time passing for everything at once: the pots fill, the hold's fish go off, and each new morning the market
## recovers, the board fills, whatever is still in the live well dies into the hold, the ponds and tanks have their
## day, and on the year's show day the ponds are judged.


static func advance(state: Dictionary, minutes: float, rng: RandomNumberGenerator) -> void:
	var left := maxf(0.0, minutes)
	# A long stretch is lived a day at a time, so each morning comes on its own day and the pots fill between them.
	while left > 0.0:
		var t := float(state["time"])
		var day := Clock.day_of(t)
		var step := minf(left, (day + 1) * Clock.minutes_per_day() - t)
		_pass(state, step, rng)
		left -= step
		if Clock.day_of(float(state["time"])) > day:
			new_day(state, rng)


static func _pass(state: Dictionary, minutes: float, rng: RandomNumberGenerator) -> void:
	var start := float(state["time"])
	state["time"] = start + minutes
	var hours := minutes * 24.0 / Clock.minutes_per_day()
	var season := Clock.season(Clock.day_of(float(state["time"])))
	for t in state["traps"]:
		Traps.fill(t, hours, rng)
		_trap_legend(state, t, start, minutes, season, rng)
	Hold.freshen(state, minutes)
	if state.get("_ashore", false):
		Helpers.fish(state, minutes, rng)
	Rescue.check(state)


static func new_day(state: Dictionary, rng: RandomNumberGenerator) -> void:
	Market.new_day(state)
	var died := 0
	for f in state["live_well"]:
		f["live"] = false
		f["fresh"] = 0.7
		if Hold.room(state) > 0:
			state["hold"].append(f)
		else:
			died += 1
	state["live_well"] = []
	if died > 0:
		state["_lost"] = died
	var day := Clock.day_of(float(state["time"]))
	state["weather"] = Weather.for_day(int(state["seed"]), day)
	# The show judges the ponds as they stood last evening, before the night makes the fish hungry again.
	if "pond_show" in Events.on(day) and not state["ponds"].is_empty():
		state["_show"] = Ponds.show(state)
	Orders.new_day(state, rng)
	Ponds.day(state, rng)
	Garum.day(state)
	# The helpers work once the night is over, so what they feed and stir counts for the day ahead.
	Helpers.morning(state)


## A legend that is caught in pots may wander into one at its depth baited with what it likes, while its hours last.
## A long stretch, such as a night slept through, is taken an hour at a time, so a night legend still has its night.
static func _trap_legend(state: Dictionary, trap: Dictionary, start: float, minutes: float, season: String, rng: RandomNumberGenerator) -> void:
	var hours := minutes * 24.0 / Clock.minutes_per_day()
	var slices := maxi(1, ceili(hours))
	for k in slices:
		if trap["catch"].size() >= int(trap.get("size", 3)):
			return
		var hour := Clock.hour(start + (k + 0.5) * minutes / slices)
		for id in Legends.here(str(trap["place"]), hour, season, str(state.get("weather", "clear")), state, "trap"):
			var depth: Array = Data.fish[id]["depth"]
			if float(trap["depth"]) < float(depth[0]) or float(trap["depth"]) > float(depth[1]):
				continue
			if str(trap.get("bait", "")) in Data.fish[id]["baits"] and rng.randf() < 0.08 * hours / slices \
					and not state["traps"].any(func(t): return t["catch"].any(func(c): return c["fish"] == id)):
				trap["catch"].append(Pick.catch_of(id, rng, true))


## Goes to bed in town and wakes at the next dawn, with everything that happens overnight.
static func sleep(state: Dictionary, rng: RandomNumberGenerator) -> void:
	var t := float(state["time"])
	advance(state, (Clock.day_of(t) + 1) * Clock.minutes_per_day() - t, rng)
