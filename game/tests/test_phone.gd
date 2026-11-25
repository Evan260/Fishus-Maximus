extends "res://tests/test_case.gd"
## Phones and tablets: the interface drawn as large as it fits, clear of the camera and the rounded corners, targets a
## fingertip across, and what a tap, a held finger, a slide and the back gesture do.


func _windowing() -> GDScript:
	return load("res://scripts/autoload/windowing.gd")


func test_phones_draw_the_interface_as_large_as_it_fits() -> void:
	var w := _windowing()
	check(w.phone_ui_zoom(Vector2i(2424, 1080), 0) == 4, "a 20:9 phone draws the interface at four times: %d" % w.phone_ui_zoom(Vector2i(2424, 1080), 0))
	check(w.phone_ui_zoom(Vector2i(2340, 1080), 0) == 4, "and so does a 19.5:9 one")
	check(w.phone_ui_zoom(Vector2i(2424, 1080), 2) == 4, "Larger can't push it past what fits")
	check(w.phone_ui_zoom(Vector2i(2424, 1080), -1) == 3, "Smaller still makes it smaller")
	check(w.phone_ui_zoom(Vector2i(1212, 540), 0) == 2, "the half-size preview keeps the phone's layout at two")
	check(w.phone_ui_zoom(Vector2i(2048, 1536), 0) == 4 and w.phone_ui_zoom(Vector2i(1024, 768), 0) == 2,
		"a 4:3 tablet and its half-size preview keep one layout")
	check(w.phone_ui_zoom(Vector2i(2560, 1600), 0) == 5, "a 16:10 tablet draws it at five")
	check(w.phone_ui_zoom(Vector2i(300, 200), 0) == 1, "and never under one")


func test_phone_corners_clear_the_camera_and_rounded_corners() -> void:
	var insets: Array = _windowing().phone_insets(Vector2i(2424, 1080), Rect2i(136, 0, 2288, 1080), 4)
	check(insets[0] == Vector2(34, 10), "the left clears the camera cutout and the top clears the corner: %s" % insets[0])
	check(insets[1] == Vector2(10, 10), "the right and bottom clear the rounded corners: %s" % insets[1])


func test_a_fingertip_is_about_seven_millimetres() -> void:
	var w := _windowing()
	check(w.touch_px_for(420.0, 4) == 29, "a Pixel 9a's fingertip is 29 interface pixels at four times: %d" % w.touch_px_for(420.0, 4))
	check(w.touch_px_for(420.0, 3) > w.touch_px_for(420.0, 4), "a smaller interface needs more of its pixels for the same finger")


func test_controls_hung_in_a_corner_keep_clear_of_it() -> void:
	var tl := Vector2(34, 10)
	var br := Vector2(10, 12)
	check(Ui.inset_for("top_left", tl, br) == Vector2(34, 10), "the top left corner moves in by the top left inset")
	check(Ui.inset_for("top_right", tl, br) == Vector2(10, 10), "the top right by the right and the top")
	check(Ui.inset_for("bottom_left", tl, br) == Vector2(34, 12), "the bottom left by the left and the bottom")
	check(Ui.inset_for("bottom_right", tl, br) == Vector2(10, 12), "the bottom right by the right and the bottom")
	check(Ui.inset_for("top", tl, br) == Vector2.ZERO and Ui.inset_for("bottom", tl, br) == Vector2.ZERO,
		"what is centred across stays where it is, away from the corners")


func test_a_finger_held_still_asks_rather_than_taps() -> void:
	check(not Touch.is_hold(0.2, 0.0, 30.0), "a quick touch is a tap")
	check(Touch.is_hold(0.5, 10.0, 30.0), "a finger resting in place for half a second is held")
	check(not Touch.is_hold(0.5, 60.0, 30.0), "a finger that slid away is not held")
	check(Touch.is_tap(5.0, 30.0, false), "a short touch that stayed put taps")
	check(not Touch.is_tap(5.0, 30.0, true), "lifting a held finger does not tap as well")
	check(not Touch.is_tap(60.0, 30.0, false), "a finger slid away does not tap")


func test_the_back_gesture_steps_back_one_place_at_a_time() -> void:
	check(Touch.back_step(true, "coast", true) == "close", "an open window closes before anything else")
	check(Touch.back_step(false, "town", false) == "leave", "the town steps back to the boat")
	check(Touch.back_step(false, "shore", false) == "leave" and Touch.back_step(false, "map", false) == "leave",
		"the pond and the bay map step back too")
	check(Touch.back_step(false, "coast", false) == "title", "the boat goes back to the title")
	check(Touch.back_step(false, "coast", true) == "stay", "but never with a fish on the line")
	check(Touch.back_step(false, "title", false) == "background", "and the title puts the game away")


func test_a_finger_on_the_water_reels_in_or_sets_the_bait_deeper() -> void:
	check(Touch.line_gesture(Vector2(3, 2), 8.0) == "tap", "a finger that stays put reels in")
	check(Touch.line_gesture(Vector2(4, 30), 8.0) == "depth", "one that slides down lowers the bait")
	check(Touch.line_gesture(Vector2(-2, -25), 8.0) == "depth", "and one that slides up raises it")
	check(Touch.line_gesture(Vector2(40, 6), 8.0) == "slide", "one that slides across does neither")
	check(Touch.bait_depth(40.0, 25.0, 120.0) == 65.0, "the bait follows the finger down")
	check(Touch.bait_depth(40.0, -60.0, 120.0) == 0.0, "no higher than the surface")
	check(Touch.bait_depth(100.0, 50.0, 120.0) == 120.0, "and no deeper than the seabed or the line allows")


func test_a_text_field_rises_above_the_keyboard() -> void:
	check(Touch.keyboard_lift(150.0, INF, 60.0) == 0.0, "no keyboard, no lift")
	check(Touch.keyboard_lift(150.0, 200.0, 60.0) == 0.0, "a field already above the keyboard stays")
	check(Touch.keyboard_lift(220.0, 140.0, 60.0) == 58.0, "a hidden field rises until the window reaches the top")
	check(Touch.keyboard_lift(180.0, 140.0, 80.0) == 44.0, "and no further than it shows above the keyboard")


func test_small_things_are_a_fingertip_to_tap() -> void:
	var r := Touch.finger_rect(Rect2(100, 50, 10, 40), 29.0)
	check(r.size == Vector2(29, 40) and r.get_center() == Vector2(105, 70), "a narrow target widens about its middle: %s" % r)
	check(Touch.finger_rect(Rect2(0, 0, 40, 40), 29.0) == Rect2(0, 0, 40, 40), "a big one stays as it is")
	check(Touch.finger_rect(Rect2(0, 0, 10, 10), 0.0) == Rect2(0, 0, 10, 10), "and nothing changes on a computer")


func test_the_map_finds_the_pin_under_a_finger() -> void:
	var pins := {"harbour": Vector2(100, 100), "capri": Vector2(130, 100)}
	check(BayMap.pin_at(Vector2(104, 102), pins, 9.0) == "harbour", "a pin under the pointer")
	check(BayMap.pin_at(Vector2(113, 100), pins, 9.0) == "", "a mouse must be on the pin")
	check(BayMap.pin_at(Vector2(113, 100), pins, 15.0) == "harbour", "a finger reaches further")
	check(BayMap.pin_at(Vector2(116, 100), pins, 20.0) == "capri", "and takes the nearer of two pins it reaches")


## The window's size before a test laid it out as a phone, given back afterwards.
var _window := Vector2i.ZERO


## Lays the game out as the half-size preview of a 20:9 phone, or puts the computer's layout back.
func _phone(on: bool) -> void:
	if on and not Windowing.phone:
		_window = Windowing.get_window().size
	Windowing.phone = on
	Windowing.phone_preview = on
	Windowing.get_window().size = Vector2i(1212, 540) if on else _window
	Windowing._fit()


func _clear() -> void:
	for c in Nav.ui.get_children():
		c.free()


func _frames(n: int) -> void:
	for k in n:
		await Engine.get_main_loop().process_frame


## Presses or lets go of the mouse at a point in interface pixels, as a phone does for a finger, with no move first.
func _touch(at: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = Nav.ui_to_window(at)
	e.global_position = e.position
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Nav.get_viewport().push_input(e)


func _coast() -> Node:
	_clear()
	Game.new_game("Test", "mutt")
	Game.state["guide"]["finished"] = true
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	return s


func _done(s: Node) -> void:
	_clear()
	s.free()


func test_a_phone_sizes_its_buttons_for_a_fingertip() -> void:
	_phone(true)
	var finger := Windowing.touch_px()
	check(finger == 29, "the preview's fingertip is a Pixel 9a's: %d" % finger)
	check(Nav.ui_zoom == 2 and Nav.ui_view() == Vector2(606, 270), "the half-size preview lays out a 20:9 phone's interface: %dx, %s" % [Nav.ui_zoom, Nav.ui_view()])
	var list := Ui.window("Test", 200, 120)
	var b := Ui.button(list, "Go", func(): pass)
	await _frames(2)
	check(b.size.y >= finger and b.size.x >= finger, "a button is a fingertip each way: %s" % b.size)
	var close: Button = Nav.ui.get_node("Window").find_child("Close", true, false)
	check(close.size.x >= finger and close.size.y >= finger, "and so is a window's close button: %s" % close.size)
	var tab := Ui.tab_button(Ui.tab_row(list), "Tab", false, func(): pass)
	await _frames(1)
	check(tab.size.y >= finger, "and a closed tab: %s" % tab.size)
	_clear()
	_phone(false)
	var plain := Ui.button(Nav.ui, "Go", func(): pass)
	await _frames(1)
	check(plain.size.y < 24.0, "a computer's buttons keep their own size: %s" % plain.size)
	_clear()


func test_a_phone_keeps_the_corners_clear() -> void:
	_phone(true)
	var s := _coast()
	await _frames(2)
	var room := Nav.ui_view()
	for name in ["BayMap", "Menu", "InfoPanel"]:
		var c: Control = Nav.ui.find_child(name, true, false)
		var r := c.get_global_rect()
		check(r.position.x >= 4.0 + Windowing.safe_top_left.x - 0.5 and r.end.x <= room.x - 4.0 - Windowing.safe_bottom_right.x + 0.5
			and r.position.y >= 4.0 + Windowing.safe_top_left.y - 0.5 and r.end.y <= room.y - 4.0 - Windowing.safe_bottom_right.y + 0.5,
			"%s keeps clear of the rounded corners: %s in %s" % [name, r, room])
	check(Windowing.safe_top_left.y >= 9.0, "and the corners are cleared by a few millimetres: %s" % Windowing.safe_top_left)
	_done(s)
	_phone(false)


func test_a_phone_rows_with_arrows_on_the_screen() -> void:
	_phone(true)
	var s := _coast()
	await _frames(2)
	var right: Button = Nav.ui.find_child("RowRight", true, false)
	var left: Button = Nav.ui.find_child("RowLeft", true, false)
	check(right != null and left != null, "the boat has an arrow to row each way")
	if right != null:
		check(right.size.x >= Windowing.touch_px() and right.size.y >= Windowing.touch_px(), "each a fingertip across: %s" % right.size)
		var was: float = s.boat_x
		_touch(right.get_global_rect().get_center(), true)
		for i in 10:
			s._process(0.05)
		check(s.boat_x > was + 5.0, "holding the right arrow rows right: %s to %s" % [was, s.boat_x])
		var held: float = s.boat_x
		_touch(right.get_global_rect().get_center(), false)
		for i in 5:
			s._process(0.05)
		check(is_equal_approx(s.boat_x, held), "and lifting the finger stops the boat")
	_done(s)
	_phone(false)
	s = _coast()
	check(Nav.ui.find_child("RowRight", true, false) == null, "a computer rows with its keys and has no arrows")
	_done(s)


func test_a_finger_on_the_water_sets_the_bait_or_reels_in() -> void:
	_phone(true)
	var s := _coast()
	s.cast(0.5)
	for i in 600:
		s.sink(0.05)
	s.flight = 0.0
	s._state = "waiting"
	var water := Vector2(Nav.ui_view().x / 2.0, Nav.ui_view().y * 0.7)
	var deep: float = s.hook.y
	_touch(water, true)
	s._process(0.05)
	_slide(water + Vector2(0, -30))
	s._process(0.05)
	check(s.hook.y < deep - 20.0, "sliding a finger up the water raises the bait: %s from %s" % [s.hook.y, deep])
	_touch(water + Vector2(0, -30), false)
	s._process(0.05)
	check(s.line_state() == "waiting", "and lifting it leaves the line in, not reeled in: %s" % s.line_state())
	_touch(water, true)
	s._process(0.05)
	check(s.line_state() == "waiting", "a finger on the water does not reel in until it lifts")
	_touch(water, false)
	s._process(0.05)
	check(s.line_state() == "reeling", "a tap reels in when the finger lifts: %s" % s.line_state())
	_done(s)
	_phone(false)


## Moves a held finger to a point in interface pixels.
func _slide(to: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = Nav.ui_to_window(to)
	m.global_position = m.position
	m.button_mask = MOUSE_BUTTON_MASK_LEFT
	Nav.get_viewport().push_input(m)


func test_a_held_finger_reads_a_button_without_pressing_it() -> void:
	_phone(true)
	var s := _coast()
	await _frames(2)
	var pots: Button = s.hud.method_buttons["trap"]
	_touch(pots.get_global_rect().get_center(), true)
	await _frames(1)
	Tips._process(Touch.HOLD_SECONDS + 0.05)
	check(Tips.shown() and Tips.long_press, "a finger held on the pots shows what they do")
	_touch(pots.get_global_rect().get_center(), false)
	await _frames(1)
	check(s.methods.method == "line", "and lifting it does not pick them")
	_touch(pots.get_global_rect().get_center(), true)
	await _frames(1)
	_touch(pots.get_global_rect().get_center(), false)
	await _frames(1)
	check(s.methods.method == "trap", "while a tap does")
	_done(s)
	_phone(false)


func test_a_phone_leaves_out_the_computers_settings() -> void:
	_phone(true)
	_clear()
	var kept: String = SettingsPanel.tab
	SettingsPanel.tab = "Sound"
	SettingsPanel.open()
	var tabs: Array = Nav.ui.get_node("Window").find_children("*", "Button", true, false).filter(func(b): return b.toggle_mode and b.get_parent().name != "Languages").map(func(b): return b.text)
	check(tabs == ["Sound", "Display", "Gameplay"], "a phone has no keys to change: %s" % [tabs])
	var rows := func(tab: String) -> Array:
		SettingsPanel.tab = tab
		SettingsPanel.open()
		var page: Control = Nav.ui.get_node("Window").find_child(tab, true, false)
		return page.get_children().filter(func(r): return r is HBoxContainer).map(func(r): return r.get_child(0).text)
	check(rows.call("Sound") == ["Everything", "Music", "Effects", "Ambience"], "Sound has the volumes alone: %s" % [rows.call("Sound")])
	check(rows.call("Display") == ["Interface size", "Weights"], "Display has no window, full screen or strip: %s" % [rows.call("Display")])
	var play: Array = rows.call("Gameplay")
	check("Tips when you hold a finger on a button" in play and not "Tips when you point at a button" in play, "the tips come from a held finger: %s" % [play])
	check(not "Flash the taskbar when something needs you" in play, "and there is no taskbar to flash")
	SettingsPanel.tab = kept
	_clear()
	_phone(false)


func test_a_phone_links_the_privacy_policy_in_the_settings() -> void:
	_clear()
	var kept: String = SettingsPanel.tab
	var opener: Callable = SettingsPanel.open_url
	var opened := []
	SettingsPanel.open_url = func(url: String) -> void: opened.append(url)
	SettingsPanel.tab = "Gameplay"
	SettingsPanel.open()
	check(_privacy_link() == null, "a computer's settings look as they always have, with no privacy policy")
	_phone(true)
	_clear()
	SettingsPanel.open()
	var link := _privacy_link()
	check(link != null and link.text == "Open", "a phone's gameplay settings link the privacy policy, as the stores ask")
	if link:
		link.pressed.emit()
	check(opened == ["https://evan260.github.io/slowsunday/privacy.html"], "which opens the policy's page: %s" % [opened])
	SettingsPanel.open_url = opener
	SettingsPanel.tab = kept
	_clear()
	_phone(false)


## The button on the settings row named Privacy policy, or null without one.
func _privacy_link() -> Button:
	for r in Nav.ui.get_node("Window").find_child("Gameplay", true, false).get_children():
		if r is HBoxContainer and r.get_child(0) is Label and r.get_child(0).text == "Privacy policy":
			return r.get_child(1)
	return null


func test_a_phone_title_has_no_quit() -> void:
	_phone(true)
	_clear()
	var t: Node = load(Nav.SCREENS["title"]).new()
	Nav.port.add_child(t)
	t.enter({})
	var words := Nav.ui.find_children("*", "Button", true, false).map(func(b): return b.text)
	check(not "Quit" in words and "Settings" in words, "a phone game is put away, not quit: %s" % [words])
	_clear()
	t.free()
	_phone(false)


func test_the_map_sails_where_a_finger_lifts() -> void:
	_phone(true)
	_clear()
	Game.new_game("Test", "mutt")
	var map: Node = load(Nav.SCREENS["map"]).new()
	Nav.port.add_child(map)
	map.enter({})
	await _frames(1)
	var pin: Vector2 = map._stage.get_global_transform_with_canvas() * map._pin("rocky_shore")
	_touch(Nav.to_ui(pin + Vector2(12, 0)), true)
	map._process(0.05)
	check(map._hover == "", "a finger that has just touched names nothing yet")
	_touch(Nav.to_ui(pin + Vector2(12, 0)), false)
	var why := BayMap.locked_reason(Game.state, "rocky_shore")
	check(why != "" and Nav.ui.find_children("*", "Label", true, false).any(func(l): return l.text == why),
		"a tap a fingertip's half beside a locked pin says why it is locked: %s" % why)
	_clear()
	map.free()
	_phone(false)


func test_the_back_gesture_closes_then_steps_back() -> void:
	_phone(true)
	var s := _coast()
	var before := [Nav.current, Nav.current_name]
	Nav.current = s
	Nav.current_name = "coast"
	Ui.window("Test", 200, 100)
	check(Nav.back_gesture() == "close" and not Ui.window_open(), "the back gesture closes an open window first")
	s._state = "fighting"
	check(Nav.back_gesture() == "stay", "and with a fish on the line it stays")
	Nav.current = before[0]
	Nav.current_name = before[1]
	_done(s)
	_phone(false)


func test_a_phone_is_saved_and_silent_when_put_away() -> void:
	_phone(true)
	Windowing._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")) < -60.0, "a phone game put away is silent")
	Windowing._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")) > -20.0, "and its sound comes back with it")
	check(Saves.saves_when(Node.NOTIFICATION_APPLICATION_PAUSED, true) and Saves.saves_when(Node.NOTIFICATION_APPLICATION_FOCUS_OUT, true),
		"a phone saves as soon as it is put away, since it may close the game without warning")
	check(not Saves.saves_when(Node.NOTIFICATION_APPLICATION_FOCUS_OUT, false), "a computer saves on its own clock and when closed")
	_phone(false)


func test_a_phones_logbook_tabs_are_a_fingertip_tall_and_scroll() -> void:
	_phone(true)
	_clear()
	Game.new_game("Test", "mutt")
	LogbookPanel.open(0)
	await _frames(2)
	var marks := Nav.ui.get_node("Window").find_children("*", "Button", true, false).filter(func(b): return b.get_parent().name == "Bookmarks")
	var finger := Windowing.touch_px()
	check(marks.size() == LogbookPanel._sections().size() and marks.all(func(b): return b.size.y >= finger), "every bookmark is a fingertip tall: %d of them" % marks.size())
	var list: Node = marks[0].get_parent().get_parent() if not marks.is_empty() else null
	check(list is ScrollContainer, "and they scroll beside the book rather than making it taller")
	var win: Control = Nav.ui.get_node("Window")
	check(Rect2(Vector2.ZERO, Nav.ui_view()).encloses(win.get_global_rect()) and is_equal_approx(win.scale.x, 1.0),
		"the logbook fits the phone at full size: %s in %s" % [win.get_global_rect(), Nav.ui_view()])
	_clear()
	_phone(false)


func test_a_text_field_shows_above_the_phone_keyboard() -> void:
	_phone(true)
	_clear()
	var list := Ui.window("Name", 200, 160)
	for i in 4:
		Ui.label(list, "Line")
	var field := LineEdit.new()
	list.add_child(field)
	await _frames(2)
	field.grab_focus()
	var win: Control = Nav.ui.get_node("Window")
	var top := win.get_global_rect().position.y
	Ui.lift_for_keyboard(Nav.ui_view().y * 0.55)
	check(field.get_global_rect().end.y <= Nav.ui_view().y * 0.55 and win.get_global_rect().position.y < top,
		"the window rises until the field shows above the keyboard: %s" % field.get_global_rect())
	Ui.lift_for_keyboard(INF)
	check(is_equal_approx(win.get_global_rect().position.y, top), "and settles back when the keyboard goes")
	_clear()
	_phone(false)

func test_a_phone_keeps_the_street_where_people_walk() -> void:
	_phone(true)
	_clear()
	Game.new_game("Test", "mutt")
	var town: Node = load(Nav.SCREENS["town"]).new()
	Nav.world.add_child(town)
	town.enter({})
	var feet: Vector2 = town._stage.transform * Vector2(240, town.STREET_Y + 4.0)
	check(feet.y <= Nav.view().y, "a 20:9 phone crops the town's sky rather than its street: feet at %s in %s" % [feet, Nav.view()])
	var t: Transform2D = town._stage.transform
	var top_left: Vector2 = t * -town.margin
	var bottom_right: Vector2 = t * (Nav.SIZE + town.margin)
	check(top_left.x <= 0.0 and top_left.y <= 0.0 and bottom_right.x >= Nav.view().x and bottom_right.y >= Nav.view().y,
		"and the street's picture still reaches every edge: %s to %s" % [top_left, bottom_right])
	town.free()
	_clear()
	_phone(false)


func test_a_phones_window_grows_to_show_what_it_holds() -> void:
	_phone(true)
	_clear()
	var list := Ui.window("Many", 240, 120)
	for i in 6:
		Ui.button(list, "Line %d" % i, func(): pass)
	await _frames(3)
	var win: Control = Nav.ui.get_node("Window")
	var scroll: ScrollContainer = win.get_meta("list")
	check(scroll.size.y >= list.size.y - 0.5, "the list shows whole: %s of %s" % [scroll.size.y, list.size.y])
	check(Rect2(Vector2.ZERO, Nav.ui_view()).encloses(win.get_global_rect()), "and the window stays on the screen: %s" % win.get_global_rect())
	_clear()
	_phone(false)