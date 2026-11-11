class_name GroundView
extends Node2D
## Solid shadow below the seabed, fading in over sixteen pixels, so pieces in front of the floor never end in a cut.
## Its shape is laid out once in world pixels for the whole place, and only moved with the camera.

## Columns laid out past each end of the place, enough for the widest view the window or the desktop strip shows.
const SPARE := 1600.0
const STEP := 8.0
## How far below the seabed the shadow reaches, always past the bottom of any view.
const DEEP := 4000.0

var _points := PackedVector2Array()
var _colours := PackedColorArray()
var _indices := PackedInt32Array()


func build(bed: Seabed, width: float, below: float) -> void:
	_points.clear()
	_colours.clear()
	_indices.clear()
	var x0 := -SPARE
	while x0 < width + SPARE:
		var x1 := x0 + STEP
		var a := Vector2(x0, roundf(bed.depth_at(x0) + below))
		var b := Vector2(x1, roundf(bed.depth_at(x1) + below))
		_quad([a, b, Vector2(b.x, maxf(a.y, b.y) + DEEP), Vector2(a.x, maxf(a.y, b.y) + DEEP)], FloorView.SHADOW)
		for k in 8:
			var up := Vector2(0, 16.0 - k * 2.0)
			var down := Vector2(0, 14.0 - k * 2.0)
			_quad([a - up, b - up, b - down, a - down], Color(FloorView.SHADOW, (k + 1) / 9.0))
		x0 = x1
	queue_redraw()


func _quad(corners: Array, colour: Color) -> void:
	var first := _points.size()
	for c in corners:
		_points.append(c)
		_colours.append(colour)
	_indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])


func place_at(cam: Vector2) -> void:
	position = -cam


func _draw() -> void:
	if not _indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _indices, _points, _colours)
