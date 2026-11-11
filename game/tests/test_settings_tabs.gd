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
	var tabs: Array = Nav.ui.get_node("Window").find_children("*", "Button", true, false).filter(func(b): return b.toggle_mode and b.get_parent().name != "Languages").map(func(b): return b.text)
	check(tabs == ["Sound", "Display", "Gameplay", "Keys"], "the settings have the tabs Sound, Display, Gameplay and Keys: %s" % [tabs])
	check(_rows("Sound") == ["Everything", "Music", "Effects", "Ambience", "Your own music", "While you use other windows"], "Sound: the four volumes, your own music and the sound behind other windows: %s" % [_rows("Sound")])
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


func test_reduced_motion_larger_text_and_the_sound_behind_other_windows() -> void:
	_clear()
	var play := _rows("Gameplay")
	check(play.find("Reduced motion") == play.find("Larger text for messages") + 1, "Reduced motion follows Larger text: %s" % [play])
	check("Flash the taskbar when something needs you" in play, "and the taskbar can be flashed")
	var kept := [Settings.reduced_motion, Settings.background_sound, Settings.master]
	Settings.master = 0.8
	for quiet in [["full", 0.8], ["quieter", 0.2], ["muted", 0.0]]:
		Settings.background_sound = quiet[0]
		Windowing._focused = false
		Windowing._apply_volume()
		var db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
		check(absf(db - linear_to_db(maxf(0.0001, quiet[1]))) < 0.1, "behind other windows at %s the game plays at %s" % quiet)
	Windowing._focused = true
	Windowing._apply_volume()
	check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")) - linear_to_db(0.8)) < 0.1, "and at full volume again in front")
	Game.new_game("Still", "mutt")
	Settings.reduced_motion = true
	AchievementCard.show_earned("first_fish")
	var card: Control = Nav.ui.get_children().filter(func(c): return c.has_meta("achievement"))[0]
	check(card.position == card.get_meta("rest"), "with reduced motion a card appears where it rests, without sliding")
	card.free()
	CatchCard.show_catch("bream", 2.0, true)
	var hang: Control = CatchCard._open.get_node("Hang")
	check(hang.size.y == float(hang.get_meta("full")) and CatchCard._open.modulate.a == 1.0, "and the banner hangs at once, unfurled")
	CatchCard._open.free()
	Settings.reduced_motion = kept[0]
	Settings.background_sound = kept[1]
	Settings.master = kept[2]
	Settings.apply()
	_clear()


func test_an_achievement_card_stays_five_seconds_or_till_clicked() -> void:
	_clear()
	Game.new_game("Card", "mutt")
	check(AchievementCard.HOLD == 5.0, "a card stays five seconds")
	AchievementCard.show_earned("first_fish")
	var card: Control = Nav.ui.get_children().filter(func(c): return c.has_meta("achievement"))[0]
	var tw: Tween = card.get_meta("tween")
	tw.custom_step(4.0)
	check(not card.is_queued_for_deletion(), "and is still there after four")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	card.gui_input.emit(click)
	(card.get_meta("tween") as Tween).custom_step(1.0)
	check(card.is_queued_for_deletion(), "a click takes it away at once")
	_clear()


func test_a_controller_clicks_in_menus_and_casts_on_the_coast() -> void:
	_clear()
	var kept := Nav.current_name
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	Nav.current_name = "title"
	Pad._input(a)
	check(Pad.clicking, "on the title, A clicks like the mouse")
	a.pressed = false
	Pad._input(a)
	check(not Pad.clicking, "and lets go when A does")
	Nav.current_name = "coast"
	a.pressed = true
	Pad._input(a)
	check(not Pad.clicking, "on the coast with nothing under the pointer, A is left to cast")
	Ui.window("Test", 100, 60)
	Pad._input(a)
	check(Pad.clicking, "but with a window open it clicks")
	a.pressed = false
	Pad._input(a)
	check(InputMap.action_get_events("close_panel").any(func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_B),
		"and B closes the window or steps back")
	Nav.current_name = kept
	_clear()


func test_every_setting_is_kept_in_one_settings_file() -> void:
	var kept: Dictionary = Settings.strip.duplicate()
	Settings.strip = {"dock": "top", "strip_scale": 3, "focus_mode": true}
	var cfg := ConfigFile.new()
	Settings.write_to(cfg)
	check(cfg.get_value("strip", "dock") == "top" and int(cfg.get_value("strip", "strip_scale")) == 3, "the strip's settings go in settings.cfg")
	var fresh: Node = load("res://scripts/autoload/settings.gd").new()
	fresh.read_from(cfg)
	check(fresh.strip.get("dock") == "top" and bool(fresh.strip.get("focus_mode")), "and come back from it")
	fresh.free()
	Settings.strip = kept
