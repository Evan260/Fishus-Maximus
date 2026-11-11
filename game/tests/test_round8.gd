extends "res://tests/test_case.gd"
## The eighth round of feedback: the town and the pond under the coast's live sky, lit by the hour, and the town's
## picture painted on past its edges so a window of another shape still shows the whole scene.

const SIZES := [Vector2i(1918, 1007), Vector2i(1920, 1080), Vector2i(1920, 1200), Vector2i(2560, 1600)]


func _resize(size: Vector2i) -> void:
	Windowing.get_window().size = size
	Windowing._process(0.0)


func _open(screen: String, hour := 13.0, weather := "clear") -> Node:
	Game.new_game("Test", "mutt")
	Game.state["time"] = Clock.at_hour(0.0, hour)
	Game.state["weather"] = weather
	var s: Node = load(Nav.SCREENS[screen]).new()
	Nav.port.add_child(s)
	s.enter({})
	return s


## Closes a screen and waits a frame, so the sky it left in Nav.sky is gone before the next one opens.
func _close(s: Node) -> void:
	for c in Nav.ui.get_children():
		c.free()
	s.free()
	await Nav.get_tree().process_frame


func _sky() -> SkyView:
	for n in Nav.sky.get_children():
		if n is SkyView and not n.is_queued_for_deletion():
			return n
	return null


## The town's picture laid over the window, with how far it is painted past the scene.
func _picture() -> Image:
	return load("res://assets/art/town/street.png").get_image()


func test_the_clock_finds_an_hour_of_the_same_day() -> void:
	var day := 3.0 * Clock.minutes_per_day()
	for h in [5.0, 9.5, 13.0, 19.75, 22.0, 2.0]:
		var t := Clock.at_hour(day + 4.0, h)
		check(absf(Clock.hour(t) - h) < 0.01, "%s o'clock is %s" % [h, Clock.hour(t)])
		check(Clock.day_of(t) == 3, "on the same day")


func test_the_town_and_ponds_show_the_coast_sky() -> void:
	for screen in ["town", "shore"]:
		var s := _open(screen)
		var sky := _sky()
		check(sky != null, "%s: the live sky is in Nav.sky behind the picture" % screen)
		if sky:
			check(sky.hour == Clock.hour(float(Game.state["time"])) and sky.weather == "clear", "%s: by the hour and the weather" % screen)
		await _close(s)
		check(_sky() == null, "%s: and it goes with the screen" % screen)


func test_the_town_has_no_painted_sky() -> void:
	var img := _picture()
	var margin := (Vector2(img.get_size()) - Nav.SIZE) / 2.0
	var horizon: float = load(Nav.SCREENS["town"]).HORIZON
	var blue := 0
	for y in int(horizon + margin.y):
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.1 and c.b > c.r + 0.07 and c.b >= c.g and c.get_luminance() > 0.55:
				blue += 1
	check(blue < 20, "town: no painted sky above its horizon, %d sky-blue pixels left" % blue)
	var street := _picture()
	check(street.get_pixel(100 + 16, 60 + 33).a == 0.0, "the sky over the town's wall is left open for the live sky")


func test_the_town_is_painted_past_the_scene() -> void:
	var margin := (Vector2(_picture().get_size()) - Nav.SIZE) / 2.0
	check(margin.x >= 16.0 and margin.y >= 25.0, "town: painted %s past the scene, enough for a 2560 by 1600 window" % margin)


func test_the_town_is_lit_by_the_hour_and_the_weather() -> void:
	var looks := {}
	for when in [[13.0, "clear"], [23.0, "clear"], [13.0, "rain"]]:
		var s := _open("town", when[0], when[1])
		looks["%d %s" % when] = s._lit.modulate
		check(s._painter.get_parent() != s._lit, "the gold outline and the names stay bright at %s" % when[0])
		await _close(s)
	check(looks["13 clear"].v > 0.99, "a fine noon lights the town fully")
	check(looks["23 clear"].v < 0.85 and looks["23 clear"].b > looks["23 clear"].r, "at night it is dark and blue")
	check(looks["13 rain"].v < 0.9, "and rain dims it")
	var s := _open("shore", 23.0)
	check(s._lit.modulate.v < 0.85, "the pond is dark at night too")
	await _close(s)


func test_the_sky_meets_each_picture_at_its_horizon() -> void:
	var before := Windowing.get_window().size
	for size in [Vector2i(1920, 1080), Vector2i(1920, 1200)]:
		_resize(size)
		for screen in ["town", "shore"]:
			var s := _open(screen)
			var row: float = (s._stage.transform * Vector2(0, s.HORIZON)).y if screen == "town" else s.HORIZON + Nav.offset().y
			check(absf(_sky().position.y + SkyView.HORIZON - row) < 0.01, "%s %s: the sky's horizon lies on the picture's" % [screen, size])
			await _close(s)
	_resize(before)


func test_every_window_shows_the_whole_town_with_no_mirrored_edge() -> void:
	var before := Windowing.get_window().size
	for size in SIZES:
		_resize(size)
		var s := _open("town")
		var view := Rect2(Vector2.ZERO, Nav.view())
		check(s._stage.transform == Nav.cover(s.margin), "%s: the street covers the window, scaled whole" % size)
		var street: Sprite2D = s._street
		var shown := Rect2(s._stage.transform * street.position, street.texture.get_size() * s._stage.scale)
		check(shown.grow(0.01).encloses(view), "%s: the painted street reaches every edge, %s against %s" % [size, shown, view])
		check(not s._stage.get_children().any(func(n): return n is Backdrop), "%s: with no mirrored copies" % size)
		for id in s.BUILDINGS:
			var r: Rect2 = Nav.from_ui(s.guide_target(id))
			check(view.grow(1.5).encloses(r), "%s: the %s is on screen at %s" % [size, id, r])
			var middle: Vector2 = s._stage.transform.affine_inverse() * r.get_center()
			check(s._building_at(middle) == id or s._building_at(middle) == "", "%s: and the guide's arrow points at it" % size)
		await _close(s)
	_resize(before)


func test_every_window_shows_the_whole_pond_with_no_mirrored_edge() -> void:
	var before := Windowing.get_window().size
	for size in SIZES + [Vector2i(2560, 1080), Vector2i(3440, 1440)]:
		_resize(size)
		var s := _open("shore")
		var view := Rect2(Vector2.ZERO, Nav.view())
		var bank: Sprite2D = s._layers._nodes.filter(func(n): return n["node"] is Sprite2D and n["node"].texture.resource_path.ends_with("bank.png"))[0]["node"]
		check(bank.position.x <= 0.0 and bank.position.x + bank.texture.get_width() >= view.size.x, "%s: the pond's far bank reaches both sides, %s" % [size, bank.position])
		var beach: Sprite2D = s._beach
		check(beach.position.x <= 0.0 and beach.position.x + beach.region_rect.size.x >= view.size.x, "%s: and the beach does" % size)
		check(s.pond_cam.x >= 0.0 and s.pond_cam.x + view.size.x <= s.WIDTH, "%s: and the pond's water runs past both sides" % size)
		check(absf(-s.pond_cam.y - (s.WATER + Nav.offset().y)) < 0.01, "%s: its waterline is on the scene's" % size)
		var flipped: Array = s.find_children("*", "Sprite2D", true, false).filter(func(n): return (n.flip_h or n.flip_v) and not s.pond.is_ancestor_of(n))
		check(flipped.is_empty(), "%s: nothing but a fish swimming the other way is turned over" % size)
		var garum: Rect2 = Rect2(s._bank_at() + Vector2(s._garum.get_used_rect().position), Vector2(s._garum.get_used_rect().size))
		check(view.grow(1.0).encloses(Rect2(garum.position, Vector2(garum.size.x * 0.6, garum.size.y))), "%s: the garum works are on screen at %s" % [size, garum])
		await _close(s)
	_resize(before)


func test_the_bay_map_fades_into_the_deep_past_its_edges_with_no_mirrored_copies() -> void:
	var before := Windowing.get_window().size
	for size in [Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(3440, 1440), Vector2i(1280, 1024)]:
		_resize(size)
		var s := _open("map")
		var flipped: Array = s.find_children("*", "Sprite2D", true, false).filter(func(n): return n.flip_h or n.flip_v)
		check(flipped.is_empty(), "%s: no picture on the map is turned over" % size)
		var backdrop: Backdrop = s._backdrop
		var view := Rect2(Vector2.ZERO, Nav.view())
		check(Rect2(s._stage.position + backdrop._view.position, backdrop._view.size).is_equal_approx(view), "%s: the plain deep fills the whole view" % size)
		var fade: Vector4 = backdrop._picture.material.get_shader_parameter("fade")
		var room := view.size - Vector2(480, 270)
		check((fade.x > 0.0) == (room.x > 0.5) and (fade.y > 0.0) == (room.y > 0.5), "%s: an edge fades only where the view reaches past it, %s" % [size, fade])
		await _close(s)
	_resize(before)
