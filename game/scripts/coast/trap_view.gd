class_name TrapView
extends Node2D
## The place's pots on the seabed, each with a rope up to its float on the surface.

var screen: Node
var _pot: Texture2D = load("res://assets/art/props/trap.png") if ResourceLoader.exists("res://assets/art/props/trap.png") else null
var _buoy: Texture2D = load("res://assets/art/props/buoy.png") if ResourceLoader.exists("res://assets/art/props/buoy.png") else null


func _draw() -> void:
	var cam: Vector2 = screen.camera.cam
	var t: float = screen.time()
	for trap in Game.state["traps"]:
		if trap["place"] != screen.place_id:
			continue
		var x := float(trap["x"])
		var bed := Vector2(x, screen.seabed.depth_at(x)) - cam
		var top := Vector2(x, -cam.y + roundf(sin(t * 1.7 + x)))
		draw_line(top + Vector2(0, 2), bed + Vector2(0, -6), Color(0.75, 0.68, 0.5, 0.7), 1.0)
		if _pot:
			draw_texture(_pot, (bed - Vector2(_pot.get_width() / 2.0, _pot.get_height() - 3)).round())
		else:
			draw_rect(Rect2(bed + Vector2(-6, -10), Vector2(12, 10)), Color("#8a6236"))
		if _buoy:
			draw_texture(_buoy, (top - Vector2(_buoy.get_width() / 2.0, _buoy.get_height() * 0.6)).round())
		else:
			draw_rect(Rect2(top + Vector2(-2, -3), Vector2(5, 4)), Color("#c8443a"))
		if not trap["catch"].is_empty():
			draw_rect(Rect2(top + Vector2(-1, -10), Vector2(3, 3)), UiTheme.GOLD)
