extends "res://tests/test_case.gd"
## The ninth round of feedback: the bait on the hook, the sea filled with fish from the start, the depth he fishes at
## on his own, birds over the bay, and fish spread out from the shore.


func test_each_bait_shows_on_the_hook_as_itself() -> void:
	var looks := {}
	for id in Data.bait:
		var px: Array = LineView.bait_pixels(id)
		check(px.size() >= 6, "%s shows on the hook as a small picture, not a single pixel" % id)
		looks[str(px)] = id
	check(looks.size() == Data.bait.size(), "and each bait looks different from the others")
	check(LineView.bait_pixels("").is_empty(), "a bare hook shows no bait")


func test_the_fish_are_in_the_water_from_the_first_moment() -> void:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "hound")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour", "boat_x": 600.0})
	var sw: Swimmers = s.swimmers
	check(sw.fish.size() > 0, "the sea has fish as soon as it opens")
	check(sw.fish.all(func(f): return (f["sprite"].position - (f["pos"] - sw.cam)).length() < 0.5), "each drawn where it swims, not waiting in a corner for the first frame")
	for c in Nav.ui.get_children():
		c.free()
	s.free()
