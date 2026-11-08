extends "res://tests/test_case.gd"
## The title: the harbour at sunset built from the coast's own pieces, filling any window, before any game is loaded.


func _resize(size: Vector2i) -> void:
	Windowing.get_window().size = size
	Windowing._process(0.0)


func _title() -> Node:
	for c in Nav.ui.get_children():
		c.free()
	var s: Node = load(Nav.SCREENS["title"]).new()
	Nav.port.add_child(s)
	s.enter({})
	return s


func _close(s: Node) -> void:
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func _all(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out += _all(c)
	return out


func _textures(n: Node) -> Array:
	return _all(n).filter(func(k): return k is Sprite2D and k.texture != null).map(func(k): return str(k.texture.resource_path))


func _buttons() -> Array:
	return _all(Nav.ui).filter(func(k): return k is Button).map(func(k): return str(k.text))


func test_the_title_draws_no_mirrored_copy() -> void:
	var s := _title()
	var drawn := _all(s) + _all(Nav.sky)
	check(not drawn.any(func(n): return n is Backdrop), "no copy of a picture is laid round the view")
	check(not (_textures(s) + _textures(Nav.sky)).any(func(p): return p.begins_with("res://assets/art/title/")), "nothing is drawn from the old painted title")
	_close(s)


func test_the_title_is_the_harbour_at_sunset_from_the_coasts_own_pieces() -> void:
	var kept := Game.state
	Game.state = {}
	var s := _title()
	var drawn := _all(s)
	var used := _textures(s)
	for row in Data.places["harbour"]["layers"].filter(func(l): return l.has("file") and l.has("at")):
		check(("res://assets/art/" + str(row["file"])) in used, "the harbour's %s is on the title" % row["file"])
	for kind in [ParallaxLayers, WaterView, UnderLand, FloorView, Murk, Swimmers]:
		check(drawn.any(func(n): return is_instance_of(n, kind)), "the title has the coast's %s" % kind.get_global_name())
	var skies := _all(Nav.sky).filter(func(n): return n is SkyView and not n.is_queued_for_deletion())
	check(skies.size() == 1, "one live sky behind it, not %d" % skies.size())
	if skies.size() == 1:
		check(skies[0].hour >= 18.5 and skies[0].hour < SkyPalette.SUNSET, "the sky is at sunset, not %.1f" % skies[0].hour)
	var swimmers: Swimmers = drawn.filter(func(n): return n is Swimmers)[0]
	check(not swimmers.fish.is_empty(), "fish swim in the water")
	var was: Array = swimmers.fish.map(func(f): return f["pos"])
	for k in 10:
		s._process(0.1)
	check(swimmers.fish.any(func(f): return not f["pos"] in was), "and they move")
	_close(s)
	Game.state = kept


func test_the_title_fills_windows_of_every_shape_inside_the_harbour() -> void:
	var before := Windowing.get_window().size
	var s := _title()
	var width := float(Data.places["harbour"]["width"])
	for size in [Vector2i(1440, 810), Vector2i(1918, 1007), Vector2i(2400, 1500), Vector2i(1280, 1024), Vector2i(960, 540), Vector2i(2560, 1080), Vector2i(5120, 1440)]:
		_resize(size)
		var view := Nav.view()
		var cam: Vector2 = s.cam
		check(cam.x >= 0.0 and cam.x + view.x <= width, "%s: the view stays inside the harbour, so neither end of it shows" % size)
		check(cam.y >= CoastCamera.ROW_SEA - view.y and cam.y + view.y <= float(Data.places["harbour"]["depth"]) + 40.0, "%s: and no higher or lower than the game's camera goes" % size)
		check(is_equal_approx(-cam.y, 160.0 + Nav.offset().y), "%s: the waterline lies where the centred interface expects it" % size)
		var at: Vector2 = s.get_script().get_script_constant_map()["AT"]
		var centred := at.x + Nav.SIZE.x / 2.0 - view.x / 2.0
		check(is_equal_approx(cam.x, clampf(centred, 0.0, width - view.x)), "%s: the town is centred as far as the harbour allows" % size)
	_resize(before)
	_close(s)


func test_the_title_leaves_the_game_untouched() -> void:
	var kept := Game.state
	Game.state = {}
	var s := _title()
	for k in 20:
		s._process(0.1)
	check(Game.state.is_empty(), "with no game loaded, none is started")
	_close(s)
	Game.new_game("Test", "hound")
	Game.state["time"] = 123.4
	var held := var_to_str(Game.state)
	s = _title()
	for k in 20:
		s._process(0.1)
	check(var_to_str(Game.state) == held, "a game back at the title is left as it was")
	_close(s)
	Game.state = kept


func test_continue_and_load_find_the_saves() -> void:
	var kept := Game.state
	var slot := Saves.slot
	for n in range(1, Saves.SLOTS + 1):
		Saves.delete(n)
	Game.state = {}
	var s := _title()
	check(not "Continue" in _buttons() and not "Load" in _buttons(), "with no saves there is nothing to continue or load")
	check("New game" in _buttons() and "Settings" in _buttons() and "Quit" in _buttons(), "a new game, the settings and quitting are there")
	_close(s)
	Game.new_game("Saved", "hound")
	Saves.save(2)
	Game.state = {}
	s = _title()
	check("Continue" in _buttons() and "Load" in _buttons(), "a save is there to continue or load")
	check(s._latest_slot() == 2, "and Continue picks its slot")
	_close(s)
	Saves.delete(2)
	Saves.slot = slot
	Game.state = kept
