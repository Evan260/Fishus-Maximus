extends Node
## Tips drawn in the interface's own pixels, so they grow with the interface size like everything else, as Mosaicus
## Maximus draws them. A control asks for one with `Ui.tip_on(control, text)`; the text is read and translated each
## frame, so it can change while shown. The settings can turn them off. A phone has no pointer resting anywhere, so
## there a finger held still on a control shows its tip instead, as in Farmus Maximus.

const DELAY := 0.4
## The widest a tip runs before it breaks onto another line, in interface pixels.
const WRAP := 200.0
## How long a tip shown by a held finger stays after the finger lifts, in seconds.
const SHOW_FOR := 4.0

## True from a finger resting still long enough to ask what is under it until the next touch, so the lift does not act.
var long_press := false

var _layer: CanvasLayer
var _panel: PanelContainer
var _label: Label
var _owner: Control
var _wait := 0.0
## Where the pointer last was, in window pixels, read from its own events so a scripted pointer is followed too.
var _pointer := Vector2.ZERO
## Where the finger touched down in window pixels, or INF while none rests; how far it has wandered and how long it has
## rested; and how long a tip it asked for has left.
var _press_at := Vector2.INF
var _moved := 0.0
var _pressed_for := 0.0
var _shown_left := 0.0


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 40
	Nav.port.add_child(_layer)
	_panel = PanelContainer.new()
	_panel.name = "Tip"
	_panel.theme = UiTheme.build()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _panel.theme.get_stylebox("panel", "TooltipPanel"))
	_layer.add_child(_panel)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The text is translated before it is broken into lines, so the label never looks it up again.
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_panel.add_child(_label)
	_panel.visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_pointer = event.position
	if not Windowing.phone:
		return
	if event is InputEventMouseMotion and _press_at != Vector2.INF:
		_moved = maxf(_moved, event.position.distance_to(_press_at))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			long_press = false
			_press_at = event.position
			_moved = 0.0
			_pressed_for = 0.0
			_owner = null
			_panel.visible = false
		else:
			_press_at = Vector2.INF


func _process(delta: float) -> void:
	_layer.transform = Nav.ui_layer.transform
	if Windowing.phone:
		_process_touch(delta)
		return
	var owner := _tip_owner(Nav.port.gui_get_hovered_control()) if Settings.tooltips else null
	if owner == null or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_owner = null
		_panel.visible = false
		_wait = 0.0
		return
	if owner != _owner:
		_owner = owner
		_wait = 0.0
		_panel.visible = false
	_wait += delta
	if _wait >= DELAY:
		show_for(owner, Nav.window_to_ui(_pointer))


func _process_touch(delta: float) -> void:
	if _press_at != Vector2.INF and not long_press:
		_pressed_for += delta
		if Touch.is_hold(_pressed_for, _moved, Windowing.touch_slop()):
			long_press = true
			var under := Nav.port.gui_get_hovered_control()
			var owner := _tip_owner(under)
			if owner != null and Settings.tooltips:
				_cancel_press(under)
				_owner = owner
				_shown_left = SHOW_FOR
	if _owner != null and is_instance_valid(_owner) and _owner.is_visible_in_tree() and _shown_left > 0.0:
		if _press_at == Vector2.INF:
			_shown_left -= delta
		show_for(_owner, Nav.window_to_ui(_pointer))
	else:
		_owner = null
		_panel.visible = false


## A button whose tip was asked for forgets its press, as disabling it for a moment makes it do.
func _cancel_press(c: Control) -> void:
	var n: Node = c
	for i in 4:
		if n is BaseButton:
			if not n.disabled:
				n.disabled = true
				n.disabled = false
			return
		if not n is Control:
			return
		n = n.get_parent()


## The control under the pointer that has a tip: it or one of the few controls round it, as a picture's tile has.
func _tip_owner(c: Control) -> Control:
	var n: Node = c
	for i in 4:
		if not n is Control:
			return null
		if n.has_meta("tip") and str(n.get_meta("tip")) != "" and (n as Control).is_visible_in_tree():
			return n
		n = n.get_parent()
	return null


## Shows `owner`'s tip beside a pointer at `at`, in interface pixels.
func show_for(owner: Control, at: Vector2) -> void:
	var lines := wrap_text(tr(str(owner.get_meta("tip"))))
	_label.add_theme_font_size_override("font_size", UiTheme.text_size() * Settings.message_scale())
	if _label.text != lines or not _panel.visible:
		_label.text = lines
		_panel.visible = true
		_panel.reset_size()
	var room := Rect2(Vector2.ZERO, Nav.ui_view())
	_panel.position = (Nav.tip_above(at, _panel.size, room) if Windowing.phone else Nav.tip_at(at, _panel.size, room)).floor()


func shown() -> bool:
	return _panel.visible


func panel() -> PanelContainer:
	return _panel


## Breaks a tip into lines no wider than `WRAP`, between letters where a language leaves no spaces between words.
func wrap_text(text: String) -> String:
	var font := UiTheme.body_font()
	var size := UiTheme.text_size() * Settings.message_scale()
	var width := WRAP * Settings.message_scale()
	var out := PackedStringArray()
	var spaced := Ui.sentence_gap() != ""
	for para in text.split("\n"):
		var line := ""
		# Chinese and Japanese break anywhere between letters, so a space in them is no better place to break.
		for word in (para.split(" ") if spaced else PackedStringArray([para])):
			var next := word if line == "" else line + " " + word
			if font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
				line = next
				continue
			if line != "":
				out.append(line)
			line = ""
			if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
				line = word
				continue
			for c in word:
				if line != "" and font.get_string_size(line + c, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
					out.append(line)
					line = ""
				line += c
		out.append(line)
	return "\n".join(out)
