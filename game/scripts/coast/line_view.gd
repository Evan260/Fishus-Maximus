class_name LineView
extends Node2D
## The rod's line, the float on the surface and the hook below it; a hooked fish on the hook; the cast bar while the
## cast is charging and the tension bar during a fight; and the rain above the water.

const LINE := Color(0.92, 0.88, 0.78, 0.85)
const UNDER := Color(0.85, 0.9, 0.9, 0.5)

var screen: Node


func _draw() -> void:
	var cam: Vector2 = screen.camera.cam
	var t: float = screen.time()
	var state: String = screen.line_state()
	var tip: Vector2 = (screen.rod_tip() - cam).round()
	var at: Vector2 = (screen.hook - cam).round()
	if state == "reeled":
		at = tip + Vector2(0, 10)
		draw_line(tip, at, LINE, 1.0)
	else:
		var dip := 3.0 if state == "bite" and fmod(t, 0.3) < 0.15 else 0.0
		if state == "fighting":
			dip = 2.0
		var bob := Vector2(at.x - 2, -cam.y - 1 + roundf(sin(t * 1.9)) + dip)
		if state == "fighting" or at.y <= bob.y:
			draw_line(tip, at, LINE, 1.0)
		else:
			var mid := (tip + bob) / 2.0 + Vector2(0, 5)
			var last := tip
			for k in range(1, 9):
				var u := k / 8.0
				var p := tip.lerp(mid, u).lerp(mid.lerp(bob, u), u)
				draw_line(last, p, LINE, 1.0)
				last = p
			draw_line(bob + Vector2(1, 2), at, UNDER, 1.0)
			draw_rect(Rect2(bob + Vector2(-1, -1), Vector2(4, 3)), Color("#c98a4b"))
			draw_rect(Rect2(bob + Vector2(-1, -1), Vector2(4, 1)), Color("#e8c08a"))
		if state == "bite":
			draw_string(UiTheme.title_font(), bob + Vector2(-1, -6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.GOLD)
	if state == "fighting" and screen.fight != null:
		var tex: Texture2D = screen.swimmers.texture_for(screen.fight.fish)
		var flip: bool = screen.hook.x < screen.rod_tip().x
		draw_set_transform(at + Vector2(0, 2), 0.3 * sin(t * 6.0), Vector2(-1 if flip else 1, 1))
		draw_texture(tex, -tex.get_size() / 2.0)
		draw_set_transform(Vector2.ZERO)
		_bar(tip + Vector2(-18, -18), 36, screen.fight.tension, Color("#d65a44") if screen.fight.tension > 0.75 else Color("#ecc460"))
	draw_rect(Rect2(at, Vector2(1, 3)), Color("#b8c0c0"))
	draw_rect(Rect2(at + Vector2(1, 1), Vector2(2, 1)), Color("#e07a8a"))
	WaterView.draw_surface(self, cam, t)
	if screen.charge >= 0.0:
		_bar(tip + Vector2(-14, -14), 28, screen.charge, Color("#ecc460"))
	var surface := -cam.y
	for r in screen.rain():
		if r.y < surface:
			draw_line(r, r + Vector2(-2, 7), Color(0.82, 0.87, 0.92, 0.6), 1.0)


func _bar(at: Vector2, width: float, fill: float, colour: Color) -> void:
	draw_rect(Rect2(at, Vector2(width, 4)), Color("#3a261e"))
	draw_rect(Rect2(at + Vector2(1, 1), Vector2((width - 2) * clampf(fill, 0.0, 1.0), 2)), colour)
