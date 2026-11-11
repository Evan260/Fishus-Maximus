extends Node
## Controller support for every menu, as in Mosaicus Maximus: a stick moves the pointer and A clicks with it, so every
## window and screen works as with a mouse. On the coast the left stick rows and A casts, so there the right stick
## moves the pointer and A clicks only on a button or in a window. B closes a window or steps back (`Controls`).

const SPEED := 900.0
const DEAD := 0.18

## True from A pressed as a click until it is let go, so the coast does not also cast with it.
var clicking := false
var _cursor := Vector2.ZERO
var _active := false


func _process(delta: float) -> void:
	if Input.get_connected_joypads().is_empty():
		return
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() < DEAD and not _rows():
		stick = Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if stick.length() < DEAD:
		return
	if not _active:
		_active = true
		_cursor = get_viewport().get_mouse_position()
	var size := get_viewport().get_visible_rect().size
	var before := _cursor
	_cursor = (_cursor + stick * stick.length() * SPEED * delta).clamp(Vector2.ZERO, size - Vector2.ONE)
	get_viewport().warp_mouse(_cursor)
	var motion := InputEventMouseMotion.new()
	motion.position = _cursor
	motion.global_position = _cursor
	motion.relative = _cursor - before
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if clicking else 0
	Input.parse_input_event(motion)


## Whether the left stick rows the boat here rather than moving the pointer.
func _rows() -> bool:
	return Nav.current_name == "coast" and not Ui.window_open()


func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A):
		return
	if event.pressed and (not _rows() or Nav.port.gui_get_hovered_control() != null):
		clicking = true
		_click(true)
	elif not event.pressed and clicking:
		_click(false)
		clicking = false


func _click(pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = get_viewport().get_mouse_position()
	e.global_position = e.position
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(e)
