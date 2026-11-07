class_name SettingsPanel
## The settings: the volumes, full screen, gentle fishing, larger messages, old Rufus's guide and the desktop strip.


static func open() -> void:
	var list := Ui.window("Settings", 280, 190)
	list.add_theme_constant_override("separation", 3)
	for key in ["master", "music", "effects"]:
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
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 3)
	list.add_child(gap)
	for key in [["fullscreen", "Full screen (F11)"], ["gentle", "Gentle fishing: lines never snap"], ["large_text", "Larger text for messages"], ["guide", "Old Rufus's advice for new players"]]:
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
