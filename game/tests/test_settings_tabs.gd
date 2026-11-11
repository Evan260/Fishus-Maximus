extends "res://tests/test_case.gd"
## The settings window: four tabs of rows, each with one On, Off or choice button, and keys that can be changed.


func _clear() -> void:
	for c in Nav.ui.get_children():
		c.free()


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Nav.get_viewport().push_input(e)


func _rows(tab: String) -> Array:
	SettingsPanel.tab = tab
	SettingsPanel.open()
	var page: Control = Nav.ui.get_node("Window").find_child(tab, true, false)
	return page.get_children().filter(func(r): return r is HBoxContainer).map(func(r): return r.get_child(0).text)


func test_the_settings_are_four_tabs_of_rows() -> void:
	_clear()
	var kept: String = SettingsPanel.tab
	SettingsPanel.open()
	var tabs: Array = Nav.ui.get_node("Window").find_children("*", "Button", true, false).filter(func(b): return b.toggle_mode).map(func(b): return b.text)
	check(tabs == ["Sound", "Display", "Gameplay", "Keys"], "the settings have the tabs Sound, Display, Gameplay and Keys: %s" % [tabs])
	check(_rows("Sound") == ["Everything", "Music", "Effects", "Ambience", "Your own music"], "Sound: the four volumes and your own music: %s" % [_rows("Sound")])
	var display := _rows("Display")
	check(display.slice(0, 3) == ["Interface size", "Full screen (F11)", "Weights"] and display[3].begins_with("Desktop strip (F10)"),
		"Display: the interface size, full screen, then the weights and the strip: %s" % [display])
	var play := _rows("Gameplay")
	check(play.slice(0, 3) == ["Old Rufus's advice for new players", "Tips when you point at a button", "Larger text for messages"],
		"Gameplay: old Rufus's advice, the tips and larger text first: %s" % [play])
	check("Gentle fishing: lines never snap" in play, "and gentle fishing")
	check(_rows("Keys").size() == Controls.ACTIONS.size(), "Keys: a row for every key")
	for t in SettingsPanel.TABS:
		_rows(t)
		check(Nav.ui.get_node("Window").find_children("*", "CheckBox", true, false).is_empty(), "%s has no tick boxes" % t)
	SettingsPanel.tab = kept
	_clear()


func test_a_key_can_be_changed() -> void:
	_clear()
	Controls.ensure()
	_rows("Keys")
	var button := func() -> Button: return Nav.ui.get_node("Window").find_child("row_left", true, false).get_child(1)
	check(button.call().text == "A", "rowing left is on A")
	button.call().pressed.emit()
	check(button.call().text == "Press a key...", "a click waits for a key")
	_key(KEY_ESCAPE)
	await Nav.get_tree().process_frame
	check(Ui.window_open() and Controls.key_for("row_left") == KEY_A and button.call().text == "A", "Escape keeps the old key and leaves the window open")
	button.call().pressed.emit()
	_key(KEY_J)
	await Nav.get_tree().process_frame
	check(Controls.key_for("row_left") == KEY_J and button.call().text == "J", "the next key pressed is the new one")
	var keys: Array = InputMap.action_get_events("row_left").filter(func(e): return e is InputEventKey).map(func(e): return e.physical_keycode)
	check(KEY_J in keys and KEY_LEFT in keys and not KEY_A in keys, "and it rows left, with the arrow key still working: %s" % [keys])
	var cfg := ConfigFile.new()
	Settings.write_to(cfg)
	check(int(cfg.get_value("keys", "row_left", 0)) == KEY_J, "and it is kept in the settings")
	Controls.rebind("row_left", KEY_A)
	check(not Settings.keys.has("row_left"), "a key put back to its own is no longer kept")
	_clear()
