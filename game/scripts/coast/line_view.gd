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
const HOOK := Color("#b8c0c0")
## How far the float, with the hook under it, drifts to either side of where it landed.
const DRIFT := 5.0
## Each bait as it hangs on the hook, a few pixels drawn row by row, with the colour of each letter.
const BAITS := {
	"worm": [".xo..", "x..x.", "o..xo", "....x"],
	"shrimp": [".hxx.", "x..ox", "x...o", ".xo.."],
	"bread": [".hhx.", "hxxxo", "xxxoo", ".ooo."],
	"squid": [".xx.", "xxxx", "xoox", "x.x.", "x.x."],
	"sardine_strip": ["hxxxo", "rrrro"],
	"live_sardine": [".hxxo.", "xxxxxo", ".xxxo."],
	"salted_fish": [".xhxo.", "xxhxxo", ".xxo.."],
	"oyster": [".ooo.", "ohhxo", ".ooo."],
	"seaweed": [".x.x.", "xo.ox", ".xox.", "..o.."],
}
const BAIT_COLOURS := {
	"worm": {"x": Color("#c0606a"), "o": Color("#8a3f4a")},
	"shrimp": {"x": Color("#f08a7a"), "o": Color("#c0584f"), "h": Color("#ffd0c0")},
	"bread": {"x": Color("#e2c08a"), "o": Color("#b0844a"), "h": Color("#f8e8c0")},
	"squid": {"x": Color("#eadce2"), "o": Color("#c49aaa")},
	"sardine_strip": {"x": Color("#c8d2dc"), "o": Color("#7f92a2"), "h": Color("#eef4f8"), "r": Color("#c87272")},
	"live_sardine": {"x": Color("#c4d0dc"), "o": Color("#6f86a0"), "h": Color("#eef4f8")},
	"salted_fish": {"x": Color("#d8c8a6"), "o": Color("#a89068"), "h": Color("#ffffff")},
	"oyster": {"o": Color("#8f877a"), "x": Color("#c8bca8"), "h": Color("#ece0cc")},
	"seaweed": {"x": Color("#6aa060"), "o": Color("#3f7040")},
}
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
const SPLASH_SECONDS := 1.0
## How fast a thrown drop falls back, in pixels a second each second.
const SPLASH_FALL := 320.0

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
	_fish.z_index = _under_z()
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
	_fish.z_index = 0 if above else _under_z()
	if _fish.material:
		_fish.material.set_shader_parameter("keep", 1.0 if above else Murk.FISH_KEEP)
	_fish.position = at - screen.camera.cam
	_fish.rotation = turn
	_fish.flip_h = facing < 0.0
	_fish.modulate = Color(0.95, 1.0, 1.0)
	Pixels.set_swim(_fish, _swim)


## Under the water the fish on the line is drawn with the other fish, so the murk lies over it as over them.
func _under_z() -> int:
	return screen.swimmers.z_index - z_index if screen else 0


func _splash(at: Vector2) -> void:
	_splashes.append({"at": at, "age": 0.0, "seed": randf() * 10.0, "size": splash_size(_fish.texture.get_width() if _fish.texture else 16)})
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
		draw_rect(Rect2(at, Vector2(1, 3)), HOOK)
		var bait: String = screen.bait()
		var rows: Array = BAITS.get(bait, [])
		var corner := at + Vector2(-floorf(str(rows[0]).length() / 2.0) if not rows.is_empty() else 0.0, 3)
		for p in bait_pixels(bait):
			draw_rect(Rect2(corner + Vector2(p[0], p[1]), Vector2.ONE), p[2])
	if screen.charge >= 0.0:
		_bar(tip + Vector2(-14, -14), 28, screen.charge, CALM)
	for r in screen.rain():
		if r.y < surface:
			Pixels.line(self, r, r + Vector2(-2, 7), Color(0.82, 0.87, 0.92, 0.6))


## How far the float has drifted from where it landed: two slow swells to and fro, which now and then die away so it
## lies still for a while, never more than `DRIFT` pixels either side.
static func float_drift(t: float) -> float:
	var wander := sin(t * 0.23) * 0.65 + sin(t * 0.097 + 1.3) * 0.35
	var spells := clampf(sin(t * 0.045 + 0.6) * 1.6, 0.0, 1.0)
	return DRIFT * wander * spells


## How big a splash a fish this many texels long throws up when it breaks the surface.
static func splash_size(length: float) -> float:
	return clampf(length * 0.3, 6.0, 18.0)


## Where each drop of a splash is, `age` seconds after it, from where the fish broke the surface; drops at or below
## zero have fallen back in.
static func splash_drops(size: float, seed: float, age: float) -> Array:
	var out := []
	for i in int(size * 1.6):
		var r := fposmod(sin(seed * 12.9898 + i * 78.233) * 43758.5453, 1.0)
		var r2 := fposmod(sin(seed * 39.3468 + i * 11.135) * 24634.6345, 1.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var up := sqrt(2.0 * SPLASH_FALL * size * lerpf(1.0, 1.8, r))
		var out_speed := side * size * lerpf(0.6, 2.4, r2)
		out.append(Vector2(out_speed * age, -(up * age - SPLASH_FALL * age * age / 2.0)))
	return out


## The pixels of a bait as it hangs on the hook: [x, y, colour] from its top left corner; none for a bare hook.
static func bait_pixels(bait: String) -> Array:
	var out := []
	var rows: Array = BAITS.get(bait, [])
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] != ".":
				out.append([x, y, BAIT_COLOURS[bait][row[x]]])
	return out


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
		var n: float = s["size"]
		var at: Vector2 = (s["at"] - cam).round()
		# Two sheets of white water stand up either side of the hole the fish broke, lean out and fall back in.
		var crown := n * (1.0 - k * 2.5)
		if crown >= 1.0:
			var wide := roundf(n * 0.6)
			for c in range(-wide, wide + 1):
				var edge := absf(c) / maxf(1.0, wide)
				if edge < 0.4:
					continue
				var h := roundf(crown * edge)
				var lean := signf(c) * k * n * 1.5 * edge
				for y in h:
					var u := y / maxf(1.0, h)
					_over.draw_rect(Rect2(at + Vector2(c + roundf(lean * u), -y - 1), Vector2.ONE), Color(SPRAY, 0.9 - 0.45 * u))
		for d in splash_drops(n, float(s["seed"]), float(s["age"])):
			if d.y < 0.0:
				var big := Vector2(2, 2) if absf(d.x) < n * 0.5 and k < 0.4 else Vector2.ONE
				_over.draw_rect(Rect2(at + d.round(), big), Color(SPRAY, 1.0 - k * 0.4))
		# Foam lies on the water where it fell and thins away, as two rings of ripples spread out from it.
		var foam := roundf(n * (0.8 + k * 0.6))
		for c in range(-foam, foam + 1):
			if fposmod(c * 7.0 + float(s["seed"]) * 3.0, 5.0) < 3.5 - k * 3.0:
				_over.draw_rect(Rect2(at + Vector2(c, -1), Vector2(1, 2)), Color(SPRAY, 0.75 * (1.0 - k)))
		for ring_k in [k, k - 0.3]:
			if ring_k > 0.0:
				var ring := roundf(n + ring_k * n * 2.2)
				for side: float in [-1.0, 1.0]:
					_over.draw_rect(Rect2(at + Vector2(side * ring - 1.0, 0), Vector2(3, 1)), Color(RIPPLE, 0.9 * (1.0 - ring_k)))
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
