class_name LineView
extends Node2D
## The rod's line, the float on the surface and the hook below it: the float twitches while a fish nibbles and goes
## under when it takes the bait. A hooked fish thrashes and darts off while it runs, under a tension bar that turns red
## as the line nears breaking. Also the cast bar while the cast is charging, and the rain above the water.

const LINE := Color(0.92, 0.88, 0.78, 0.85)
const UNDER := Color(0.85, 0.9, 0.9, 0.5)
const RIPPLE := Color(1.0, 0.98, 0.92, 0.95)
const CALM := Color("#ecc460")
const DANGER := Color("#d65a44")
const BREAKING := Color("#ff9a7a")
## The share of the bar past which the line is in danger, tinted on the empty bar.
const DANGER_FROM := 0.7

var screen: Node
var _bar_at := Vector2(-999, -999)


func _draw() -> void:
	var cam: Vector2 = screen.camera.cam
	var t: float = screen.time()
	var state: String = screen.line_state()
	var tip: Vector2 = (screen.rod_tip() - cam).round()
	var at: Vector2 = (screen.hook - cam).round()
	var surface := -cam.y
	WaterView.draw_surface(self, cam, t)
	# While he rows the rod lies in the boat with its line wound in, and while the float flies out no hook shows yet.
	var hook_shown := true
	if state == "reeled":
		hook_shown = not screen.rowing()
		at = tip + Vector2(0, 10)
		if hook_shown:
			draw_line(tip, at, LINE, 1.0)
	elif screen.flight > 0.0:
		hook_shown = false
		var float_at: Vector2 = (screen.flying() - cam).round()
		draw_line(tip, float_at, LINE, 1.0)
		draw_rect(Rect2(float_at + Vector2(-1, -1), Vector2(4, 3)), Color("#c98a4b"))
		draw_rect(Rect2(float_at + Vector2(-1, -1), Vector2(4, 1)), Color("#e8c08a"))
	else:
		var twitch: float = screen.twitch
		var dip := 0.0
		if state == "nibble" and twitch > 0.0:
			dip = minf(2.0, ceilf(twitch * 8.0))
		elif state == "bite":
			dip = 5.0
		var bob := Vector2(at.x - 2, surface - 1 + roundf(sin(t * 1.9)) + dip)
		var fight: LineFight = screen.fight
		if state == "fighting" or at.y <= bob.y:
			_curve(tip, at, (0.25 - fight.tension) * 40.0 if fight != null and fight.tension < 0.25 else 0.0)
		else:
			_curve(tip, bob, 5.0)
			draw_line(bob + Vector2(1, 2), at, UNDER, 1.0)
			var shade := 0.55 if state == "bite" else 1.0
			draw_rect(Rect2(bob + Vector2(-1, -1), Vector2(4, 3)), Color(Color("#c98a4b"), shade))
			draw_rect(Rect2(bob + Vector2(-1, -1), Vector2(4, 1)), Color(Color("#e8c08a"), shade))
		if state == "nibble" and twitch > 0.0:
			draw_rect(Rect2(Vector2(bob.x - 4, surface), Vector2(2, 1)), RIPPLE)
			draw_rect(Rect2(Vector2(bob.x + 5, surface), Vector2(2, 1)), RIPPLE)
		elif state == "bite":
			var spread := roundf(minf(8.0, 3.0 + (Bite.window() - screen.bite_left) * 12.0))
			for side: float in [-1.0, 1.0]:
				var x := bob.x + 1.0 + side * spread
				draw_rect(Rect2(Vector2(x - 1, surface), Vector2(2, 1)), RIPPLE)
				draw_rect(Rect2(Vector2(x - 1 + side * 2.0, surface - 1 - (1 if fmod(t, 0.3) < 0.15 else 0)), Vector2(1, 1)), RIPPLE)
			draw_string(UiTheme.title_font(), Vector2(bob.x - 1, surface - 6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.GOLD)
	if state == "fighting" and screen.fight != null:
		_hooked_fish(at, t)
	if hook_shown:
		draw_rect(Rect2(at, Vector2(1, 3)), Color("#b8c0c0"))
		draw_rect(Rect2(at + Vector2(1, 1), Vector2(2, 1)), Color("#e07a8a"))
	if screen.charge >= 0.0:
		_bar(tip + Vector2(-14, -14), 28, screen.charge, CALM)
	for r in screen.rain():
		if r.y < surface:
			draw_line(r, r + Vector2(-2, 7), Color(0.82, 0.87, 0.92, 0.6), 1.0)


## The line from a to b, sagging by some pixels in the middle.
func _curve(a: Vector2, b: Vector2, sag: float) -> void:
	if sag <= 0.0:
		draw_line(a, b, LINE, 1.0)
		return
	var mid := (a + b) / 2.0 + Vector2(0, sag)
	var last := a
	for k in range(1, 9):
		var u := k / 8.0
		var p := a.lerp(mid, u).lerp(mid.lerp(b, u), u)
		draw_line(last, p, LINE, 1.0)
		last = p


## The fish on the hook: while it runs it faces away from the boat, thrashes and darts; resting, it is drawn in head first.
func _hooked_fish(at: Vector2, t: float) -> void:
	var fight: LineFight = screen.fight
	var tex: Texture2D = screen.swimmers.texture_for(fight.fish)
	var away: float = signf(screen.hook.x - screen.rod_tip().x + 0.01)
	var run := fight.running()
	var facing := away if run else -away
	var turn := 0.55 * sin(t * 17.0) if run else 0.12 * sin(t * 4.0)
	var dart := Vector2(roundf(away * (2.0 + 2.0 * sin(t * 11.0))), 0.0) if run else Vector2.ZERO
	draw_set_transform(at + Vector2(0, 2) + dart, turn, Vector2(facing, 1))
	draw_texture(tex, -tex.get_size() / 2.0)
	draw_set_transform(Vector2.ZERO)
	var colour := CALM
	if fight.tension > 0.9:
		colour = BREAKING if fmod(t, 0.16) < 0.08 else DANGER
	elif fight.tension > DANGER_FROM:
		colour = DANGER
	# The bar rides over the fish, where the eye is, and trails its darting so that it holds still enough to read.
	var want := Vector2(clampf(at.x - 18, 4, Nav.view().x - 40), maxf(6, at.y - tex.get_height() / 2.0 - 8))
	_bar_at = want if _bar_at.distance_to(want) > 60.0 else _bar_at.lerp(want, 0.1)
	var bar := _bar_at.round()
	var safe := roundf(34.0 * DANGER_FROM)
	draw_rect(Rect2(bar, Vector2(36, 4)), Color("#3a261e"))
	draw_rect(Rect2(bar + Vector2(1 + safe, 1), Vector2(34 - safe, 2)), Color(DANGER, 0.35))
	draw_rect(Rect2(bar + Vector2(1, 1), Vector2(roundf(34.0 * clampf(fight.tension, 0.0, 1.0)), 2)), colour)


func _bar(at: Vector2, width: float, fill: float, colour: Color) -> void:
	draw_rect(Rect2(at, Vector2(width, 4)), Color("#3a261e"))
	draw_rect(Rect2(at + Vector2(1, 1), Vector2((width - 2) * clampf(fill, 0.0, 1.0), 2)), colour)
