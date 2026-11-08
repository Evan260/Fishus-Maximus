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


func _sea(cam: Vector2, seed: String) -> Swimmers:
	var sw := Swimmers.new()
	sw.setup("harbour", Seabed.new(Data.places["harbour"]["seabed"]), Seeds.rng(5, seed))
	Nav.port.add_child(sw)
	sw.cam = cam
	sw.hour = 9.0
	return sw


func test_fish_do_not_pile_up_at_the_end_of_the_harbour() -> void:
	var piled := 0
	var groups := 0
	for k in 20:
		var sw := _sea(Vector2(0, -160), "pile %d" % k)
		sw.populate()
		for f in sw.fish:
			if f["leader"].is_empty():
				groups += 1
				if f["pos"].x < 30.0:
					piled += 1
		sw.free()
	check(piled <= groups * 0.08, "by the jetty the fish are spread along the water, not heaped at its end: %d of %d" % [piled, groups])


func test_the_shoals_and_fish_keep_apart() -> void:
	var sw := _sea(Vector2(500, -160), "apart")
	sw.populate()
	var leaders := sw.fish.filter(func(f): return f["leader"].is_empty())
	var close := 0
	for a in leaders.size():
		for b in range(a + 1, leaders.size()):
			if leaders[a]["pos"].distance_to(leaders[b]["pos"]) < Swimmers.APART:
				close += 1
	check(close == 0, "no two fish or shoals start on top of each other")
	check(leaders.size() <= Swimmers.WANTED + 2, "and the water near the boat is not crowded: %d" % leaders.size())
	sw.free()


func test_the_shallows_by_the_shore_hold_fewer_fish() -> void:
	check(Swimmers.room_for_fish(40.0) < Swimmers.room_for_fish(160.0), "fewer fish swim where the water is shallow")
	check(Swimmers.room_for_fish(400.0) == 1.0, "and the open water is as full as ever")


func test_fishing_on_his_own_he_hangs_the_bait_in_mid_water() -> void:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "hound")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour", "boat_x": 900.0})
	s.methods.set_idle(true)
	s.cast(0.6)
	s.flight = 0.0
	for i in 300:
		s.sink(0.1)
	var floor_y: float = s.seabed.depth_at(s.hook.x)
	check(s.hook.y < floor_y * 0.6 and s.hook.y > 15.0, "his float holds the bait in mid water, at %d of %d, not on the seabed" % [s.hook.y, floor_y])
	check(s.line_state() == "waiting", "and he waits there for a bite")
	for c in Nav.ui.get_children():
		c.free()
	s.free()
