extends "res://tests/test_case.gd"
## Bugs found by the third audit: each test shows one, failing before its fix.


func test_the_bots_and_tools_load() -> void:
	for path in ["res://tests/flow_bot.gd", "res://tests/pacing_bot.gd", "res://tools/bench.gd", "res://tools/write_credits.gd",
			"res://tools/trailer/shots.gd", "res://tools/trailer/edit.gd"]:
		var script: GDScript = load(path)
		check(script != null and script.can_instantiate(), "%s loads" % path)


func test_a_wide_window_opens_on_the_boat_without_gliding() -> void:
	var was := Nav.port.size_2d_override
	Nav.port.size_2d_override = Vector2i(960, 300)
	Game.new_game("Test", "mutt")
	Game.state["boat_x"] = 1200.0
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "open_bay"})
	var start: float = s.camera.cam.x
	check(is_equal_approx(start, 1200.0 + 52.0 - 480.0), "the camera starts centred on the boat in the wider view, not at %s" % start)
	s._process(0.05)
	check(absf(s.camera.cam.x - start) < 1.0, "and stays there rather than gliding across")
	for c in Nav.ui.get_children():
		c.free()
	s.free()
	Nav.port.size_2d_override = was


func test_fish_in_a_wide_view_count_as_near() -> void:
	var was := Nav.port.size_2d_override
	Nav.port.size_2d_override = Vector2i(960, 300)
	var sw := Swimmers.new()
	sw.setup("open_bay", Seabed.new(Data.places["open_bay"]["seabed"]), Seeds.rng(5, "wide"))
	Nav.port.add_child(sw)
	sw.cam = Vector2(400, -160)
	var tex := sw.texture_for("tuna")
	for x in [1300.0, 1500.0]:
		var s := Swimmers.sprite_for("tuna", tex)
		sw.add_child(s)
		sw.fish.append({"id": "tuna", "lb": 100.0, "sprite": s, "pos": Vector2(x, 80), "heading": 1.0, "leader": {}, "state": "swim"})
	check(sw._near_count() == 2, "two shoals in the right of a wide view are counted as near, not %d" % sw._near_count())
	check(sw.crowded("tuna"), "so a third tuna shoal waits")
	sw.free()
	Nav.port.size_2d_override = was
