class_name FingerPress
extends RefCounted
## One finger on a screen's scene on a phone, followed from the mouse events the phone makes of it: the scene acts when
## a tap lifts, and names what is under a finger held still instead, as a pointer resting there would. Positions are
## in view pixels, as the screen's own input events give them.

var down := false
var from := Vector2.ZERO
var at := Vector2.ZERO


## Follows an input event; true when it is the lift of a tap, which acts on what is at `at`.
func follow(e: InputEvent) -> bool:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		at = e.position
		if e.pressed:
			down = true
			from = e.position
			return false
		var was := down
		down = false
		return was and Touch.is_tap(from.distance_to(at) * Nav.zoom, Windowing.touch_slop(), Tips.long_press)
	if e is InputEventMouseMotion and down:
		at = e.position
	return false


## Whether a finger has rested on the scene long enough to be told what is under it.
func naming() -> bool:
	return down and Tips.long_press
