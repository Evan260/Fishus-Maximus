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

