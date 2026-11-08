extends "res://tests/test_case.gd"


func test_the_seabed_stops_the_hook() -> void:
	var bed := Seabed.new([[0, 100], [200, 300]])
	check(is_equal_approx(bed.depth_at(100.0), 200.0), "the seabed between two points")
	check(bed.clamp_hook(Vector2(100, 900)).y == 200.0 - 2.0, "a hook sinks no further than the sand")
	check(bed.clamp_hook(Vector2(-50, 10)).x == 0.0, "nor off the place's end")
	check(bed.clamp_hook(Vector2(50, -20)).y == 0.0, "nor up out of the water while it is cast")


func test_the_camera_stays_inside_the_place() -> void:
	var c := CoastCamera.new(Vector2(1440, 460))
	for i in 200:
		c.follow(1420.0, Vector2(1440, 450), true, 0.1)
	check(c.cam.x <= 1440 - 480 and c.cam.y <= 460 - 270, "the camera never shows past the place's end or bottom")
	for i in 200:
		c.follow(10.0, Vector2(10, -1), false, 0.1)
	check(c.cam == Vector2(0, -160) and c.top() == -160.0, "back home with the waterline 160 pixels down")


func test_the_camera_leads_the_boat() -> void:
	var c := CoastCamera.new(Vector2(2400, 460))
	var x := 600.0
	for i in 100:
		x += 4.0
		c.follow(x, Vector2(x, -1), false, 0.1)
	check(c.cam.x + 240.0 > x + 20.0, "rowing east, the camera looks a little ahead")


func test_every_place_has_a_boat_end_stop() -> void:
	Game.new_game("Test", "mutt")
	for p in Data.places.values():
		var s: Node = load("res://scripts/coast/coast_screen.gd").new()
		Nav.port.add_child(s)
		s.enter({"place": p["id"]})
		s.row(-1.0, 100.0)
		check(s.boat_x >= 0.0, p["id"] + ": the boat stops at the start")
		s.row(1.0, 100.0)
		check(s.boat_x <= float(p["width"]) - s.boat_width() and s.boat_x > float(p["width"]) - 200.0, p["id"] + ": and at the end")
		s.free()


func test_a_cast_sinks_to_the_seabed_and_no_further() -> void:
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	s.cast(0.5)
	check(s.line_state() == "sinking", "a cast sinks")
	for i in 600:
		s.sink(1.0 / 30.0)
	check(s.hook.y <= s.seabed.depth_at(s.hook.x) and s.line_state() == "waiting", "it stops on the seabed")
	s.free()


func test_every_place_is_painted() -> void:
	for p in Data.places.values():
		check(p["layers"].size() >= 8, p["id"] + " has its painted layers")
		for l in p["layers"]:
			if l.has("file"):
				check(ResourceLoader.exists("res://assets/art/" + l["file"]), "%s: %s exists" % [p["id"], l["file"]])
		check(p.has("floor") and ResourceLoader.exists("res://assets/art/" + str(p["floor"].get("file", ""))), p["id"] + " has a painted sea floor")
		check(p["seabed"].size() >= 6, p["id"] + " has a seabed with its rises and falls")
		check(p["seabed"].all(func(pt): return pt[1] > 0 and pt[1] <= p["depth"]), p["id"] + "'s seabed stays within the place's depth")


func test_a_fish_reaches_a_hook_lying_on_the_seabed() -> void:
	var bed := Seabed.new(Data.places["harbour"]["seabed"])
	var w := Swimmers.new()
	w.setup("harbour", bed, Seeds.rng(1, "w"))
	var hook := bed.clamp_hook(Vector2(600, 999))
	var s := Sprite2D.new()
	w.add_child(s)
	var f := {"id": "mullet", "lb": 1.0, "sprite": s, "pos": hook + Vector2(-30, -20), "heading": 1.0, "phase": 0.0, "speed": 10.0,
		"band": Data.fish["mullet"]["depth"], "goal_y": hook.y, "turn": 5.0, "look": 1.0, "state": "approach", "leader": {}, "group": 1}
	var got := []
	w.bit.connect(func(fish): got.append(fish))
	for i in 150:
		w._move(f, 1.0 / 30.0, hook)
	check(got.size() == 1 and f["state"] == "bit", "a fish swimming in to a hook on the sand gets there and takes it")
	w.free()


func _line_out() -> Node:
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	s.cast(0.5)
	for i in 600:
		s.sink(1.0 / 30.0)
	return s


func _done(s: Node) -> void:
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func _press(s: Node) -> void:
	s._click = true
	s._handle_input(1.0 / 30.0)


## Lets the fish at the hook nibble until it takes the bait, and counts the float's twitches.
func _nibble(s: Node) -> int:
	var twitches := 0
	var t := 0.0
	while s.line_state() == "nibble" and t < 10.0:
		var before: float = s.twitch
		s.bite_step(0.05)
		if s.twitch > before:
			twitches += 1
		t += 0.05
	return twitches


func test_a_strike_while_the_fish_nibbles_scares_it_off_and_leaves_the_line_in() -> void:
	var s := _line_out()
	var f := {"id": "mullet", "lb": 1.0, "state": "bit", "heading": 1.0}
	var worms := int(Game.state["bait"]["worm"])
	s._on_bite(f)
	check(s.line_state() == "nibble", "a fish at the hook nibbles first")
	s.bite_step(0.05)
	check(s.twitch > 0.0, "and the float twitches")
	_press(s)
	check(s.line_state() == "waiting" and s.biter.is_empty() and s.fight == null, "a press while it nibbles scares it off and the line stays in")
	check(f["state"] == "swim" and f["flee"] > 0.0, "the fish darts away")
	check(int(Game.state["bait"]["worm"]) == worms, "and the bait is still on the hook")
	_done(s)


func test_the_float_goes_under_after_the_nibbles_and_a_strike_then_hooks_the_fish() -> void:
	var s := _line_out()
	s._on_bite({"id": "mullet", "lb": 1.0, "state": "bit", "heading": 1.0})
	var twitches := _nibble(s)
	check(s.line_state() == "bite" and twitches >= 1, "after %d twitches the fish takes the bait" % twitches)
	_press(s)
	check(s.line_state() == "fighting" and s.fight != null, "a strike now hooks it")
	_done(s)


func test_too_slow_a_strike_lets_the_fish_take_the_bait() -> void:
	var s := _line_out()
	s._on_bite({"id": "mullet", "lb": 1.0, "state": "bit", "heading": 1.0})
	_nibble(s)
	var worms := int(Game.state["bait"]["worm"])
	for i in 50:
		s.bite_step(0.05)
	check(s.line_state() == "waiting" and s.biter.is_empty(), "with no strike in time the fish goes")
	check(int(Game.state["bait"]["worm"]) == worms - 1, "and takes the bait with it")
	_done(s)


func test_a_press_with_no_fish_at_the_hook_reels_in() -> void:
	var s := _line_out()
	_press(s)
	check(s.line_state() == "reeling", "a press with nothing at the hook reels the line in")
	_done(s)


func test_the_demo_strikes_only_on_the_bite_and_reels_only_while_the_fish_rests() -> void:
	var s := _line_out()
	s._demo = true
	s._on_bite({"id": "mullet", "lb": 1.0, "state": "bit", "heading": 1.0})
	s._demo_step()
	check(s.line_state() == "nibble", "the demo waits through the nibbles")
	_nibble(s)
	s._demo_step()
	check(s.line_state() == "fighting", "and strikes when the float goes under")
	var ok := true
	for i in 120:
		ok = ok and s._reeling_input() == s.fight.resting()
		s.fight.step(s._reeling_input(), 1.0 / 30.0)
		if s.fight.state != "fighting":
			break
	check(ok, "and reels only while the fish rests")
	_done(s)
