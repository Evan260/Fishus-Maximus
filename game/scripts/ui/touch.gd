class_name Touch
## Decisions about a phone's touch screen, kept apart from the interface so the tests can check them.

## How long a finger rests on something before the game shows what it is rather than acting on it.
const HOLD_SECONDS := 0.4


## Whether a finger that has rested this long and wandered this far, in screen pixels, is holding rather than tapping.
static func is_hold(seconds: float, moved: float, slop: float) -> bool:
	return seconds >= HOLD_SECONDS and moved <= slop


## Whether a lifted finger acts on what it touched, which a finger that slid away or was held to read it does not.
static func is_tap(moved: float, slop: float, held: bool) -> bool:
	return moved <= slop and not held


## What the back gesture does next: "close" what is open, "leave" the town, the pond or the bay map, go from the boat to
## the "title", put the game in the "background" from the title, or "stay" while a fish is on the line.
static func back_step(something_open: bool, screen: String, fighting: bool) -> String:
	if something_open:
		return "close"
	match screen:
		"title":
			return "background"
		"coast":
			return "stay" if fighting else "title"
	return "leave"


## What a finger on the water did while the line is out: a "tap" reels in, sliding up or down sets the bait's "depth",
## and sliding across is a "slide" that does neither.
static func line_gesture(moved: Vector2, slop: float) -> String:
	if moved.length() <= slop:
		return "tap"
	return "depth" if absf(moved.y) >= absf(moved.x) else "slide"


## The bait's depth once the finger has slid `dy` game pixels down from where it touched, kept between the surface and
## the deepest the seabed and the line allow.
static func bait_depth(from: float, dy: float, deepest: float) -> float:
	return clampf(from + dy, 0.0, maxf(0.0, deepest))


## How far a window rises so the text field ending at `field_bottom` shows above the keyboard's top, though never past
## the top of the screen; all in interface pixels, with INF for no keyboard.
static func keyboard_lift(field_bottom: float, keyboard_top: float, window_top: float) -> float:
	return clampf(field_bottom + 4.0 - keyboard_top, 0.0, maxf(0.0, window_top - 2.0))


## A rect grown about its middle to at least a fingertip each way, so something small is easy to tap.
static func finger_rect(r: Rect2, finger: float) -> Rect2:
	var grow := (Vector2(finger, finger) - r.size).max(Vector2.ZERO) / 2.0
	return r.grow_individual(grow.x, grow.y, grow.x, grow.y)
