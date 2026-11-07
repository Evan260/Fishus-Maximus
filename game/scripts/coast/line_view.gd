class_name LineView
extends Node2D
## The rod's line, the float on the surface and the hook below it: the float twitches while a fish nibbles and goes
## under when it takes the bait. A hooked fish thrashes and darts off while it runs, and near the surface it sometimes
## leaps clear of the water, under a tension bar that turns red as the line nears breaking. A fish he catches on his
## own pulls the float under and comes in on the line. Also the cast bar while the cast is charging, and the rain.

const LINE := Color(0.92, 0.88, 0.78, 0.85)
const UNDER := Color(0.85, 0.9, 0.9, 0.5)
const RIPPLE := Color(1.0, 0.98, 0.92, 0.95)
const CALM := Color("#ecc460")
const DANGER := Color("#d65a44")
const BREAKING := Color("#ff9a7a")
const SPRAY := Color(0.9, 0.97, 1.0, 0.9)
## The share of the bar past which the line is in danger, tinted on the empty bar.
const DANGER_FROM := 0.7
## How deep a running fish may be and still leap, the chance each second that one at the surface does (less the deeper
## it is), how long a leap from the surface takes and how much longer for each pixel it comes up from, how high it
## goes above the water and how far it carries on the way.
const LEAP_DEPTH := 90.0
const LEAP_CHANCE := 0.5
const LEAP_SECONDS := 0.9
const LEAP_PER_DEPTH := 0.006
const LEAP_HEIGHT := Vector2(14.0, 26.0)
const LEAP_TRAVEL := 40.0
## The steepest a leaping fish tilts, in radians.
const LEAP_TILT := 0.85
## The shortest wait between two leaps.
const LEAP_REST := 2.5
const SPLASH_SECONDS := 0.6

var screen: Node
var _bar_at := Vector2(-999, -999)
## The fish on the line, drawn over the line, and the bar and splashes drawn over the fish.
var _fish: Sprite2D
var _over: Node2D
var _fish_id := ""
var _swim := 0.0
## How far through its leap the fish is, from 0 to 1, or below zero when it is in the water.
var _leap := -1.0
var _leap_height := 20.0
var _leap_for := LEAP_SECONDS
var _leap_wait := 0.0
## How far the fish still is from the hook after a leap, which the line draws back in under the water.
var _back := Vector2.ZERO
var _above := false
var _splashes: Array = []


func _ready() -> void:
	_fish = Sprite2D.new()
	_fish.visible = false
	add_child(_fish)
	_over = Node2D.new()
	_over.draw.connect(_draw_over)
	add_child(_over)


## The kind of fish on the line: hooked in a fight, or caught by him fishing on his own.
func fish_on_line() -> String:
	if screen.fight != null:
		return screen.fight.fish
	return str(screen.landing) if screen.line_state() in ["taken", "landing"] else ""


## Whether the fish on the line is in the air, in the middle of a leap.
func leaping() -> bool:
	return _leap >= 0.0


func _process(delta: float) -> void:
	if screen == null or screen.camera == null:
		return
	var id := fish_on_line()
	if id != _fish_id:
		_fish_id = id
		_leap = -1.0
		_back = Vector2.ZERO
		_above = false
		if id != "":
			var tex: Texture2D = screen.swimmers.texture_for(id)
			_fish.texture = tex
			_fish.material = Pixels.look(Swimmers.wave_for(id, tex) + 1.0)
	_fish.visible = id != ""
	_leap_wait = maxf(0.0, _leap_wait - delta)
	var fight: LineFight = screen.fight
	var shallow: float = 1.0 - screen.hook.y / LEAP_DEPTH
	if fight != null and _leap < 0.0 and _leap_wait <= 0.0 and fight.running() and shallow > 0.0 \
			and bool(Data.fish[id].get("leaps", true)) and (randf() < LEAP_CHANCE * shallow * delta or Dev.has("leap")):
		_leap = 0.0
		_leap_height = randf_range(LEAP_HEIGHT.x, LEAP_HEIGHT.y)
		_leap_for = LEAP_SECONDS + maxf(0.0, screen.hook.y) * LEAP_PER_DEPTH
	if _leap >= 0.0:
		_leap += delta / _leap_for
		if _leap >= 1.0 or fight == null:
			_back = _leap_offset(1.0)
			_leap = -1.0
			_leap_wait = LEAP_REST
	else:
		_back = _back.move_toward(Vector2.ZERO, 30.0 * delta)
	var wild: bool = fight.running() if fight != null else screen.line_state() == "taken"
	_swim = fmod(_swim + delta * (22.0 if wild else 7.0), TAU * 64.0)
	if id != "":
		_place_fish()
	for s in _splashes:
		s["age"] += delta
	_splashes = _splashes.filter(func(s): return s["age"] < SPLASH_SECONDS)
	_over.queue_redraw()


## Which way from the boat the line runs out.
func _away() -> float:
	return signf(screen.hook.x - screen.rod_tip().x + 0.01)


## Where the leaping fish is drawn from the hook a share u through its leap: up out of the water in an arc carrying
## it away from the boat, and back down to the hook's depth.
func _leap_offset(u: float) -> Vector2:
	var depth: float = screen.hook.y
	var y := depth * (1.0 - 2.0 * u) * (1.0 - 2.0 * u) - _leap_height * 4.0 * u * (1.0 - u)
	return Vector2(_away() * LEAP_TRAVEL * u, y - depth)


## Where the fish on the line is drawn in the world.
func fish_at() -> Vector2:
	var t: float = screen.time()
	var fight: LineFight = screen.fight
	var run: bool = fight == null or fight.running()
	var dart := Vector2(_away() * (2.0 + 2.0 * sin(t * 11.0)), 0.0) if run and screen.line_state() != "landing" else Vector2.ZERO
	var leap := _leap_offset(_leap) if _leap >= 0.0 else _back
	return screen.hook + Vector2(0, 2) + dart + leap


func _place_fish() -> void:
	var t: float = screen.time()
	var away := _away()
	var fight: LineFight = screen.fight
	var landing: bool = screen.line_state() == "landing"
	# While it runs it faces away from the boat; resting, or being brought in, it is drawn in head first.
	var run: bool = ((fight == null or fight.running()) and not landing) or _leap >= 0.0
	var facing := away if run else -away
	var at := fish_at()
	var turn := 0.55 * sin(t * 17.0) if run else 0.12 * sin(t * 4.0)
	if _leap >= 0.0:
		var rise: float = -4.0 * (1.0 - 2.0 * _leap) * (screen.hook.y + _leap_height)
		turn = clampf(atan2(rise * facing, LEAP_TRAVEL), -LEAP_TILT, LEAP_TILT)
	elif at.y < 0.0:
		# Lifted out of the water on the line it hangs head up.
		turn = -facing * PI / 2.0 * clampf(-at.y / 10.0, 0.0, 1.0) + 0.1 * sin(t * 9.0)
	var above := at.y < 0.0
	if above != _above:
		_above = above
		_splash(Vector2(at.x, 0.0))
	_fish.position = at - screen.camera.cam
	_fish.rotation = turn
	_fish.flip_h = facing < 0.0
	_fish.modulate = Color(0.95, 1.0, 1.0)
	Pixels.set_swim(_fish, _swim)


func _splash(at: Vector2) -> void:
	_splashes.append({"at": at, "age": 0.0, "seed": randf() * 10.0})
	Audio.play("splash_small", -8.0, randf_range(0.9, 1.2))


func _draw() -> void:
	var cam: Vector2 = screen.camera.cam
	var t: float = screen.time()
	var state: String = screen.line_state()
	var tip: Vector2 = screen.rod_tip() - cam
	var at: Vector2 = screen.hook - cam
	var surface := -cam.y
	WaterView.draw_surface(self, cam, t)
	# While he rows the rod lies in the boat with its line wound in, and while the float flies out no hook shows yet.
	var hook_shown := true
	if state == "reeled":
		hook_shown = not screen.rowing()
		at = tip + Vector2(0, 10)
		if hook_shown:
			Pixels.line(self, tip, at, LINE)
	elif screen.flight > 0.0:
		hook_shown = false
		var float_at: Vector2 = screen.flying() - cam
		Pixels.line(self, tip, float_at, LINE)
		draw_rect(Rect2(float_at + Vector2(-1, -1), Vector2(4, 3)), Color("#c98a4b"))
		draw_rect(Rect2(float_at + Vector2(-1, -1), Vector2(4, 1)), Color("#e8c08a"))
	else:
		var twitch: float = screen.twitch
		var dip := 0.0
		var under := state in ["bite", "taken"]
		if state == "nibble" and twitch > 0.0:
			dip = minf(2.0, ceilf(twitch * 8.0))
		elif under:
			dip = 5.0
		var bob := Vector2(at.x - 2, surface - 1 + sin(t * 1.9) + dip)
		var fight: LineFight = screen.fight
		if state == "fighting" or at.y <= bob.y:
			var end := fish_at() - cam - Vector2(0, 2) if _leap >= 0.0 or _back != Vector2.ZERO else at
			_curve(tip, end, (0.25 - fight.tension) * 40.0 if fight != null and fight.tension < 0.25 else 0.0)
		else:
			_curve(tip, bob, 5.0)
			Pixels.line(self, bob + Vector2(1, 2), at, UNDER)
			var shade := 0.55 if under else 1.0
			draw_rect(Rect2(bob + Vector2(-1, -1), Vector2(4, 3)), Color(Color("#c98a4b"), shade))
			draw_rect(Rect2(bob + Vector2(-1, -1), Vector2(4, 1)), Color(Color("#e8c08a"), shade))
		if state == "nibble" and twitch > 0.0:
			draw_rect(Rect2(Vector2(bob.x - 4, surface), Vector2(2, 1)), RIPPLE)
			draw_rect(Rect2(Vector2(bob.x + 5, surface), Vector2(2, 1)), RIPPLE)
		elif under:
			var spread := roundf(minf(8.0, 3.0 + (Bite.window() - screen.bite_left) * 12.0)) if state == "bite" else 3.0 + fmod(t * 6.0, 5.0)
			for side: float in [-1.0, 1.0]:
				var x := bob.x + 1.0 + side * spread
				draw_rect(Rect2(Vector2(x - 1, surface), Vector2(2, 1)), RIPPLE)
				draw_rect(Rect2(Vector2(x - 1 + side * 2.0, surface - 1 - (1 if fmod(t, 0.3) < 0.15 else 0)), Vector2(1, 1)), RIPPLE)
			if state == "bite":
				draw_string(UiTheme.title_font(), Vector2(bob.x - 1, surface - 6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.GOLD)
	if hook_shown:
		draw_rect(Rect2(at, Vector2(1, 3)), Color("#b8c0c0"))
		draw_rect(Rect2(at + Vector2(1, 1), Vector2(2, 1)), Color("#e07a8a"))
	if screen.charge >= 0.0:
		_bar(tip + Vector2(-14, -14), 28, screen.charge, CALM)
	for r in screen.rain():
		if r.y < surface:
			Pixels.line(self, r, r + Vector2(-2, 7), Color(0.82, 0.87, 0.92, 0.6))


## The line from a to b, sagging by some pixels in the middle, its pixels all on the grid of a.
func _curve(a: Vector2, b: Vector2, sag: float) -> void:
	if sag <= 0.0:
		Pixels.line(self, a, b, LINE)
		return
	var mid := (a + b) / 2.0 + Vector2(0, sag)
	var last := a
	for k in range(1, 9):
		var u := k / 8.0
		var p := a + (a.lerp(mid, u).lerp(mid.lerp(b, u), u) - a).round()
		Pixels.line(self, last, p, LINE)
		last = p


## The tension bar over the fish while it fights, and the splashes where a fish leaves the water and goes back in.
func _draw_over() -> void:
	var cam: Vector2 = screen.camera.cam
	for s in _splashes:
		var k: float = s["age"] / SPLASH_SECONDS
		var at: Vector2 = s["at"] - cam
		var crown := roundf(7.0 * (1.0 - k * 1.6))
		if crown >= 1.0:
			_over.draw_rect(Rect2(at + Vector2(-4, -crown), Vector2(2, crown)), Color(SPRAY, 0.85))
			_over.draw_rect(Rect2(at + Vector2(3, -crown + 1.0), Vector2(2, crown - 1.0)), Color(SPRAY, 0.85))
			_over.draw_rect(Rect2(at + Vector2(-1, -crown + 2.0), Vector2(2, maxf(1.0, crown - 2.0))), Color(SPRAY, 0.6))
		for i in 10:
			var side := -1.0 if i % 2 == 0 else 1.0
			var out := side * (2.0 + floorf(i / 2.0) * 2.0 + fmod(float(s["seed"]) * (i + 1), 1.5))
			var up := (8.0 + (i % 4) * 3.5) * 4.0 * k * (1.0 - k)
			var drop := Vector2(2, 1) if i % 3 == 0 else Vector2.ONE
			_over.draw_rect(Rect2(at + Vector2(out * (0.6 + k), -up - 1.0), drop), Color(SPRAY, 1.0 - k * 0.6))
		var ring := 3.0 + k * 9.0
		_over.draw_rect(Rect2(at + Vector2(-ring - 2.0, 0), Vector2(3, 1)), Color(RIPPLE, 1.0 - k))
		_over.draw_rect(Rect2(at + Vector2(ring - 1.0, 0), Vector2(3, 1)), Color(RIPPLE, 1.0 - k))
	var fight: LineFight = screen.fight
	if screen.line_state() != "fighting" or fight == null:
		return
	var t: float = screen.time()
	var at: Vector2 = screen.hook - cam
	var tex: Texture2D = screen.swimmers.texture_for(fight.fish)
	var colour := CALM
	if fight.tension > 0.9:
		colour = BREAKING if fmod(t, 0.16) < 0.08 else DANGER
	elif fight.tension > DANGER_FROM:
		colour = DANGER
	# The bar rides over the fish, where the eye is, and trails its darting so that it holds still enough to read.
	var want := Vector2(clampf(at.x - 18, 4, Nav.view().x - 40), maxf(6, at.y - tex.get_height() / 2.0 - 8))
	_bar_at = want if _bar_at.distance_to(want) > 60.0 else _bar_at.lerp(want, 0.1)
	var bar := _bar_at
	var safe := roundf(34.0 * DANGER_FROM)
	_over.draw_rect(Rect2(bar, Vector2(36, 4)), Color("#3a261e"))
	_over.draw_rect(Rect2(bar + Vector2(1 + safe, 1), Vector2(34 - safe, 2)), Color(DANGER, 0.35))
	_over.draw_rect(Rect2(bar + Vector2(1, 1), Vector2(roundf(34.0 * clampf(fight.tension, 0.0, 1.0)), 2)), colour)


func _bar(at: Vector2, width: float, fill: float, colour: Color) -> void:
	draw_rect(Rect2(at, Vector2(width, 4)), Color("#3a261e"))
	draw_rect(Rect2(at + Vector2(1, 1), Vector2((width - 2) * clampf(fill, 0.0, 1.0), 2)), colour)
