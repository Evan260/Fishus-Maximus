extends "res://tests/test_case.gd"


func test_events_fall_on_their_days() -> void:
	check("tuna_run" in Events.on(4) and not "tuna_run" in Events.on(10), "the tuna run is in spring")
	check("neptunalia" in Events.on(7 + 3), "the Neptunalia is in summer")
	check("saturnalia" in Events.on(21 + 2), "the Saturnalia in winter")
	check("pond_show" in Events.on(20) and "pond_show" in Events.on(28 + 20), "the pond show on year day 21, every year")
	var dolphins := 0
	for d in 60:
		if "dolphins" in Events.on(d):
			dolphins += 1
	check(dolphins >= 4 and dolphins <= 20, "dolphins on about one day in six")


func test_storms_only_in_autumn_and_winter() -> void:
	var storms := 0
	for d in 28 * 4:
		var w := Weather.for_day(5, d)
		check(w in ["clear", "cloudy", "rain", "wind", "storm"], "a known weather")
		if Clock.season(d) in ["spring", "summer"]:
			check(w != "storm", "no storms in %s (day %d)" % [Clock.season(d), d])
		elif w == "storm":
			storms += 1
	check(storms > 0, "but some in autumn and winter")
	check(Weather.for_day(5, 3) == Weather.for_day(5, 3), "the same day has the same weather")


func test_legends_keep_their_conditions() -> void:
	Game.new_game("Test", "mutt")
	check(not Legends.can_appear("tiberius_mullet", "harbour", 10.0, "autumn", "clear", Game.state), "Tiberius's mullet only at dawn")
	check(Legends.can_appear("tiberius_mullet", "harbour", 5.5, "autumn", "clear", Game.state), "it comes at dawn in autumn")
	check(not Legends.can_appear("tiberius_mullet", "rocky_shore", 5.5, "autumn", "clear", Game.state), "and only in the harbour")
	Game.state["legends"]["tiberius_mullet"] = true
	check(not Legends.can_appear("tiberius_mullet", "harbour", 5.5, "autumn", "clear", Game.state), "a legend is caught once")
	check(Legends.clue("tiberius_mullet") != "", "each has a clue")
	check(not Legends.can_appear("misenum_swordfish", "misenum", 12.0, "autumn", "clear", Game.state) and \
		Legends.can_appear("misenum_swordfish", "misenum", 12.0, "autumn", "storm", Game.state), "the swordfish comes with the storm")


func test_sailing_takes_an_hour_and_needs_the_boat() -> void:
	Game.new_game("Test", "mutt")
	var t: float = Game.state["time"]
	check(not BayMap.sail(Game.state, "lucrine"), "the skiff cannot reach the lake")
	Game.state["chapter"] = 2
	check(BayMap.sail(Game.state, "rocky_shore") and Game.state["place"] == "rocky_shore", "the rocky shore in the skiff")
	check(is_equal_approx(float(Game.state["time"]) - t, Clock.minutes_per_day() / 24.0), "an hour of the day")
