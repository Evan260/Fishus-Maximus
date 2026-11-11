class_name PondView
extends Node2D
## The pond's fish swimming under the waterline, each one texel to a pixel as the coast's fish are: they wander in
## curves, change pace, pause and ease round to turn. Feeding brings them up to the food; ringing the bell brings the
## named ones to the front with their names over them.

## Seconds the bell keeps the named fish at the front, and the food on the water.
const BELL_SECONDS := 6.0
const FOOD_SECONDS := 7.0
const ACCEL := 9.0
const TURN_NARROW := 0.3

## The water the fish swim in, in the pond's own pixels: its left and right walls and its floor below the waterline.
var left := 8.0
var right := 792.0
var floor_y := 70.0
## Where the camera is in the pond's pixels, so the fish are drawn where they swim.
var cam := Vector2.ZERO
var bell_left := 0.0
var food_left := 0.0
var _fish: Array = []
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _textures := {}


func _ready() -> void:
	_rng.randomize()


## Matches the swimming fish to the fish in the pond, keeping each one where it was.
func sync() -> void:
	var wanted: Array = Ponds.of(Game.state).get("fish", [])
	while _fish.size() > wanted.size():
		_fish.pop_back()["sprite"].queue_free()
	while _fish.size() < wanted.size():
		_fish.append({"pos": Vector2(_rng.randf_range(left + 30.0, right - 30.0), _rng.randf_range(12.0, floor_y - 14.0)),
			"heading": 1.0 if _rng.randf() < 0.5 else -1.0, "phase": _rng.randf() * TAU, "vel": Vector2.ZERO, "pace": 1.0,
			"pace_left": _rng.randf_range(1.0, 3.0), "turn": _rng.randf_range(3.0, 9.0), "width": 1.0, "swim": _rng.randf() * TAU,
			"drift": _rng.randf_range(0.2, 0.45), "goal_y": _rng.randf_range(12.0, floor_y - 14.0), "id": ""})
	for i in wanted.size():
		var one: Dictionary = _fish[i]
		var f: Dictionary = wanted[i]
		one["data"] = f
		if one["id"] != f["fish"]:
			if one.has("sprite"):
				one["sprite"].queue_free()
			var s := Swimmers.sprite_for(f["fish"], _texture(f["fish"]))
			s.material.set_shader_parameter("keep", Murk.FISH_KEEP)
			add_child(s)
			one["sprite"] = s
			one["id"] = f["fish"]
			one["face"] = one["heading"]
			one["speed"] = _rng.randf_range(5.0, 10.0) * (1.0 + float(Data.fish[f["fish"]]["strength"]) * 0.06)
		_show(one, Vector2.ZERO, 0.0)


func _texture(id: String) -> Texture2D:
	if not _textures.has(id):
		var path := "res://assets/art/fish/%s.png" % id
		_textures[id] = load(path) if ResourceLoader.exists(path) else load("res://assets/art/coast/mullet.png")
	return _textures[id]


func ring() -> void:
	bell_left = BELL_SECONDS


func feed() -> void:
	food_left = FOOD_SECONDS


func fish() -> Array:
	return _fish


## The named fish being shown off by the bell, with where each is in the pond.
func shown_names() -> Array:
	if bell_left <= 0.0:
		return []
	return _fish.filter(func(one): return str(one["data"].get("name", "")) != "")


func _process(delta: float) -> void:
	_time += delta
	bell_left = maxf(0.0, bell_left - delta)
	food_left = maxf(0.0, food_left - delta)
	var named := shown_names()
	var middle := (left + right) / 2.0
	for i in _fish.size():
		var one: Dictionary = _fish[i]
		var was: Vector2 = one["pos"]
		var size: Vector2 = (one["sprite"] as Sprite2D).texture.get_size()
		if one in named:
			# The named fish line up across the front of the pond, near the top, facing the bell.
			var k := named.find(one)
			var spot := Vector2(middle + (k - (named.size() - 1) / 2.0) * 56.0, 14.0 + size.y / 2.0)
			one["heading"] = signf(spot.x - one["pos"].x) if absf(spot.x - one["pos"].x) > 3.0 else one["heading"]
			one["pos"] = one["pos"].move_toward(spot, one["speed"] * 2.2 * delta)
		elif food_left > 0.0:
			var spot := Vector2(clampf(one["pos"].x, middle - 90.0, middle + 90.0), 6.0 + size.y / 2.0) + Vector2(sin(_time + one["phase"]) * 10.0, 0.0)
			one["heading"] = signf(spot.x - one["pos"].x) if absf(spot.x - one["pos"].x) > 3.0 else one["heading"]
			one["pos"] = one["pos"].move_toward(spot, one["speed"] * 1.6 * delta)
		else:
			_wander(one, delta, size)
		one["pos"] = Vector2(clampf(one["pos"].x, left + size.x / 2.0, right - size.x / 2.0),
			clampf(one["pos"].y, 3.0 + size.y / 2.0, floor_y - 2.0 - size.y / 2.0))
		_show(one, (one["pos"] - was) / delta if delta > 0.0 else Vector2.ZERO, delta)
	queue_redraw()


## A fish on its own: it changes its pace every few seconds and now and then stops, eases its speed round when it
## turns, turns back from the walls, and rises and dips gently on its way to the depth it is making for.
func _wander(one: Dictionary, delta: float, size: Vector2) -> void:
	one["turn"] -= delta
	if one["turn"] <= 0.0:
		one["turn"] = _rng.randf_range(4.0, 11.0)
		if _rng.randf() < 0.4:
			one["heading"] = -one["heading"]
		one["goal_y"] = _rng.randf_range(4.0 + size.y / 2.0, floor_y - 4.0 - size.y / 2.0)
	one["pace_left"] -= delta
	if one["pace_left"] <= 0.0:
		var stop := _rng.randf() < 0.15
		one["pace"] = 0.0 if stop else _rng.randf_range(0.45, 1.3)
		one["pace_left"] = _rng.randf_range(1.0, 3.0) if stop else _rng.randf_range(1.5, 4.0)
	if one["pos"].x < left + size.x / 2.0 + 6.0 or one["pos"].x > right - size.x / 2.0 - 6.0:
		one["heading"] = signf((left + right) / 2.0 - one["pos"].x)
		one["pace"] = maxf(one["pace"], 0.6)
	var speed: float = one["speed"]
	var vel: Vector2 = one["vel"]
	vel.x = move_toward(vel.x, one["heading"] * speed * one["pace"], ACCEL * delta)
	var curve: float = one["goal_y"] + sin(_time * one["drift"] + one["phase"]) * 4.0
	var climb := clampf((curve - one["pos"].y) * 0.6, -speed * 0.4, speed * 0.4)
	vel.y = move_toward(vel.y, climb * (0.3 if one["pace"] == 0.0 else 1.0), ACCEL * 0.5 * delta)
	one["vel"] = vel
	one["pos"] += vel * delta


## Draws a fish where it is: turning, it narrows as it slows and faces the new way once it swims that way or has
## stopped and narrowed fully; its tail beats faster the faster it goes.
func _show(one: Dictionary, moved: Vector2, delta: float) -> void:
	var turning: bool = one["face"] != one["heading"]
	var still := absf(moved.x) < 0.4
	if turning and ((signf(moved.x) == one["heading"] and not still) or (still and one["width"] <= TURN_NARROW + 0.01)):
		one["face"] = one["heading"]
		turning = false
	var narrow := lerpf(TURN_NARROW, 1.0, clampf(absf(moved.x) / (one["speed"] * 0.6), 0.0, 1.0))
	one["width"] = move_toward(one["width"], narrow if turning else 1.0, delta * 3.0)
	one["swim"] = fmod(one["swim"] + delta * (3.0 + moved.length() * 0.5), TAU * 64.0)
	var s: Sprite2D = one["sprite"]
	s.flip_h = one["face"] < 0.0
	s.scale = Vector2(one["width"], 1.0)
	s.position = one["pos"] - cam
	Pixels.set_swim(s, one["swim"])


func _draw() -> void:
	# A fish wearing finery shows a glint of gold at its throat.
	for one in _fish:
		if str(one["data"].get("finery", "")) == "":
			continue
		var s: Sprite2D = one["sprite"]
		var m := Swimmers.mouth_of(s.texture)
		var at: Vector2 = s.position + Vector2(m.x * (-1.0 if s.flip_h else 1.0) * s.scale.x * 0.7, m.y + 3.0)
		draw_rect(Rect2(at.floor(), Vector2(1, 2)), UiTheme.GOLD)
	if food_left > 0.0:
		var middle := (left + right) / 2.0 - cam.x
		for i in 14:
			var x := middle + (hash_of(i) - 0.5) * 170.0 + sin(_time * 0.8 + i) * 3.0
			var sink := fposmod(_time * (2.0 + hash_of(i + 50) * 3.0) + i * 3.0, 18.0) * clampf(1.0 - (FOOD_SECONDS - food_left) / FOOD_SECONDS, 0.3, 1.0)
			draw_rect(Rect2(Vector2(x, -cam.y + 1.0 + sink).floor(), Vector2.ONE), Color("#c9a46a"))


static func hash_of(i: int) -> float:
	return fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
