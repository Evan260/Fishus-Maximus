extends "res://tests/test_case.gd"

const PLANTS := ["seagrass.png", "tuft.png", "kelp.png", "fans.png", "reeds.png", "seapens.png"]


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


func _close(s: Node) -> void:
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func _layers(s: Node) -> ParallaxLayers:
	return s.get("_layers")


func _sky(s: Node) -> SkyView:
	return s.get("_sky")


func test_the_sea_mirrors_the_sky_of_the_hour() -> void:
	for hour in [7.0, 12.0, 19.0, 23.0]:
		var s := _coast("open_bay", hour)
		var look := _sky(s).look()
		var waters: Array = _layers(s).bands() + _layers(s).reflections()
		check(waters.all(func(w): return w.material.get_shader_parameter("low") == look["low"] and w.material.get_shader_parameter("zenith") == look["zenith"]),
			"at %d o'clock every band of sea and the sea under the land have the sky's colours" % hour)
		_close(s)


func test_a_storm_greys_the_sea() -> void:
	var clear := _coast("harbour", 12.0)
	var blue: Color = _layers(clear).bands()[0].material.get_shader_parameter("middle")
	_close(clear)
	var storm := _coast("harbour", 12.0, "storm")
	var grey: Color = _layers(storm).bands()[0].material.get_shader_parameter("middle")
	check(grey.s < blue.s * 0.6 and grey.v < blue.v, "under a storm the sea mirrors a grey, darker sky")
	_close(storm)


func test_the_suns_path_follows_the_sun() -> void:
	var xs: Array = []
	for hour in [8.0, 12.0, 18.0]:
		var s := _coast("open_bay", hour)
		var sun: Vector2 = _sky(s).look()["sun"]
		var band: Node2D = _layers(s).bands()[0]
		check(band.material.get_shader_parameter("sun") == sun, "at %d o'clock the path lies below the sun itself" % hour)
		check(band.material.get_shader_parameter("sun_colour") == Color(_sky(s).look()["sun_colour"], 1.0), "in the sun's own colour")
		check(band.material.get_shader_parameter("sun_light") > 0.5, "and sparkles on a clear day")
		xs.append(sun.x)
		_close(s)
	check(xs[0] < xs[1] and xs[1] < xs[2], "it moves across the sea with the sun through the day")
	var grey := _coast("open_bay", 12.0, "cloudy")
	check(_layers(grey).bands()[0].material.get_shader_parameter("sun_light") < 0.3, "and fades when it is overcast")
	_close(grey)


func test_the_night_sea_has_the_moons_path() -> void:
	var s := _coast("open_bay", 23.0)
	var band: Node2D = _layers(s).bands()[0]
	check(band.material.get_shader_parameter("sun_light") == 0.0, "no sun at night")
	check(band.material.get_shader_parameter("moon_light") > 0.0 and band.material.get_shader_parameter("moon") == _sky(s).look()["moon"], "the moon lays its path below it")
	_close(s)


func test_layers_slide_by_fractions_of_a_pixel() -> void:
	var layers := ParallaxLayers.new()
	Nav.port.add_child(layers)
	layers.build(Data.places["harbour"]["layers"])
	layers.place(Vector2(101.0, CoastCamera.HOME_Y))
	var far: Node2D = layers.bands()[0]
	check(is_equal_approx(far.position.x, -101.0 * 0.12), "a slow layer moves a fraction of a pixel at a time, so it glides")
	layers.free()


func test_every_sea_plant_sways() -> void:
	for p in Data.places.values():
		var plants: Array = p["layers"].filter(func(l): return PLANTS.has(str(l.get("file", "")).get_file()))
		check(plants.all(func(l): return l.get("sway", false)), p["id"] + ": its sea plants sway")
		check(p["layers"].all(func(l): return not l.get("sway", false) or plants.has(l)), p["id"] + ": and nothing else does")
		var layers := ParallaxLayers.new()
		Nav.port.add_child(layers)
		layers.build(p["layers"])
		check(layers.swaying().size() == plants.size(), p["id"] + ": each plant is drawn swaying")
		for s in layers.swaying():
			var used: Rect2i = s.texture.get_image().get_used_rect()
			check(s.material.get_shader_parameter("root") == float(used.end.y) and s.material.get_shader_parameter("top") == float(used.position.y),
				p["id"] + ": a plant is still at its roots and sways most at its tips")
		var phases := layers.swaying().map(func(s): return s.material.get_shader_parameter("phase"))
		check(phases.size() < 2 or phases.any(func(ph): return ph != phases[0]), p["id"] + ": the plants sway out of step")
		layers.free()


func test_the_art_specs_keep_the_sway() -> void:
	var specs := ProjectSettings.globalize_path("res://").path_join("../tools/art/places/")
	for p in Data.places.values():
		var spec = JSON.parse_string(FileAccess.get_file_as_string(specs + p["id"] + ".json"))
		check(spec is Dictionary, p["id"] + ": has a spec")
		if not spec is Dictionary:
			continue
		var swaying := func(layers: Array) -> Array:
			return layers.filter(func(l): return l.get("sway", false)).map(func(l): return str(l["file"]).get_file())
		var want: Array = swaying.call(p["layers"])
		var have: Array = swaying.call(spec["layers"])
		want.sort()
		have.sort()
		check(want == have, p["id"] + ": the plants marked swaying in places.json are marked in its spec, so painting it again keeps them")
