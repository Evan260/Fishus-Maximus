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
		Nav.add_child(s)
		s.enter({"place": p["id"]})
		s.row(-1.0, 100.0)
		check(s.boat_x >= 0.0, p["id"] + ": the boat stops at the start")
		s.row(1.0, 100.0)
		check(s.boat_x <= float(p["width"]) - s.boat_width() and s.boat_x > float(p["width"]) - 200.0, p["id"] + ": and at the end")
		s.free()


func test_a_cast_sinks_to_the_seabed_and_no_further() -> void:
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.add_child(s)
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
