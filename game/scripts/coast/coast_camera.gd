class_name CoastCamera
extends RefCounted
## The camera's top-left corner on a place. It follows the boat along the coast, looking a little ahead in the way
## the boat is rowing, and rises while he rows so the view looks over the water rather than into it. With the line
## out it keeps the float on screen, rising with it while it flies and following the hook down so it is never lower
## than 200 pixels down the screen.

const HOME_Y := -160.0
const LEAD := 40.0
const HOOK_ROOM := 200.0
## Rows of sea left showing under the waterline while he rows, which keeps the boat clear of the bar along the bottom.
const ROW_SEA := 44.0
## Seconds the rowing view waits after the oars stop before it looks back down, so a short pause does not bob it.
const ROW_LINGER := 1.2
## How far below the top of the view a flying float is kept, and how far in from the sides the float is kept.
const FLOAT_ROOM := 60.0
const FLOAT_EDGE := 60.0
## The view's size, which grows past 480 by 270 to fill a window of another shape.
var view := Vector2(480, 270)

var world: Vector2
var cam := Vector2(0, HOME_Y)
var _last_x := NAN
var _lead := 0.0
var _since_rowed := INF


func _init(size: Vector2) -> void:
	world = size


func top() -> float:
	return HOME_Y


## Follows the boat; with the line out, `hook` is the float or the hook, and while the float flies it is where the
## float will land, at the height it has reached.
func follow(boat_x: float, hook: Vector2, hooked: bool, delta: float, rowing := false) -> void:
	var dir := 0.0 if is_nan(_last_x) else signf(boat_x - _last_x)
	_last_x = boat_x
	_lead = lerpf(_lead, dir * LEAD, minf(1.0, delta * 2.0))
	_since_rowed = 0.0 if rowing else _since_rowed + delta
	var want := Vector2(boat_x + 52.0 - view.x / 2.0 + _lead, HOME_Y)
	if hooked:
		want.x = clampf(want.x, hook.x + FLOAT_EDGE - view.x, hook.x - FLOAT_EDGE)
		if hook.y < 0.0:
			want.y = minf(HOME_Y, hook.y - FLOAT_ROOM)
		else:
			want.y = clampf(hook.y - HOOK_ROOM, HOME_Y, maxf(HOME_Y, world.y - view.y))
	elif _since_rowed < ROW_LINGER:
		want.y = minf(HOME_Y, ROW_SEA - view.y)
	want.x = clampf(want.x, 0.0, maxf(0.0, world.x - view.x))
	cam = cam.lerp(want, minf(1.0, delta * 3.0))
	if cam.distance_to(want) < 0.02:
		cam = want


## Puts the camera straight somewhere, for screenshots and for arriving at a place.
func jump(at: Vector2) -> void:
	cam = Vector2(clampf(at.x, 0.0, maxf(0.0, world.x - view.x)), clampf(at.y, HOME_Y, maxf(HOME_Y, world.y - view.y)))
