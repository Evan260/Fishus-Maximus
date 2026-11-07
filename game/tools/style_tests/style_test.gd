extends Node2D
## The style test: one finished scene of the bay at sunset, cut through at the waterline, with the boat fishing above
## and the fish swimming below. It shows the look only; nothing here is a rule of the game.

const ART := "res://assets/art/style_test/"
const WATERLINE := 132.0
## Fish further down take more of the water's colour, so the sprites sit in the sea rather than on top of it.
const SHALLOW := Color(0.9, 0.96, 1.0)
const DEEP := Color(0.62, 0.8, 0.86)

var _time := 0.0
var _boat: Sprite2D
var _hull: Sprite2D
var _fish: Array = []
var _bubbles: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	var bg := Sprite2D.new()
	bg.texture = load(ART + "background.png")
	bg.centered = false
	# Behind the scene's own drawing: the line, the float, the bubbles and the light on the water.
	bg.z_index = -1
	add_child(bg)
	_swimmer("moray", Vector2(36, 196), 0.0, 3.0, 2.0)
	_swimmer("octopus", Vector2(404, 226), 0.0, 4.0, 1.2)
	_swimmer("mullet", Vector2(120, 238), 9.0, 1.5, 3.0)
	_swimmer("mullet", Vector2(330, 244), -7.0, 1.5, 2.6)
	_swimmer("bream", Vector2(300, 176), -13.0, 3.0, 1.8)
	for i in 9:
		_swimmer("sardine", Vector2(60 + (i % 3) * 16 + _rng.randf_range(-3, 3), 148 + (i / 3) * 8 + _rng.randf_range(-2, 2)), 21.0, 2.0, 2.2, true)
	_boat = Sprite2D.new()
	_boat.texture = load(ART + "boat.png")
	_boat.centered = false
	_boat.position = Vector2(236, WATERLINE - 44)
	add_child(_boat)
	# The part of the hull below the waterline is seen through the water, so a tinted copy of it lies over the boat.
	_hull = Sprite2D.new()
	_hull.texture = _boat.texture
	_hull.centered = false
	_hull.region_enabled = true
	_hull.modulate = Color(0.5, 0.78, 0.84, 0.85)
	add_child(_hull)


func _swimmer(kind: String, at: Vector2, speed: float, sway: float, rate: float, shoal := false) -> void:
	var s := Sprite2D.new()
	s.texture = load(ART + kind + ".png")
	s.position = at
	s.flip_h = speed < 0.0
	var depth := clampf((at.y - WATERLINE) / (270.0 - WATERLINE), 0.0, 1.0)
	s.modulate = SHALLOW.lerp(DEEP, depth)
	add_child(s)
	_fish.append({"sprite": s, "kind": kind, "home": at, "speed": speed, "sway": sway, "rate": rate,
		"phase": _rng.randf() * TAU, "shoal": shoal})


func _process(delta: float) -> void:
	_time += delta
	_boat.position.y = WATERLINE - 44 + roundf(sin(_time * 1.6))
	var cut := WATERLINE + 1.0 - _boat.position.y
	_hull.region_rect = Rect2(0, cut, _boat.texture.get_width(), _boat.texture.get_height() - cut)
	_hull.position = _boat.position + Vector2(0, cut)
	for f in _fish:
		var s: Sprite2D = f["sprite"]
		var speed: float = f["speed"]
		if speed != 0.0:
			s.position.x += speed * delta
			var reach := 500.0 if f["shoal"] else 470.0
			if s.position.x > reach:
				s.position.x = -20.0
			elif s.position.x < -20.0:
				s.position.x = reach
		match f["kind"]:
			"moray":
				s.position.x = f["home"].x + sin(_time * 0.7 + f["phase"]) * f["sway"]
			"octopus":
				s.scale.y = 1.0 + sin(_time * 2.4) * 0.06
		s.position.y = roundf(f["home"].y + sin(_time * f["rate"] + f["phase"]) * f["sway"])
	if _rng.randf() < delta * 1.2:
		_bubbles.append(Vector2(_rng.randf_range(30, 60), 200.0))
	if _rng.randf() < delta * 0.6:
		_bubbles.append(Vector2(_hook().x + _rng.randf_range(-2, 2), _hook().y))
	for i in _bubbles.size():
		_bubbles[i] += Vector2(sin(_time * 3.0 + i) * 4.0 * delta, -18.0 * delta)
	_bubbles = _bubbles.filter(func(b): return b.y > WATERLINE + 2)
	queue_redraw()


func _rod_tip() -> Vector2:
	return _boat.position + Vector2(102, 4)


func _float() -> Vector2:
	return Vector2(_rod_tip().x + 22, WATERLINE - 1 + roundf(sin(_time * 1.9 + 1.0)))


func _hook() -> Vector2:
	return _float() + Vector2(roundf(sin(_time * 0.8) * 2.0), 70)


func _draw() -> void:
	# Light on the water: short glints that drift along the surface and sparkle in the sun's path.
	for i in 40:
		var x := fposmod(i * 37.0 + _time * (6.0 + i % 3 * 2.0), 480.0)
		draw_rect(Rect2(roundf(x), WATERLINE + (i % 2), 3 + i % 3, 1), Color(1.0, 0.93, 0.8, 0.55))
	for i in 14:
		if sin(_time * 3.0 + i * 1.7) > 0.6:
			draw_rect(Rect2(250 + (i * 13) % 50, 100 + (i * 7) % 28, 1, 1), Color(1.0, 0.95, 0.75, 0.9))
	var tip := _rod_tip()
	var bob := _float()
	var mid := (tip + bob) / 2.0 + Vector2(0, 6)
	var last := tip
	for k in range(1, 9):
		var t := k / 8.0
		var p := tip.lerp(mid, t).lerp(mid.lerp(bob, t), t)
		draw_line(last, p, Color(0.92, 0.88, 0.78, 0.8), 1.0)
		last = p
	var hook := _hook()
	draw_line(bob + Vector2(1, 2), hook, Color(0.85, 0.9, 0.9, 0.55), 1.0)
	draw_rect(Rect2(bob + Vector2(-1, -1), Vector2(4, 3)), Color("#c98a4b"))
	draw_rect(Rect2(bob + Vector2(-1, -1), Vector2(4, 1)), Color("#e8c08a"))
	draw_rect(Rect2(hook + Vector2(0, 0), Vector2(1, 3)), Color("#b8c0c0"))
	draw_rect(Rect2(hook + Vector2(-1, 2), Vector2(1, 1)), Color("#b8c0c0"))
	draw_rect(Rect2(hook + Vector2(1, 1), Vector2(2, 1)), Color("#e07a8a"))
	for b in _bubbles:
		draw_rect(Rect2(b.round(), Vector2(1, 1)), Color(0.9, 1.0, 1.0, 0.7))
