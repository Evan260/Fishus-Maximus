extends "res://tests/test_case.gd"
## The town's lamps: the goldsmith's lantern and the fish market's oil lamp light the street round them, glowing most at
## night and wavering like a flame, while the gold outline and the names over the buildings stay as bright as ever.


func _open(hour: float, weather := "clear") -> Node:
	Game.new_game("Test", "mutt")
	Game.state["time"] = Clock.at_hour(0.0, hour)
	Game.state["weather"] = weather
	var s: Node = load("res://scripts/town/town_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({})
	return s


func _close(s: Node) -> void:
	for c in Nav.ui.get_children():
		c.free()
	s.free()
	await Nav.get_tree().process_frame


## How brightly each lamp burns over two seconds, a sample every tenth of a second, lamp by lamp.
func _burning(s: Node) -> Array:
	var out := []
	for l in s.lamps:
		out.append([])
	for i in 20:
		s._process(0.1)
		for k in s.lamps.size():
			out[k].append(s.lamps[k].light.energy)
	return out


func _mean(values: Array) -> float:
	return values.reduce(func(a, b): return a + b, 0.0) / values.size()


func test_the_town_has_at_least_two_lamps() -> void:
	var s := _open(22.0)
	check(s.lamps.size() >= 2, "the goldsmith's lantern and at least one more light, %d found" % s.lamps.size())
	for l in s.lamps:
		check(l.light is PointLight2D and l.halo is Sprite2D, "each lights the street round it and glows itself")
		check(Rect2(Vector2.ZERO, Nav.SIZE).has_point(l.position), "and hangs in the scene, at %s" % l.position)
	await _close(s)


func test_each_lamp_hangs_at_a_lamp_painted_in_the_street() -> void:
	var s := _open(22.0)
	var street: Image = s._street.texture.get_image()
	for l in s.lamps:
		var warm := false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var c := street.get_pixelv(Vector2i(l.position + s.margin) + Vector2i(dx, dy))
				warm = warm or (c.r > 0.85 and c.r > c.b + 0.25 and c.get_luminance() > 0.55)
		check(warm, "the lamp at %s glows from a flame painted there" % l.position)
	await _close(s)


func test_the_lamps_burn_brighter_at_night_than_by_day() -> void:
	var s := _open(13.0)
	var day: Array = _burning(s)
	await _close(s)
	s = _open(22.0)
	var night: Array = _burning(s)
	await _close(s)
	s = _open(13.0, "rain")
	var rain: Array = _burning(s)
	await _close(s)
	for k in night.size():
		check(_mean(day[k]) > 0.0, "lamp %d burns faintly by day, %.2f" % [k, _mean(day[k])])
		check(_mean(night[k]) > 3.0 * _mean(day[k]),
			"and far brighter at night, %.2f against %.2f" % [_mean(night[k]), _mean(day[k])])
		check(_mean(rain[k]) > _mean(day[k]), "and brighter on a rainy day than a fine one")


func test_the_lamps_flicker() -> void:
	var s := _open(22.0)
	var night: Array = _burning(s)
	for k in night.size():
		var low: float = night[k].min()
		var high: float = night[k].max()
		check(high - low > 0.1 * _mean(night[k]), "lamp %d wavers like a flame, from %.2f to %.2f" % [k, low, high])
		var halo: Sprite2D = s.lamps[k].halo
		check(halo.modulate.a > 0.0, "and its halo glows")
	check(night.size() < 2 or night[0] != night[1], "and no two waver in step")
	await _close(s)


func test_the_lamplight_falls_on_the_street_and_not_on_the_outline() -> void:
	var s := _open(22.0)
	for l in s.lamps:
		var light: PointLight2D = l.light
		check(light.range_item_cull_mask & s._street.light_mask != 0, "the lamp lights the street")
		check(light.range_item_cull_mask & s._painter.light_mask == 0, "but not the gold outline and the names")
		check(not s._lit.is_ancestor_of(l.halo), "and its halo is not dimmed by the night")
	await _close(s)
