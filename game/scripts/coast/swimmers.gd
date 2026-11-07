class_name Swimmers
extends Node2D
## The fish in the water near the camera, chosen from what lives at this place, depth, hour, season and weather.
## Each wanders inside its own depth band and never through the seabed; shoals keep together, and a fish that comes
## within reach of a bait it likes may turn to it and bite.

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


## Fills the water around the camera at once, for arriving at a place.
func populate() -> void:
	for i in WANTED * 3:
		if _near_count() < WANTED:
			_spawn()


## Every fish of a kind that can be on the line or in a net here and now, at this depth.
func kinds_at(depth: float) -> Array:
	var out := []
	for method in ["line", "net", "trident"]:
		for id in Catalog.available(place_id, depth, hour, season, weather, method):
			if not id in out and Data.fish[id].get("swims", true):
				out.append(id)
	return out


func _spawn() -> void:
	var x := clampf(cam.x + _rng.randf_range(-REACH, Nav.view().x + REACH), 8.0, float(place["width"]) - 8.0)
	var floor_y := seabed.depth_at(x) - 8.0
	if floor_y < 12.0:
		return
	var y := _rng.randf_range(6.0, floor_y)
	var kinds := kinds_at(y)
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
	legends = legends.filter(func(l): return not Data.fish[l].has("spot") or Data.fish[l]["spot"] == null 		or absf(float(place["spots"].get(Data.fish[l]["spot"], 0)) - x) < 300.0)
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
		var s := Sprite2D.new()
		s.texture = texture_for(id)
		s.scale = Vector2.ONE * (0.85 + 0.3 * Catalog.share(id, lb)) * (0.75 if count > 1 and big else 1.0) * (1.2 if f["legend"] else 1.0)
		add_child(s)
		var one := {"id": id, "lb": lb, "sprite": s, "pos": Vector2(x, y), "heading": heading, "phase": _rng.randf() * TAU,
			"speed": _rng.randf_range(6.0, 14.0) * (1.0 + float(f["strength"]) * 0.08), "band": f["depth"], "goal_y": y,
			"turn": _rng.randf_range(4.0, 12.0), "look": _rng.randf() * LOOK_EVERY, "state": "swim", "leader": leader, "group": _groups,
			"offset": Vector2((i % 3) * (s.texture.get_width() + 3) + _rng.randf_range(-3, 3), (i / 3) * (s.texture.get_height() + 2) + _rng.randf_range(-2, 2)) * Vector2(-heading, 1)}
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
				if f["state"] == "swim" and likes and away < NOTICE and _rng.randf() < 0.35:
					f["state"] = "curious"
					f["curious"] = CURIOUS_FOR
				elif f["state"] == "curious" and _rng.randf() < Bite.chance(f["id"], bait_id, away):
					f["state"] = "approach"
					biting = true
		keep.append(f)
	fish = keep


func _near_count() -> int:
	return fish.filter(func(f): return f["leader"].is_empty() and absf(f["pos"].x - (cam.x + 240.0)) < 240.0 + REACH).size()


func _move(f: Dictionary, delta: float, bait) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if f["state"] == "approach":
		if bait == null:
			f["state"] = "swim"
		else:
			var to: Vector2 = bait + Vector2(-6.0 * f["heading"], 2)
			f["heading"] = signf(bait.x - f["pos"].x) if absf(bait.x - f["pos"].x) > 2.0 else f["heading"]
			f["pos"] = f["pos"].move_toward(to, (f["speed"] + 10.0) * delta)
			if f["pos"].distance_to(to) < 2.0:
				f["state"] = "bit"
				bit.emit(f)
	elif f["state"] == "swim":
		var leader: Dictionary = f["leader"]
		if not leader.is_empty() and leader["state"] in ["swim", "curious"]:
			f["heading"] = leader["heading"]
			f["pos"] = f["pos"].lerp(leader["pos"] + f["offset"], minf(1.0, delta * 1.5))
		else:
			f["turn"] -= delta
			if f["turn"] <= 0.0:
				f["turn"] = _rng.randf_range(4.0, 12.0)
				if _rng.randf() < 0.4:
					f["heading"] = -f["heading"]
				f["goal_y"] = _rng.randf_range(float(f["band"][0]), float(f["band"][1]))
			f["pos"].x += f["heading"] * f["speed"] * delta
			if f["pos"].x < 10.0 or f["pos"].x > float(place["width"]) - 10.0:
				f["heading"] = signf(float(place["width"]) / 2.0 - f["pos"].x)
			if "dolphins" in events and Data.fish[f["id"]].get("shoal", false):
				f["goal_y"] = minf(f["goal_y"], 30.0)
			f["pos"].y = move_toward(f["pos"].y, f["goal_y"], 4.0 * delta) + sin(t * 1.3 + f["phase"]) * 0.08
			if light != null and "trident" in Data.fish[f["id"]]["methods"] and f["pos"].distance_to(light) < 160.0:
				var near: Vector2 = light + Vector2(sin(t * 0.5 + f["phase"]) * 30.0, cos(t * 0.4 + f["phase"]) * 14.0)
				f["pos"] = f["pos"].move_toward(near, f["speed"] * 0.6 * delta)
				f["heading"] = signf(near.x - f["pos"].x) if absf(near.x - f["pos"].x) > 3.0 else f["heading"]
	elif f["state"] == "curious":
		f["curious"] -= delta
		if bait == null or f["curious"] <= 0.0:
			release(f, false)
		else:
			var near: Vector2 = bait + Vector2(-18.0 * signf(bait.x - f["pos"].x + 0.01), sin(t * 0.9 + f["phase"]) * 6.0)
			f["heading"] = signf(bait.x - f["pos"].x) if absf(bait.x - f["pos"].x) > 4.0 else f["heading"]
			f["pos"] = f["pos"].move_toward(near, f["speed"] * delta)
	var lo := maxf(5.0, float(f["band"][0]) * 0.5)
	var hi := seabed.depth_at(f["pos"].x) - 5.0
	f["pos"].y = clampf(f["pos"].y, minf(lo, hi), hi)
	var s: Sprite2D = f["sprite"]
	s.flip_h = f["heading"] < 0.0
	s.position = (f["pos"] - cam).round()
	var depth := clampf(f["pos"].y / maxf(200.0, float(place["depth"])), 0.0, 1.0)
	s.modulate = Color(0.95, 1.0, 1.0).lerp(Color(0.55, 0.72, 0.8), depth)


## Takes a fish off the swimmers, when it is hooked or has given up on the bait.
func release(f: Dictionary, hooked: bool) -> void:
	if hooked:
		f["state"] = "gone"
	else:
		f["state"] = "swim"
		f["heading"] = -f["heading"]
		f["look"] = 4.0
