extends "res://tests/test_case.gd"
## The controller: its buttons pictured beside the hints while it is the input in use, and the lists in a window
## scrolled with the right stick or a page at a time with LB and RB.


func _clear() -> void:
	for c in Nav.ui.get_children():
		c.free()


func _frames(n: int) -> void:
	for k in n:
		await Engine.get_main_loop().process_frame


func test_every_button_the_game_names_has_a_picture() -> void:
	for p in Controls.PAD:
		check(Controls.glyph(p[0]) != null, "%s has a picture of its button" % p[0])
	check(Controls.glyph("method_trap") == null, "an action with no button has none")
	var text := Controls.fill_pad("Hold {cast}, row with {row_left} and {row_right}, pots with {method_trap}.")
	check(text.contains("[img") and text.contains("pad/a.png") and text.contains("pad/dpad_left.png"), "a lesson names the buttons as pictures: %s" % text)
	check(text.contains(Controls.key_name("method_trap")), "and an action with no button by its key")


func test_the_input_used_last_is_remembered() -> void:
	var before := Pad.active
	Pad.use_pad(false)
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_A
	b.pressed = true
	Pad._note_input(b)
	check(Pad.active, "a controller button makes the controller the input in use")
	var made := InputEventMouseMotion.new()
	made.device = Pad.DEVICE
	made.position = Vector2(500, 500)
	Pad._note_input(made)
	check(Pad.active, "the pointer moved by the stick does not count as the mouse")
	var moved := InputEventMouseMotion.new()
	moved.position = Pad._cursor + Vector2(40, 0)
	Pad._note_input(moved)
	check(not Pad.active, "the mouse moved by hand does")
	Pad._note_input(b)
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	Pad._note_input(key)
	check(not Pad.active, "and so does a key")
	Pad.use_pad(before)


func test_the_hints_show_the_buttons_while_the_controller_is_in_use() -> void:
	_clear()
	Game.new_game("Test", "mutt")
	var coast: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(coast)
	coast.enter({"place": "harbour"})
	Pad.use_pad(true)
	coast.hud.refresh()
	var badges := Nav.ui.find_children("PadBadge*", "TextureRect", true, false)
	check(badges.size() == 3 and badges.all(func(t): return t.visible), "the line, the net and fishing on his own show their buttons: %d" % badges.size())
	Pad.use_pad(false)
	coast.hud.refresh()
	check(badges.all(func(t): return not t.visible), "and hide them with the mouse")
	var note := GuideNote.find()
	if note:
		Pad.use_pad(true)
		note.refresh()
		check(not note.visible or note._rich.visible, "old Rufus writes the buttons as pictures")
		Pad.use_pad(false)
		note.refresh()
		check(not note._rich.visible, "and the keys again with the keyboard")
	coast.free()
	_clear()
	Game.state = {}


func test_the_keys_tab_shows_the_buttons() -> void:
	_clear()
	Pad.use_pad(true)
	SettingsPanel.tab = "Keys"
	SettingsPanel.open()
	var shown := Nav.ui.find_children("PadGlyph", "TextureRect", true, false)
	check(shown.size() == Controls.PAD.size(), "each action with a button shows it: %d of %d" % [shown.size(), Controls.PAD.size()])
	Ui.close_window()
	Pad.use_pad(false)
	_clear()


func test_a_window_scrolls_with_the_controller() -> void:
	_clear()
	SettingsPanel.tab = "Keys"
	SettingsPanel.open()
	await _frames(3)
	var list := Pad.scroll_target()
	check(list != null, "the keys tab has a list to scroll")
	if list:
		list.scroll_vertical = 0
		Pad.scroll(30.0)
		await _frames(1)
		check(list.scroll_vertical >= 29, "the right stick scrolls it: %d" % list.scroll_vertical)
		var page := InputEventJoypadButton.new()
		page.button_index = JOY_BUTTON_RIGHT_SHOULDER
		page.pressed = true
		var was := list.scroll_vertical
		Pad._input(page)
		await _frames(1)
		check(list.scroll_vertical > was, "RB scrolls it a page down")
		page.button_index = JOY_BUTTON_LEFT_SHOULDER
		was = list.scroll_vertical
		Pad._input(page)
		await _frames(1)
		check(list.scroll_vertical < was, "LB a page up")
	Ui.close_window()
	_clear()
	await _frames(1)
	check(Pad.scroll_target() == null, "with no window there is nothing to scroll")


func test_a_casts_on_the_coast_unless_the_pointer_is_on_a_button() -> void:
	_clear()
	Game.new_game("Test", "mutt")
	var coast: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(coast)
	coast.enter({"place": "harbour"})
	var was := Nav.current_name
	Nav.current_name = "coast"
	var panel := PanelContainer.new()
	var button := Button.new()
	check(not Pad.clicks_on(panel) and not Pad.clicks_on(null), "on the coast A casts over a panel or the water")
	check(Pad.clicks_on(button), "and clicks a button")
	Ui.window("Test")
	check(Pad.clicks_on(panel), "in a window it clicks anywhere")
	Ui.close_window()
	Nav.current_name = "town"
	check(Pad.clicks_on(panel), "and off the coast too")
	Nav.current_name = was
	panel.free()
	button.free()
	coast.free()
	_clear()
	Game.state = {}


func _press(button: JoyButton, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = down
	Input.parse_input_event(e)


func test_fishing_with_the_controller() -> void:
	_clear()
	Game.new_game("Test", "mutt")
	Game.state["guide"]["finished"] = true
	var coast: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(coast)
	var was := Nav.current_name
	Nav.current_name = "coast"
	coast.enter({"place": "harbour"})
	await _frames(5)
	_press(JOY_BUTTON_A, true)
	await _frames(20)
	_press(JOY_BUTTON_A, false)
	await _frames(40)
	check(coast.line_state() in ["waiting", "sinking"], "holding A and letting go casts: %s" % coast.line_state())
	var deep: float = coast.hook.y
	_press(JOY_BUTTON_DPAD_DOWN, true)
	await _frames(90)
	_press(JOY_BUTTON_DPAD_DOWN, false)
	check(coast.hook.y > deep, "the D-pad's down lets the bait sink")
	deep = coast.hook.y
	_press(JOY_BUTTON_DPAD_UP, true)
	await _frames(10)
	_press(JOY_BUTTON_DPAD_UP, false)
	check(coast.hook.y < deep, "and its up reels it in")
	coast._on_bite({"id": "mullet", "lb": 1.5, "state": "bit", "heading": 1.0})
	for k in 600:
		if coast.line_state() == "bite":
			break
		await _frames(1)
	_press(JOY_BUTTON_A, true)
	await _frames(2)
	check(coast.line_state() == "fighting", "A strikes a bite: %s" % coast.line_state())
	await _frames(2)
	_press(JOY_BUTTON_A, false)
	_press(JOY_BUTTON_LEFT_SHOULDER, true)
	await _frames(2)
	_press(JOY_BUTTON_LEFT_SHOULDER, false)
	check(coast.methods.method == "line", "LB picks the line")
	Pad.use_pad(false)
	Nav.current_name = was
	coast.free()
	_clear()
	Game.state = {}
