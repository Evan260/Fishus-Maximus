class_name StripControls
extends Control
## The desktop strip's own bars: at the top left the purse, the hold and the way back to the full window; at the top
## right, only while the pointer is over the strip, its size, handles to drag it along and wider, its dock, the
## see-through sky, focus mode and re-centring.

const ICONS := {
	"smaller": [".......", ".......", "XXXXXXX", ".......", "......."],
	"larger": ["...X...", "...X...", "XXXXXXX", "...X...", "...X..."],
	"move": ["...X...", "..XXX..", ".X.X.X.", "XXXXXXX", ".X.X.X.", "..XXX..", "...X..."],
	"width": [".X...X.", "XX...XX", "XXXXXXX", "XX...XX", ".X...X."],
	"to_top": ["XXXXXXX", ".......", "...X...", "..XXX..", ".X.X.X.", "...X...", "...X..."],
	"to_bottom": ["...X...", "...X...", ".X.X.X.", "..XXX..", "...X...", ".......", "XXXXXXX"],
	"sky": [".......", "..XX...", ".XXXXX.", "XXXXXXX", "XXXXXXX"],
	"no_sky": [".......", "..XX...", ".X..XX.", "X.....X", "XXXXXXX"],
	"focus": ["..XXX..", ".XX....", "XX.....", "XX.....", "XX.....", ".XX....", "..XXX.."],
	"centre": ["...X...", "...X...", "..X.X..", "XX...XX", "..X.X..", "...X...", "...X..."],
}

var _info: HBoxContainer
var _purse: Label
var _bar: HBoxContainer
var _scale_label: Label
var _dock_button: Button
var _sky_button: Button
var _focus_button: Button
## The drag in progress, "move" or "width", where the pointer started on the screen, and the value it started from.
var _drag := ""
var _drag_from := Vector2i.ZERO
var _drag_start := Vector2i.ZERO
## For checking how the controls look: shown all the time, as if the pointer were over the strip.
var _pinned := Dev.has("strip-controls")
var _shown := false


## Puts the controls on the interface while the window is the strip, and takes them away when it is not.
static func sync() -> void:
	if Nav.ui == null or Dev.has("no-hud"):
		return
	var c := Nav.ui.get_node_or_null("StripControls")
	if Windowing.strip and c == null:
		# A window laid out for the full view would cover the strip's few rows.
		Ui.close_window()
		c = StripControls.new()
		c.name = "StripControls"
		Nav.ui.add_child(c)
	elif not Windowing.strip and c != null:
		c.name = "StripControlsClosing"
		c.queue_free()


func _ready() -> void:
	add_to_group("strip_area")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info = HBoxContainer.new()
	_info.add_theme_constant_override("separation", 3)
	_info.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_info)
	_purse = _outlined(_info)
	Ui.button(_info, "Expand", func(): Windowing.set_strip(false))
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 1)
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_bar.modulate.a = 0.0
	add_child(_bar)
	_icon_button("smaller", "Smaller", func(): Windowing.change_strip_scale(-1))
	_scale_label = _outlined(_bar)
	_icon_button("larger", "Larger", func(): Windowing.change_strip_scale(1))
	_grip(_icon_button("move", "Drag to move the strip", Callable()), "move")
	_grip(_icon_button("width", "Drag to make the strip wider or narrower", Callable()), "width")
	_dock_button = _icon_button("to_top", "Move to the other edge of the screen", func(): Windowing.toggle_dock())
	_sky_button = _icon_button("sky", "See the desktop through the sky", func(): Windowing.set_transparent(not Windowing.transparent))
	_focus_button = _icon_button("focus", "Focus mode: quieter and slower", func(): Windowing.set_focus_mode(not Windowing.focus_mode))
	_icon_button("centre", "Back to the middle (F9)", func(): Windowing.reset_strip())
	for b in [_sky_button, _focus_button]:
		b.toggle_mode = true
	_refresh()


## Shows the right bar while the pointer is over the strip or a drag is under way, read from the pointer's place on the
## screen, which the game knows even over the see-through parts of the strip that let clicks through.
func _process(delta: float) -> void:
	var win := get_window()
	var over := Rect2i(win.position, win.size).has_point(DisplayServer.mouse_get_position())
	var target := 1.0 if over or _pinned or _drag != "" else 0.0
	_bar.modulate.a = move_toward(_bar.modulate.a, target, delta / 0.25)
	var shown := _bar.modulate.a > 0.0
	_bar.visible = shown
	if shown != _shown:
		_shown = shown
		Windowing.refresh_click_area()
	_refresh()


func _refresh() -> void:
	var s: Dictionary = Game.state
	if not s.is_empty():
		var boat: Dictionary = Data.boats.get(str(s.get("boat", "skiff")), {})
		_purse.text = "%s   Hold %d/%d" % [Ui.coins_text(int(s.get("denarii", 0))), s.get("hold", []).size(), int(boat.get("hold", 0))]
	_scale_label.text = "%dx" % Windowing.scale
	_dock_button.icon = _texture("to_bottom" if Windowing.dock == "top" else "to_top")
	_sky_button.icon = _texture("no_sky" if Windowing.transparent else "sky")
	_sky_button.set_pressed_no_signal(Windowing.transparent)
	_focus_button.set_pressed_no_signal(Windowing.focus_mode)
	_info.reset_size()
	_bar.reset_size()
	_info.position = Vector2(4, 4)
	_bar.position = Vector2(roundf(size.x - _bar.size.x - 4.0), 4.0)
	Windowing.strip_min_width = int(ceilf(Nav.from_ui(Rect2(Vector2.ZERO, Vector2(_info.size.x + _bar.size.x + 16.0, 0))).size.x))


## The bars' area while they show, which must stay clickable when the rest of the sky lets clicks through.
func area() -> Rect2:
	var r := _info.get_global_rect()
	return r.merge(_bar.get_global_rect()) if _bar.visible else r


func _outlined(parent: Node) -> Label:
	var l := Ui.label(parent, "", "LightLabel")
	l.add_theme_color_override("font_outline_color", UiTheme.INK)
	l.add_theme_constant_override("outline_size", 2)
	return l


func _icon_button(icon: String, tip: String, action: Callable) -> Button:
	var b := Button.new()
	b.icon = _texture(icon)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(16, 16)
	_bar.add_child(b)
	# The icons are drawn white and take the colour of the buttons' words, so they match the painted buttons.
	var ink := b.get_theme_color("font_color")
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(c, ink)
	if action.is_valid():
		b.pressed.connect(Audio.play.bind("click", -6.0))
		b.pressed.connect(action)
	return b


## Makes a button a handle: held down and dragged, it moves the strip or changes its width, following the pointer
## across the screen, and the new place is remembered when it is let go.
func _grip(b: Button, kind: String) -> void:
	b.mouse_default_cursor_shape = Control.CURSOR_MOVE if kind == "move" else Control.CURSOR_HSIZE
	b.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag = kind
				_drag_from = DisplayServer.mouse_get_position()
				_drag_start = Windowing.strip_offset() if kind == "move" else Vector2i(Windowing.strip_view(), 0)
				Windowing.start_strip_drag()
			elif _drag != "":
				_drag = ""
				Windowing.finish_strip_drag()
		elif event is InputEventMouseMotion and _drag == kind:
			var moved := DisplayServer.mouse_get_position() - _drag_from
			if kind == "move":
				Windowing.move_strip(_drag_start + moved)
			else:
				Windowing.set_strip_width(_drag_start.x + moved.x / Windowing.scale))


static var _textures := {}


## A small white pixel icon from its picture above, tinted by the button it sits on.
static func _texture(name: String) -> Texture2D:
	if not _textures.has(name):
		var rows: Array = ICONS[name]
		var img := Image.create(7, 7, false, Image.FORMAT_RGBA8)
		var top := (7 - rows.size()) / 2
		for y in rows.size():
			for x in 7:
				if String(rows[y])[x] == "X":
					img.set_pixel(x, top + y, Color.WHITE)
		_textures[name] = ImageTexture.create_from_image(img)
	return _textures[name]
