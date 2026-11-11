extends Node
## The player's settings, kept apart from the save slots so they apply to every game: the volumes, the window, the
## interface size, the units weights are shown in, gentle fishing, the text size, old Rufus's guide, the tips and the
## language.

signal changed

const PATH := "user://settings.cfg"

var master := 0.9
var music := 0.6
var effects := 0.9
## The sounds around you: the sea, the gulls, the cicadas, the wind and the rain.
var ambience := 0.8
var fullscreen := false
var maximized := false
## Gentle fishing never snaps a line or lets a hook slip.
var gentle := false
var large_text := false
## Keeps the screen still: the cards and the banner appear without sliding or unfurling, and pages turn at once.
var reduced_motion := false
## How loud the game stays while another window has the focus: "full", "quieter" or "muted".
var background_sound := "full"
## Flashes the taskbar when a fish bites or an achievement is earned while the player is in another window.
var notifications := true
## How large the interface is drawn: -1 Smaller, 0 Normal (a step under the game's own size), 1 Larger (the game's
## own size) or 2 Largest.
var ui_scale_step := 0
## The units weights are shown in: "metric" for kilograms or "imperial" for pounds.
var units := "metric"
## Old Rufus's lessons for a new player.
var guide := true
## The tips shown when the pointer rests on a button.
var tooltips := true
## The keys the player has chosen in place of an action's own, by action; see `Controls`.
var keys := {}
## The desktop strip's size, width, place, dock, see-through sky and focus mode, which `Windowing` reads and sets.
var strip := {}
## A language code such as "fr" or "zh_CN"; empty until chosen, when the computer's own language is used if the game has it.
var language := ""
var _before := DisplayServer.WINDOW_MODE_WINDOWED


func _ready() -> void:
	var cfg := ConfigFile.new()
	if not Dev.has("no-save") and not Dev.has("run-tests") and cfg.load(PATH) == OK:
		read_from(cfg)
	# --ui-size=-1 (Smaller), 0 (Normal), 1 (Larger) or 2 (Largest) tries an interface size without saving it.
	if Dev.has("ui-size"):
		ui_scale_step = clampi(int(Dev.num("ui-size", 0)), -1, 2)
	_load_translations()
	TranslationServer.set_locale(language if language in TranslationServer.get_loaded_locales() else system_language())
	# --locale=xx shows the game in another language without keeping it.
	if Dev.get_arg("locale") != "":
		TranslationServer.set_locale(Dev.get_arg("locale"))
	UiTheme.use_language()
	Controls.ensure()
	apply()
	_restore_window.call_deferred()


## Takes the settings from a settings file, keeping each one the file does not have.
func read_from(cfg: ConfigFile) -> void:
	master = cfg.get_value("sound", "master", master)
	music = cfg.get_value("sound", "music", music)
	effects = cfg.get_value("sound", "effects", effects)
	ambience = cfg.get_value("sound", "ambience", ambience)
	fullscreen = cfg.get_value("display", "fullscreen", fullscreen)
	maximized = cfg.get_value("display", "maximized", maximized)
	if cfg.has_section_key("display", "ui_scale_step"):
		ui_scale_step = clampi(int(cfg.get_value("display", "ui_scale_step")), -1, 2)
	elif cfg.has_section_key("display", "interface_size"):
		# The old steps counted Normal as -1, so each saved size moves up one and still draws the same.
		ui_scale_step = clampi(int(cfg.get_value("display", "interface_size")) + 1, 0, 2)
	gentle = cfg.get_value("play", "gentle", gentle)
	large_text = cfg.get_value("play", "large_text", large_text)
	reduced_motion = cfg.get_value("play", "reduced_motion", reduced_motion)
	notifications = cfg.get_value("play", "notifications", notifications)
	var quiet := str(cfg.get_value("sound", "background_sound", background_sound))
	background_sound = quiet if quiet in ["full", "quieter", "muted"] else "full"
	guide = cfg.get_value("play", "guide", guide)
	tooltips = cfg.get_value("play", "tooltips", tooltips)
	language = str(cfg.get_value("play", "language", language))
	var u := str(cfg.get_value("display", "units", units))
	units = u if u in ["metric", "imperial"] else "metric"
	strip = {}
	if cfg.has_section("strip"):
		for key in cfg.get_section_keys("strip"):
			strip[key] = cfg.get_value("strip", key)
	keys = {}
	if cfg.has_section("keys"):
		for action in cfg.get_section_keys("keys"):
			if Controls.ACTIONS.has(action):
				keys[action] = int(cfg.get_value("keys", action))


func apply() -> void:
	for bus in [["Master", master], ["Music", music], ["Effects", effects], ["Ambience", ambience]]:
		var i := AudioServer.get_bus_index(bus[0])
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(0.0001, bus[1])))
	changed.emit()


## How many times the usual size a message's text is drawn: the toasts, old Rufus's notes, the cards and the tips.
func message_scale() -> int:
	return 2 if large_text else 1


## Flashes the taskbar for something that needs the player while another window has the focus.
func alert() -> void:
	if notifications and DisplayServer.get_name() != "headless" and not get_window().has_focus():
		DisplayServer.window_request_attention()


func set_value(key: String, value) -> void:
	set(key, value)
	apply()
	save()


func _restore_window() -> void:
	if Dev.has("window"):
		return
	if maximized:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	if fullscreen:
		_before = DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var mode := Windowing.normal_mode()
		maximized = mode == DisplayServer.WINDOW_MODE_MAXIMIZED or (mode == DisplayServer.WINDOW_MODE_FULLSCREEN and _before == DisplayServer.WINDOW_MODE_MAXIMIZED)
		save()


func save() -> void:
	if Dev.has("no-save") or Dev.has("run-tests"):
		return
	var cfg := ConfigFile.new()
	write_to(cfg)
	cfg.save(PATH)


func write_to(cfg: ConfigFile) -> void:
	cfg.set_value("sound", "master", master)
	cfg.set_value("sound", "music", music)
	cfg.set_value("sound", "effects", effects)
	cfg.set_value("sound", "ambience", ambience)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "maximized", maximized)
	cfg.set_value("display", "ui_scale_step", ui_scale_step)
	cfg.set_value("display", "units", units)
	cfg.set_value("play", "gentle", gentle)
	cfg.set_value("play", "large_text", large_text)
	cfg.set_value("play", "reduced_motion", reduced_motion)
	cfg.set_value("play", "notifications", notifications)
	cfg.set_value("sound", "background_sound", background_sound)
	cfg.set_value("play", "guide", guide)
	cfg.set_value("play", "tooltips", tooltips)
	if language != "":
		cfg.set_value("play", "language", language)
	for action in keys:
		cfg.set_value("keys", action, int(keys[action]))
	for key in strip:
		cfg.set_value("strip", key, strip[key])


## Loads every translated column of the strings sheet; one without even the word "Language" is still waiting for Azure.
func _load_translations() -> void:
	for file in ResourceLoader.list_directory("res://translations/"):
		if file.get_extension() == "translation":
			var t: Translation = load("res://translations/" + file)
			if t.locale == "en" or t.get_message("Language") != "":
				TranslationServer.add_translation(t)


## The computer's own language if the game has it, matching "fr_CA" to "fr" and "zh_Hans_CN" to "zh_CN"; otherwise English.
func system_language() -> String:
	var have := TranslationServer.get_loaded_locales()
	var os := OS.get_locale()
	if os in have:
		return os
	if os.begins_with("zh"):
		var traditional := os.contains("Hant") or os.ends_with("TW") or os.ends_with("HK") or os.ends_with("MO")
		var zh := "zh_TW" if traditional else "zh_CN"
		return zh if zh in have else "en"
	var lang := OS.get_locale_language()
	for loc in have:
		if loc.get_slice("_", 0) == lang:
			return loc
	return "en"


## Shows the game in another language and keeps the choice: the fonts change with it, and the screen is built again.
func set_language(code: String) -> void:
	language = code
	save()
	TranslationServer.set_locale(code)
	UiTheme.use_language()
	Nav.reopen()


## The interface size after `step`: Normal, Larger, Largest, Smaller, then Normal again.
static func next_ui_step(step: int) -> int:
	return (step + 2) % 4 - 1


func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	fullscreen = mode != DisplayServer.WINDOW_MODE_FULLSCREEN
	if fullscreen:
		_before = mode
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(_before)
	save()
	SettingsPanel.refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		toggle_fullscreen()
