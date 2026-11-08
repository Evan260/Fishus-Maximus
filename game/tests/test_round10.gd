extends "res://tests/test_case.gd"
## The tenth round of feedback: the boat's sounds, its oar and its height, and never being left without a way to fish.


func test_the_lapping_hull_is_gone() -> void:
	check(not ResourceLoader.exists("res://assets/audio/ambience/sea.ogg"), "the noisy recording of waves on a hull is gone")
	for path in ["res://scripts/coast/coast_screen.gd", "res://scripts/screens/title.gd", "res://scripts/shore/shore_screen.gd"]:
		check(not "\"sea\":" in FileAccess.get_file_as_string(path), "%s no longer plays it" % path.get_file())


func test_the_oar_comes_out_of_the_water_between_strokes() -> void:
	var b := BoatView.new()
	b.set_boat("skiff")
	var above := 0
	var below := 0
	for i in 90:
		b.rowing = 1.0
		b._process(1.0 / 30.0)
		b.place(100.0, Vector2(0, -160), i / 30.0)
		var blade: Vector2 = b._oar()[0]
		if blade.y < -1.0:
			above += 1
		elif blade.y > 4.0:
			below += 1
		check((blade - b._oar()[2]).length() <= BoatView.OAR_OUT + 0.5, "the oar never grows longer as it swings")
	check(above >= 20 and below >= 30, "the blade pulls through the water and lifts clear of it to swing back: %d up, %d down" % [above, below])
	b.free()


func _broke() -> void:
	Game.new_game("Test", "hound")
	Game.state["denarii"] = 0
	Game.state["bait"] = {"worm": 0}
	Game.state["hold"] = []
	Game.state["live_well"] = []


func test_a_player_left_with_nothing_is_helped_back_to_fishing() -> void:
	_broke()
	World.advance(Game.state, 1.0, Seeds.rng(1, "rescue"))
	check(int(Game.state["bait"]["worm"]) > 0 and Game.state["current_bait"] == "worm", "old Rufus brings worms when there is no bait, no money for any and nothing to sell")
	check(Game.state.has("_rescued"), "and says so")


func test_nobody_is_helped_who_can_still_get_by() -> void:
	_broke()
	Game.state["denarii"] = 5
	World.advance(Game.state, 1.0, Seeds.rng(1, "rescue"))
	check(int(Game.state["bait"]["worm"]) == 0, "a player who can buy bait buys his own")
	_broke()
	Game.state["hold"].append({"fish": "mullet", "pounds": 1.0, "fresh": 1.0})
	World.advance(Game.state, 1.0, Seeds.rng(1, "rescue"))
	check(int(Game.state["bait"]["worm"]) == 0, "nor one with fish in the hold to sell")


func test_the_panel_shows_no_ticking_clock() -> void:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "hound")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	s.hud.refresh()
	var text: String = s.hud._info.text
	check(not ":" in text, "the panel has no hour and minute ticking by: %s" % text)
	check("Day 1" in text and "spring" in text, "but still the day and the season")
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func test_there_are_two_seconds_to_strike() -> void:
	check(is_equal_approx(Bite.window(), 2.0), "the float stays under two seconds before the fish has the bait")


func test_the_oar_is_one_straight_pole_in_every_frame() -> void:
	var b := BoatView.new()
	b.set_boat("skiff")
	for i in 90:
		b.rowing = 1.0
		b._process(1.0 / 30.0)
		b.place(100.0, Vector2(0, -160), i / 30.0)
		var line: Array = b.oar_line()
		var hands: Vector2 = line[0]
		var blade: Vector2 = line[1]
		var through: Vector2 = line[2]
		var off := absf((blade - hands).normalized().cross(through - hands))
		check(off < 0.5, "frame %d: the handle and the blade lie on one straight line, %.2f off" % [b.pose()[1], off])
	b.free()


func test_the_float_drifts_a_little_and_comes_back() -> void:
	var seen := []
	for i in 2400:
		seen.append(LineView.float_drift(i * 0.1))
	var far: float = seen.map(func(d): return absf(d)).max()
	check(far > 2.0, "the float drifts to and fro on the water, as much as %.1f pixels" % far)
	check(far <= LineView.DRIFT + 0.01, "but never far from where it landed")
	var still := seen.filter(func(d): return absf(d) < 0.4).size()
	check(still > 100, "and some of the time it lies still")
	var steps := []
	for i in range(1, seen.size()):
		steps.append(absf(seen[i] - seen[i - 1]))
	check(steps.max() < 0.5, "and it moves slowly, never jumping")
