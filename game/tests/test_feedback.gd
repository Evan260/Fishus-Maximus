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

