extends Node2D
## The estate by the shore: one large fish pond cut into the rock, seen side on as the coast is, its water cut away to
## show the fish. Beyond its far wall the sea washes up a beach between the villa on its rise and the garum works. It is
## built from the coast's own pieces, so it has the coast's sky and light for the hour and the weather, its bands of
## sea, the land mirrored in the water and the murk.

const ESTATE := "res://assets/art/estate/"
## Rows of the 480 by 270 scene: where the sky meets the sea, and where the pond's water is cut away.
const HORIZON := 92.0
const WATER := 182.0
## How deep the pond is below its waterline.
const DEPTH := 72.0
## How far left of the 480 by 270 scene the estate reaches, where the pond's own pixels start, and how wide it is.
const LEFT := 160.0
const WIDTH := 800.0
## The coast draws its pieces for a waterline 160 rows down, so they are laid out that much higher than the scene.
const RAISE := WATER + CoastCamera.HOME_Y
## The sea's shaders mirror the sky for a horizon at row 106 with the camera at home.
const SKY_SHIFT := SkyView.HORIZON - HORIZON + RAISE
## The pond's floor along its length, levelled by hand but never quite flat.
const FLOOR := [[0, 72], [130, 73], [260, 71], [410, 73], [560, 71], [690, 72], [800, 72]]
## How far past the estate's ends the beach, the wall and the pond's floor carry on: past the edge of the widest view, and
## a whole number of the beach's and the floor's pictures, so they line up with the estate's own.
const REACH := 4096.0
const BANK_AT := Vector2(-144, 16)
const BEACH_AT := Vector2(-160, 96)
const POND_TOP := 166.0
## The scene's layers in scene rows, from the far sea to the pond's far wall.
const LAYERS := [
	{"band": "#8fa0a8", "at": [0, 92], "z": -19},
	{"file": "places/harbour/far.png", "at": [-96, 22], "z": -18},
	{"band": "#6f93a0", "at": [0, 100], "z": -17},
	{"band": "#4d8590", "at": [0, POND_TOP], "z": -15},
	{"file": "estate/bank.png", "at": [BANK_AT.x, BANK_AT.y], "z": -14},
]
## Seabed pieces each feature puts on the pond's floor: its picture and where along the pond it lies, all within the
## stretch a 16:9 view shows.
const PIECES := {
	"tunnel": [["estate/pond_tunnel.png", 545]],
	"rocks": [["estate/pond_rocks.png", 300], ["estate/pond_rocks.png", 690]],
	"caves": [["estate/pond_cave.png", 445]],
	"weed": [["estate/pond_weed.png", 200], ["estate/pond_weed.png", 380], ["estate/pond_weed.png", 610]],
	"sand": [["places/harbour/tuft.png", 245], ["places/harbour/tuft.png", 515]],
}
## The sea channel's culvert through the wall, laid over the bank where it was painted into it, and where its water
## streams into the pond; the spring's place along the pond; and the stretch the shade roof keeps in shadow.
const CHANNEL_AT := Vector2(512, 96)
const CHANNEL_X := 562.0
const SPRING_X := 185.0
const SHADE_FROM := 160.0
const SHADE_TO := 330.0
## How many rows of the floor's picture lie above the seabed line, and how far into the sand a piece's base sinks.
const SURFACE := 6
const SINK := 2

## The row each piece's picture rests on, by its path, worked out once.
static var _bases := {}
## The garum works' mask and its outline, traced once.
static var _garum_traced := []
var views: Array = []
var pond: PondView
var _rng: RandomNumberGenerator
var _time := 0.0
var _top: Label
var _sky: SkyView
var _lit: Node2D
var _layers: ParallaxLayers
var _beach: Sprite2D
var _floor: FloorView
## The pond's floor carried on past each end of the pond, flat as the pond's own ends are.
var _floor_sides: Array[Sprite2D] = []
var _water: WaterView
var _back: Node2D
var _ground: Node2D
var _surface: Node2D
var _murk: Murk
var _bed: Node2D
var _shade: Node2D
var _channel: Sprite2D
var _spill: Node2D
var _painter: Node2D
var _names: Control
var _bed_built := []
var _garum: Image
var _garum_outline := PackedVector2Array()
var _floor_file := ""
## What the mouse is over: "pond", "garum" or "".
var hovered := ""
## Where the layers' camera and the pond's camera are this frame.
var cam := Vector2.ZERO
var pond_cam := Vector2.ZERO
## Where the mouse last was in view pixels, from its own events, so a click sent by a script finds what it is on too.
var _mouse := Vector2(-100, -100)


## Escape and the pad's B go back to town, as Back to town does.
func go_back() -> bool:
	Nav.go("town")
	return true


func enter(_args: Dictionary) -> void:
	Controls.ensure()
	if Game.state.is_empty():
		Game.new_game("Marcus", "")
	if Dev.has("hour"):
		Game.state["time"] = Clock.at_hour(float(Game.state["time"]), Dev.num("hour", 12.0))
	# --features=all (or a list such as rocks,channel) dresses a dug pond with those features, for checks.
	if Dev.has("features") and Ponds.dug(Game.state):
		var want := str(Dev.get_arg("features", "all"))
		Ponds.of(Game.state)["features"] = Data.ponds["features"].map(func(f): return str(f["id"])) if want in ["", "all"] else Array(want.split(","))
	if not Game.state.has("weather"):
		Game.state["weather"] = Weather.for_day(int(Game.state["seed"]), Clock.day_of(float(Game.state["time"])))
	_rng = Seeds.rng(int(Game.state["seed"]), "shore", Clock.day_of(float(Game.state["time"])))
	_build()
	var bar := PanelContainer.new()
	bar.position = Vector2(4, 4)
	Nav.ui.add_child(bar)
	_top = Ui.label(bar, "")
	_names = Control.new()
	_names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Nav.ui.add_child(_names)
	var back := Ui.button(Nav.ui, tr("Back to town"), go_back)
	Ui.hang(back, "bottom_right", Vector2(4, 4), Vector2(90, 18))
	Windowing.view_changed.connect(_relayout)
	Game.changed.connect(_refresh)
	_refresh()
	_show_frame()


func _exit_tree() -> void:
	if is_instance_valid(_sky):
		_sky.queue_free()


func _build() -> void:
	_sky = SkyView.new()
	_sky.rise_follow = 1.0
	Nav.sky.add_child(_sky)
	_lit = Node2D.new()
	add_child(_lit)
	_layers = ParallaxLayers.new()
	_layers.sky = _sky
	_lit.add_child(_layers)
	var specs := []
	for l in LAYERS:
		var spec: Dictionary = l.duplicate(true)
		if spec.has("at"):
			spec["at"] = [spec["at"][0], spec["at"][1] - RAISE]
			spec["factor"] = [1.0, 1.0]
		specs.append(spec)
	specs.append_array(_walls())
	_layers.build(specs)
	for n in _layers.bands() + _layers.reflections():
		var m: ShaderMaterial = n.material
		m.set_shader_parameter("home", m.get_shader_parameter("home") + Vector2(0, SKY_SHIFT))
	_beach = Sprite2D.new()
	_beach.texture = load(ESTATE + "beach.png")
	_beach.centered = false
	_beach.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_beach.region_enabled = true
	_beach.region_rect = Rect2(0, 0, WIDTH + REACH * 2.0, _beach.texture.get_height())
	_beach.z_index = -16
	var wash := ShaderMaterial.new()
	wash.shader = preload("res://scripts/shore/wash.gdshader")
	wash.set_shader_parameter("sea", Color("#6f93a0"))
	wash.set_shader_parameter("moon_colour", SkyView.MOON_LIGHT)
	wash.set_shader_parameter("home", BEACH_AT + Vector2(-REACH, SKY_SHIFT - RAISE))
	ShoreWash.set_up(wash)
	_beach.material = wash
	_lit.add_child(_beach)
	_water = WaterView.new()
	_water.depth = DEPTH
	_water.z_index = -10
	_lit.add_child(_water)
	_back = Node2D.new()
	_back.z_index = -9
	_back.draw.connect(_draw_back)
	_lit.add_child(_back)
	_channel = Sprite2D.new()
	_channel.texture = load(ESTATE + "channel.png")
	_channel.centered = false
	_channel.z_index = -13
	_lit.add_child(_channel)
	_spill = Node2D.new()
	_spill.z_index = -13
	_spill.draw.connect(_draw_spill)
	_lit.add_child(_spill)
	_shade = Node2D.new()
	_shade.z_index = -9
	_shade.draw.connect(_draw_shade)
	_lit.add_child(_shade)
	_bed = Node2D.new()
	# The pieces stand in front of the floor, so their own uneven feet rest on the sand rather than being cut by it.
	_bed.z_index = -7
	_lit.add_child(_bed)
	_floor = FloorView.new()
	_floor.z_index = -8
	_lit.add_child(_floor)
	for x in [-REACH, WIDTH]:
		var side := Sprite2D.new()
		side.centered = false
		side.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		side.region_enabled = true
		side.position.x = x
		_floor.add_child(side)
		_floor_sides.append(side)
	_ground = Node2D.new()
	_ground.z_index = -6
	_ground.draw.connect(_draw_ground)
	_lit.add_child(_ground)
	pond = PondView.new()
	pond.z_index = -4
	pond.right = WIDTH - 8.0
	pond.floor_y = DEPTH
	_lit.add_child(pond)
	views = [pond]
	_surface = Node2D.new()
	_surface.draw.connect(func(): WaterView.draw_surface(_surface, pond_cam, _time))
	_lit.add_child(_surface)
	# The murk shades the lit picture under it, so inside the light it would tint it a second time.
	_murk = Murk.new()
	_murk.z_index = pond.z_index
	_murk.set_depth(DEPTH)
	add_child(_murk)
	_painter = Node2D.new()
	_painter.z_index = 20
	_painter.draw.connect(_draw_over)
	add_child(_painter)
	# The garum works' pixels are read back and its outline traced once, and kept for the next visit.
	if _garum_traced.is_empty():
		var img := (load(ESTATE + "garum_mask.png") as Texture2D).get_image()
		_garum_traced = [img, _outline(img)]
	_garum = _garum_traced[0]
	_garum_outline = _garum_traced[1]
	_dress_pond()
	pond.sync()


## The stone wall along the pond carried on past each end of the bank, a stretch of the bank's own wall over and over,
## laid so its stones run on unbroken from the bank's.
func _walls() -> Array:
	var bank: Texture2D = load(ESTATE + "bank.png")
	var tile := float((load(ESTATE + "wall.png") as Texture2D).get_width())
	var count := ceili(REACH / tile)
	var y := BANK_AT.y - RAISE
	return [
		{"file": "estate/wall.png", "at": [BANK_AT.x - tile * count, y], "factor": [1.0, 1.0], "repeat": count, "z": -14},
		{"file": "estate/wall.png", "at": [BANK_AT.x + bank.get_width(), y], "factor": [1.0, 1.0], "repeat": count, "z": -14},
	]


## The pond's floor and the pieces on it for the features it has; laid again whenever the features change.
func _dress_pond() -> void:
	var features: Array = Ponds.of(Game.state).get("features", [])
	var want := "places/harbour/floor.png" if "sand" in features else "places/rocky_shore/floor.png"
	if want != _floor_file:
		_floor_file = want
		_floor.bake({"width": WIDTH, "depth": DEPTH, "floor": {"file": want, "surface": SURFACE}}, Seabed.new(FLOOR))
		var strip: Texture2D = load("res://assets/art/" + want)
		for side in _floor_sides:
			side.texture = strip
			side.position.y = DEPTH - SURFACE
			# The region starts at the side's own place along the pond, so its sand runs on from the pond's.
			side.region_rect = Rect2(fposmod(side.position.x, strip.get_width()), 0, REACH, strip.get_height())
	_channel.visible = "channel" in features
	if _bed_built == features:
		return
	_shade.queue_redraw()
	_bed_built = features.duplicate()
	for c in _bed.get_children():
		c.queue_free()
	for feature in PIECES:
		if not feature in features:
			continue
		for piece in PIECES[feature]:
			var tex: Texture2D = load("res://assets/art/" + str(piece[0]))
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			var used := ParallaxLayers.used_rect(tex)
			s.position = Vector2(float(piece[1]) - used.size.x / 2.0 - used.position.x, sand_top(float(piece[1])) + SINK - base_row(tex))
			var layer := {"sway": feature == "weed"}
			s.self_modulate = Murk.shade_for(layer)
			var m := ShaderMaterial.new()
			if feature == "weed":
				m.shader = ParallaxLayers.SWAY
				m.set_shader_parameter("top", float(used.position.y))
				m.set_shader_parameter("root", float(used.end.y))
				m.set_shader_parameter("amount", clampf(used.size.y / 22.0, 1.0, 2.2))
				m.set_shader_parameter("phase", float(piece[1]) * 0.37)
			else:
				m.shader = ParallaxLayers.BED
			m.set_shader_parameter("keep", Murk.keep_for(layer))
			s.material = m
			_bed.add_child(s)


## The top row of the floor's sand at a point along the pond, where its picture's ragged top edge turns solid.
static func sand_top(x: float) -> float:
	return roundf(Seabed.new(FLOOR).depth_at(x))


## The row of a piece's picture that rests on the sand: most of its middle columns reach down to it, so the piece stands
## on the floor in front of it without floating, and only a stray pebble or root runs on into the sand.
static func base_row(tex: Texture2D) -> int:
	var key := tex.resource_path
	if not _bases.has(key):
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		var used := img.get_used_rect()
		var lows := []
		var margin := used.size.x / 6
		for x in range(used.position.x + margin, used.end.x - margin):
			for y in range(used.end.y - 1, used.position.y - 1, -1):
				if img.get_pixel(x, y).a > 0.5:
					lows.append(y)
					break
		lows.sort()
		_bases[key] = int(lows[lows.size() / 5]) if not lows.is_empty() else used.end.y - 1
	return _bases[key]


func _relayout() -> void:
	var off := Nav.offset()
	cam = Vector2(-off.x, CoastCamera.HOME_Y - RAISE - off.y)
	pond_cam = Vector2(LEFT - off.x, -WATER - off.y)


func _refresh() -> void:
	if not is_instance_valid(_top):
		return
	var p := Ponds.of(Game.state)
	var room: String = (tr("Pond room %d of %d") % [Ponds.room_used(p), Ponds.room(p)]) if Ponds.dug(Game.state) else tr("No pond yet")
	_top.text = "%s   %s   %s" % [Ui.coins_text(int(Game.state["denarii"])), room, tr("Salt %d") % int(Game.state.get("salt", 0))]
	if is_instance_valid(pond):
		_dress_pond()


func _process(delta: float) -> void:
	_time += delta
	var day := Clock.day_of(float(Game.state["time"]))
	World.advance(Game.state, delta / 60.0, _rng)
	# Each morning the fish breed and grow, so their pictures are matched to them again.
	if Clock.day_of(float(Game.state["time"])) != day:
		pond.sync()
		_refresh()
	_show_frame()


## Lays every piece out for the view and lights it for the hour and the weather.
func _show_frame() -> void:
	var hour := Clock.hour(float(Game.state["time"]))
	var weather := str(Dev.get_arg("weather", str(Game.state.get("weather", "clear"))))
	var day_time := hour >= 6.0 and hour < 19.5
	Audio.set_ambience({"gulls": 0.3 if day_time else 0.0, "cicadas": 0.25 if hour >= 16.0 and hour < 20.5 else 0.0,
		"night": 0.3 if not day_time else 0.0, "rain": 0.5 if weather in ["rain", "storm"] else 0.0})
	_relayout()
	_sky.follow(Vector2(cam.x, CoastCamera.HOME_Y + SkyView.HORIZON - HORIZON - Nav.offset().y), hour, weather)
	var light := SkyView.light(hour)
	if weather in ["rain", "storm"]:
		light *= AshoreSky.RAIN_LIGHT
	_lit.modulate = Color(light, 1.0)
	_layers.rough = 2.2 if weather in ["rain", "storm"] else 1.0
	_layers.time = _time
	_layers.place(cam)
	_copy_sea(_beach.material)
	_beach.position = BEACH_AT + Vector2(-REACH - cam.x, -RAISE - cam.y + CoastCamera.HOME_Y)
	_beach.material.set_shader_parameter("wash_time", _time)
	_beach.material.set_shader_parameter("to_sky", _beach.global_position.x - _sky.position.x)
	_water.cam = pond_cam
	_water.time = _time
	_floor.place_at(pond_cam)
	_bed.position = -pond_cam
	_shade.position = -pond_cam
	_channel.position = _bank_at() + CHANNEL_AT
	pond.cam = pond_cam
	_murk.place_at(pond_cam, _lit.modulate)
	for s in _layers.swaying():
		s.material.set_shader_parameter("time", _time)
	for s in _bed.get_children():
		if (s.material as ShaderMaterial).shader == ParallaxLayers.SWAY:
			s.material.set_shader_parameter("time", _time)
	hovered = "" if Ui.window_open() else _thing_at(_mouse)
	_water.queue_redraw()
	_back.queue_redraw()
	_spill.queue_redraw()
	_ground.queue_redraw()
	_surface.queue_redraw()
	_painter.queue_redraw()
	_place_names()


## Gives the beach's water the hour's sky and the sun's and moon's paths, as the bands of sea have them.
func _copy_sea(m: ShaderMaterial) -> void:
	var from: ShaderMaterial = _layers.bands()[1].material
	for key in ["zenith", "middle", "low", "glow", "glow_radius", "sun", "sun_colour", "sun_light", "sun_width", "moon",
			"moon_light", "time", "rough"]:
		m.set_shader_parameter(key, from.get_shader_parameter(key))


## Where the bank picture is drawn in view pixels.
func _bank_at() -> Vector2:
	return BANK_AT + Vector2(-cam.x, CoastCamera.HOME_Y - RAISE - cam.y)


func _thing_at(at: Vector2) -> String:
	var p := Vector2i((at - _bank_at()).floor())
	if _solid(_garum, p):
		return "garum"
	if at.y >= _bank_at().y + 120.0 and at.y < Nav.view().y - 26.0:
		return "pond"
	return ""


## The pixels touching the garum works on a side or a corner, drawn in gold round it while the mouse is over it.
func _outline(img: Image) -> PackedVector2Array:
	var out := PackedVector2Array()
	var used := img.get_used_rect()
	for y in range(used.position.y - 1, used.end.y + 1):
		for x in range(used.position.x - 1, used.end.x + 1):
			if _solid(img, Vector2i(x, y)):
				continue
			for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
				if _solid(img, Vector2i(x, y) + d):
					out.append(Vector2(x, y))
					break
	return out


static func _solid(img: Image, p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() and img.get_pixelv(p).a > 0.5


## What the features add to the pond's water: the channel's sea water streaming in as bubbles near the top, and the
## spring's fresh water rising from the floor at the far end, shimmering as it meets the sea water.
func _draw_back() -> void:
	var features: Array = Ponds.of(Game.state).get("features", [])
	if "channel" in features:
		var at := Vector2(CHANNEL_X, 3.0) - pond_cam
		for i in 10:
			var t := fposmod(_time * 0.7 + i * 0.1, 1.0)
			var bx := at.x + (i % 5 - 2) * 2.0 + sin(_time * 3.0 + i) * 1.5
			_back.draw_rect(Rect2(Vector2(bx, at.y + t * 26.0).floor(), Vector2.ONE), Color(0.9, 0.97, 1.0, 0.6 * (1.0 - t)))
	if "spring" in features:
		var at := Vector2(SPRING_X, sand_top(SPRING_X)) - pond_cam
		for i in 12:
			var t := fposmod(_time * 0.35 + i / 12.0, 1.0)
			var bx := at.x + sin(t * 9.0 + i) * (2.0 + t * 5.0)
			_back.draw_rect(Rect2(Vector2(bx, at.y - t * (DEPTH - 4.0)).floor(), Vector2.ONE), Color(0.92, 0.98, 1.0, 0.55 * (1.0 - t * 0.7)))


## The shade roof's shadow over the near end of the pond, drawn once: bands slanting with the sun where its slats keep
## the light off, the lighter gaps between them, and soft ends where the shadow thins out.
func _draw_shade() -> void:
	if not "shade" in Ponds.of(Game.state).get("features", []):
		return
	var shadow := Color(0.02, 0.06, 0.08, 0.06)
	var lean := 0.35 * DEPTH
	for k in 5:
		var inset := k * 5.0
		Pixels.polygon(_shade, PackedVector2Array([Vector2(SHADE_FROM + inset, 0), Vector2(SHADE_TO - inset, 0),
			Vector2(SHADE_TO - inset + lean, DEPTH + 4.0), Vector2(SHADE_FROM + inset + lean, DEPTH + 4.0)]), shadow, Vector2.ZERO)
	var x := SHADE_FROM + 6.0
	while x < SHADE_TO - 12.0:
		var fade := clampf(minf(x - SHADE_FROM, SHADE_TO - x) / 30.0, 0.0, 1.0)
		Pixels.polygon(_shade, PackedVector2Array([Vector2(x, 0), Vector2(x + 6.0, 0), Vector2(x + 6.0 + lean, DEPTH + 4.0),
			Vector2(x + lean, DEPTH + 4.0)]), Color(shadow, 0.08 * fade), Vector2.ZERO)
		x += 9.0


## The sea water pouring out of the channel's culvert into the pond below it, in falling streaks with foam where it
## lands.
func _draw_spill() -> void:
	if not "channel" in Ponds.of(Game.state).get("features", []):
		return
	var sill := _bank_at() + CHANNEL_AT + Vector2(34.0, 54.0)
	var fall := WATER - POND_TOP
	for i in 20:
		var t := fposmod(_time * 1.1 + i / 20.0, 1.0)
		var spread := float(i % 7 - 3) * (1.0 + t * 1.6)
		_spill.draw_rect(Rect2((sill + Vector2(spread, t * fall)).floor(), Vector2(1, 2)), Color(0.86, 0.95, 0.98, 0.75 * (1.0 - t * 0.8)))
	for i in 6:
		var w := 3.0 + fposmod(_time * 6.0 + i * 1.7, 4.0)
		_spill.draw_rect(Rect2((sill + Vector2(-w - 2.0 + i * 1.0, fall - 1.0 + float(i % 2))).floor(), Vector2(w, 1)), Color(0.95, 0.99, 1.0, 0.5))


## Solid ground below the pond's floor, fading in over its last rows, as the coast draws it.
func _draw_ground() -> void:
	var view := Nav.view()
	var y := DEPTH + 24.0 - pond_cam.y
	_ground.draw_rect(Rect2(0, y, view.x, maxf(0.0, view.y - y + 2.0)), FloorView.SHADOW)
	for k in 8:
		_ground.draw_rect(Rect2(0, y - 16.0 + k * 2.0, view.x, 2), Color(FloorView.SHADOW, (k + 1) / 9.0))


func _draw_over() -> void:
	if hovered == "garum":
		var at := _bank_at()
		for p in _garum_outline:
			_painter.draw_rect(Rect2(at + p, Vector2.ONE), UiTheme.GOLD)
		_tip(_pointer(), tr("The garum works"))
	elif hovered == "pond":
		_tip(_pointer(), tr("The fish pond") if Ponds.dug(Game.state) else tr("Dig a fish pond here"))


func _pointer() -> Vector2:
	return _mouse + Vector2(0, -10)


func _tip(at: Vector2, text: String) -> void:
	var w := Ui.tag_width(text)
	var x := clampf(at.x - w / 2.0, 3.0, Nav.view().x - w - 3.0)
	Ui.draw_tag(_painter, Vector2(x, at.y), text)


## The names over the named fish while the bell rings, in the interface so they stay crisp.
func _place_names() -> void:
	if not is_instance_valid(_names):
		return
	var shown := pond.shown_names()
	while _names.get_child_count() < shown.size():
		var l := Ui.label(_names, "", "LightLabel")
		# A fish's name is the player's own, never looked up as words to translate.
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.add_theme_color_override("font_outline_color", UiTheme.INK)
		l.add_theme_constant_override("outline_size", 3)
	for i in _names.get_child_count():
		var l: Label = _names.get_child(i)
		l.visible = i < shown.size()
		if l.visible:
			var one: Dictionary = shown[i]
			var s: Sprite2D = one["sprite"]
			l.text = str(one["data"]["name"])
			l.reset_size()
			var at := Nav.to_ui(s.position - Vector2(0, s.texture.get_height() / 2.0 + 3.0))
			l.position = (at - Vector2(l.size.x / 2.0, l.size.y)).round()


func _input(e: InputEvent) -> void:
	if e is InputEventMouse:
		_mouse = e.position


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or Ui.window_open():
		return
	var thing := _thing_at(e.position)
	if thing == "garum":
		GarumPanel.open()
	elif thing == "pond":
		PondPanel.open(pond)
