class_name World
## Time passing for everything at once: the pots fill, the hold's fish go off, and each new morning the market
## recovers, the board fills, whatever is still in the live well dies into the hold, the pond and tanks have their
## day, and on the year's show day the pond is judged.


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
	_judge_contest(state)
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
	# The show judges the pond as it stood last evening, before the night makes the fish hungry again.
	if "pond_show" in Events.on(day) and Ponds.dug(state):
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


## At noon on its day the Neptunalia is judged against the best of the town's fishermen, wherever you are by then,
## leaving word of it in `_contest` to be told.
static func _judge_contest(state: Dictionary) -> void:
	if not state.has("contest") or state["contest"]["done"]:
		return
	var c: Dictionary = state["contest"]
	var t := float(state["time"])
	if Clock.day_of(t) < int(c["day"]) or (Clock.day_of(t) == int(c["day"]) and Clock.hour(t) < 12.0):
		return
	c["done"] = true
	var bar := contest_bar(int(state["chapter"]))
	var won := float(c["best"]) > bar
	var prize := 40 * int(state["chapter"]) if won else 0
	if won:
		state["denarii"] = int(state["denarii"]) + prize
		Story.add_reputation(state, 10)
		state["stats"]["neptunalia_won"] = int(state["stats"].get("neptunalia_won", 0)) + 1
	state["_contest"] = {"won": won, "pounds": float(c["best"]) if won else bar + 0.4, "fish": str(c["fish"]), "prize": prize}


## The town's best catch at the Neptunalia, rising with the chapter but never past a share of the heaviest fish the
## harbour gives on a line in the contest's hours, so it can always be beaten.
static func contest_bar(chapter: int) -> float:
	var heaviest := 0.0
	for hour in range(int(CoastEvents.CONTEST_HOURS[0]), int(CoastEvents.CONTEST_HOURS[1])):
		for depth in range(0, int(Data.places["harbour"]["depth"]), 10):
			for id in Catalog.available("harbour", float(depth), float(hour), "summer", "clear", "line"):
				heaviest = maxf(heaviest, float(Data.fish[id]["pounds"][1]))
	return minf(Data.num("contest.bar", 2.5) + chapter * Data.num("contest.bar_per_chapter", 1.5), heaviest * Data.num("contest.most", 0.75))


## Goes to bed in town and wakes at the next dawn, with everything that happens overnight.
static func sleep(state: Dictionary, rng: RandomNumberGenerator) -> void:
	var t := float(state["time"])
	advance(state, (Clock.day_of(t) + 1) * Clock.minutes_per_day() - t, rng)
