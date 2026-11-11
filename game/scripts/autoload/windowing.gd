extends Node
## The desktop strip from Farmus Maximus: F10 turns the window into a borderless band along an edge of the screen,
## always on top, where the fisherman fishes on his own. Its size, width, place, dock, see-through sky and focus mode
## are kept in user://window.json, and the game draws fewer frames in the strip or in the background.

signal view_changed

const SETTINGS_PATH := "user://window.json"
const BASE := Vector2i(480, 270)
## The strip shows these rows of the coast: the boat, the waterline and a little of the water below.
const STRIP := Vector2i(480, 90)
const STRIP_TOP := 96
## The strip's narrowest and widest view in game pixels: room for its controls, and no wider than the narrowest place.
const STRIP_MIN_VIEW := 240
const STRIP_MAX_VIEW := 1440

var strip := false
## Whether the desktop shows through the strip's sky, so only the sea and the boat float over it.
var transparent := true
## Screen pixels per game pixel the player has chosen for the strip; 0 until they do, when it is the largest that keeps
## the strip under a fifth of the screen's height.
var strip_scale := 0
## The strip's width in game pixels, set by dragging it wider or narrower; 0 until the player first does.
var strip_width := 0
## Where the strip sits on the screen: "bottom" or "top".
var dock := "bottom"
## Focus mode makes the strip quieter and slower, for long stretches of work.
var focus_mode := false
## The strip's horizontal offset from the middle of the screen, in screen pixels, set by dragging it.
var offset_x := 0
## How far the strip sits in from the screen edge it is docked to, in screen pixels, set by dragging it up or down.
var offset_y := 0
## The narrowest the strip may be, in game pixels, so its two bars always fit side by side; its controls set it.
var strip_min_width := 0
## True while the strip is being dragged along the screen or wider.
var strip_dragging := false
## Screen pixels per game pixel while the window is the strip.
var scale := 1
var _focused := true
var _size_before := Vector2i.ZERO
var _pos_before := Vector2i.ZERO
var _mode_before := Window.MODE_WINDOWED
var _sliding := false
var _slide_from := Vector2i.ZERO
var _slide_start := 0
var _click_wait := 0.0
## Set when a run started with --strip asks for it before its first screen has opened.
var _strip_on_arrival := false
## The window size and interface size the view was last fitted to.
var _fitted := Vector2i.ZERO
var _fitted_ui := 0


func _ready() -> void:
	_load()
	if Dev.has("strip") and Dev.has("solid"):
		transparent = false
	strip_scale = int(Dev.num("strip-scale", strip_scale))
	strip_width = int(Dev.num("strip-width", strip_width))
	get_window().size_changed.connect(_fit)
	get_viewport().transparent_bg = false
	Settings.changed.connect(_apply_volume)
	Settings.changed.connect(func(): if Settings.ui_scale_step != _fitted_ui: _fit())
	Nav.screen_changed.connect(_on_screen_changed)
	_fit.call_deferred()
	_update_fps()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focused = true
			_update_fps()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focused = false
			_update_fps()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_strip"):
		set_strip(not strip)
	elif event.is_action_pressed("reset_strip") and strip:
		reset_strip()


func _input(event: InputEvent) -> void:
	if not strip:
		return
	# Full screen would stretch the strip's few rows over the whole screen, so F11 there goes back to the full window.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		get_viewport().set_input_as_handled()
		set_strip(false)
	# A borderless strip has no title bar, so dragging with the right mouse button slides it along the screen.
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed and not _sliding:
			_sliding = true
			_slide_from = DisplayServer.mouse_get_position()
			_slide_start = offset_x
			start_strip_drag()
		elif not event.pressed and _sliding:
			_sliding = false
			finish_strip_drag()
	elif event is InputEventMouseMotion and _sliding:
		offset_x = _slide_start + DisplayServer.mouse_get_position().x - _slide_from.x
		_place_strip()
		_redraw_now()


func _process(delta: float) -> void:
	# The view keeps its size when the window is maximised, so Godot sends no resize signal and the window is watched here.
	if get_window().size != _fitted:
		_fit()
	if not (strip and transparent) or strip_dragging or not _windowed():
		return
	_click_wait -= delta
	if _click_wait <= 0.0:
		_click_wait = 0.3
		_set_click_area()


## Sizes the view to the window: the whole-number scale that keeps 270 rows, and as many columns as fit, so a window
## of any shape is filled to its edges with no bars. The strip's view is its own width by its few rows.
func _fit() -> void:
	_fitted = get_window().size
	_fitted_ui = Settings.ui_scale_step
	if strip:
		Nav.fit(Vector2i(strip_view(), STRIP.y), scale)
		view_changed.emit()
		return
	var size := get_window().size
	var s := maxi(1, size.y / BASE.y)
	while s > 1 and size.x / s < 400:
		s -= 1
	# The view is rounded up, so the game covers the window to its edges and loses under a game pixel at each side.
	Nav.fit(Vector2i(maxi(400, ceili(size.x / float(s))), maxi(BASE.y, ceili(size.y / float(s)))), s)
	view_changed.emit()


func set_strip(on: bool) -> void:
	if on == strip:
		return
	if on and Nav.current_name != "coast" and not Dev.has("run-tests"):
		# The first screen of a run started with --strip has not opened yet, so the strip waits for the coast.
		if Nav.current == null:
			_strip_on_arrival = true
			return
		Toast.say("The strip shows the boat: go out fishing first.")
		return
	strip = on
	# The coast is laid out for the full screen, so the strip shows the band of it around the waterline.
	Nav.port.canvas_transform = Transform2D(0.0, Vector2(0, -STRIP_TOP if strip else 0))
	if strip:
		_enter_strip()
	else:
		_leave_strip()
	_update_fps()
	_apply_volume()
	_fit()


## The strip closes as the coast does, before the next screen is laid out, so that screen gets the full window.
func _on_coast_left() -> void:
	if strip and is_inside_tree():
		set_strip(false)


func _on_screen_changed(screen: String) -> void:
	if _strip_on_arrival and screen == "coast":
		set_strip(true)
	_strip_on_arrival = false


func _enter_strip() -> void:
	if Nav.current and not Nav.current.tree_exiting.is_connected(_on_coast_left):
		Nav.current.tree_exiting.connect(_on_coast_left, CONNECT_ONE_SHOT)
	get_viewport().transparent_bg = transparent
	if _windowed():
		var win := get_window()
		_mode_before = win.mode
		# Windows keeps a maximized window's frame and size whatever is asked of it, so the strip starts from a plain window.
		if win.mode != Window.MODE_WINDOWED:
			win.mode = Window.MODE_WINDOWED
		# The plain window's own size is remembered, not the full screen's, so leaving the strip gives it back.
		_size_before = win.size
		_pos_before = win.position
		win.borderless = true
		win.always_on_top = true
	_place_strip()
	_click_wait = 0.0


## The window's mode as the player left it: while the strip is on, the mode it had before.
func normal_mode() -> int:
	return _mode_before if strip and _windowed() else get_window().mode


func _leave_strip() -> void:
	if Nav.current and Nav.current.tree_exiting.is_connected(_on_coast_left):
		Nav.current.tree_exiting.disconnect(_on_coast_left)
	_sliding = false
	strip_dragging = false
	get_viewport().transparent_bg = false
	if not _windowed():
		return
	var win := get_window()
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array())
	win.always_on_top = false
	win.borderless = false
	if _size_before != Vector2i.ZERO:
		win.size = _size_before
		win.position = _pos_before
	if _mode_before != Window.MODE_WINDOWED:
		win.mode = _mode_before


## The strip's width in game pixels: the player's, or the full view's until they drag it, within what the screen holds.
func strip_view() -> int:
	var most := STRIP_MAX_VIEW
	if _windowed():
		most = mini(most, _usable().size.x / scale)
	var least := maxi(STRIP_MIN_VIEW, strip_min_width)
	return clampi(strip_width if strip_width > 0 else STRIP.x, mini(least, most), most)


## The largest strip the screen holds: at most 40% of its height, and at least its narrowest view across.
func max_strip_scale() -> int:
	if not _windowed():
		return 1
	var usable := _usable()
	return mini(maxi(1, int(usable.size.y * 0.4) / STRIP.y), maxi(1, usable.size.x / STRIP_MIN_VIEW))


func change_strip_scale(step: int) -> void:
	strip_scale = clampi(scale + step, 1, max_strip_scale())
	_strip_changed()


func set_transparent(on: bool) -> void:
	transparent = on
	_strip_changed()


func set_focus_mode(on: bool) -> void:
	focus_mode = on
	_strip_changed()


func toggle_dock() -> void:
	dock = "top" if dock == "bottom" else "bottom"
	offset_y = 0
	_strip_changed()


## Puts the strip back in the middle of its edge of the screen.
func reset_strip() -> void:
	offset_x = 0
	offset_y = 0
	_strip_changed()


## Moves the strip across and up or down the screen while it is dragged; where it is kept when the drag ends.
func move_strip(offset: Vector2i) -> void:
	offset_x = offset.x
	# Dragged up a strip at the bottom moves in from its edge, and dragged down a strip at the top does.
	offset_y = -offset.y if dock == "bottom" else offset.y
	_place_strip()
	_redraw_now()


## Where the strip is dragged from: across from the middle, and up or down from its edge.
func strip_offset() -> Vector2i:
	return Vector2i(offset_x, -offset_y if dock == "bottom" else offset_y)


## Makes the strip wider or narrower from its right edge while it is dragged, its left edge staying where it is, so the
## window only changes size and never jumps along the screen as well.
func set_strip_width(view: int) -> void:
	if not _windowed():
		strip_width = view
		_fit()
		return
	var left := get_window().position.x
	strip_width = clampi(view, maxi(STRIP_MIN_VIEW, strip_min_width), STRIP_MAX_VIEW)
	var usable := _usable()
	offset_x = left - usable.position.x - (usable.size.x - strip_view() * scale) / 2
	_place_strip()
	_fit()
	_redraw_now()


## While the strip is dragged it lets no clicks through: on Windows the outline that does so also cuts away what the
## strip draws, and redrawing it on every step of the drag makes the strip flicker. It is drawn afresh once the drag ends.
func start_strip_drag() -> void:
	strip_dragging = true
	_update_fps()
	if _windowed():
		DisplayServer.window_set_mouse_passthrough(PackedVector2Array())


func finish_strip_drag() -> void:
	strip_dragging = false
	_update_fps()
	_click_wait = 0.0
	_save()


## Windows shows a grown window's new edge blank until the game next draws, so during a drag it draws at once.
func _redraw_now() -> void:
	if strip_dragging and _windowed():
		RenderingServer.force_draw()


## Asks for the clickable outline to be drawn again on the next frame, as when the strip's controls appear.
func refresh_click_area() -> void:
	_click_wait = 0.0


## The strip's own settings only change the window while it is the strip; the full window is left exactly as it is.
func _strip_changed() -> void:
	if strip:
		get_viewport().transparent_bg = transparent
		if not transparent and _windowed():
			DisplayServer.window_set_mouse_passthrough(PackedVector2Array())
		_place_strip()
		_update_fps()
		_apply_volume()
		_fit()
		_click_wait = 0.0
	_save()


func _place_strip() -> void:
	if not _windowed():
		return
	var win := get_window()
	var usable := _usable()
	var auto := clampi(int(usable.size.y * 0.2) / STRIP.y, 1, max_strip_scale())
	scale = clampi(strip_scale if strip_scale > 0 else auto, 1, max_strip_scale())
	var size := Vector2i(strip_view() * scale, STRIP.y * scale)
	Nav.fit(Vector2i(strip_view(), STRIP.y), scale)
	win.size = size
	# The strip never slides off the screen, and its offsets are held to what fits so a later drag starts from there.
	var room := (usable.size.x - size.x) / 2
	offset_x = clampi(offset_x, -room, room)
	offset_y = clampi(offset_y, 0, maxi(0, usable.size.y - size.y))
	# The usable rect already leaves out the taskbar, wherever it sits, so the strip never covers it.
	var y := usable.position.y + offset_y if dock == "top" else usable.end.y - size.y - offset_y
	win.position = Vector2i(usable.position.x + room + offset_x, y)


## On Windows the outline that lets clicks through the see-through strip also clips what the strip draws, so it follows
## everything drawn in the last frame, column by column, plus the strip's controls the moment they appear.
func _set_click_area() -> void:
	var img := Nav.port.get_texture().get_image()
	if img == null or img.is_empty():
		return
	# The port is drawn at the window's resolution, so the outline is measured in window pixels, four game pixels a column.
	var step := 4 * scale
	var w := img.get_width()
	var h := img.get_height()
	var tops := PackedInt32Array()
	for x in range(0, w, step):
		var used := img.get_region(Rect2i(x, 0, mini(step, w - x), h)).get_used_rect()
		tops.append(used.position.y if used.has_area() else h)
	for node in get_tree().get_nodes_in_group("strip_area"):
		var area := Nav.from_ui(node.area())
		if not area.has_area():
			continue
		var r := Rect2(area.position * scale, area.size * scale)
		for i in range(maxi(0, int(r.position.x) / step), mini(tops.size(), int(ceilf(r.end.x / step)))):
			tops[i] = mini(tops[i], maxi(0, int(r.position.y)))
	var points := PackedVector2Array([Vector2(0, h)])
	var i := 0
	while i < tops.size():
		var end := i
		while end < tops.size() and tops[end] == tops[i]:
			end += 1
		points.append(Vector2(i * step, tops[i]))
		points.append(Vector2(mini(end * step, w), tops[i]))
		i = end
	points.append(Vector2(w, h))
	DisplayServer.window_set_mouse_passthrough(points)


func _apply_volume() -> void:
	# Focus mode turns everything down a little, so a strip left running all day stays in the background.
	var quiet := -8.0 if strip and focus_mode else 0.0
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(0.0001, Settings.master)) + quiet)


func _update_fps() -> void:
	if not _windowed():
		return
	# A cozy game left running beside the player's work should barely touch the processor or the battery.
	var fps := 0
	if strip_dragging:
		fps = 0
	elif strip and focus_mode:
		fps = 15
	elif strip or not _focused:
		fps = 30
	Engine.max_fps = fps


func _usable() -> Rect2i:
	return DisplayServer.screen_get_usable_rect(get_window().current_screen)


func _windowed() -> bool:
	return DisplayServer.get_name() != "headless"


## Test runs and runs with --no-save neither read nor write the player's strip, so they always start the same way.
func _persist() -> bool:
	return not Dev.has("no-save") and not Dev.has("run-tests")


func _load() -> void:
	if not _persist() or not FileAccess.file_exists(SETTINGS_PATH):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if typeof(d) != TYPE_DICTIONARY:
		return
	transparent = bool(d.get("transparent", true))
	strip_scale = int(d.get("strip_scale", 0))
	strip_width = int(d.get("strip_width", 0))
	offset_x = int(d.get("offset_x", 0))
	offset_y = int(d.get("offset_y", 0))
	dock = "top" if str(d.get("dock", "bottom")) == "top" else "bottom"
	focus_mode = bool(d.get("focus_mode", false))


func _save() -> void:
	if not _persist():
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"transparent": transparent, "strip_scale": strip_scale, "strip_width": strip_width,
			"offset_x": offset_x, "offset_y": offset_y, "dock": dock, "focus_mode": focus_mode}))
