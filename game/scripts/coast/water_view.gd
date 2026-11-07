class_name WaterView
extends Node2D
## The water in front of everything above the surface: lighter at the top and darker with depth, with rays of light
## falling through from above.

const SURFACE := Color("#6fb8b2")
const MID_WATER := Color("#2f7f8f")
const DEEP_WATER := Color("#123448")

var cam := Vector2(0, CoastCamera.HOME_Y)
var depth := 300.0
var time := 0.0
var rays := 1.0


func _draw() -> void:
	var top := maxf(0.0, -cam.y)
	var view := Nav.view()
	# The desktop strip shifts the canvas up to the waterline, so the water runs to the bottom of what is on screen.
	for y in range(int(top), int(view.y - get_canvas_transform().origin.y), 2):
		var d := (y + cam.y) / maxf(200.0, depth)
		var c := SURFACE.lerp(MID_WATER, clampf(d * 2.2, 0.0, 1.0)).lerp(DEEP_WATER, clampf(d * 2.0 - 0.6, 0.0, 1.0))
		draw_rect(Rect2(0, y, view.x, 2), c)
	if rays <= 0.0:
		return
	for i in 7:
		var x := fposmod(i * 211.0 - cam.x * 0.9, 1500.0) - 300.0 + sin(time * 0.4 + i) * 8.0
		var alpha := (0.08 + 0.04 * sin(time * 0.7 + i * 2.0)) * rays
		# Each ray is drawn in steps that fade with depth, so it dies away instead of ending in a hard edge.
		for k in 8:
			var a0 := -cam.y + k * 22.0
			var f0 := k / 8.0
			var f1 := (k + 1) / 8.0
			draw_colored_polygon(PackedVector2Array([Vector2(x + 70 * f0, a0), Vector2(x + 22 + 82 * f0, a0),
				Vector2(x + 22 + 82 * f1, a0 + 22), Vector2(x + 70 * f1, a0 + 22)]), Color(1.0, 0.93, 0.8, alpha * (1.0 - f0)))


## The glints along the waterline, drawn in front of the boat.
static func draw_surface(node: CanvasItem, cam: Vector2, time: float) -> void:
	var surface := -cam.y
	var view := Nav.view()
	if surface < 0.0 or surface >= view.y - node.get_canvas_transform().origin.y:
		return
	for i in 40:
		var x := fposmod(i * 37.0 - cam.x + time * (6.0 + i % 3 * 2.0), view.x)
		node.draw_rect(Rect2(roundf(x), surface + (i % 2), 3 + i % 3, 1), Color(1.0, 0.93, 0.8, 0.5))
