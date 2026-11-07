class_name Seabed
extends RefCounted
## A place's seabed as a line of [x, depth] points below the waterline, traced from its painted seabed, so the hook and
## the fish stop on the sand.

var points: Array = []


func _init(list: Array) -> void:
	points = list.duplicate()
	points.sort_custom(func(a, b): return a[0] < b[0])


func depth_at(x: float) -> float:
	if points.is_empty():
		return 0.0
	if x <= float(points[0][0]):
		return float(points[0][1])
	for i in range(1, points.size()):
		if x <= float(points[i][0]):
			var a: Array = points[i - 1]
			var b: Array = points[i]
			return lerpf(float(a[1]), float(b[1]), (x - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])))
	return float(points[-1][1])


## Keeps a hook in the water: within the place's ends, below the surface, and two pixels above the sand.
func clamp_hook(at: Vector2) -> Vector2:
	var x := clampf(at.x, float(points[0][0]), float(points[-1][0]))
	return Vector2(x, clampf(at.y, 0.0, depth_at(x) - 2.0))
