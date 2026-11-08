class_name Swimmers
extends Node2D
## The fish in the water near the camera, chosen from what lives at this place, depth, hour, season and weather.
## Each wanders inside its own depth band and never through the seabed, a big fish only over deep water, rising and
## dipping, speeding up, slowing and now and then stopping, and easing round to turn; its tail beats faster the faster
## it swims. Shoals keep together, and a fish that comes within reach of a bait it likes may turn to it and bite.

signal bit(fish: Dictionary)

## How many fish or shoals swim near the camera at once.
const WANTED := 7
const REACH := 260.0
const LOOK_EVERY := 1.0
## The chance that a legend whose time and place have come shows itself when a fish is placed in the water.
const LEGEND_CHANCE := 0.05
## How far off a fish notices a bait it likes and comes to look at it.
const NOTICE := 110.0
const CURIOUS_FOR := 7.0
## How many times its usual speed a scared fish darts away at.
const FLEE_SPEED := 3.0
## How quickly a fish changes its speed, in pixels a second each second, and how many times quicker a scared one is.
const ACCEL := 9.0
const FLEE_ACCEL := 4.0
## The chance that a fish stops for a moment when it next changes its pace.
const PAUSE_CHANCE := 0.15
## How narrow a fish looks halfway round a turn, as a share of its width.
const TURN_NARROW := 0.3
## How far ahead a fish feels for water too shallow for it, and turns back towards the deep.
const SHALLOWS_AHEAD := 30.0
## What a fish is given to swim with when it was made without it.
const AT_REST := {"vel": Vector2.ZERO, "width": 1.0, "swim": 0.0, "pace": 1.0, "pace_left": 2.0, "drift": 0.3, "flee": 0.0, "age": 0.0}

var place_id := ""
var place := {}
var seabed: Seabed
var cam := Vector2.ZERO
var hour := 12.0
var season := "spring"
var weather := "clear"
var fish: Array = []
var _rng: RandomNumberGenerator
var _spawn_left := 0.0
var _textures := {}
var _groups := 0
var events: Array[String] = []
## How far the lamp's light draws the night fish, by the lamp.
var light_reach := 100.0
## Where the lamp's light falls at night, which the night fish swim up to; null when it is not lit.
var light = null


func setup(id: String, bed: Seabed, rng: RandomNumberGenerator) -> void:
	place_id = id
	place = Data.places[id]
	seabed = bed
	_rng = rng


func texture_for(id: String) -> Texture2D:
	if not _textures.has(id):
		var path := "res://assets/art/fish/%s.png" % id
		_textures[id] = load(path) if ResourceLoader.exists(path) else load("res://assets/art/coast/mullet.png")
	return _textures[id]


## How many texels a kind's tail swings as it swims: more for a bigger fish, and none for a crab in its shell.
static func wave_for(id: String, tex: Texture2D) -> float:
	var f: Dictionary = Data.fish.get(id, {})
	if f.has("wave"):
		return float(f["wave"])
	return 1.0 if tex.get_width() < 30 else (2.0 if tex.get_width() < 70 else 3.0)


## A sprite of a kind of fish that waves its tail as `Pixels.set_swim` beats it.
static func sprite_for(id: String, tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.material = Pixels.look(wave_for(id, tex), float(Data.fish.get(id, {}).get("waves", 0.7)))
	return s


## Fills the water around the camera at once, for arriving at a place.
func populate() -> void:
	for i in WANTED * 3:
		if _near_count() < WANTED:
			_spawn()


## Every fish of a kind that can be on the line or in a net here and now, at this depth, over water this deep.
func kinds_at(depth: float, water := INF) -> Array:
	var out := []
	for method in ["line", "net", "trident"]:
		for id in Catalog.available(place_id, depth, hour, season, weather, method, water):
			if not id in out and Data.fish[id].get("swims", true):
				out.append(id)
	return out


func _spawn() -> void:
	var x := clampf(cam.x + _rng.randf_range(-REACH, Nav.view().x + REACH), 8.0, float(place["width"]) - 8.0)
	var floor_y := seabed.depth_at(x) - 8.0
	if floor_y < 12.0:
		return
	var y := _rng.randf_range(6.0, floor_y)
	var kinds := kinds_at(y, seabed.depth_at(x))
	if kinds.is_empty():
		return
	var total := 0.0
	for k in kinds:
		total += _weight(k)
	var pick: float = _rng.randf() * total
	var id: String = kinds[0]
	for k in kinds:
		pick -= _weight(k)
		if pick <= 0.0:
			id = k
			break
	var legends := Legends.here(place_id, hour, season, weather, Game.state, "line") + Legends.here(place_id, hour, season, weather, Game.state, "net")
	legends = legends.filter(func(l): return deep_enough(l, x) and (not Data.fish[l].has("spot") or Data.fish[l]["spot"] == null 		or absf(float(place["spots"].get(Data.fish[l]["spot"], 0)) - x) < 300.0))
	if not legends.is_empty() and _rng.randf() < LEGEND_CHANCE and not fish.any(func(f): return Data.fish[f["id"]]["legend"]):
		id = legends[_rng.randi() % legends.size()]
		if Data.fish[id]["methods"] == ["net"]:
			y = 6.0
	var f: Dictionary = Data.fish[id]
	var big := texture_for(id).get_width() > 24
	var count := (_rng.randi_range(3, 4) if big else _rng.randi_range(5, 9)) if f.get("shoal", false) else 1
	var heading := -1.0 if _rng.randf() < 0.5 else 1.0
	var leader := {}
	_groups += 1
	for i in count:
		var lb := Catalog.roll_pounds(id, _rng)
		var s := sprite_for(id, texture_for(id))
		s.material.set_shader_parameter("keep", Murk.FISH_KEEP)
		s.scale = Vector2.ONE * (0.85 + 0.3 * Catalog.share(id, lb)) * (0.75 if count > 1 and big else 1.0) * (1.2 if f["legend"] else 1.0)
		add_child(s)
		var speed := _rng.randf_range(6.0, 14.0) * (1.0 + float(f["strength"]) * 0.08)
		var one := {"id": id, "lb": lb, "sprite": s, "pos": Vector2(x, y), "heading": heading, "phase": _rng.randf() * TAU,
			"speed": speed, "band": f["depth"], "goal_y": y,
			"turn": _rng.randf_range(4.0, 12.0), "look": _rng.randf() * LOOK_EVERY, "state": "swim", "leader": leader, "group": _groups,
			"offset": Vector2((i % 3) * (s.texture.get_width() + 3) + _rng.randf_range(-3, 3), (i / 3) * (s.texture.get_height() + 2) + _rng.randf_range(-2, 2)) * Vector2(-heading, 1),
			"vel": Vector2(heading * speed * 0.7, 0.0), "swim": _rng.randf() * TAU, "pace_left": _rng.randf_range(1.0, 4.0),
			"drift": _rng.randf_range(0.2, 0.45)}
		_fill(one)
		if i == 0:
			leader = one
			one["leader"] = {}
		fish.append(one)


## How often a kind is chosen: its rarity, and far more often the tuna while they run.
func _weight(kind: String) -> float:
	var w := float(Data.fish[kind]["rarity"])
	if kind == "tuna" and "tuna_run" in events:
		w *= 6.0
	return w


## Moves every fish; `bait` is the hook's position when a baited hook is in the water, otherwise null.
func step(delta: float, bait, bait_id: String) -> void:
	_spawn_left -= delta
	if _spawn_left <= 0.0:
		_spawn_left = 0.7
		if _near_count() < WANTED:
			_spawn()
	var keep: Array = []
	var biting := fish.any(func(f): return f["state"] == "approach")
	for f in fish:
		if f["state"] == "gone":
			f["sprite"].queue_free()
			continue
		if absf(f["pos"].x - (cam.x + Nav.view().x / 2.0)) > Nav.view().x + REACH * 1.6:
			f["sprite"].queue_free()
			continue
		_move(f, delta, bait)
		if bait != null and not biting and f["state"] in ["swim", "curious"]:
			f["look"] -= delta
			if f["look"] <= 0.0:
				f["look"] = LOOK_EVERY
				var likes: bool = "line" in Data.fish[f["id"]]["methods"] and Bite.chance(f["id"], bait_id, 0.0) > 0.0
				var away: float = f["pos"].distance_to(bait)
				if f["state"] == "swim" and likes and away < NOTICE and deep_enough(f["id"], bait.x) and _rng.randf() < 0.35:
					f["state"] = "curious"
					f["curious"] = CURIOUS_FOR
				elif f["state"] == "curious" and _rng.randf() < Bite.chance(f["id"], bait_id, away, weather):
					f["state"] = "approach"
					biting = true
		keep.append(f)
	fish = keep


func _near_count() -> int:
	return fish.filter(func(f): return f["leader"].is_empty() and absf(f["pos"].x - (cam.x + 240.0)) < 240.0 + REACH).size()


## Gives a fish what it swims with that it was made without: its pace, its facing, its turn and its tail's beat.
func _fill(f: Dictionary) -> void:
	f.merge(AT_REST)
	if not f.has("face"):
		f["face"] = f["heading"]
	if not f.has("size"):
		f["size"] = (f["sprite"] as Sprite2D).scale.y


func _move(f: Dictionary, delta: float, bait) -> void:
	if not f.has("face"):
		_fill(f)
	f["age"] += delta
	var t: float = f["age"]
	var was: Vector2 = f["pos"]
	if f["state"] == "approach":
		if bait == null:
			f["state"] = "swim"
		else:
			var to: Vector2 = bait + Vector2(-6.0 * f["heading"], 2)
			# A hook lying on the seabed is lower than a fish may swim, so it noses in as close as it can.
			to.y = _keep_y(f, to.x, to.y)
			f["heading"] = signf(bait.x - f["pos"].x) if absf(bait.x - f["pos"].x) > 2.0 else f["heading"]
			f["pos"] = f["pos"].move_toward(to, (f["speed"] + 10.0) * delta)
			if f["pos"].distance_to(to) < 2.0:
				f["state"] = "bit"
				bit.emit(f)
	elif f["state"] == "swim":
		var leader: Dictionary = f["leader"]
		if not leader.is_empty() and leader["state"] in ["swim", "curious"]:
			f["heading"] = leader["heading"]
			# Each fish of a shoal drifts a little about its place in it, so the shoal never moves as one block.
			var spot: Vector2 = leader["pos"] + f["offset"] + Vector2(sin(t * 0.6 + f["phase"]) * 2.0, cos(t * 0.45 + f["phase"]) * 1.5)
			f["pos"] = f["pos"].lerp(spot, minf(1.0, delta * 1.5))
		else:
			_wander(f, delta, t)
	elif f["state"] == "curious":
		f["curious"] -= delta
		if bait == null or f["curious"] <= 0.0:
			release(f, false)
		else:
			var near: Vector2 = bait + Vector2(-18.0 * signf(bait.x - f["pos"].x + 0.01), sin(t * 0.9 + f["phase"]) * 6.0)
			f["heading"] = signf(bait.x - f["pos"].x) if absf(bait.x - f["pos"].x) > 4.0 else f["heading"]
			f["pos"] = f["pos"].move_toward(near, f["speed"] * delta)
	f["pos"].y = _keep_y(f, f["pos"].x, f["pos"].y)
	_show(f, (f["pos"] - was) / delta if delta > 0.0 else Vector2.ZERO, delta)


## A fish on its own, or leading its shoal: it changes its pace every few seconds and now and then stops, eases its
## speed round when it turns, and rises and dips gently on its way to the depth it is making for.
func _wander(f: Dictionary, delta: float, t: float) -> void:
	f["turn"] -= delta
	if f["turn"] <= 0.0:
		f["turn"] = _rng.randf_range(4.0, 12.0)
		if _rng.randf() < 0.4:
			f["heading"] = -f["heading"]
		f["goal_y"] = _rng.randf_range(float(f["band"][0]), float(f["band"][1]))
	f["pace_left"] -= delta
	if f["pace_left"] <= 0.0:
		var stop := _rng.randf() < PAUSE_CHANCE
		f["pace"] = 0.0 if stop else _rng.randf_range(0.45, 1.35)
		f["pace_left"] = _rng.randf_range(1.0, 3.0) if stop else _rng.randf_range(1.5, 4.0)
	f["flee"] = maxf(0.0, float(f["flee"]) - delta)
	var fleeing: bool = f["flee"] > 0.0
	if f["pos"].x < 10.0 or f["pos"].x > float(place["width"]) - 10.0:
		f["heading"] = signf(float(place["width"]) / 2.0 - f["pos"].x)
		f["pace"] = maxf(f["pace"], 0.6)
	elif not deep_enough(f["id"], f["pos"].x + f["heading"] * SHALLOWS_AHEAD):
		var deeper := signf(seabed.depth_at(f["pos"].x + 20.0) - seabed.depth_at(f["pos"].x - 20.0))
		f["heading"] = deeper if deeper != 0.0 else -f["heading"]
		f["pace"] = maxf(f["pace"], 0.6)
	if "dolphins" in events and Data.fish[f["id"]].get("shoal", false):
		f["goal_y"] = minf(f["goal_y"], 30.0)
	var speed: float = f["speed"]
	var accel := ACCEL * (FLEE_ACCEL if fleeing else 1.0)
	var vel: Vector2 = f["vel"]
	vel.x = move_toward(vel.x, f["heading"] * speed * (FLEE_SPEED if fleeing else f["pace"]), accel * delta)
	var curve: float = f["goal_y"] + sin(t * f["drift"] + f["phase"]) * 5.0
	var climb := clampf((curve - f["pos"].y) * 0.6, -speed * 0.4, speed * 0.4)
	vel.y = move_toward(vel.y, climb * (0.3 if f["pace"] == 0.0 and not fleeing else 1.0), accel * 0.5 * delta)
	f["vel"] = vel
	f["pos"] += vel * delta
	if light != null and "trident" in Data.fish[f["id"]]["methods"] and f["pos"].distance_to(light) < light_reach:
		var near: Vector2 = light + Vector2(sin(t * 0.5 + f["phase"]) * 30.0, cos(t * 0.4 + f["phase"]) * 14.0)
		f["pos"] = f["pos"].move_toward(near, f["speed"] * 0.6 * delta)
		f["heading"] = signf(near.x - f["pos"].x) if absf(near.x - f["pos"].x) > 3.0 else f["heading"]


## Draws a fish where it is. Turning, it narrows as it slows, and faces the new way once it swims that way or has
## stopped and narrowed fully; its tail beats faster the faster it goes.
func _show(f: Dictionary, moved: Vector2, delta: float) -> void:
	var turning: bool = f["face"] != f["heading"]
	var still := absf(moved.x) < 0.4
	if turning and ((signf(moved.x) == f["heading"] and not still) or (still and f["width"] <= TURN_NARROW + 0.01)):
		f["face"] = f["heading"]
		turning = false
	var narrow := lerpf(TURN_NARROW, 1.0, clampf(absf(moved.x) / (f["speed"] * 0.6), 0.0, 1.0))
	f["width"] = move_toward(f["width"], narrow if turning else 1.0, delta * 3.0)
	f["swim"] = fmod(f["swim"] + delta * (3.0 + moved.length() * 0.5), TAU * 64.0)
	var s: Sprite2D = f["sprite"]
	s.flip_h = f["face"] < 0.0
	s.scale = Vector2(f["size"] * f["width"], f["size"])
	s.position = f["pos"] - cam
	Pixels.set_swim(s, f["swim"])


## The nearest depth to y that a fish keeps to at x: no higher than half its band's top, and clear of the seabed.
func _keep_y(f: Dictionary, x: float, y: float) -> float:
	var lo := maxf(5.0, float(f["band"][0]) * 0.5)
	var hi := seabed.depth_at(x) - 5.0
	return clampf(y, minf(lo, hi), hi)


## Whether the water at x is deep enough for a kind of fish to swim in.
func deep_enough(id: String, x: float) -> bool:
	return seabed.depth_at(x) >= Catalog.water_needed(id)


## Takes a fish off the swimmers, when it is hooked or has given up on the bait; a scared fish darts away.
func release(f: Dictionary, hooked: bool, scared := false) -> void:
	if hooked:
		f["state"] = "gone"
	else:
		f["state"] = "swim"
		f["heading"] = -f["heading"]
		f["look"] = 8.0 if scared else 4.0
		f["flee"] = 1.5 if scared else 0.0
