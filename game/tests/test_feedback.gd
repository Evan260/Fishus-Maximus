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
		if c is Button and c.text in ["Bay map", "Go ashore"]:
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
