class_name BoatLantern
extends Node2D
## The lantern on the big boat's prow: its flame wavers as it burns, and its warm light spreads round it over the boat
## and the water, faint by day and strong at night. Drawn added onto the scene, outside the darkening of the night, so
## it glows.

const COLOUR := Color(1.0, 0.72, 0.36)
const FLAME := Color(1.0, 0.93, 0.62)
## How far the light reaches, in game pixels.
const REACH := 44.0

var screen: Node


func _ready() -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add


## How strongly the lantern shines, from 0 to about 1: a little by day and fully in the dark, wavering as it burns.
static func glow(dark: float, t: float) -> float:
	var waver := 0.82 + 0.1 * sin(t * 9.0) + 0.05 * sin(t * 23.0 + 1.3) + 0.03 * sin(t * 41.0)
	return (0.2 + 0.8 * clampf(dark, 0.0, 1.0)) * waver


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var boat: BoatView = screen.boat_view()
	if boat == null or boat.lantern.x < 0.0:
		return
	var at := boat.lantern_at()
	var t: float = screen.time()
	var light: Color = screen.light_now()
	var dark := clampf((1.0 - light.g) / 0.5, 0.0, 1.0)
	var shine := glow(dark, t)
	for k in 7:
		var r := REACH * (1.0 - k / 7.0)
		Pixels.disc(self, at, r, Color(COLOUR, (0.05 + 0.07 * k / 6.0) * shine))
	# In the dark its light lies on the water under it as a column of short warm streaks, breaking up as the sea moves.
	var surface := -float(screen.camera.cam.y)
	if dark > 0.0:
		for k in 6:
			var y := surface + 1.0 + k * 2.0
			var w := roundf(5.0 - k * 0.5 + 2.0 * sin(t * 2.3 + k * 1.7))
			var x := roundf(at.x - 0.5 + sin(t * 1.4 + k * 2.1) * (1.0 + k * 0.5) - w / 2.0)
			draw_rect(Rect2(Vector2(x, y), Vector2(maxf(1.0, w), 1.0)), Color(COLOUR, 0.65 * dark * shine * (1.0 - k / 7.0)))
	# The flame's brightest pixel climbs and drops a little as it burns, and its glass brightens and dims with it.
	var lick := roundf(sin(t * 7.0) * 0.6 + sin(t * 17.0) * 0.5)
	draw_rect(Rect2(at + Vector2(-1.5, -1.5), Vector2(4, 4)), Color(COLOUR, 0.25 * shine))
	draw_rect(Rect2(at + Vector2(-0.5, -0.5 + lick), Vector2(2, 2)), Color(FLAME, 0.55 * shine))
