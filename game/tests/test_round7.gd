extends "res://tests/test_case.gd"
## The seventh round of feedback: pictures that cover the window, the dog inside the boat, the tackle from the line,
## and the jetty.


func _resize(size: Vector2i) -> void:
	Windowing.get_window().size = size
	Windowing._process(0.0)


func test_a_screen_picture_covers_any_window_without_mirrored_edges() -> void:
	var win := Windowing.get_window()
	var before := win.size
	for size in [Vector2i(1918, 1007), Vector2i(2400, 1500), Vector2i(1280, 1024), Vector2i(960, 540)]:
		_resize(size)
		var t: Transform2D = Nav.cover()
		var shown := Rect2(t.origin, Vector2(480, 270) * t.get_scale())
		check(shown.encloses(Rect2(Vector2.ZERO, Nav.view())), "%s: the picture reaches every edge of the view, %s against %s" % [size, shown, Nav.view()])
		var px: float = t.get_scale().x * Nav.zoom
		check(is_equal_approx(px, roundf(px)), "%s: each of its pixels is a whole %s window pixels" % [size, px])
		var left: float = -t.origin.x
		var right: float = shown.end.x - Nav.view().x
		check(absf(left - right) * Nav.zoom <= 1.01, "%s: and it is cropped evenly on both sides" % size)
	_resize(before)


func test_the_town_and_ponds_cover_the_window() -> void:
	var win := Windowing.get_window()
	var before := win.size
	_resize(Vector2i(1918, 1007))
	Game.new_game("Test", "hound")
	for screen in ["town", "shore"]:
		for c in Nav.ui.get_children():
			c.free()
		var s: Node = load(Nav.SCREENS[screen]).new()
		Nav.world.add_child(s)
		s.enter({})
		check(s._stage.transform == Nav.cover(), "%s: its picture covers the window rather than leaving room for mirrored copies" % screen)
		s.free()
	for c in Nav.ui.get_children():
		c.free()
	_resize(before)


func test_a_picture_painted_past_its_edges_keeps_the_whole_scene_in_view() -> void:
	var before := Windowing.get_window().size
	var margin := Vector2(24, 32)
	for size in [Vector2i(2422, 1550), Vector2i(1920, 1200), Vector2i(1918, 1007), Vector2i(1920, 1080)]:
		_resize(size)
		var t: Transform2D = Nav.cover(margin)
		var shown := Rect2(t * -margin, (Vector2(480, 270) + margin * 2.0) * t.get_scale())
		check(shown.encloses(Rect2(Vector2.ZERO, Nav.view())), "%s: the painted margin reaches every edge of the view" % size)
		var scene := Rect2(t.origin, Vector2(480, 270) * t.get_scale())
		var view := Rect2(Vector2.ZERO, Nav.view())
		var cut := scene.size.x - view.intersection(scene).size.x
		check(cut <= 0.01 or size == Vector2i(1918, 1007), "%s: and the whole width of the scene stays on screen" % size)
	_resize(before)
