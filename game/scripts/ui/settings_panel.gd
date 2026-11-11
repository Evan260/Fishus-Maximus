class_name SettingsPanel
## Settings in four tabs, Sound, Display, Gameplay and Keys, opened from the title and the boat. Each row names a
## setting on the left and has one button on the right: On or Off, or the choice it is at, which a click steps on.

const TABS := ["Sound", "Display", "Gameplay", "Keys"]
const UI_SIZES := {-1: "Smaller", 0: "Normal", 1: "Larger", 2: "Largest"}
## The page's width, and its height, so changing tab never makes the window jump.
const WIDTH := 270.0
const PAGE := 168.0

## The tab last open, shown again the next time the window opens.
static var tab := "Sound"
## The action waiting for a new key on the Keys tab, or "".
static var _waiting := ""
static var _scroll: ScrollContainer


static func open() -> void:
	var kept := _scroll.scroll_vertical if is_instance_valid(_scroll) and Ui.window_open() and is_settings_open() else 0
	var col := Ui.frame("Settings", WIDTH + 24.0, PAGE + 52.0)
	Nav.ui.get_node("Window").set_meta("settings", true)
	var tabs := Ui.tab_row(col)
	for t in TABS:
		Ui.tab_button(tabs, t, t == tab, func():
			tab = t
			_waiting = ""
			open())
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(WIDTH + 8.0, PAGE)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_right", 6)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(margin)
	var page := VBoxContainer.new()
	page.name = tab
	page.add_theme_constant_override("separation", 3)
	margin.add_child(page)
	match tab:
		"Sound":
			_sound(page)
		"Display":
			_display(page)
		"Gameplay":
			_gameplay(page)
		_:
			_keys(page)
	_scroll.set_deferred("scroll_vertical", kept)


static func is_settings_open() -> bool:
	return Ui.window_open() and Nav.ui.get_node("Window").has_meta("settings")


## Shows a change made from outside the window, such as F11, while the window is open.
static func refresh() -> void:
	if is_settings_open():
		open()


static func waiting_for_key() -> bool:
	return _waiting != "" and is_settings_open()


static func _sound(page: VBoxContainer) -> void:
	for bus in [["master", "Everything"], ["music", "Music"], ["effects", "Effects"], ["ambience", "Ambience"]]:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		page.add_child(r)
		Ui.label(r, bus[1]).custom_minimum_size = Vector2(70, 0)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = float(Settings.get(bus[0]))
		slider.focus_mode = Control.FOCUS_NONE
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(slider)
		var amount := Ui.label(r, _percent(slider.value), "MutedLabel")
		amount.custom_minimum_size = Vector2(30, 0)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var key: String = bus[0]
		slider.value_changed.connect(func(v):
			amount.text = _percent(v)
			Settings.set_value(key, v))
	var own := Ui.setting(page, "Your own music", "Open folder", func(): Audio.open_music_folder(), WIDTH)
	own.get_parent().name = "OwnMusic"
	Ui.tip_on(own, "Music you put in this folder (.ogg, .mp3 or .wav) plays between the game's own tracks.")


static func _display(page: VBoxContainer) -> void:
	Ui.setting(page, "Interface size", UI_SIZES.get(Settings.ui_scale_step, "Normal"), func():
		Settings.set_value("ui_scale_step", Settings.next_ui_step(Settings.ui_scale_step))
		open(), WIDTH).get_parent().name = "InterfaceSize"
	Ui.on_off(page, "Full screen (F11)", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,
		func(): Settings.toggle_fullscreen(), WIDTH)
	Ui.setting(page, "Weights", "Kilograms" if Settings.units == "metric" else "Pounds", func():
		Settings.set_value("units", "imperial" if Settings.units == "metric" else "metric")
		open(), WIDTH).get_parent().name = "Weights"
	var strip := Ui.on_off(page, TranslationServer.translate("Desktop strip (%s)") % Controls.key_name("toggle_strip"), Windowing.strip, func():
		Ui.close_window()
		Windowing.set_strip(not Windowing.strip), WIDTH)
	Ui.tip_on(strip, "The boat fishes on its own along the bottom of your screen.")


static func _gameplay(page: VBoxContainer) -> void:
	_toggle(page, "Old Rufus's advice for new players", "guide")
	_toggle(page, "Tips when you point at a button", "tooltips")
	_toggle(page, "Larger text for messages", "large_text")
	_toggle(page, "Gentle fishing: lines never snap", "gentle")


static func _toggle(page: VBoxContainer, text: String, key: String) -> void:
	var on := bool(Settings.get(key))
	Ui.on_off(page, text, on, func():
		Settings.set_value(key, not on)
		open(), WIDTH).get_parent().name = key


static func _keys(page: VBoxContainer) -> void:
	for action in Controls.ACTIONS:
		var a: String = action
		var text := "Press a key..." if _waiting == a else Controls.key_name(a)
		var b := Ui.setting(page, Controls.ACTIONS[a]["name"], text, func():
			_waiting = a
			open(), WIDTH)
		b.get_parent().name = a
		# A key's name is the same in every language, so it is never looked up as words to translate.
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED if _waiting != a else Node.AUTO_TRANSLATE_MODE_INHERIT
	page.add_child(KeyCatcher.new())
	Ui.label(page, "The arrow keys and a controller work too.", "MutedLabel")


static func _stop_waiting() -> void:
	_waiting = ""
	open()


static func _percent(v: float) -> String:
	return "%d%%" % int(roundf(v * 100.0))


## Takes the next key pressed while an action on the Keys tab waits for one. Escape keeps the old key, except for
## closing a window or going back, whose usual key Escape is.
class KeyCatcher extends Node:
	var _caught := false

	func _input(event: InputEvent) -> void:
		if _caught or SettingsPanel._waiting == "" or not (event is InputEventKey and event.pressed and not event.echo):
			return
		_caught = true
		get_viewport().set_input_as_handled()
		var action := SettingsPanel._waiting
		if event.physical_keycode != KEY_ESCAPE or action == "close_panel":
			Controls.rebind(action, event.physical_keycode)
		# It stops waiting a frame later, so Escape reaching the game after this never also closes the window.
		SettingsPanel._stop_waiting.call_deferred()
