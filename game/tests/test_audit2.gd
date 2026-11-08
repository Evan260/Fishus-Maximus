extends "res://tests/test_case.gd"
## Bugs found by the second audit: each test shows one, failing before its fix.


func test_a_clients_title_keeps_its_own_capitals() -> void:
	check(ClientVisit.title_of({"title": "the freedman with the biggest dinners on the bay"}) == "The freedman with the biggest dinners on the bay",
		"only the first letter of a title starting with 'the' is raised, not every word")
	check(ClientVisit.title_of({"title": "cook of the Elephant tavern"}) == "cook of the Elephant tavern", "other titles are left as written")


func test_the_garum_works_count_in_good_latin_and_english() -> void:
	check(GarumPanel.amphorae(1) == "1 amphora", "one amphora, not '%s'" % GarumPanel.amphorae(1))
	check(GarumPanel.amphorae(3) == "3 amphorae", "and several amphorae")
	check(GarumPanel.ship_text(6) == "comes in 1 day", "the ship comes in 1 day, not '%s'" % GarumPanel.ship_text(6))
	check(GarumPanel.ship_text(5) == "comes in 2 days", "or in 2 days")


func _hooked() -> Node:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	s.cast(0.5)
	for i in 600:
		s.sink(0.05)
	s._on_bite({"id": "mullet", "lb": 1.0, "state": "bit", "heading": 1.0})
	while s.line_state() == "nibble":
		s.bite_step(0.05)
	s.strike()
	return s


func _done(s: Node) -> void:
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func test_a_hooked_fish_waits_while_a_window_is_open() -> void:
	var s := _hooked()
	check(s.line_state() == "fighting", "a fish is on")
	var was: float = s.fight.distance
	var tension: float = s.fight.tension
	Ui.window("Settings", 200, 100)
	for i in 200:
		s._process(0.05)
	check(s.line_state() == "fighting" and s.fight != null, "ten seconds in the settings do not lose the fish")
	check(is_equal_approx(s.fight.distance, was) and is_equal_approx(s.fight.tension, tension), "nor move the fight on at all")
	_done(s)


func test_the_way_of_fishing_cannot_change_with_a_fish_on() -> void:
	var s := _hooked()
	s.methods.set_method("trap")
	check(s.methods.method == "line" and s.fight != null, "picking pots while a fish is on keeps the line and the fish")
	_done(s)


func test_a_nibbling_fish_keeps_its_mouth_on_the_drifting_bait() -> void:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	s.cast(0.5)
	for i in 600:
		s.sink(0.05)
	s.swimmers.populate()
	var f: Dictionary = s.swimmers.fish[0]
	f["state"] = "bit"
	s._on_bite(f)
	check(s.line_state() == "nibble", "the fish is at the bait")
	s.hook.x += 4.0
	for i in 3:
		s._process(0.05)
	check(Swimmers.mouth_at(f).distance_to(s.hook + Swimmers.BAIT_MIDDLE) <= 2.0, "and its mouth stays on the bait as the hook drifts, %s against %s" % [Swimmers.mouth_at(f), s.hook + Swimmers.BAIT_MIDDLE])
	_done(s)


func _coast_at(place: String) -> Node:
	for c in Nav.ui.get_children():
		c.free()
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": place})
	return s


func test_a_game_saved_while_he_fished_on_his_own_carries_on_so() -> void:
	Game.new_game("Test", "mutt")
	Game.state["idle"] = {"place": "harbour", "bait": "worm", "depth": 30.0, "water": 60.0}
	var s := _coast_at("harbour")
	s._process(0.05)
	check(s.methods.idle, "back at the same place, he is still fishing on his own")
	_done(s)
	Game.state["idle"] = {"place": "rocky_shore", "bait": "worm", "depth": 30.0, "water": 60.0}
	s = _coast_at("harbour")
	s._process(0.05)
	check(not s.methods.idle and not Game.state.has("idle"), "and elsewhere it is over, not left set in the save")
	_done(s)


func test_fishing_on_his_own_while_away_uses_bait() -> void:
	Game.new_game("Test", "mutt")
	Game.state["bait"] = {"worm": 3}
	Game.state["idle"] = {"place": "harbour", "bait": "worm", "depth": 30.0, "water": 60.0}
	Game.state["last_real_time"] = Time.get_unix_time_from_system() - 8 * 3600
	var before: int = Game.state["hold"].size() + Game.state["live_well"].size()
	Game.catch_up()
	var caught: int = Game.state["hold"].size() + Game.state["live_well"].size() - before
	check(caught > 0 and caught <= 3, "with three worms he catches at most three fish while you are away, %d" % caught)
	check(int(Game.state["bait"]["worm"]) == 3 - caught, "using a worm for each")
	Game.new_game("Test", "mutt")
	Game.state["bait"] = {}
	Game.state["idle"] = {"place": "harbour", "bait": "", "depth": 30.0, "water": 60.0}
	Game.state["last_real_time"] = Time.get_unix_time_from_system() - 8 * 3600
	Game.catch_up()
	check(Game.state["hold"].is_empty(), "and with no bait he catches nothing")
