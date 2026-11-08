extends "res://tests/test_case.gd"
## The third round of feedback: the title, the harbour, the boat and the guide, each pinned by a test.


func test_a_maximised_window_is_filled_to_its_edges() -> void:
	var win := Windowing.get_window()
	var before := win.size
	win.size = Vector2i(2400, 1500)
	Windowing._process(0.0)
	check(Nav.view() == Vector2(480, 300) and Nav.zoom == 5, "the view grows to 480 by 300 at five times when the window does, not %s" % Nav.view())
	win.size = before
	Windowing._process(0.0)


func test_the_buttons_along_the_bottom_line_up() -> void:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	var edges := []
	for c in Nav.ui.get_children():
		if c is Button and (c == s._sail or c.text == "Go ashore"):
			edges.append([c.text, c.offset_top, c.offset_top + maxf(c.offset_bottom - c.offset_top, c.get_combined_minimum_size().y)])
		if c is Hud:
			for k in c.get_children():
				if k is HBoxContainer and k.anchor_top == 1.0:
					edges.append(["methods", k.offset_top, k.offset_top + maxf(k.offset_bottom - k.offset_top, k.get_combined_minimum_size().y)])
	check(edges.size() == 3, "the map, the methods and going ashore are all there")
	for e in edges:
		check(e[1] == edges[0][1] and e[2] == edges[0][2], "%s runs from %d to %d like %s" % [e[0], e[1], e[2], edges[0][0]])
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func test_the_strip_hides_the_full_window_buttons() -> void:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	Windowing.strip = true
	s._on_view_changed()
	check(not s._sail.visible, "no Bay map button over the strip's view")
	Windowing.strip = false
	s._on_view_changed()
	check(s._sail.visible, "it comes back in the full window")
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func test_a_window_between_whole_sizes_is_covered_to_its_edges() -> void:
	var win := Windowing.get_window()
	var before := win.size
	win.size = Vector2i(2404, 1503)
	Windowing._process(0.0)
	var frame: Control = Nav.port.get_parent()
	check(frame.position.x <= 0.0 and frame.position.y <= 0.0, "the game starts at or past the window's top left")
	check(frame.position.x + Nav.view().x * Nav.zoom >= 2404 and frame.position.y + Nav.view().y * Nav.zoom >= 1503, "and reaches past its bottom right")
	win.size = before
	Windowing._process(0.0)


func test_the_dog_is_drawn_at_its_painted_size() -> void:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "hound")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	s.dog._process(0.0)
	check(s.dog.scale.abs() == Vector2.ONE, "the dog is to scale beside the fisherman, not shrunk to %s" % s.dog.scale)
	check(s.dog.rect().size.y >= 30.0, "and can be petted anywhere on it")
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func test_a_cast_line_flies_out_before_it_lands() -> void:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "hound")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	s.cast(0.8)
	check(s.flight > 0.0 and not s.hook_baited(), "the float is still in the air, so nothing can take it yet")
	var mid: Vector2 = s.flying()
	check(mid.y < 0.0, "and it arcs above the water on its way out")
	s._process(1.0)
	check(s.flight <= 0.0 and s.hook_baited(), "once it lands the bait is in the water")
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func test_the_rod_bends_towards_a_pulling_fish() -> void:
	var b := BoatView.new()
	b.set_boat("skiff")
	b.place(100.0, Vector2.ZERO, 0.0)
	var straight: Vector2 = b.rod_tip(100.0)
	b.strain = 1.0
	b.pull = straight + Vector2(60, 120)
	var bent: Vector2 = b.rod_tip(100.0)
	check(bent.y > straight.y + 3.0, "under strain the tip is pulled down towards the fish")
	b.free()


func test_no_line_hangs_from_the_rod_while_he_rows() -> void:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "hound")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	s.row(1.0, 0.1)
	check(s.rowing(), "the coast knows he is rowing, so the line view leaves the stowed rod bare")
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func _coast() -> Node:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "hound")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	return s


func _done(s: Node) -> void:
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func test_casting_ends_the_wind_up() -> void:
	var s := _coast()
	s.charge = 0.4
	s.cast(0.6)
	check(s.charge < 0.0, "no wind-up is left over to fire a second cast by itself")
	_done(s)


func test_the_float_sets_off_from_the_rod_tip() -> void:
	var s := _coast()
	s.cast(0.8)
	check(s.flying().distance_to(s.rod_tip()) < 1.5, "the float leaves from the tip of the swinging rod, at %s, not %s" % [s.rod_tip(), s.flying()])
	_done(s)


func test_a_line_reeled_in_mid_flight_makes_no_splash() -> void:
	var s := _coast()
	s.cast(0.8)
	s.reel_in()
	check(s.flight <= 0.0, "the flight ends when the line is pulled back")
	_done(s)


func test_a_click_on_the_dog_strikes_a_bite() -> void:
	var s := _coast()
	s.relayout()
	s.dog._process(0.0)
	var on_dog: Vector2 = s.dog.rect().get_center()
	s._state = "bite"
	check(not s._pets_dog(on_dog), "while a fish has the bait a click there strikes rather than petting the dog")
	s._state = "reeled"
	check(s._pets_dog(on_dog), "with the line in, the click pets him")
	_done(s)


func test_a_napping_dog_sleeps_on_while_fish_pass() -> void:
	var s := _coast()
	s.methods.set_idle(true)
	s.dog.cheer()
	s.dog._process(0.1)
	check(s.dog.mood == "sleep_east", "a shoal going by does not get him up while the fisherman fishes on his own")
	_done(s)


func test_petting_the_dog_floats_up_a_heart() -> void:
	var s := _coast()
	s.dog.pet()
	check(s.dog.hearts() == 1, "a heart rises over him, as in Farmus")
	s.methods.set_idle(true)
	s.dog.pet()
	s.dog._process(0.1)
	check(s.dog.hearts() == 2 and s.dog.mood == "sleep_east", "a sleeping dog takes a stroke without waking, and still shows a heart")
	_done(s)


func test_coming_back_says_nothing_about_time_gone_by() -> void:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "hound")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour", "away": Clock.minutes_per_day() * 3.0})
	var box: Control = Toast._box
	check(not is_instance_valid(box) or not box.get_children().any(func(l): return "away" in l.text or "passed" in l.text), "no reminder of the time spent away")
	_done(s)


func test_the_boat_rides_two_pixels_higher() -> void:
	check(BoatView.DRAFT == 8.0, "the hull sits 8 pixels deep, not 10")


func test_the_catch_card_shows_in_the_middle() -> void:
	for c in Nav.ui.get_children():
		c.free()
	CatchCard.show_catch("mullet", 1.2, true)
	var card: Control = CatchCard._open
	check(card.anchor_top == 0.5 and card.anchor_left == 0.5, "the card is centred in the view, not hung from the top")
	for c in Nav.ui.get_children():
		c.free()


func _said(text: String) -> bool:
	var box: Control = Toast._box
	return is_instance_valid(box) and box.get_children().any(func(l): return text in l.text)


func test_the_first_pot_explains_itself() -> void:
	var s := _coast()
	s.methods.set_method("trap")
	s.methods.use()
	check(_said("Row over it later"), "the first pot says what it is for and how to haul it up")
	_done(s)


func test_hauling_a_pot_says_why() -> void:
	var s := _coast()
	Game.state["traps"] = [{"place": "harbour", "x": s.boat_x + 52.0, "depth": 60.0, "set_time": 0.0, "catch": [{"fish": "crab", "pounds": 0.5}], "size": 3, "hours": 2.0, "bait": ""}]
	s.methods._pull_traps_under_boat()
	check(_said("rowed over"), "the message says the pot came up because the boat passed over it")
	_done(s)


func test_a_napping_dog_does_not_bark_at_his_own_catches() -> void:
	var s := _coast()
	s.methods.set_idle(true)
	s.dog.bark()
	check(s.dog._bark_left <= 0.0, "no bark or mark over a sleeping dog while the fisherman fishes on his own")
	_done(s)


func test_a_bite_waits_while_a_window_is_open() -> void:
	var s := _coast()
	s.cast(0.5)
	s.flight = 0.0
	s.biter = {"id": "mullet", "lb": 1.0, "state": "bit"}
	s._state = "bite"
	s.bite_left = 1.0
	Ui.window("Tackle", 200, 100)
	s._process(0.5)
	check(s.line_state() == "bite" and s.bite_left >= 0.99, "picking bait does not cost the fish on the line")
	Ui.close_window()
	_done(s)
