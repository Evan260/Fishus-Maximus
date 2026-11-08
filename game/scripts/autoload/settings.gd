extends Node
## The player's settings, kept apart from the save slots so they apply to every game: the volumes, the window, the
## interface size, the units weights are shown in, gentle fishing, the text size and old Rufus's guide.

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
## How large the interface is drawn: -1 a step smaller than the game, 0 the game's own size, 1 a step larger.
var interface_size := 0
## The units weights are shown in: "metric" for kilograms or "imperial" for pounds.
var units := "metric"
## Old Rufus's lessons for a new player.
var guide := true
var _before := DisplayServer.WINDOW_MODE_WINDOWED


func _ready() -> void:
	var cfg := ConfigFile.new()
	if not Dev.has("no-save") and not Dev.has("run-tests") and cfg.load(PATH) == OK:
		read_from(cfg)
	# --ui-size=-1, 0 or 1 tries an interface size without saving it, for screenshots.
	if Dev.has("ui-size"):
		interface_size = clampi(int(Dev.num("ui-size", 0)), -1, 1)
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
	interface_size = clampi(int(cfg.get_value("display", "interface_size", interface_size)), -1, 1)
	gentle = cfg.get_value("play", "gentle", gentle)
	large_text = cfg.get_value("play", "large_text", large_text)
	guide = cfg.get_value("play", "guide", guide)
	var u := str(cfg.get_value("display", "units", units))
	units = u if u in ["metric", "imperial"] else "metric"


func apply() -> void:
	for bus in [["Master", master], ["Music", music], ["Effects", effects], ["Ambience", ambience]]:
		var i := AudioServer.get_bus_index(bus[0])
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(0.0001, bus[1])))
	changed.emit()


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
	cfg.set_value("display", "interface_size", interface_size)
	cfg.set_value("display", "units", units)
	cfg.set_value("play", "gentle", gentle)
	cfg.set_value("play", "large_text", large_text)
	cfg.set_value("play", "guide", guide)


func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	fullscreen = mode != DisplayServer.WINDOW_MODE_FULLSCREEN
	if fullscreen:
		_before = mode
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(_before)
	save()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		toggle_fullscreen()
