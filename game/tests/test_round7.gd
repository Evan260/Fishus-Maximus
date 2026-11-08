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


func test_the_dog_sits_in_front_of_the_far_rail() -> void:
	for id in ["skiff", "fishing_boat"]:
		var b := BoatView.new()
		b.set_boat(id)
		var img: Image = b.boat.texture.get_image()
		var x := int(b.dog_seat().x)
		var behind := 0
		for y in int(b.seat.y):
			if img.get_pixel(x, y).a > 0.5:
				behind += 1
		check(behind >= 2, "%s: the far rail above the near side is drawn behind the dog, %d rows of it" % [id, behind])
		check(b.dog_seat().y - b.seat.y >= 12.0, "%s: and the near side still hides the dog's legs" % id)
		b.free()


func test_the_dog_never_shows_below_the_hull() -> void:
	for id in ["skiff", "fishing_boat", "sailing_boat", "big_boat"]:
		for c in Nav.ui.get_children():
			c.free()
		Game.new_game("Test", "hound")
		Game.state["boat"] = id
		var s: Node = load("res://scripts/coast/coast_screen.gd").new()
		Nav.port.add_child(s)
		s.enter({"place": "harbour", "boat_x": 400.0})
		s.dog._process(0.1)
		var img: Image = s._boat.boat.texture.get_image()
		var seat: Vector2 = s.dog_seat()
		var lowest := 1000
		for x in range(int(seat.x) - 16, int(seat.x) + 17):
			var b := -1
			for y in img.get_height():
				if img.get_pixel(clampi(x, 0, img.get_width() - 1), y).a > 0.5:
					b = y
			lowest = mini(lowest, b)
		var deepest: float = seat.y + s.dog.cut
		check(deepest <= lowest, "%s: the dog is drawn no lower than row %d, inside the hull's bottom at %d" % [id, deepest, lowest])
		check(deepest >= s._boat.seat.y, "%s: and down to the near rail, which then hides the rest of it" % id)
		s.free()
	for c in Nav.ui.get_children():
		c.free()


func test_the_jetty_runs_on_to_the_shore_past_the_view() -> void:
	var layers: Array = Data.places["harbour"]["layers"]
	var jetty: Dictionary = layers.filter(func(l): return str(l.get("file", "")).ends_with("jetty.png"))[0]
	check(float(jetty["world"][0]) <= -30.0, "the jetty's shore end lies past the harbour's end, where the view never goes")
	var width := float(load("res://assets/art/" + str(jetty["file"])).get_width())
	var under := layers.filter(func(l): return str(l.get("file", "")).ends_with("boulders.png") and float(l["world"][0]) < float(jetty["world"][0]) + width)
	check(under.is_empty(), "and no round boulder sits under it")
