extends "res://tests/test_case.gd"
## Hake off Cape Misenum: found deep down by day and by night, never crowding the screen, quick to take a sardine strip
## let down to them, and the tips and the logbook say where to find them.


func _clear() -> void:
	for c in Nav.ui.get_children():
		c.free()


func _misenum(hour: float) -> Node:
	_clear()
	Game.max_state()
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "misenum"})
	var sw: Swimmers = s.get("swimmers")
	sw.hour = hour
	return s


func _empty(sw: Swimmers) -> void:
	for f in sw.fish:
		f["sprite"].free()
	sw.fish = []


func test_hake_are_found_deep_down_by_day_and_by_night() -> void:
	for hour in [10.0, 22.0]:
		check("hake" in Catalog.available("misenum", 400.0, hour, "spring", "clear", "line"), "hake swim deep at %d o'clock" % hour)
		check(not "hake" in Catalog.available("misenum", 100.0, hour, "spring", "clear", "line"), "but not up near the surface at %d" % hour)
	check(Catalog.habits("hake") == ["deep down"], "so the game says they are found deep down, %s" % [Catalog.habits("hake")])
	check(Catalog.habits("conger") == ["at night", "deep down"], "and a conger at night, deep down")
	check(Catalog.habits("bonito") == ["by day"], "and a bonito by day, %s" % [Catalog.habits("bonito")])
	check(Catalog.habits("garfish") == ["near the surface"] or Catalog.habits("garfish") == ["by day", "near the surface"], "and a garfish near the surface, %s" % [Catalog.habits("garfish")])


func test_no_kind_crowds_the_screen() -> void:
	for hour in [10.0, 22.0]:
		for y in [40.0, 300.0]:
			var s := _misenum(hour)
			var sw: Swimmers = s.get("swimmers")
			for seed in [1, 2, 3]:
				_empty(sw)
				sw._rng.seed = seed
				sw.cam = Vector2(1200, y)
				sw.populate()
				for i in 1200:
					sw.step(0.1, null, "")
					if i % 50 == 0:
						var near: Array = sw._near_leaders()
						for kind in Data.fish:
							var groups := near.filter(func(f): return f["id"] == kind).size()
							var most := Swimmers.MOST_SHOALS if Data.fish[kind].get("shoal", false) else Swimmers.MOST_SINGLES
							check(groups <= most, "%s at %d o'clock, %d deep: %d groups of %s near the camera, at most %d" % [seed, hour, y, groups, kind, most])
			_clear()
			s.free()


## With a rod that suits its size, as the rod's tip advises.
func test_a_hake_takes_a_sardine_strip_let_down_to_it() -> void:
	for hour in [10.0, 22.0]:
		var s := _misenum(hour)
		Game.state["gear"]["rod"] = "yew_rod"
		var sw: Swimmers = s.get("swimmers")
		sw.cam = Vector2(1300, 300)
		var hake := {}
		for seed in 200:
			_empty(sw)
			sw._rng.seed = seed
			sw._spawn(true)
			if not sw.fish.is_empty() and sw.fish[0]["id"] == "hake":
				hake = sw.fish[0]
				break
		check(not hake.is_empty(), "a hake swims at %d o'clock" % hour)
		if hake.is_empty():
			s.free()
			continue
		var bites := [0.0]
		var t := [0.0]
		sw.bit.connect(func(f): bites[0] = t[0])
		# The bait hangs a little ahead of the hake, at the depth it swims.
		var bait: Vector2 = hake["pos"] + Vector2(50.0 * float(hake["heading"]), 0.0)
		for i in 600:
			t[0] = i * 0.1
			sw.step(0.1, bait, "sardine_strip")
			if bites[0] > 0.0:
				break
		check(bites[0] > 0.0 and bites[0] < 60.0, "at %d o'clock it bites within a minute, at %s seconds" % [hour, bites[0]])
		_clear()
		s.free()


func test_the_sardine_strip_tip_says_where_its_fish_are() -> void:
	var tip := TacklePanel.bait_tip("sardine_strip", "misenum")
	check("hake (deep down)" in tip, "the sardine strip's tip says hake are deep down, %s" % tip)
	check("conger eel (at night, deep down)" in tip, "and congers come at night, %s" % tip)


func test_the_logbook_says_where_a_fish_not_yet_caught_is_found() -> void:
	_clear()
	Game.new_game("Test", "mutt")
	var at: int = LogbookPanel._sections().find("misenum")
	LogbookPanel.section = at
	LogbookPanel.selected = "hake"
	LogbookPanel.open(at)
	var words: Array = Nav.ui.get_node("Window").find_children("*", "Label", true, false).map(func(l): return l.text)
	check("Found deep down." in words, "the hake's page says it is found deep down, %s" % [words])
	LogbookPanel.selected = ""
	_clear()
