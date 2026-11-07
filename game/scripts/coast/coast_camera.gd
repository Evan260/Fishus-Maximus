class_name CoastCamera
extends RefCounted
## The camera's top-left corner on a place. It follows the boat along the coast, looking a little ahead in the way
## the boat is rowing, and follows the hook down so it is never lower than 200 pixels down the screen.

const HOME_Y := -160.0
const LEAD := 40.0
const HOOK_ROOM := 200.0
## The view's size, which grows past 480 by 270 to fill a window of another shape.
var view := Vector2(480, 270)

var world: Vector2
var cam := Vector2(0, HOME_Y)
var _last_x := NAN
var _lead := 0.0


func _init(size: Vector2) -> void:
	world = size


func top() -> float:
	return HOME_Y


func follow(boat_x: float, hook: Vector2, hooked: bool, delta: float) -> void:
	var dir := 0.0 if is_nan(_last_x) else signf(boat_x - _last_x)
	_last_x = boat_x
	_lead = lerpf(_lead, dir * LEAD, minf(1.0, delta * 2.0))
	var want := Vector2(clampf(boat_x + 52.0 - view.x / 2.0 + _lead, 0.0, maxf(0.0, world.x - view.x)), HOME_Y)
	if hooked:
		want.y = clampf(hook.y - HOOK_ROOM, HOME_Y, maxf(HOME_Y, world.y - view.y))
	cam = cam.lerp(want, minf(1.0, delta * 3.0))
	if cam.distance_to(want) < 0.02:
		cam = want


## Puts the camera straight somewhere, for screenshots and for arriving at a place.
func jump(at: Vector2) -> void:
	cam = Vector2(clampf(at.x, 0.0, maxf(0.0, world.x - view.x)), clampf(at.y, HOME_Y, maxf(HOME_Y, world.y - view.y)))
