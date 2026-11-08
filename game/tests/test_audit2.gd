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
