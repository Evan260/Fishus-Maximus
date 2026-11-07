extends "res://tests/test_case.gd"
## The morning review's findings, each pinned by a test.


func test_a_message_shows_above_a_window_opened_after_it() -> void:
	Toast.say("The bait box is full.")
	var list := Ui.window("The netmaker", 320, 210)
	var box: Control = Toast._box
	var frame: Control = list
	while frame.get_parent() != Nav.ui:
		frame = frame.get_parent()
	check(box.z_index > frame.z_index, "the message is drawn over the window")
	Ui.close_window()
	for c in Nav.ui.get_children():
		c.free()


func test_leaving_the_coast_stops_him_fishing_on_his_own() -> void:
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.add_child(s)
	s.enter({"place": "harbour"})
	s.methods.set_idle(true)
	s.prepare_to_leave()
	check(not Game.state.has("idle"), "no fish are caught for him once he has gone")
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func test_the_town_says_good_morning_after_a_night_at_the_inn() -> void:
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/town/town_screen.gd").new()
	Nav.add_child(s)
	s.enter({"slept": true})
	var box: Control = Toast._box
	check(is_instance_valid(box) and box.get_children().any(func(l): return "dawn" in l.text), "the message comes with the new morning")
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func test_an_old_save_keeps_the_quality_of_every_grade_in_store() -> void:
	Game.new_game("Test", "mutt")
	Game.state["garum_quality"] = 0.9
	Game.state["garum"] = {"garum": 3, "muria": 2}
	Game.state["tanks"][0] = {"restored": true, "fish": {"sardine": 10.0}, "pounds": 10.0, "days": 4, "quality": 0.5, "stirred": false}
	var g := Garum.grade(Game.state["tanks"][0])
	Garum.take(Game.state, 0)
	var other := "garum" if g != "garum" else "muria"
	check(is_equal_approx(Garum.quality(Game.state, other), 0.9), "the %s already bottled keeps its quality" % other)


func test_a_sail_takes_an_hour_on_the_clock_by_day_and_by_night() -> void:
	for start in [8.0, 21.0]:
		Game.new_game("Test", "mutt")
		Game.state["chapter"] = 2
		Game.state["weather"] = "clear"
		while absf(Clock.hour(float(Game.state["time"])) - start) > 0.05:
			Game.state["time"] = float(Game.state["time"]) + 0.01
		var before := Clock.hour(float(Game.state["time"]))
		BayMap.sail(Game.state, "rocky_shore")
		check(absf(fposmod(Clock.hour(float(Game.state["time"])) - before, 24.0) - 1.0) < 0.02, "an hour passes when sailing from %d o'clock" % int(start))
