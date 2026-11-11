class_name SettingsPanel
## The settings: the volumes, the player's own music, the interface size, kilograms or pounds, full screen, gentle
## fishing, larger messages, old Rufus's guide, the tips and the desktop strip.


static func open() -> void:
	var list := Ui.window("Settings", 280, 290)
	for key in ["master", "music", "effects", "ambience"]:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		list.add_child(r)
		Ui.label(r, key.capitalize()).custom_minimum_size = Vector2(50, 0)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = float(Settings.get(key))
		slider.focus_mode = Control.FOCUS_NONE
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(slider)
		var amount := Ui.label(r, _percent(slider.value), "MutedLabel")
		amount.custom_minimum_size = Vector2(30, 0)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var k: String = key
		slider.value_changed.connect(func(v):
			amount.text = _percent(v)
			Settings.set_value(k, v))
	var own := HBoxContainer.new()
	own.name = "OwnMusic"
	own.add_theme_constant_override("separation", 3)
	list.add_child(own)
	Ui.label(own, "Your music").custom_minimum_size = Vector2(53, 0)
	Ui.button(own, "Open folder", func(): Audio.open_music_folder()).tooltip_text = "Songs you put in this folder play between the game's own."
	Ui.label(own, ".ogg, .mp3 or .wav", "MutedLabel").size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sizes := HBoxContainer.new()
	sizes.add_theme_constant_override("separation", 3)
	list.add_child(sizes)
	Ui.label(sizes, "Interface").custom_minimum_size = Vector2(53, 0)
	var group := ButtonGroup.new()
	for choice in [[-1, "Normal", "The usual size."], [0, "Larger", "A step larger, the size of the scene's own pixels."],
			[1, "Largest", "Larger still, while the window has room for it."]]:
		var step: int = choice[0]
		var b := Ui.button(sizes, choice[1], func(): Settings.set_value("interface_size", step))
		b.name = choice[1]
		b.toggle_mode = true
		b.button_group = group
		b.tooltip_text = choice[2]
		b.set_pressed_no_signal(Settings.interface_size == step)
	var units := HBoxContainer.new()
	units.add_theme_constant_override("separation", 3)
	list.add_child(units)
	Ui.label(units, "Weights").custom_minimum_size = Vector2(53, 0)
	var unit_group := ButtonGroup.new()
	for choice in [["metric", "Kilograms", "Fish weighed in kilograms."], ["imperial", "Pounds", "Fish weighed in pounds."]]:
		var u: String = choice[0]
		var b := Ui.button(units, choice[1], func(): Settings.set_value("units", u))
		b.name = choice[1]
		b.toggle_mode = true
		b.button_group = unit_group
		b.tooltip_text = choice[2]
		b.set_pressed_no_signal(Settings.units == u)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 3)
	list.add_child(gap)
	for key in [["fullscreen", "Full screen (F11)"], ["gentle", "Gentle fishing: lines never snap"], ["large_text", "Larger text for messages"], ["guide", "Old Rufus's advice for new players"], ["tooltips", "Tips when you point at a button"]]:
		var check := CheckBox.new()
		check.text = key[1]
		check.focus_mode = Control.FOCUS_NONE
		check.button_pressed = bool(Settings.get(key[0]))
		var k: String = key[0]
		check.toggled.connect(func(on):
			Audio.play("click", -8.0)
			if k == "fullscreen":
				if on != (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
					Settings.toggle_fullscreen()
			else:
				Settings.set_value(k, on))
		list.add_child(check)
	list.add_child(gap.duplicate())
	Ui.row(list, "The desktop strip (F10): the boat fishes on its own along the bottom of your screen.", "Strip", func():
		Ui.close_window()
		Windowing.set_strip(true))


static func _percent(v: float) -> String:
	return "%d%%" % int(roundf(v * 100.0))
