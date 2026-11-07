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
