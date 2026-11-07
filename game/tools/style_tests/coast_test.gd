extends Node2D
## The parallax style test: a stretch of coast three screens wide and two deep, in layers that slide at their own
## speeds. A demo rows out from the quay, casts beyond the reef, follows the hook down, reels a grouper up and rows on
## towards the cape. The arrow keys take over: left and right row, down lets out line, up reels in. Nothing here is a rule of the game.

const ART := "res://assets/art/coast/"
const OLD_ART := "res://assets/art/style_test/"
const WORLD := Vector2(1440, 460)
## The camera's top-left corner at the start, with the waterline 160 pixels down the screen.
const HOME := Vector2(0, -160)
const SCREEN := Vector2(480, 270)
const HORIZON := 106.0
const SURFACE := Color("#6fb8b2")
const MID_WATER := Color("#2f7f8f")
const DEEP_WATER := Color("#123448")
const SHADOW := Color("#14222a")
## The ground below the quay, the harbour floor and the reef, in world pixels.
const GROUND: Array[Rect2] = [Rect2(0, 95, 150, 400), Rect2(120, 238, 620, 300), Rect2(680, 404, 256, 100)]

var cam := HOME
var boat_x := 150.0
## How far the hook is below the waterline; below zero it is out of the water, at the rod.
var hook_depth := -1.0
var _time := 0.0
var _manual := false
var _layers: Array = []
var _fish: Array = []
var _bubbles: Array = []
var _boat: Sprite2D
var _hull: Sprite2D
var _quay_under: Sprite2D
var _caught: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 3
	_layer("sky.png", Vector2(0, HORIZON - 150), Vector2(0.05, 0.05), -20)
	_sea_band(Vector2(0.12, 0.12), HORIZON, Color("#c98f7a"), Color("#8fa0a8"), -19)
	_layer("far.png", Vector2(-40, HORIZON - 70), Vector2(0.12, 0.12), -18)
	_sea_band(Vector2(0.3, 0.3), HORIZON + 10, Color("#b9877a"), Color("#6f93a0"), -17)
	_layer("mid.png", Vector2(200, HORIZON + 10 - 80), Vector2(0.3, 0.3), -16)
	_sea_band(Vector2(0.55, 0.55), HORIZON + 30, Color("#a37e78"), Color("#4f8494"), -15)
	_layer("town.png", Vector2(-190, HORIZON + 30 - 110), Vector2(0.55, 0.55), -14)
	_layer("cape.png", Vector2(700, HORIZON + 30 - 112), Vector2(0.55, 0.55), -14)
	_painter(_draw_water, -10)
	_layer("deep_far.png", Vector2(300, 420), Vector2(0.6, 0.8), -9)
	_layers[-1]["node"].modulate.a = 0.6
	_painter(_draw_ground, -8)
	_layer("bed_harbour.png", Vector2(120, 40) - HOME, Vector2.ONE, -8)
	_layer("bed_harbour.png", Vector2(420, 40) - HOME, Vector2.ONE, -8, true)
	_layer("bed_reef.png", Vector2(680, 150) - HOME, Vector2.ONE, -8)
	_layer("bed_deep.png", Vector2(920, 300) - HOME, Vector2.ONE, -8)
	_layer("bed_deep.png", Vector2(1300, 300) - HOME, Vector2.ONE, -8, true)
	_painter(_draw_ground_fade, -8)
	_layer("quay.png", Vector2(0, -83) - HOME, Vector2.ONE, -7)
	_quay_under = Sprite2D.new()
	_quay_under.texture = load(ART + "quay.png")
	_quay_under.centered = false
	_quay_under.region_enabled = true
	_quay_under.region_rect = Rect2(0, 84, 160, 94)
	_quay_under.modulate = Color(0.45, 0.72, 0.78, 0.8)
	_quay_under.z_index = -7
	add_child(_quay_under)
	_swimmer("sardine", Vector2(250, 40), 20.0, 2.0, 2.2, 9)
	_swimmer("mullet", Vector2(300, 160), 8.0, 1.5, 3.0)
	_swimmer("mullet", Vector2(520, 165), -6.0, 1.5, 2.6)
	_swimmer("bream", Vector2(460, 100), -11.0, 3.0, 1.8)
	_swimmer("bream", Vector2(760, 110), 9.0, 3.0, 2.0)
	_swimmer("moray", Vector2(735, 272), 0.0, 3.0, 0.8)
	_swimmer("octopus", Vector2(860, 372), 0.0, 4.0, 1.2)
	_swimmer("grouper", Vector2(1060, 396), 4.0, 2.0, 1.0)
	_swimmer("tuna", Vector2(1200, 130), -34.0, 4.0, 1.4)
	_swimmer("tuna", Vector2(1260, 160), -34.0, 4.0, 1.5)
	_layer("weeds_a.png", Vector2(330, 120) - HOME, Vector2(1.15, 1.0), -2)
	_layer("weeds_b.png", Vector2(560, 124) - HOME, Vector2(1.15, 1.0), -2)
	_layer("weeds_a.png", Vector2(980, 352) - HOME, Vector2(1.15, 1.0), -2)
	_boat = Sprite2D.new()
	_boat.texture = load(OLD_ART + "boat.png")
	_boat.centered = false
	_boat.z_index = -1
	add_child(_boat)
	_hull = Sprite2D.new()
	_hull.texture = _boat.texture
	_hull.centered = false
	_hull.region_enabled = true
	_hull.modulate = Color(0.5, 0.78, 0.84, 0.85)
	_hull.z_index = -1
	add_child(_hull)
	_painter(_draw_line_and_light, 0)


## A picture that slides with the camera at its own speed; `at` is where it sits on screen at the start.
func _layer(file: String, at: Vector2, factor: Vector2, z: int, mirror := false) -> void:
	if not ResourceLoader.exists(ART + file):
		return
	var s := Sprite2D.new()
	s.texture = load(ART + file)
	s.centered = false
	s.flip_h = mirror
	s.z_index = z
	add_child(s)
	_layers.append({"node": s, "at": at, "factor": factor})


## The sea between a row of land and the land in front of it, so no layer ever floats over the sky.
func _sea_band(factor: Vector2, top: float, near_sun: Color, colour: Color, z: int) -> void:
	var p := _painter(func(node: Node2D) -> void:
		var y := roundf(top - (cam.y - HOME.y) * factor.y)
		node.draw_rect(Rect2(0, y, SCREEN.x, SCREEN.y - y + 400), colour)
		var sun_x := 264.0 - (cam.x - HOME.x) * 0.05
		for i in 26:
			var row := y + 2 + (i * 7) % 40
			var x := fposmod(i * 53.0 - (cam.x - HOME.x) * factor.x + _time * (3.0 + i % 4), 520.0) - 20.0
			node.draw_rect(Rect2(roundf(x), row, 4 + i % 5, 1), Color(1, 1, 1, 0.12))
		for i in 18:
			if sin(_time * 2.6 + i * 1.3) > 0.2:
				node.draw_rect(Rect2(roundf(sun_x - 18 + (i * 11) % 36), y + 1 + (i * 5) % 22, 3, 1), Color(near_sun.lightened(0.5), 0.8)), z)
	p.z_index = z


func _painter(fn: Callable, z: int) -> Node2D:
	var p := Painter.new()
	p.fn = fn
	p.z_index = z
	add_child(p)
	return p


func _swimmer(kind: String, at: Vector2, speed: float, sway: float, rate: float, shoal := 1) -> void:
	for i in shoal:
		var s := Sprite2D.new()
		var file := ART + kind + ".png"
		s.texture = load(file if ResourceLoader.exists(file) else OLD_ART + kind + ".png")
		s.z_index = -4
		add_child(s)
		var home := at + (Vector2((i % 3) * 16 + _rng.randf_range(-3, 3), (i / 3) * 8 + _rng.randf_range(-2, 2)) if shoal > 1 else Vector2.ZERO)
		_fish.append({"sprite": s, "kind": kind, "pos": home, "home": home, "speed": speed, "sway": sway, "rate": rate,
			"phase": _rng.randf() * TAU})


func _process(delta: float) -> void:
	_time += delta
	if Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right") or Input.is_action_pressed("ui_up") or Input.is_action_pressed("ui_down"):
		_manual = true
	if _manual:
		boat_x = clampf(boat_x + Input.get_axis("ui_left", "ui_right") * 40.0 * delta, 60.0, WORLD.x - 120.0)
		hook_depth = clampf(hook_depth + Input.get_axis("ui_up", "ui_down") * 70.0 * delta, -1.0, WORLD.y - 70.0)
	else:
		_demo()
	var want := Vector2(clampf(boat_x + 52.0 - SCREEN.x / 2.0, 0.0, WORLD.x - SCREEN.x),
		clampf(maxf(HOME.y, hook_depth - 160.0), HOME.y, WORLD.y - SCREEN.y))
	cam = cam.lerp(want, minf(1.0, delta * 3.0))
	for l in _layers:
		l["node"].position = (l["at"] - (cam - HOME) * l["factor"]).round()
	_quay_under.position = (Vector2(0, 1) - cam).round()
	_boat.position = (Vector2(boat_x, -44.0 + roundf(sin(_time * 1.6))) - cam).round()
	var cut := clampf(1.0 - (_boat.position.y + cam.y), 0.0, _boat.texture.get_height() - 1.0)
	_hull.region_rect = Rect2(0, cut, _boat.texture.get_width(), _boat.texture.get_height() - cut)
	_hull.position = _boat.position + Vector2(0, cut)
	_swim(delta)
	if _rng.randf() < delta * 1.5:
		_bubbles.append(Vector2(_rng.randf_range(600, 680), 270.0))
	for i in _bubbles.size():
		_bubbles[i] += Vector2(sin(_time * 3.0 + i) * 4.0 * delta, -20.0 * delta)
	_bubbles = _bubbles.filter(func(b): return b.y > 2.0)
	for c in get_children():
		if c is Painter:
			c.queue_redraw()


## The demo: row out, cast, follow the hook down, hook a grouper, reel it up and row on to the cape.
func _demo() -> void:
	var t := _time
	boat_x = 150.0 + 680.0 * _ease(t, 2.0, 9.5) + 330.0 * _ease(t, 26.0, 34.0)
	if t < 10.0:
		hook_depth = -1.0
	elif t < 17.0:
		hook_depth = 10.0 + 330.0 * _ease(t, 10.5, 16.5)
	elif t < 19.0:
		hook_depth = 340.0
	else:
		hook_depth = 340.0 - 342.0 * _ease(t, 19.0, 24.5)
	if t >= 16.0 and t < 25.0 and _caught.is_empty():
		_caught = _fish.filter(func(f): return f["kind"] == "grouper")[0]
	if t >= 25.0 and not _caught.is_empty():
		_caught["sprite"].visible = false
		_caught = {}


func _ease(t: float, from: float, to: float) -> float:
	var k := clampf((t - from) / (to - from), 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


func _swim(delta: float) -> void:
	for f in _fish:
		var s: Sprite2D = f["sprite"]
		if f == _caught:
			var target := _hook_world() + Vector2(4, 6)
			var pull := 1.0 if _time >= 18.0 else clampf((_time - 16.0) / 2.0, 0.0, 1.0)
			f["pos"] = f["pos"].lerp(target, pull)
			s.flip_h = true
			s.rotation = 0.5 if _time >= 18.0 else 0.0
		else:
			f["pos"].x += f["speed"] * delta
			if f["pos"].x > WORLD.x + 20.0:
				f["pos"].x = -20.0
			elif f["pos"].x < -20.0:
				f["pos"].x = WORLD.x + 20.0
			var y: float = f["home"].y + sin(_time * f["rate"] + f["phase"]) * f["sway"]
			if f["kind"] == "moray":
				f["pos"].x = f["home"].x + sin(_time * 0.7) * 3.0
			if f["kind"] == "octopus":
				s.scale.y = 1.0 + sin(_time * 2.4) * 0.05
			f["pos"].y = y
			s.flip_h = f["speed"] < 0.0
		s.position = (f["pos"] - cam).round()
		var depth := clampf(f["pos"].y / WORLD.y, 0.0, 1.0)
		s.modulate = Color(0.95, 1.0, 1.0).lerp(Color(0.55, 0.72, 0.8), depth)


func _rod_tip_world() -> Vector2:
	return Vector2(boat_x + 102.0, -40.0 + roundf(sin(_time * 1.6)))


func _hook_world() -> Vector2:
	if hook_depth < 0.0:
		return _rod_tip_world() + Vector2(2, 10)
	return Vector2(boat_x + 126.0 + roundf(sin(_time * 0.8) * 2.0), hook_depth)


## The water in front of everything above the surface: tinted by depth, with light falling through from above.
func _draw_water(node: Node2D) -> void:
	var top := maxf(0.0, -cam.y)
	for y in range(int(top), int(SCREEN.y), 2):
		var depth := (y + cam.y) / WORLD.y
		var c := SURFACE.lerp(MID_WATER, clampf(depth * 2.2, 0.0, 1.0)).lerp(DEEP_WATER, clampf(depth * 2.0 - 0.6, 0.0, 1.0))
		node.draw_rect(Rect2(0, y, SCREEN.x, 2), c)
	for i in 7:
		var x := fposmod(i * 211.0 - cam.x * 0.9, 1500.0) - 300.0 + sin(_time * 0.4 + i) * 8.0
		var y0 := -cam.y
		var alpha := 0.08 + 0.04 * sin(_time * 0.7 + i * 2.0)
		# Each ray is drawn in steps that fade with depth, so it dies away instead of ending in a hard edge.
		for k in 8:
			var a0 := y0 + k * 22.0
			var a1 := a0 + 22.0
			var f0 := k * 22.0 / 176.0
			var f1 := (k + 1) * 22.0 / 176.0
			node.draw_colored_polygon(PackedVector2Array([Vector2(x + 70 * f0, a0), Vector2(x + 22 + 70 * f0 + 12 * f0, a0),
				Vector2(x + 22 + 70 * f1 + 12 * f1, a1), Vector2(x + 70 * f1, a1)]), Color(1.0, 0.93, 0.8, alpha * (1.0 - f0)))


## Solid ground in deep shadow under the seabed pictures, so nothing behind shows through below their bottom edges.
func _draw_ground(node: Node2D) -> void:
	for r in GROUND:
		node.draw_rect(Rect2((r.position - cam).round(), r.size), SHADOW)


## Each seabed picture's bottom edge fades into the shadow below it rather than ending in a line.
func _draw_ground_fade(node: Node2D) -> void:
	for r in GROUND:
		for k in 16:
			var row := Rect2((Vector2(r.position.x, r.position.y - 16 + k) - cam).round(), Vector2(r.size.x, 1))
			node.draw_rect(row, Color(SHADOW, k / 16.0))
	for k in 16:
		node.draw_rect(Rect2((Vector2(680 + k, 238) - cam).round(), Vector2(1, 166)), Color(SHADOW, 1.0 - k / 16.0))


func _draw_line_and_light(node: Node2D) -> void:
	var line := Color(0.92, 0.88, 0.78, 0.85)
	var tip := _rod_tip_world() - cam
	var hook := _hook_world() - cam
	if hook_depth >= 0.0:
		var bob := Vector2(hook.x - 2, -cam.y - 1 + roundf(sin(_time * 1.9)))
		var mid := (tip + bob) / 2.0 + Vector2(0, 5)
		var last := tip
		for k in range(1, 9):
			var t := k / 8.0
			var p := tip.lerp(mid, t).lerp(mid.lerp(bob, t), t)
			node.draw_line(last, p, line, 1.0)
			last = p
		node.draw_line(bob + Vector2(1, 2), hook, Color(0.85, 0.9, 0.9, 0.5), 1.0)
		node.draw_rect(Rect2(bob + Vector2(-1, -1), Vector2(4, 3)), Color("#c98a4b"))
		node.draw_rect(Rect2(bob + Vector2(-1, -1), Vector2(4, 1)), Color("#e8c08a"))
	else:
		node.draw_line(tip, hook, line, 1.0)
	node.draw_rect(Rect2(hook, Vector2(1, 3)), Color("#b8c0c0"))
	node.draw_rect(Rect2(hook + Vector2(1, 1), Vector2(2, 1)), Color("#e07a8a"))
	for b in _bubbles:
		var p: Vector2 = b - cam
		node.draw_rect(Rect2(p.round(), Vector2(1, 1)), Color(0.9, 1.0, 1.0, 0.6))
	var surface := -cam.y
	if surface >= 0.0 and surface < SCREEN.y:
		for i in 40:
			var x := fposmod(i * 37.0 - cam.x + _time * (6.0 + i % 3 * 2.0), 480.0)
			node.draw_rect(Rect2(roundf(x), surface + (i % 2), 3 + i % 3, 1), Color(1.0, 0.93, 0.8, 0.5))


class Painter extends Node2D:
	var fn: Callable

	func _draw() -> void:
		fn.call(self)
