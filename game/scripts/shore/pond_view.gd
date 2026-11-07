class_name PondView
extends Node2D
## One pond seen in a cut through the ground: its water, its sandy floor and features, and its fish
## swimming. Ringing the bell brings the named fish to the front with their names over them.

const SIZE := Vector2(64, 92)
const PROPS := {"rocks": ["res://assets/art/places/rocky_shore/rock.png", 0.35, 0.0], "caves": ["res://assets/art/places/capri/cave.png", 0.25, 1.0],
	"weed": ["res://assets/art/places/harbour/seagrass.png", 0.45, 0.4], "sand": ["res://assets/art/places/harbour/tuft.png", 0.5, 0.7]}

var site := 0
var bell_left := 0.0
var _fish: Array = []
var _time := 0.0
var _floor: Texture2D = load("res://assets/art/places/harbour/floor.png") if ResourceLoader.exists("res://assets/art/places/harbour/floor.png") else null
var _props := {}


func _ready() -> void:
	clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	# Textures are loaded ahead of drawing; one first loaded inside a draw call shows as a blank square.
	for feature in PROPS:
		if ResourceLoader.exists(PROPS[feature][0]):
			_props[feature] = Pixels.shrunk(load(PROPS[feature][0]), PROPS[feature][1])


func pond() -> Dictionary:
	var i := Ponds.site_of(Game.state, site)
	return Game.state["ponds"][i] if i >= 0 else {}


## Matches the swimming sprites to the fish in the pond, keeping each one where it was.
func sync() -> void:
	var p := pond()
	var wanted: Array = p.get("fish", [])
	while _fish.size() > wanted.size():
		_fish.pop_back()["sprite"].queue_free()
	while _fish.size() < wanted.size():
		var s := Sprite2D.new()
		add_child(s)
		_fish.append({"sprite": s, "pos": Vector2(randf_range(10, SIZE.x - 10), randf_range(16, SIZE.y - 24)), "dir": 1.0 if randf() < 0.5 else -1.0,
			"phase": randf() * TAU})
	for i in wanted.size():
		var f: Dictionary = wanted[i]
		var s: Sprite2D = _fish[i]["sprite"]
		var path := "res://assets/art/fish/%s.png" % f["fish"]
		s.texture = load(path) if ResourceLoader.exists(path) else null
		if s.texture:
			s.material = Pixels.look(maxf(0.0, Swimmers.wave_for(f["fish"], s.texture) - 1.0))
		s.scale = Vector2.ONE * (0.45 + 0.35 * Catalog.share(f["fish"], float(f["pounds"])))
		_fish[i]["data"] = f


func _process(delta: float) -> void:
	_time += delta
	bell_left = maxf(0.0, bell_left - delta)
	for one in _fish:
		var s: Sprite2D = one["sprite"]
		var named: bool = one.has("data") and str(one["data"].get("name", "")) != ""
		if bell_left > 0.0 and named:
			one["pos"] = one["pos"].move_toward(Vector2(SIZE.x / 2.0, SIZE.y / 2.0 + 6.0), 30.0 * delta)
		else:
			one["pos"].x += one["dir"] * 6.0 * delta
			if one["pos"].x < 8.0 or one["pos"].x > SIZE.x - 8.0:
				one["dir"] = -one["dir"]
			one["pos"].y += sin(_time * 1.2 + one["phase"]) * 0.05
		s.flip_h = one["dir"] < 0.0
		s.position = one["pos"]
		one["swim"] = float(one.get("swim", one["phase"])) + delta * 6.0
		Pixels.set_swim(s, one["swim"])
	queue_redraw()


func _draw() -> void:
	var p := pond()
	if p.is_empty():
		return
	for y in range(0, int(SIZE.y), 2):
		var k := y / SIZE.y
		draw_rect(Rect2(0, y, SIZE.x, 2), WaterView.SURFACE.lerp(WaterView.MID_WATER, k * 1.2).lerp(WaterView.DEEP_WATER, maxf(0.0, k - 0.5)))
	if _floor:
		draw_texture_rect_region(_floor, Rect2(0, SIZE.y - 18, SIZE.x, 18), Rect2((site * 70) % 300, 4, SIZE.x, 18))
	for feature in p["features"]:
		if _props.has(feature):
			var tex: Texture2D = _props[feature]
			var size := tex.get_size()
			var x: float = roundf(PROPS[feature][2] * (SIZE.x - size.x))
			draw_texture(tex, Vector2(x, SIZE.y - 12 - size.y))
	if "channel" in p["features"]:
		for i in 5:
			var bx := fposmod(_time * 14.0 + i * 13.0, SIZE.x)
			draw_rect(Rect2(bx, 3 + (i % 2), 2, 1), Color(1, 1, 1, 0.5))
	if "tunnel" in p["features"]:
		Pixels.disc(self, Vector2(SIZE.x - 2, SIZE.y - 30), 9.0, Color(0.03, 0.08, 0.12, 0.9))
	for i in 5:
		var gx := fposmod(i * 17.0 + _time * 4.0, SIZE.x)
		draw_rect(Rect2(gx, 1, 4, 1), Color(1.0, 0.95, 0.8, 0.5))
	if bell_left > 0.0:
		for one in _fish:
			if one.has("data") and str(one["data"].get("name", "")) != "":
				var at: Vector2 = one["pos"] + Vector2(-12, -10)
				draw_string(UiTheme.body_font(), at, one["data"]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiTheme.CREAM)
	for one in _fish:
		if one.has("data") and str(one["data"].get("finery", "")) != "":
			draw_rect(Rect2(one["pos"] + Vector2(-2, -1), Vector2(2, 2)), UiTheme.GOLD)
