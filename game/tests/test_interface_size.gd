extends "res://tests/test_case.gd"
## The interface size setting: Smaller, Normal and Larger draw each interface pixel a whole number of window pixels,
## and everything hung on the interface still lines up with what it belongs to.

const SIZES := [Vector2i(1440, 810), Vector2i(1918, 1007), Vector2i(1920, 1080), Vector2i(1280, 800), Vector2i(2560, 1377), Vector2i(3840, 2066)]


func _resize(size: Vector2i) -> void:
	Windowing.get_window().size = size
	Windowing._process(0.0)


func _set_size(step: int) -> void:
	Settings.interface_size = step
	Windowing._fit()


func _clear() -> void:
	for c in Nav.ui.get_children():
		c.free()


func _coast() -> Node:
	_clear()
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	return s


## Where an interface rect is drawn in the window, in window pixels.
func _in_window(r: Rect2) -> Rect2:
	var frame: Control = Nav.port.get_parent()
	var v := Nav.from_ui(r)
	return Rect2(v.position * Nav.zoom + frame.position, v.size * Nav.zoom)


func _restore(before: Vector2i) -> void:
	_set_size(0)
	_resize(before)


func test_each_interface_size_draws_its_pixels_whole() -> void:
	var before := Windowing.get_window().size
	for size in SIZES:
		_resize(size)
		var zoom := Nav.zoom
		for step in [-1, 0, 1]:
			_set_size(step)
			var room := Vector2(size) / float(zoom + 1)
			var want := maxi(1, zoom + step)
			if step > 0 and (room.x < Nav.UI_LEAST.x or room.y < Nav.UI_LEAST.y):
				want = zoom
			check(Nav.ui_zoom == want, "%s at %d: the interface is %dx, not %dx" % [size, step, want, Nav.ui_zoom])
			var corner := _in_window(Rect2(Vector2(5, 7), Vector2(11, 3)))
			check(corner.position.is_equal_approx(Vector2(5, 7) * Nav.ui_zoom) and corner.size.is_equal_approx(Vector2(11, 3) * Nav.ui_zoom),
				"%s at %d: interface pixels start at the window's corner and are %d window pixels each, not %s" % [size, step, Nav.ui_zoom, corner])
			check(Nav.ui_view() == (Vector2(size) / float(Nav.ui_zoom)).floor(), "%s at %d: the interface fills the window, %s" % [size, step, Nav.ui_view()])
	_restore(before)


func test_smaller_and_larger_differ_from_normal_where_there_is_room() -> void:
	var before := Windowing.get_window().size
	_resize(Vector2i(2560, 1377))
	var zoom := Nav.zoom
	_set_size(-1)
	check(Nav.ui_zoom == zoom - 1, "Smaller draws the interface a step smaller than the game")
	_set_size(1)
	check(Nav.ui_zoom == zoom + 1, "Larger a step larger, while it has room")
	_resize(Vector2i(480, 270))
	_set_size(-1)
	check(Nav.ui_zoom == 1, "never smaller than one window pixel")
	_restore(before)


func test_the_boat_buttons_hang_from_the_window_corners_at_every_size() -> void:
	var before := Windowing.get_window().size
	var s := _coast()
	for size in [Vector2i(1440, 810), Vector2i(1920, 1080), Vector2i(2560, 1377)]:
		_resize(size)
		for step in [-1, 0, 1]:
			_set_size(step)
			var map := _in_window(s._sail.get_global_rect())
			var ashore := _in_window(s._ashore.get_global_rect())
			var gap := 4.0 * Nav.ui_zoom
			check(absf(map.position.x - gap) < 0.01 and absf(size.y - map.end.y - gap) < Nav.ui_zoom, "%s at %d: the map hangs at the bottom left, %s" % [size, step, map])
			check(absf(size.x - ashore.end.x - gap) < Nav.ui_zoom and absf(size.y - ashore.end.y - gap) < Nav.ui_zoom, "%s at %d: going ashore at the bottom right, %s" % [size, step, ashore])
	_clear()
	s.free()
	_restore(before)


func test_the_guide_points_at_the_map_at_every_size() -> void:
	var before := Windowing.get_window().size
	var s := _coast()
	for step in [-1, 0, 1]:
		_resize(Vector2i(2560, 1377))
		_set_size(step)
		check(s.guide_target("map") == s._sail.get_global_rect(), "at %d the map's place is where its picture is drawn" % step)
	_clear()
	s.free()
	_restore(before)


func test_the_town_guide_and_speech_follow_the_street_at_every_size() -> void:
	var before := Windowing.get_window().size
	_clear()
	Game.new_game("Test", "mutt")
	var s: Node = load(Nav.SCREENS["town"]).new()
	Nav.port.add_child(s)
	s.enter({})
	for step in [-1, 0, 1]:
		_resize(Vector2i(2560, 1377))
		_set_size(step)
		var r: Rect2 = s.guide_target("market")
		var middle: Vector2 = s._stage.transform.affine_inverse() * Nav.from_ui(r).get_center()
		check(s._building_at(middle) == "market" or s._masks["market"]["rect"].has_point(middle), "at %d the arrow's market is the market on the street" % step)
		var f: Dictionary = s._folk[0]
		f["x"] = 200.0
		s._process(0.0)
		s._gossip(f)
		var bubble: Control = Nav.ui.get_children().filter(func(c): return c.has_meta("speech"))[0]
		var head := Nav.to_ui(s.head_on_screen(f))
		check(bubble.position.y + bubble.size.y <= head.y + 1.0 and bubble.position.x <= head.x and bubble.position.x + bubble.size.x >= head.x,
			"at %d the bubble is over the speaker's head, %s over %s" % [step, Rect2(bubble.position, bubble.size), head])
	_clear()
	s.free()
	_restore(before)


func test_the_tackle_hangs_over_the_line_at_every_size() -> void:
	var before := Windowing.get_window().size
	var s := _coast()
	for step in [-1, 0, 1]:
		_resize(Vector2i(1920, 1080))
		_set_size(step)
		var line: Button = s.hud.method_buttons["line"]
		TacklePanel.open(line)
		var win: Control = Nav.ui.get_node("Window")
		var r := Rect2(win.position, win.size)
		check(r.end.y <= line.get_global_rect().position.y and r.end.y >= line.get_global_rect().position.y - 4.0, "at %d the tackle sits just over the line, %s" % [step, r])
		check(Rect2(Vector2.ZERO, Nav.ui_view()).encloses(r), "at %d and inside the interface" % step)
		Ui.close_window()
	_clear()
	s.free()
	_restore(before)


func test_a_window_too_big_for_a_larger_interface_is_drawn_smaller_to_fit() -> void:
	var before := Windowing.get_window().size
	_clear()
	Game.new_game("Test", "mutt")
	_resize(Vector2i(1920, 1080))
	_set_size(1)
	LogbookPanel.open()
	var win: Control = Nav.ui.get_node("Window")
	win.get_parent().propagate_notification(Control.NOTIFICATION_RESIZED)
	Ui.fit_window(win)
	var shown := Rect2(win.get_global_transform() * Vector2.ZERO, win.size * win.scale)
	check(Rect2(Vector2.ZERO, Nav.ui_view()).encloses(shown), "the logbook fits in the interface, %s in %s" % [shown, Nav.ui_view()])
	var px := win.scale.x * Nav.ui_zoom
	check(is_equal_approx(px, roundf(px)) and px >= 1.0, "drawn at whole window pixels, %s each" % px)
	Ui.close_window()
	_clear()
	_restore(before)


func test_the_strip_makes_room_for_its_controls_at_every_size() -> void:
	var before := Windowing.get_window().size
	_clear()
	Game.new_game("Test", "mutt")
	for step in [-1, 0, 1]:
		_set_size(step)
		Windowing.strip = true
		Windowing._fit()
		var c := StripControls.new()
		Nav.ui.add_child(c)
		c._refresh()
		var needed := c._info.size.x + c._bar.size.x + 16.0
		check(Windowing.strip_min_width * Nav.zoom >= needed * Nav.ui_zoom - 0.01, "at %d the strip is wide enough for its bars" % step)
		c.free()
		Windowing.strip = false
		Windowing._fit()
	_restore(before)


func test_the_settings_choose_the_interface_size() -> void:
	var before := Windowing.get_window().size
	_clear()
	_resize(Vector2i(2560, 1377))
	var zoom := Nav.zoom
	SettingsPanel.open()
	var win: Control = Nav.ui.get_node("Window")
	var larger: Button = win.find_child("Larger", true, false)
	var normal: Button = win.find_child("Normal", true, false)
	check(larger != null and normal != null and normal.button_pressed and not larger.button_pressed, "the settings offer the sizes, Normal chosen")
	larger.pressed.emit()
	check(Settings.interface_size == 1 and Nav.ui_zoom == zoom + 1, "choosing Larger draws the interface a step larger at once")
	win.find_child("Smaller", true, false).pressed.emit()
	check(Settings.interface_size == -1 and Nav.ui_zoom == zoom - 1, "and Smaller a step smaller")
	Ui.close_window()
	_clear()
	_restore(before)


func test_a_tip_is_drawn_at_the_interface_size() -> void:
	var before := Windowing.get_window().size
	_resize(Vector2i(2560, 1377))
	for step in [-1, 0, 1]:
		_set_size(step)
		var tip := PopupPanel.new()
		tip.theme_type_variation = "TooltipPanel"
		var words := Label.new()
		words.text = "A tip long enough to read"
		tip.add_child(words)
		Nav.ui.add_child(tip)
		tip.show()
		Nav.fit_tip(tip)
		check(tip.content_scale_factor == Nav.ui_zoom, "at %d the tip is drawn %dx like the interface, not %sx" % [step, Nav.ui_zoom, tip.content_scale_factor])
		check(tip.size.x >= words.get_combined_minimum_size().x * Nav.ui_zoom, "at %d and is wide enough for its words" % step)
		tip.free()
	_restore(before)
