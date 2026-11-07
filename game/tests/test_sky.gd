extends "res://tests/test_case.gd"


func _coast(place: String, hour: float, weather := "clear") -> Node:
	Game.new_game("Test", "mutt")
	Game.state["weather"] = weather
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": place})
	s.hour = hour
	s.weather = weather
	s.relayout()
	return s


func _sky() -> SkyView:
	for n in Nav.sky.get_children():
		if n is SkyView and not n.is_queued_for_deletion():
			return n
	return null


func _close(s: Node) -> void:
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func test_the_sky_is_drawn_behind_the_game() -> void:
	var s := _coast("harbour", 13.0)
	var sky := _sky()
	check(sky != null, "the coast's sky is in Nav.sky, drawn at the window's resolution")
	check(sky.clouds().size() >= 20 and sky.clouds().all(func(c): return c["sprite"].get_parent() == sky), "with its clouds in it")
	check(not s.get_children().any(func(n): return n is SkyView), "and not in the game's own pixels")
	_close(s)
	await Nav.get_tree().process_frame
	check(_sky() == null, "it goes when the coast does")


func test_no_place_paints_a_wall_of_clouds() -> void:
	for p in Data.places.values():
		check(not p["layers"].any(func(l): return str(l.get("file", "")).contains("clouds")), p["id"] + " leaves its clouds to the sky")


func test_the_sky_rises_with_the_waterline() -> void:
	var s := _coast("harbour", 13.0)
	var sky := _sky()
	check(sky.position.y == 0.0, "at home the sky's horizon sits on the far sea")
	s.camera.jump(Vector2(400, 0))
	s.relayout()
	check(sky.position.y == -160.0, "the camera going down takes the sky up with the waterline")
	check(absf(sky.position.x + 400.0 * SkyView.DRIFT) < 0.001, "and it slides only a little sideways, like the farthest land")
	_close(s)


func test_the_sky_hides_in_the_see_through_strip() -> void:
	var s := _coast("harbour", 13.0)
	var sky := _sky()
	Windowing.transparent = true
	Windowing.set_strip(true)
	check(not sky.visible, "the desktop shows through the see-through strip, so there is no sky")
	Windowing.set_transparent(false)
	check(sky.visible, "the solid strip shows the sky")
	check(sky.position.y == -float(Windowing.STRIP_TOP), "lined up with the band of the coast the strip shows")
	Windowing.set_strip(false)
	Windowing.set_transparent(true)
	check(sky.visible and sky.position.y == 0.0, "and the full window has it back where it was")
	_close(s)


func test_no_cloud_starts_cut_off_or_goes_round_in_sight() -> void:
	for place in ["harbour", "open_bay", "misenum"]:
		for weather in ["clear", "storm"]:
			var s := _coast(place, 10.0, weather)
			var sky := _sky()
			var span := sky.view_span()
			var cut := sky.clouds().filter(func(c):
				var x: float = c["sprite"].position.x
				var w := float(c["sprite"].texture.get_width())
				return (x < span.x and x + w > span.x) or (x < span.y and x + w > span.y))
			check(cut.is_empty(), "%s in %s weather: no cloud starts across an edge of the view" % [place, weather])
			var bad := 0
			for step in 400:
				var before := sky.clouds().map(func(c): return c["sprite"].position.x)
				sky._process(2.0)
				for i in sky.clouds().size():
					var after: float = sky.clouds()[i]["sprite"].position.x
					if after < before[i] and (before[i] < span.y or after + sky.clouds()[i]["sprite"].texture.get_width() > span.x):
						bad += 1
			check(bad == 0, "%s in %s weather: clouds go round only out of sight" % [place, weather])
			_close(s)


func test_overcast_brings_more_and_greyer_clouds() -> void:
	var shown := func(sky: SkyView): return sky.clouds().filter(func(c): return c["sprite"].modulate.a > 0.0).size()
	var s := _coast("open_bay", 12.0, "clear")
	var fine: int = shown.call(_sky())
	_close(s)
	s = _coast("open_bay", 12.0, "rain")
	var grey: int = shown.call(_sky())
	check(fine > 0 and grey > fine, "a grey day has more clouds than a fine one")
	_close(s)
	var clear := SkyPalette.at(12.0)
	var rain := SkyPalette.at(12.0, 1.0)
	var storm := SkyPalette.at(12.0, 1.0, 1.0)
	check(rain["light"].v < clear["light"].v - 0.1 and rain["zenith"].s < clear["zenith"].s, "rain clouds are greyer, under a greyer sky")
	check(storm["zenith"].v < rain["zenith"].v and storm["light"].v < rain["light"].v, "and a storm darker still")


func test_the_sky_follows_the_hour() -> void:
	check(SkyPalette.at(13.0)["zenith"].b > 0.7 and SkyPalette.at(1.0)["zenith"].v < 0.2, "blue at midday and dark at night")
	check(SkyPalette.at(19.0)["low"].r > SkyPalette.at(13.0)["low"].r * 0.95 and SkyPalette.at(19.0)["glow"].a > 0.5, "warm at dusk")
	check(is_nan(SkyPalette.sun_position(1.0, 0, 480, 106, 84).x) and not is_nan(SkyPalette.sun_position(12.0, 0, 480, 106, 84).x), "the sun is up by day only")
	check(SkyPalette.night_amount(1.0) == 1.0 and SkyPalette.night_amount(13.0) == 0.0, "the stars come out at night")
