extends Node
## The desktop strip from Farmus Maximus: F10 turns the window into a borderless band along the bottom of the screen,
## always on top, showing the boat and its line at the waterline while the fisherman fishes on his own.

signal view_changed

const BASE := Vector2i(480, 270)
## The strip shows these rows of the coast: the boat, the waterline and a little of the water below.
const STRIP := Vector2i(480, 90)
const STRIP_TOP := 96

var strip := false
var _size_before := Vector2i.ZERO
var _pos_before := Vector2i.ZERO


func _ready() -> void:
	get_window().size_changed.connect(_fit)
	_fit.call_deferred()
	if not InputMap.has_action("toggle_strip"):
		InputMap.add_action("toggle_strip")
		var e := InputEventKey.new()
		e.physical_keycode = KEY_F10
		InputMap.action_add_event("toggle_strip", e)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_strip"):
		set_strip(not strip)


## Sizes the view to the window: the whole-number scale that keeps 270 rows, and as many columns as fit, so a window
## of any shape is filled to its edges with no bars.
func _fit() -> void:
	if strip:
		return
	var size := get_window().size
	var scale := maxi(1, size.y / BASE.y)
	while scale > 1 and size.x / scale < 400:
		scale -= 1
	get_window().content_scale_size = Vector2i(maxi(400, size.x / scale), maxi(BASE.y, size.y / scale))
	view_changed.emit()


func set_strip(on: bool) -> void:
	if on == strip:
		return
	if on and Nav.current_name != "coast" and not Dev.has("run-tests"):
		Toast.say("The strip shows the boat: go out fishing first.")
		return
	strip = on
	_apply()
	view_changed.emit()


## The strip's scale: the largest whole number that keeps it under a fifth of the screen's height.
func strip_scale() -> int:
	var usable := DisplayServer.screen_get_usable_rect(get_window().current_screen)
	return clampi(int(usable.size.y * 0.2) / STRIP.y, 1, maxi(1, usable.size.x / STRIP.x))


func _apply() -> void:
	var win := get_window()
	win.content_scale_size = STRIP if strip else BASE
	if not strip:
		_fit.call_deferred()
	# The coast is laid out for the full screen, so the strip shows the band of it around the waterline.
	get_viewport().canvas_transform = Transform2D(0.0, Vector2(0, -STRIP_TOP if strip else 0))
	if DisplayServer.get_name() == "headless":
		return
	if strip:
		_size_before = win.size
		_pos_before = win.position
		if win.mode != Window.MODE_WINDOWED:
			win.mode = Window.MODE_WINDOWED
		win.borderless = true
		win.always_on_top = true
		var s := strip_scale()
		var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
		win.size = STRIP * s
		win.position = usable.position + Vector2i((usable.size.x - win.size.x) / 2, usable.size.y - win.size.y)
	else:
		win.borderless = false
		win.always_on_top = false
		if _size_before != Vector2i.ZERO:
			win.size = _size_before
			win.position = _pos_before
