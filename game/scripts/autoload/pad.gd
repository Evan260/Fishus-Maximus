extends Node
## Controller support for every menu, as in Mosaicus Maximus: a stick moves the pointer and A clicks with it, so every
## window and screen works as with a mouse. On the coast the left stick rows and A casts, so there the right stick
## moves the pointer and A clicks only on a button or in a window. B closes a window or steps back (`Controls`). While
## a window is open the right stick scrolls the list under the pointer, LB and RB a page at a time, and the left stick
## moves the pointer. `active` says whether the controller was used last, so the hints show its buttons.

const SPEED := 900.0
const DEAD := 0.18
## Interface pixels a list scrolls each second with the right stick held all the way.
const SCROLL_SPEED := 260.0
## The share of a list's height that LB or RB scrolls it.
const PAGE := 0.8
## Marks the mouse events made here, so they never count as the mouse being used.
const DEVICE := 77

## True from A pressed as a click until it is let go, so the coast does not also cast with it.
var clicking := false
## Whether the controller is the input used last, rather than the mouse or keyboard.
var active := false
var _cursor := Vector2.ZERO
var _moving := false
var _scroll_left := 0.0


func _ready() -> void:
	# --pad shows the controller's buttons in the hints from the start, for checking them without one.
	if Dev.has("pad"):
		_cursor = get_viewport().get_mouse_position()
		active = true


func _process(delta: float) -> void:
	if Input.get_connected_joypads().is_empty():
		return
	var right := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	var left := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if right.length() >= DEAD or left.length() >= DEAD:
		use_pad(true)
	var stick := right
	if Ui.window_open():
		if absf(right.y) >= DEAD:
			scroll(right.y * absf(right.y) * SCROLL_SPEED * delta)
		stick = left
	elif stick.length() < DEAD and not _rows():
		stick = left
	if stick.length() < DEAD:
		return
	if not _moving:
		_moving = true
		_cursor = get_viewport().get_mouse_position()
	var size := get_viewport().get_visible_rect().size
	var before := _cursor
	_cursor = (_cursor + stick * stick.length() * SPEED * delta).clamp(Vector2.ZERO, size - Vector2.ONE)
	get_viewport().warp_mouse(_cursor)
	var motion := InputEventMouseMotion.new()
	motion.device = DEVICE
	motion.position = _cursor
	motion.global_position = _cursor
	motion.relative = _cursor - before
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if clicking else 0
	Input.parse_input_event(motion)


## Whether A clicks rather than casts with the pointer over `c`: anywhere off the coast or in a window, and on the
## coast only on a button, so a pointer resting on a panel or old Rufus's note never stops a cast.
func clicks_on(c: Control) -> bool:
	return not _rows() or c is BaseButton


## Whether the left stick rows the boat here rather than moving the pointer.
func _rows() -> bool:
	return Nav.current_name == "coast" and not Ui.window_open()


func _input(event: InputEvent) -> void:
	_note_input(event)
	if event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER] \
			and Ui.window_open():
		var list := scroll_target()
		if list:
			list.scroll_vertical += int(roundf(list.size.y * PAGE)) * (-1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1)
	if not (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A):
		return
	if event.pressed and clicks_on(Nav.port.gui_get_hovered_control()):
		clicking = true
		_click(true)
	elif not event.pressed and clicking:
		_click(false)
		clicking = false


## Keeps `active` to the input used last: the controller, or the keyboard or a mouse moved or clicked by hand.
func _note_input(event: InputEvent) -> void:
	if event.device == DEVICE:
		return
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) >= DEAD):
		use_pad(true)
	elif event is InputEventKey or event is InputEventMouseButton:
		use_pad(false)
	elif event is InputEventMouseMotion and event.position.distance_to(_cursor) > 2.0:
		_moving = false
		use_pad(false)


func use_pad(on: bool) -> void:
	active = on


## Scrolls the list under the pointer, or else the open window's first list that can scroll, by `by` interface pixels.
func scroll(by: float) -> void:
	var list := scroll_target()
	if not list:
		return
	_scroll_left += by
	var whole := int(_scroll_left)
	_scroll_left -= whole
	list.scroll_vertical += whole


func scroll_target() -> ScrollContainer:
	var c: Node = Nav.port.gui_get_hovered_control() if Nav.port else null
	while c != null and c != Nav.ui:
		if c is ScrollContainer and _can_scroll(c):
			return c
		c = c.get_parent()
	for s in Nav.ui.find_children("*", "ScrollContainer", true, false):
		if s.is_visible_in_tree() and _can_scroll(s):
			return s
	return null


static func _can_scroll(s: ScrollContainer) -> bool:
	return s.get_v_scroll_bar().max_value > s.size.y + 1.0


func _click(pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.device = DEVICE
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = get_viewport().get_mouse_position()
	e.global_position = e.position
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(e)
