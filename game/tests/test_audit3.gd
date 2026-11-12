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



func test_a_fish_that_reads_heavy_enough_for_an_order_is_taken() -> void:
	var units := Settings.units
	Settings.units = "metric"
	var want := {"fish": "mullet", "min_pounds": 2.0}
	check(Orders.suits(want, {"fish": "mullet", "pounds": 1.99}, false), "an order for 0.9 kg takes a mullet that reads 0.90 kg")
	check(not Orders.suits(want, {"fish": "mullet", "pounds": 1.9}, false), "but not one that reads 0.86 kg")
	Settings.units = "imperial"
	want = {"fish": "grouper", "min_pounds": 12.3}
	check(Orders.suits(want, {"fish": "grouper", "pounds": 12.1}, false), "an order for 12 lb takes a 12.1 lb fish")
	check(not Orders.suits(want, {"fish": "grouper", "pounds": 11.4}, false), "but not an 11.4 lb one")
	Settings.units = units


func test_garum_left_on_the_table_past_midnight_sells_at_the_market_price() -> void:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "mutt")
	Game.state["time"] = Clock.minutes_per_day() * 7.0 + 10.0
	Game.state["garum"] = {"muria": 3}
	GarumPanel.open()
	Game.state["time"] = Clock.minutes_per_day() * 8.0 + 10.0
	var sell: Array = Nav.ui.get_node("Window").find_children("*", "Button", true, false).filter(func(b): return b.text == "Sell one")
	check(sell.size() == 1, "one grade to sell")
	var before := int(Game.state["denarii"])
	if not sell.is_empty():
		sell[0].pressed.emit()
	var paid := int(Game.state["denarii"]) - before
	check(paid == Garum.price("muria", Garum.quality(Game.state, "muria"), false), "the ship has gone, so it fetches the market price, not %d" % paid)
	Ui.close_window()
	for c in Nav.ui.get_children():
		c.free()


func test_every_fish_that_keeps_to_part_of_the_day_says_when() -> void:
	for id in Data.fish:
		var hours: Array = Data.fish[id]["hours"]
		if float(hours[1]) - float(hours[0]) == 24.0:
			continue
		var when := Catalog.habits(id).filter(func(h): return h in ["at dawn", "at dusk", "by day", "at night"])
		check(when.size() == 1, "%s, about from %s to %s, says when it is found" % [id, hours[0], hours[1]])


func test_the_ways_of_fishing_name_a_key_just_changed() -> void:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	Controls.rebind("method_line", KEY_Q)
	s.hud.refresh()
	var tip := str(s.hud.method_buttons["line"].get_meta("tip"))
	check(tip.begins_with("Line (key Q)"), "the line's tip names the new key: %s" % tip.left(20))
	Controls.rebind("method_line", KEY_1)
	for c in Nav.ui.get_children():
		c.free()
	s.free()
