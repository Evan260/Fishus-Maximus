class_name SettingsPanel
## The settings: the volumes, full screen, gentle fishing, larger text and the desktop strip.


static func open() -> void:
	var list := Ui.window("Settings", 280, 200)
	for key in ["master", "music", "effects"]:
		var r := Ui.row(list, key.capitalize())
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = float(Settings.get(key))
		slider.custom_minimum_size = Vector2(110, 10)
		var k: String = key
		slider.value_changed.connect(func(v): Settings.set_value(k, v))
		r.add_child(slider)
	for key in [["fullscreen", "Full screen (F11)"], ["gentle", "Gentle fishing: lines never snap"], ["large_text", "Larger text"]]:
		var check := CheckBox.new()
		check.text = key[1]
		check.button_pressed = bool(Settings.get(key[0]))
		var k: String = key[0]
		check.toggled.connect(func(on): Settings.set_value(k, on))
		list.add_child(check)
	Ui.row(list, "The desktop strip (F10): the boat fishes on its own along the bottom of your screen.", "Strip", func():
		Ui.close_window()
		Windowing.set_strip(true))
