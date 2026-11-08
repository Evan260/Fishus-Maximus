class_name TrapView
extends Node2D
## The place's pots on the seabed, each with a rope up to its float on the surface. A pot just set is lifted over the
## boat's side, dropped in and sinks to the bed, swaying, with bubbles rising from it and a puff of silt where it lands;
## a pot hauled comes up hand over hand, streaming water, and is taken into the boat, or dropped again once emptied.
## The game sets, empties or lifts a pot at once and only the picture takes its time, so a game saved meanwhile holds
## the pot as set, or as lifted with its catch kept.

## How fast a pot falls through the air, how fast it sinks once the water has slowed it, and how many seconds the
## water takes to slow it; in deep water it sinks faster, so it is down within SINK_MOST seconds.
const FALL := 300.0
const SINK := 45.0
const SINK_EASE := 0.35
const SINK_MOST := 8.0
## One pull of the rope hand over hand: its seconds, the rope it brings in, the share of it spent pulling while the
## rest changes hands, and how far the pot sags back meanwhile; a deep pot comes up within HAUL_MOST seconds.
const PULL_EVERY := 0.6
const PULL := 17.0
const PULLING := 0.6
const SAG := 1.2
const HAUL_MOST := 9.0
## How far the pot swings and tilts as it sinks, and how quickly.
const SWAY := 1.5
const TILT := 0.11
const SWAY_SPEED := 2.1
## Seconds to lift a pot over the rail, to hold it there before letting go or while it drips, and to lower it into
## the boat; seconds it rocks after landing on the bed.
const RAISE := 0.5
const LET_GO := 0.2
const DRIP := 0.8
const STOW := 0.45
const SETTLE := 1.3
## Seconds the float flies when he throws it after the pot, and how high it goes.
const TOSS := 0.45
const TOSS_UP := 9.0
## Where the rope is tied, above the pot's bottom, and how far the pot's bottom sits into the sand.
const TIE := 12.0
const INTO_SAND := 3.0
const ROPE := Color(0.75, 0.68, 0.5, 0.7)
const SILT := Color(0.92, 0.88, 0.76, 1.0)
const BUBBLE_RISE := 18.0

var screen: Node
var _pot: Texture2D = load("res://assets/art/props/trap.png") if ResourceLoader.exists("res://assets/art/props/trap.png") else null
var _buoy: Texture2D = load("res://assets/art/props/buoy.png") if ResourceLoader.exists("res://assets/art/props/buoy.png") else null
## The pots on their way down or up, each {trap, phase, at (the middle of its bottom), v, t, age, angle, line, dir,
## float, say, keep, seed}; a lifted pot is drawn from here alone, since the game no longer holds it.
var _moving: Array[Dictionary] = []
## Splashes, drips, bubbles and silt, each {kind, at, vel, life, full}; a ring's vel.x is how wide it spreads.
var _bits: Array[Dictionary] = []
var _sprites: Array[Sprite2D] = []
var _shown: Array = []
## The splashes, drips, bubbles and silt, drawn over the pots.
var _front: Node2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_front = Node2D.new()
	_front.z_index = 1
	_front.draw.connect(_draw_bits)
	add_child(_front)


func _height() -> float:
	return float(_pot.get_height()) if _pot else 10.0


func _width() -> float:
	return float(_pot.get_width()) if _pot else 12.0


## The top of the boat's side, where pots go over it, at the middle of the boat.
func _rail() -> Vector2:
	var mid: float = screen.boat_x + 52.0
	return Vector2(mid, screen.gunwale(mid))


func _bed(x: float) -> float:
	return roundf(screen.seabed.depth_at(x))


## How a pot resting on the bed at x leans, along the slope of the sand under it.
func _lie(x: float) -> float:
	var w := _width() / 2.0
	return clampf(atan2(screen.seabed.depth_at(x + w) - screen.seabed.depth_at(x - w), w * 2.0), -0.3, 0.3)


func _entry(trap: Dictionary) -> Dictionary:
	for e in _moving:
		if is_same(e["trap"], trap):
			return e
	return {}


func _in_state(trap: Dictionary) -> bool:
	return Game.state["traps"].any(func(t): return is_same(t, trap))


func moving(trap: Dictionary) -> bool:
	return not _entry(trap).is_empty()


## Lifts a pot just set over the side and lets it sink to the bed.
func drop(trap: Dictionary) -> void:
	var rail := _rail()
	_moving.append({"trap": trap, "phase": "raise", "at": Vector2(float(trap["x"]), rail.y + _height()), "v": 0.0,
		"t": 0.0, "age": 0.0, "angle": 0.0, "float": -1.0, "say": [], "keep": true, "seed": _rng.randf() * TAU})


## Hauls a pot up to the boat, saying `say` once it is over the side; with `keep` it is dropped again afterwards.
func haul(trap: Dictionary, say: Array, keep: bool) -> void:
	var e := _entry(trap)
	if e.is_empty():
		var x := float(trap["x"])
		e = {"trap": trap, "phase": "haul", "at": Vector2(x, _bed(x)), "v": 0.0, "t": 0.0, "age": 0.0, "angle": 0.0,
			"float": -1.0, "say": [], "seed": _rng.randf() * TAU}
		_moving.append(e)
		_puff(e["at"], 5)
	# A pot still in his hands is already up, so what it held is told at once.
	if e["phase"] in ["raise", "hold", "over", "stow"]:
		for line in say:
			Toast.say(line)
		e["keep"] = keep
		if not keep and e["phase"] != "stow":
			_next(e, "stow")
		return
	var top: Vector2 = e["at"] - Vector2(0, _height() - INTO_SAND)
	e["phase"] = "haul"
	e["t"] = 0.0
	e["float"] = -1.0
	e["dir"] = (top - _rail()).normalized()
	e["line"] = top.distance_to(_rail())
	e["pull"] = maxf(PULL, e["line"] * PULL_EVERY / HAUL_MOST)
	e["say"].append_array(say)
	e["keep"] = keep


## Says at once what the pots still on their way up would have told, as the boat leaves.
func tell_now() -> void:
	for e in _moving:
		for line in e["say"]:
			Toast.say(line)
		e["say"] = []


## Where a pot is drawn: the middle of its bottom in the world and its tilt, or nothing once it is gone.
func pot_at(trap: Dictionary) -> Dictionary:
	var e := _entry(trap)
	if not e.is_empty():
		return {"at": e["at"], "angle": e["angle"]}
	if _in_state(trap) and trap["place"] == screen.place_id:
		return {"at": Vector2(float(trap["x"]), _bed(float(trap["x"]))), "angle": _lie(float(trap["x"]))}
	return {}


## A moving pot for the camera to keep in view, or INF when none is moving.
func watched() -> Vector2:
	for e in _moving:
		if e["phase"] in ["fall", "sink", "settle", "haul"] and e["at"].y > 0.0:
			return e["at"]
	return Vector2.INF


func sprite_of(trap: Dictionary) -> Sprite2D:
	for i in _shown.size():
		if is_same(_shown[i], trap):
			return _sprites[i]
	return null


## Where every splash, drip, bubble and grain of silt is drawn, in the world.
func bits() -> Array:
	return _bits.map(func(b): return (b["at"] as Vector2).round())


func step(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for e in _moving:
		e["age"] += delta
		e["t"] += delta
		var trap: Dictionary = e["trap"]
		# A pot taken out of the game some other way than hauling, as by a new game, stops being drawn.
		if e["phase"] != "haul" and e["phase"] != "over" and e["phase"] != "stow" and not _in_state(trap):
			continue
		if _advance(e, delta):
			keep.append(e)
	_moving = keep
	_step_bits(delta)
	_place_sprites()
	queue_redraw()
	if _front:
		_front.queue_redraw()


## Moves one pot along; false once it has finished.
func _advance(e: Dictionary, delta: float) -> bool:
	var trap: Dictionary = e["trap"]
	var rail := _rail()
	match e["phase"]:
		"raise":
			var u := clampf(e["t"] / RAISE, 0.0, 1.0)
			e["at"] = Vector2(float(trap["x"]), rail.y + lerpf(_height(), -1.0, 1.0 - (1.0 - u) * (1.0 - u)))
			if u >= 1.0:
				_next(e, "hold")
		"hold":
			e["at"] = Vector2(float(trap["x"]), rail.y - 1.0)
			if e["t"] >= LET_GO:
				_next(e, "fall")
				e["v"] = 0.0
		"fall", "sink":
			_sink(e, delta)
		"settle":
			var x := float(trap["x"])
			var d := exp(-e["t"] * 5.0)
			e["at"] = Vector2(x + (e["off"] - x) * d, _bed(x))
			e["angle"] = _lie(x) + (e["tilt"] - _lie(x)) * exp(-e["t"] * 4.0) * cos(e["t"] * 13.0)
			if e["t"] >= SETTLE and e["float"] >= TOSS:
				return false
			if e["t"] >= SETTLE:
				e["angle"] = _lie(x)
				e["at"] = Vector2(x, _bed(x))
		"haul":
			_haul(e, delta, rail)
		"over":
			e["at"] = rail + Vector2(0, -1)
			e["angle"] = lerpf(e["angle"], 0.0, 1.0 - exp(-delta * 8.0))
			_drip(e, delta, 1.0 - e["t"] / DRIP)
			if e["t"] >= DRIP:
				if e["keep"] and _in_state(trap):
					trap["x"] = roundf(rail.x)
					trap["depth"] = screen.seabed.depth_at(trap["x"])
					_next(e, "fall")
					e["v"] = 0.0
					e["float"] = -1.0
					e["angle"] = 0.0
				else:
					_next(e, "stow")
		"stow":
			e["at"] = Vector2(rail.x, rail.y - 1.0 + (_height() + 1.0) * clampf(e["t"] / STOW, 0.0, 1.0) ** 2)
			if e["t"] >= STOW:
				return false
	if e["float"] >= 0.0:
		var was: float = e["float"]
		e["float"] += delta
		if was < TOSS and e["float"] >= TOSS:
			_ring(Vector2(float(trap["x"]), 0.0), 0.5)
			Audio.play("cork", -14.0)
	return true


func _next(e: Dictionary, phase: String) -> void:
	e["phase"] = phase
	e["t"] = 0.0


## Falls through the air, splashes in and sinks to the bed at the water's own pace, swaying as it goes.
func _sink(e: Dictionary, delta: float) -> void:
	var trap: Dictionary = e["trap"]
	var x := float(trap["x"])
	var bed := _bed(x)
	var y: float = e["at"].y
	if y < 0.0:
		e["v"] += FALL * delta
	else:
		var steady := maxf(SINK, bed / SINK_MOST)
		e["v"] += (steady - e["v"]) * (1.0 - exp(-delta / SINK_EASE))
	var next := minf(bed, y + e["v"] * delta)
	if y < 0.0 and next >= 0.0:
		e["phase"] = "sink"
		e["sunk"] = 0.0
		_splash(x, 7, 1.0)
		Audio.play("splash_small", -6.0)
	var under := clampf(next / 16.0, 0.0, 1.0) * clampf((bed - next) / 40.0, 0.35, 1.0)
	var swing: float = e["age"] * SWAY_SPEED + e["seed"]
	e["at"] = Vector2(x + SWAY * sin(swing) * under, next)
	e["angle"] = TILT * sin(swing - 0.9) * under
	if next > 0.0:
		e["sunk"] = float(e.get("sunk", 0.0)) + delta
		var every := 0.06 if e["sunk"] < 1.0 else 0.3
		if fmod(e["sunk"], every) < delta:
			_bubble(e["at"] + Vector2(_rng.randf_range(-8.0, 8.0), -_rng.randf_range(4.0, _height() - 4.0)))
	if e["float"] < 0.0 and (next - _height() > 14.0 or next >= bed):
		e["float"] = 0.0
	if next >= bed:
		e["off"] = e["at"].x
		e["tilt"] = e["angle"]
		_next(e, "settle")
		_puff(e["at"], 24)


## Pulls the rope in hand over hand from the boat's side: each pull lifts the pot, and it sags back a little while
## his hands change over. The rope swings round under the boat as it shortens.
func _haul(e: Dictionary, delta: float, rail: Vector2) -> void:
	var cycle := fmod(e["t"], PULL_EVERY) / PULL_EVERY
	if cycle < PULLING:
		e["line"] -= e["pull"] / (PULL_EVERY * PULLING) * PI / 2.0 * sin(PI * cycle / PULLING) * delta
	var sag := 0.0 if cycle < PULLING else SAG * sin(PI * (cycle - PULLING) / (1.0 - PULLING))
	e["dir"] = (e["dir"] as Vector2).lerp(Vector2.DOWN, 1.0 - exp(-delta / 1.2)).normalized()
	# The last of the rope lifts the pot straight up out of the water until it clears the rail.
	var clear := _height() - INTO_SAND + 1.0
	var line := maxf(-clear, e["line"])
	var top: Vector2 = rail + (e["dir"] if line > 0.0 else Vector2.DOWN) * (line + sag)
	var was: float = e["at"].y
	e["at"] = top + Vector2(0, _height() - INTO_SAND)
	e["at"].y = minf(e["at"].y, _bed(e["at"].x))
	var lean := -atan2(e["dir"].x, e["dir"].y) * 0.8
	e["angle"] = clampf(lean + 0.05 * sin(e["age"] * 5.0 + e["seed"]) * clampf(e["at"].y / 30.0, 0.0, 1.0), -0.4, 0.4)
	if was >= 0.0 and e["at"].y < 0.0:
		_splash(e["at"].x, 6, 0.8)
		Audio.play("splash_small", -8.0)
	if e["at"].y < 0.0:
		_drip(e, delta, 1.0)
	elif _rng.randf() < delta * 3.0:
		_bubble(e["at"] + Vector2(_rng.randf_range(-8.0, 8.0), -_rng.randf_range(4.0, _height() - 4.0)))
	if line <= -clear:
		_next(e, "over")
		for line_said in e["say"]:
			Toast.say(line_said)
		e["say"] = []


## Water streaming off the bottom of a pot out of the water, thinning as `share` falls.
func _drip(e: Dictionary, delta: float, share: float) -> void:
	if _rng.randf() < delta * 40.0 * clampf(share, 0.15, 1.0):
		var half := _width() / 2.0 - 3.0
		_bits.append({"kind": "drop", "at": e["at"] + Vector2(_rng.randf_range(-half, half), 1.0 - INTO_SAND),
			"vel": Vector2(_rng.randf_range(-4.0, 4.0), _rng.randf_range(0.0, 20.0)), "life": 2.0, "full": 2.0})


func _splash(x: float, drops: int, size: float) -> void:
	for k in drops:
		var side := (k - (drops - 1) / 2.0) / maxf(1.0, (drops - 1) / 2.0)
		var vel := Vector2(side * 22.0 + _rng.randf_range(-5.0, 5.0), -(70.0 + _rng.randf_range(0.0, 30.0)) * size)
		_bits.append({"kind": "drop", "at": Vector2(x + side * 8.0, -1.0), "vel": vel, "life": 1.5, "full": 1.5})
	_ring(Vector2(x, 0.0), size)


func _ring(at: Vector2, size: float, seconds := BoatView.RING_SECONDS) -> void:
	_bits.append({"kind": "ring", "at": at, "vel": Vector2(size, 0), "life": seconds, "full": seconds})


func _bubble(at: Vector2) -> void:
	_bits.append({"kind": "bubble", "at": at, "vel": Vector2(_rng.randf() * TAU, -BUBBLE_RISE * _rng.randf_range(0.8, 1.2)),
		"life": 3.0, "full": 3.0})


## A little cloud of silt kicked up round the bottom of a pot.
func _puff(at: Vector2, grains: int) -> void:
	for k in grains:
		var side := -1.0 if k % 2 == 0 else 1.0
		_bits.append({"kind": "silt", "at": at + Vector2(side * _rng.randf_range(4.0, 13.0), -_rng.randf_range(0.0, 3.0)),
			"vel": Vector2(side * _rng.randf_range(5.0, 26.0), -_rng.randf_range(3.0, 16.0)), "life": _rng.randf_range(1.6, 2.8),
			"full": 2.8, "wide": k % 3 == 0})


func _step_bits(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for b in _bits:
		b["life"] -= delta
		match b["kind"]:
			"drop":
				b["vel"].y += BoatView.DROP_FALL * delta
				b["at"] += b["vel"] * delta
				if b["at"].y >= 1.0:
					if _rng.randf() < 0.3:
						_ring(Vector2(b["at"].x, 0.0), 0.3, 0.4)
					continue
			"bubble":
				b["at"] += Vector2(sin(b["life"] * 7.0 + b["vel"].x) * 4.0, b["vel"].y) * delta
				if b["at"].y <= 1.0:
					continue
			"silt":
				b["vel"] *= exp(-delta * 2.5)
				b["vel"].y += 3.0 * delta
				b["at"] += b["vel"] * delta
		if b["life"] > 0.0:
			keep.append(b)
	_bits = keep


## Every pot to draw: [trap, the middle of its bottom, its tilt, the row its picture is cut off at or INF].
func _pots() -> Array:
	var out := []
	for trap in Game.state["traps"]:
		if trap["place"] == screen.place_id and not moving(trap):
			var x := float(trap["x"])
			out.append([trap, Vector2(x, _bed(x)), _lie(x), INF])
	for e in _moving:
		# In the boat, a pot is hidden below the near side's top edge.
		var inside: bool = e["phase"] in ["raise", "hold", "stow"]
		out.append([e["trap"], e["at"], e["angle"], _rail().y if inside else INF])
	return out


func _place_sprites() -> void:
	if not _pot:
		return
	var cam: Vector2 = screen.camera.cam
	var pots := _pots()
	while _sprites.size() < pots.size():
		var s := Sprite2D.new()
		s.texture = _pot
		add_child(s)
		_sprites.append(s)
	_shown = []
	for i in _sprites.size():
		var s := _sprites[i]
		s.visible = i < pots.size()
		if not s.visible:
			continue
		var p: Array = pots[i]
		_shown.append(p[0])
		var top: Vector2 = p[1] - Vector2(_width() / 2.0, _height() - INTO_SAND)
		if is_finite(p[3]):
			var rows := clampf(roundf(p[3] - top.y), 0.0, _height())
			s.visible = rows > 0.0
			s.material = null
			s.centered = false
			s.region_enabled = true
			s.region_rect = Rect2(0, 0, _width(), rows)
			s.rotation = 0.0
			s.position = top - cam
		else:
			if s.material == null:
				s.material = Pixels.look()
			# Under the water a pot loses some of its colour, as the fish do, before the murk is laid over it.
			var under := clampf((p[1].y + INTO_SAND) / _height(), 0.0, 1.0)
			(s.material as ShaderMaterial).set_shader_parameter("keep", lerpf(1.0, Murk.FISH_KEEP, under))
			s.centered = true
			s.region_enabled = false
			s.rotation = p[2]
			s.position = top + Vector2(_width(), _height()) / 2.0 - cam


func _draw() -> void:
	var cam: Vector2 = screen.camera.cam
	var t: float = screen.time()
	for trap in Game.state["traps"]:
		if trap["place"] != screen.place_id or moving(trap):
			continue
		var x := float(trap["x"])
		var top := Vector2(x, sin(t * 1.7 + x))
		Pixels.line(self, top + Vector2(0, 2) - cam, Vector2(x, _bed(x) - TIE) - cam, ROPE)
		_float(top - cam, not trap["catch"].is_empty())
	for e in _moving:
		_draw_moving(e, cam, t)


func _draw_bits() -> void:
	var cam: Vector2 = screen.camera.cam
	for b in _bits:
		var at: Vector2 = (b["at"] as Vector2).round() - cam
		var fade := clampf(b["life"] / b["full"], 0.0, 1.0)
		match b["kind"]:
			"ring":
				var spread := 1.0 - fade
				var half := roundf((2.0 + spread * 9.0) * b["vel"].x)
				var c := Color(BoatView.SPRAY, BoatView.SPRAY.a * (1.0 - spread * spread))
				_front.draw_rect(Rect2(at + Vector2(-half - 3.0, 0), Vector2(3, 1)), c)
				_front.draw_rect(Rect2(at + Vector2(half, 0), Vector2(3, 1)), c)
			"bubble":
				_front.draw_rect(Rect2(at, Vector2.ONE), Color(BoatView.BUBBLE, BoatView.BUBBLE.a * minf(1.0, fade * 3.0)))
			"silt":
				_front.draw_rect(Rect2(at, Vector2(2 if b.get("wide", false) else 1, 1)), Color(SILT, SILT.a * fade))
			_:
				_front.draw_rect(Rect2(at, Vector2.ONE), BoatView.SPRAY)


func _draw_moving(e: Dictionary, cam: Vector2, t: float) -> void:
	var trap: Dictionary = e["trap"]
	var x := float(trap["x"])
	var tie: Vector2 = e["at"] + Vector2(0, -TIE).rotated(e["angle"])
	var from := _rail()
	var thrown: float = e["float"]
	if thrown >= 0.0:
		var u := clampf(thrown / TOSS, 0.0, 1.0)
		var flying := from.lerp(Vector2(x, 0.0), u) + Vector2(0, -TOSS_UP * 4.0 * u * (1.0 - u))
		from = flying if u < 1.0 else Vector2(x, sin(t * 1.7 + x))
		_float(from - cam, false)
		from += Vector2(0, 2)
	if e["phase"] in ["raise", "hold", "stow"]:
		return
	Pixels.line(self, from - cam, tie - cam, ROPE)


func _float(at: Vector2, full: bool) -> void:
	if _buoy:
		draw_texture(_buoy, at - Vector2(floorf(_buoy.get_width() / 2.0), roundf(_buoy.get_height() * 0.6)))
	else:
		draw_rect(Rect2(at + Vector2(-2, -3), Vector2(5, 4)), Color("#c8443a"))
	if full:
		draw_rect(Rect2(at + Vector2(-1, -10), Vector2(3, 3)), UiTheme.GOLD)

