class_name SkyView
extends Node2D
## The sky behind a place, as Farmus Maximus draws it: a banded gradient by the hour with the sun crossing it, the moon
## and stars at night, and clouds in three depths tinted by the hour, more and greyer when it is overcast. It lives in
## Nav.sky and is placed in game pixels, so the clouds drift by fractions of a pixel. The places' land is painted in
## daylight and tinted by `light()`.

const GRADIENT := """
shader_type canvas_item;
// The gradient from zenith to horizon in flat bands, the sun's glow in flat rings and stars at night, per sky pixel.
uniform vec2 area = vec2(480.0, 230.0);
uniform vec2 origin = vec2(0.0, -40.0);
uniform float top = -44.0;
uniform float horizon = 106.0;
uniform float bands = 9.0;
uniform vec4 zenith : source_color;
uniform vec4 middle : source_color;
uniform vec4 low : source_color;
uniform vec2 sun = vec2(240.0, 40.0);
uniform vec4 glow : source_color;
uniform float glow_radius = 100.0;
uniform float stars = 0.0;
uniform float time = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 px = floor(origin + UV * area);
	float t = clamp((px.y - top) / (horizon - top), 0.0, 1.0);
	float q = clamp(floor(t * bands * 2.0 + 0.5) / (bands * 2.0), 0.0, 1.0);
	vec3 col = q < 0.5 ? mix(zenith.rgb, middle.rgb, q * 2.0) : mix(middle.rgb, low.rgb, (q - 0.5) * 2.0);
	float r = length((px - sun) * vec2(1.0, 1.4)) / glow_radius;
	float g = clamp(1.0 - r, 0.0, 1.0);
	g = floor(g * g * 7.0 + 0.5) / 7.0;
	col = mix(col, glow.rgb, g * glow.a);
	if (stars > 0.0 && t < 0.8) {
		float h = hash(px);
		if (h > 0.9965) {
			float twinkle = 0.55 + 0.45 * sin(time * (0.8 + fract(h * 91.0) * 2.5) + h * 300.0);
			col = mix(col, vec3(0.93, 0.93, 1.0), stars * twinkle * (1.0 - t));
		}
	}
	COLOR = vec4(col, 1.0);
}
"""
## Recolours a cloud for the hour, its bright parts in the light and its shadows in the sky's shade, and keeps each of
## its pixels a crisp block while it drifts by fractions of a pixel.
const CLOUD_TINT := """
shader_type canvas_item;
uniform vec4 light : source_color = vec4(1.0);
uniform vec4 shade : source_color = vec4(0.72, 0.76, 0.9, 1.0);

void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 texel = UV * size;
	vec2 seam = floor(texel + 0.5);
	vec2 width = max(fwidth(texel), vec2(0.0001));
	texel = seam + clamp((texel - seam) / width, -0.5, 0.5);
	vec4 c = texture(TEXTURE, texel / size);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float k = smoothstep(0.45, 0.97, l);
	COLOR = vec4(mix(shade.rgb, light.rgb, k), c.a * COLOR.a);
}
"""
const CLOUDS := "res://assets/art/sky/"
const AURORA := preload("res://scripts/coast/aurora.gdshader")
## The row where the sky meets the far sea, with the camera at home.
const HORIZON := 106.0
## How far the sky moves for each row the view rises above home, as the farthest land does, so its sun, moon and low
## clouds stay above that land while he rows.
const RISE_FOLLOW := 0.12

## How far the sky moves for each row the view rises; ashore it is laid on a picture's own horizon, so it moves fully.
var rise_follow := RISE_FOLLOW
## The sky reaches this far above the view and below the horizon, past the waterline, so its ends never show.
const TOP := -40.0
const BELOW := 80.0
## The share of the camera's sideways move the sky follows, like the farthest layer.
const DRIFT := 0.04
## How high the sun climbs above the horizon at noon, and its glow's radius when it is low and when it is high.
const RISE := 84.0
const GLOW := Vector2(190, 100)
const SUN_R := 8
## The clouds go round a field wider than the widest strip with the widest cloud and `ROOM` past each side, so none
## goes round in sight, even after a long frame.
const FIELD := 1920.0
const ROOM := 32.0
## How much faster the clouds drift in each weather.
const WIND := {"clear": 1.0, "cloudy": 1.4, "rain": 1.8, "storm": 3.0, "wind": 3.0}
const OVERCAST := ["cloudy", "rain", "storm"]
## The moon goes from new to full and back over this many nights.
const MOON_CYCLE := 8
## A new game's first night has the moon a little short of full.
const FIRST_PHASE := 3
const MOON_R := 12
const MOON_LIGHT := Color8(241, 237, 204)
const MOON_SEA := Color8(220, 215, 186)
## The dark part of the moon still shows faintly against the sky, lit by the earth.
const MOON_DARK := Color(0.55, 0.57, 0.72, 0.13)

var hour := 12.0
var weather := "clear"
var _cam := Vector2(0, CoastCamera.HOME_Y)
var _gradient: Sprite2D
var _sun: Sprite2D
var _night: Node2D
var _moon: Sprite2D
var _moon_glow: Sprite2D
var _moon_phases: Array[Texture2D] = []
var _moon_phase := -1
var _cloud_look: ShaderMaterial
var _clouds: Array = []
var _widest := 0.0
## How overcast the sky looks and how dark the storm, each easing towards the weather's.
var _grey := 0.0
var _dark := 0.0
var _settled := false
var _t := 0.0
var _aurora: Sprite2D
## How bright the northern lights are, easing in after dusk and out before dawn, and how far they have rippled.
var _aurora_amount := 0.0
var _aurora_clock := 0.0
## The birds crossing the sky: {"pos", "vel", "phase", "swallow"}, in sky pixels; and seconds until the next flock.
var _birds: Array = []
var _bird_wait := 5.0
var _flock: Node2D
## Shows the lights tonight whatever the night, for --aurora; `aurora_shape` "rising" or "across" picks their shape.
var force_aurora := false
var aurora_shape := ""
var _rolled_for := []
var _tonight := false
var _rising := false


func _ready() -> void:
	_gradient = Sprite2D.new()
	_gradient.texture = _solid(Color.WHITE)
	_gradient.centered = false
	var paint := ShaderMaterial.new()
	paint.shader = Shader.new()
	paint.shader.code = GRADIENT
	paint.set_shader_parameter("horizon", HORIZON)
	_gradient.material = paint
	add_child(_gradient)
	_aurora = Sprite2D.new()
	_aurora.texture = _gradient.texture
	_aurora.centered = false
	_aurora.material = ShaderMaterial.new()
	_aurora.material.shader = AURORA
	_aurora.material.set_shader_parameter("horizon", HORIZON)
	_aurora.visible = false
	add_child(_aurora)
	if Dev.has("aurora"):
		force_aurora = true
		aurora_shape = Dev.get_arg("aurora")
	_sun = Sprite2D.new()
	_sun.texture = _disc(SUN_R)
	add_child(_sun)
	_night = Node2D.new()
	add_child(_night)
	_moon_glow = Sprite2D.new()
	_moon_glow.texture = _moon_rings()
	_night.add_child(_moon_glow)
	_moon = Sprite2D.new()
	for phase in MOON_CYCLE:
		_moon_phases.append(_moon_texture(phase))
	_night.add_child(_moon)
	_cloud_look = ShaderMaterial.new()
	_cloud_look.shader = Shader.new()
	_cloud_look.shader.code = CLOUD_TINT
	_scatter_clouds()
	Windowing.view_changed.connect(_lay_out)
	_lay_out()


## Puts the sky behind the camera for the hour and the weather; the first call settles the clouds for the day.
func follow(cam: Vector2, at_hour: float, now: String) -> void:
	hour = at_hour
	weather = now
	_cam = cam
	_lay_out()
	if not _settled:
		_settled = true
		_settle()
	_paint()


## The view's left and right edges in the sky's own pixels.
func view_span() -> Vector2:
	return Vector2(-position.x, -position.x + Nav.view().x)


## Each cloud: {"sprite", "speed", "alpha", "grey_only", ...}, for the tests.
func clouds() -> Array:
	return _clouds


## What the sea mirrors: the hour's colours as `SkyPalette.at` gives them with the sky's own greyness, "sun" and
## "moon" in the sky's pixels (NAN while down), "sun_colour", "glow_radius", "moon_light" from 0 to 1, and "grey" and
## "dark".
func look() -> Dictionary:
	var out := SkyPalette.at(hour, _grey, _dark)
	out["grey"] = _grey
	out["dark"] = _dark
	out["sun"] = _sun.position if _sun.visible else Vector2(NAN, NAN)
	out["sun_colour"] = _sun.modulate
	var radius = (_gradient.material as ShaderMaterial).get_shader_parameter("glow_radius")
	out["glow_radius"] = float(radius) if radius != null else GLOW.y
	out["moon"] = _moon.position if _moon.visible else Vector2(NAN, NAN)
	out["moon_light"] = _night.modulate.a * _moon_glow.modulate.a * (1.0 - _dark) if _moon.visible else 0.0
	return out


func _solid(c: Color) -> ImageTexture:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, c)
	return ImageTexture.create_from_image(img)


## The sun's face: a round disc with a paler rim, coloured by the hour.
func _disc(r: int) -> ImageTexture:
	var size := r * 2 + 1
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x - r, y - r).length()
			if d <= r + 0.3:
				img.set_pixel(x, y, Color(1, 1, 1) if d < r - 1.2 else Color(1, 1, 1, 0.75))
	return ImageTexture.create_from_image(img)


## The moon's light in the night air: a bright glow close round it, a wider soft halo and a faint ring further out, in
## steps like the sky's bands.
func _moon_rings() -> ImageTexture:
	var k := MOON_R / 20.0
	var size := int(140 * k)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size / 2.0 - 0.5, size / 2.0 - 0.5)
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(c) / k
			var a := 0.0
			if d < 30.0:
				a = 0.11
			elif d < 40.0:
				a = 0.07
			elif d < 52.0:
				a = 0.04
			if d >= 60.0 and d < 63.0:
				a = 0.06
			elif d >= 52.0 and d < 69.0:
				a = maxf(a, 0.02)
			if a > 0.0:
				img.set_pixel(x, y, Color(0.85, 0.87, 1.0, a))
	return ImageTexture.create_from_image(img)


## The moon on one night of its cycle: lit from the right while it grows towards full, from the left as it wanes.
func _moon_texture(phase: int) -> Texture2D:
	var size := MOON_R * 2 + 1
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var turn := cos(TAU * phase / MOON_CYCLE)
	var k := MOON_R / 20.0
	var seas := [Vector3(-6, -5, 4.5), Vector3(4, -8, 3.0), Vector3(5, 4, 5.0), Vector3(-4, 8, 3.0), Vector3(-9, 2, 2.5)]
	for y in size:
		for x in size:
			var u := (x - MOON_R) / float(MOON_R)
			var v := (y - MOON_R) / float(MOON_R)
			if u * u + v * v > 1.0:
				continue
			var w := sqrt(1.0 - v * v)
			var lit := u > w * turn if phase * 2 <= MOON_CYCLE else u < -w * turn
			if phase == 0:
				lit = false
			if not lit:
				img.set_pixel(x, y, MOON_DARK)
				continue
			var c := MOON_LIGHT
			for sea in seas:
				if Vector2(x - MOON_R - sea.x * k, y - MOON_R - sea.y * k).length() < sea.z * k:
					c = MOON_SEA
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## Clouds in three depths: small faint ones low and far away drifting slowly, big ones high and near drifting faster.
## The same seed lays them out every time, carried along by the time of day so each visit finds them moved on.
func _scatter_clouds() -> void:
	var textures: Array[Texture2D] = []
	var i := 0
	while ResourceLoader.exists("%scloud_%d.png" % [CLOUDS, i]):
		textures.append(load("%scloud_%d.png" % [CLOUDS, i]))
		i += 1
	if textures.is_empty():
		return
	var by_size := textures.duplicate()
	by_size.sort_custom(func(a, b): return a.get_width() < b.get_width())
	_widest = float(by_size[-1].get_width())
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seconds := float(Game.state.get("time", 0.0)) * 60.0
	for layer in [{"count": 9, "y": Vector2(42, 60), "speed": 0.5, "alpha": 0.7, "pick": 0.0},
			{"count": 9, "y": Vector2(14, 36), "speed": 1.0, "alpha": 0.9, "pick": 0.4},
			{"count": 8, "y": Vector2(-12, 4), "speed": 1.7, "alpha": 1.0, "pick": 0.65}]:
		var along := float(layer["speed"]) * seconds
		for k in int(layer["count"]):
			var from := int(float(layer["pick"]) * by_size.size())
			var s := Sprite2D.new()
			s.texture = by_size[rng.randi_range(from, mini(by_size.size() - 1, from + 2))]
			s.centered = false
			s.flip_h = rng.randf() < 0.5
			s.material = _cloud_look
			s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			add_child(s)
			var speed := float(layer["speed"]) * rng.randf_range(0.7, 1.35)
			# Every other cloud only shows on grey days, so a fine day has open sky between its clouds.
			_clouds.append({"sprite": s, "x": (k + rng.randf_range(0.0, 0.8)) * FIELD / int(layer["count"]) + along,
				"speed": speed, "alpha": float(layer["alpha"]), "grey_only": _clouds.size() % 2 == 1,
				"base_y": rng.randf_range(layer["y"].x, layer["y"].y), "lift": rng.randf_range(1.0, 5.0),
				"period": rng.randf_range(80.0, 220.0), "phase": rng.randf() * TAU})
			s.modulate.a = 0.0


func _lay_out() -> void:
	var view := Nav.view()
	# The sky rises with the waterline as the camera goes down, and moves with the coast in the desktop strip.
	var below := _cam.y - CoastCamera.HOME_Y
	position = Vector2(-_cam.x * DRIFT, -below * (1.0 if below > 0.0 else rise_follow) + Nav.port.canvas_transform.origin.y)
	# The camera rises above home while he rows or a float flies, so the sky reaches up to the view's top as well.
	var top := minf(TOP, floorf(-position.y) - 2.0)
	_gradient.position = Vector2(floorf(-position.x) - 2.0, top)
	_gradient.scale = Vector2(view.x + 4.0, HORIZON + BELOW - top)
	var paint := _gradient.material as ShaderMaterial
	paint.set_shader_parameter("area", _gradient.scale)
	paint.set_shader_parameter("origin", _gradient.position)
	_aurora.position = _gradient.position
	_aurora.scale = _gradient.scale
	_aurora.material.set_shader_parameter("area", _gradient.scale)
	_aurora.material.set_shader_parameter("origin", _gradient.position)
	_place_clouds()


## Settles the sky on the weather at once and moves any cloud lying across an edge of the view just out past it.
func _settle() -> void:
	_grey = 1.0 if weather in OVERCAST else 0.0
	_dark = 1.0 if weather == "storm" else 0.0
	_place_clouds()
	var span := view_span()
	for c in _clouds:
		var s: Sprite2D = c["sprite"]
		var w := float(s.texture.get_width())
		if s.position.x < span.x and s.position.x + w > span.x:
			c["x"] -= s.position.x + w - span.x + 1.0
		elif s.position.x < span.y and s.position.x + w > span.y:
			c["x"] += span.y - s.position.x + 1.0
		s.modulate.a = _shown(c)
	_place_clouds()
	_paint()


func _shown(c: Dictionary) -> float:
	return float(c["alpha"]) if weather in OVERCAST or not c["grey_only"] else 0.0


## Each cloud sits in a field starting well over a cloud's width left of the view, so it goes round out of sight.
func _place_clouds() -> void:
	var room := _widest + ROOM
	var left := -position.x - room
	var field := maxf(FIELD, Nav.view().x + room * 2.0)
	for c in _clouds:
		var s: Sprite2D = c["sprite"]
		s.position = Vector2(left + fposmod(float(c["x"]) - left, field), float(c["base_y"]) + float(c["lift"]) * sin(_t * TAU / float(c["period"]) + float(c["phase"])))


func _process(delta: float) -> void:
	_t += delta
	_grey = move_toward(_grey, 1.0 if weather in OVERCAST else 0.0, delta * 0.1)
	_dark = move_toward(_dark, 1.0 if weather == "storm" else 0.0, delta * 0.1)
	var wind := float(WIND.get(weather, 1.0))
	for c in _clouds:
		c["x"] = float(c["x"]) + float(c["speed"]) * wind * delta
		var s: Sprite2D = c["sprite"]
		s.modulate.a = move_toward(s.modulate.a, _shown(c), delta * 0.2)
	_place_clouds()
	_paint()
	_show_aurora(delta)
	_fly_birds(delta)


func _paint() -> void:
	var look := SkyPalette.at(hour, _grey, _dark)
	var sky := _gradient.material as ShaderMaterial
	for key in ["zenith", "middle", "low", "glow"]:
		sky.set_shader_parameter(key, look[key])
	var span := view_span()
	var pos := SkyPalette.sun_position(hour, span.x, span.y - span.x, HORIZON, RISE)
	_sun.visible = not is_nan(pos.x)
	if _sun.visible:
		_sun.position = pos.round()
		var height := clampf((HORIZON - pos.y) / RISE, 0.0, 1.0)
		_sun.modulate = Color(1.0, 0.72, 0.45).lerp(Color(1.0, 0.98, 0.9), height) * Color(1, 1, 1, lerpf(1.0, 0.4, _grey) * (1.0 - 0.75 * _dark))
		sky.set_shader_parameter("sun", pos)
		sky.set_shader_parameter("glow_radius", lerpf(GLOW.x, GLOW.y, height))
	else:
		# Just below the horizon the sky still glows where the sun went down or is about to come up.
		var near := hour
		var toward := 1.0 if fposmod(hour, 24.0) < 12.0 else -1.0
		for i in 160:
			near += toward * 0.05
			if not is_nan(SkyPalette.sun_position(near, span.x, span.y - span.x, HORIZON, RISE).x):
				break
		var edge := SkyPalette.sun_position(near, span.x, span.y - span.x, HORIZON, RISE)
		if not is_nan(edge.x):
			sky.set_shader_parameter("sun", Vector2(edge.x, HORIZON + 12.0))
			sky.set_shader_parameter("glow_radius", GLOW.x)
	var night := SkyPalette.night_amount(hour)
	sky.set_shader_parameter("stars", night * lerpf(1.0, 0.3, _grey) * (1.0 - _dark))
	sky.set_shader_parameter("time", _t)
	_cloud_look.set_shader_parameter("light", look["light"])
	_cloud_look.set_shader_parameter("shade", look["shade"])
	_night.modulate.a = night
	_place_moon(span)


## The moon rises on the left at dusk, climbs in an arc and sets on the right at dawn.
func _place_moon(span: Vector2) -> void:
	var t := fposmod(hour - 19.0, 24.0) / 11.0
	_moon.visible = t <= 1.0
	_moon_glow.visible = _moon.visible
	if not _moon.visible:
		return
	_moon.position = Vector2(span.x + lerpf(0.05, 0.91, t) * (span.y - span.x), HORIZON - 26.0 - sin(t * PI) * 58.0).round()
	_moon_glow.position = _moon.position
	# The day turns over at dawn, so after midnight it is still the moon that rose the evening before.
	var phase := posmod(Clock.day_of(float(Game.state.get("time", 0.0))) + FIRST_PHASE, MOON_CYCLE)
	if phase != _moon_phase:
		_moon_phase = phase
		_moon.texture = _moon_phases[phase]
		_moon_glow.modulate.a = 0.2 + 0.8 * (1.0 - cos(TAU * phase / MOON_CYCLE)) / 2.0


## Whether a night has the northern lights, rare this far south: about one in fourteen, and every night once a month has
## gone by without the player seeing them, so nobody misses them by bad luck. `evening` is the day the night began on.
static func aurora_night(seed: int, evening: int, seen: bool) -> bool:
	if evening >= int(Data.num("sky.aurora_sure_after_days", 30)) and not seen:
		return true
	return Seeds.rng(seed, "aurora", evening).randf() < Data.num("sky.aurora_chance", 0.07)


func birds() -> Array:
	return _birds


## As in Farmus Maximus, a flock crosses the sky every half minute or so by day: gulls high up, or swallows swooping
## lower at dusk. None fly at night or in a storm.
func _fly_birds(delta: float) -> void:
	if _flock == null:
		_flock = Node2D.new()
		_flock.draw.connect(_draw_birds)
		add_child(_flock)
	_bird_wait -= delta
	if _bird_wait <= 0.0:
		_bird_wait = randf_range(25.0, 60.0)
		if SkyPalette.night_amount(hour) < 0.5 and weather != "storm":
			_spawn_flock(hour >= 17.0 and hour < 20.0)
	for b in _birds:
		b["phase"] += delta
		b["pos"] += b["vel"] * delta
		if b["swallow"]:
			b["pos"].y += cos(b["phase"] * 3.0) * 22.0 * delta
	var span := view_span()
	_birds = _birds.filter(func(b): return b["pos"].x > span.x - 80.0 and b["pos"].x < span.y + 80.0)
	_flock.queue_redraw()


func _spawn_flock(swallows: bool) -> void:
	var span := view_span()
	var left := randf() < 0.5
	var y := randf_range(40.0, 75.0) if swallows else randf_range(12.0, 60.0)
	var speed := (randf_range(60.0, 90.0) if swallows else randf_range(26.0, 40.0)) * (1.0 if left else -1.0)
	for i in randi_range(3, 6):
		var x := span.x - 10.0 - i * 9.0 if left else span.y + 10.0 + i * 9.0
		_birds.append({"pos": Vector2(x, y + randf_range(-6.0, 6.0)), "vel": Vector2(speed, randf_range(-1.5, 1.5)), "phase": randf() * 5.0, "swallow": swallows})


func _draw_birds() -> void:
	var lit := light(hour)
	for b in _birds:
		var p: Vector2 = b["pos"].round()
		var up := fmod(b["phase"] * (4.0 if b["swallow"] else 2.5), 1.0) < 0.5
		var c := Color(0.2, 0.17, 0.24) if b["swallow"] else Color(0.95, 0.95, 0.92) * lit
		# A gull's wingtips are dark, which shows it against a pale sky.
		var tip := c if b["swallow"] else Color(0.4, 0.4, 0.46) * lit
		for d in ([Vector2(-2, -1), Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0), Vector2(2, -1)] if up else [Vector2(-2, 1), Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0), Vector2(2, 1)]):
			_flock.draw_rect(Rect2(p + d, Vector2.ONE), tip if absf(d.x) == 2.0 else c)


func aurora_amount() -> float:
	return _aurora_amount


## The lights ease in through the darkest hours of a clear night chosen for them, curtains or streamers by the night.
func _show_aurora(delta: float) -> void:
	var state: Dictionary = Game.state
	var evening := Clock.day_of(float(state.get("time", 0.0)))
	var seed := int(state.get("seed", 1))
	var seen := int(state.get("stats", {}).get("auroras", 0)) > 0
	# The night's chances are rolled once an evening rather than every frame.
	var key := [seed, evening, seen]
	if key != _rolled_for:
		_rolled_for = key
		_tonight = aurora_night(seed, evening, seen)
		_rising = Seeds.rng(seed, "aurora shape", evening).randf() < 0.5
	var tonight := force_aurora or _tonight
	var target := smoothstep(0.75, 1.0, SkyPalette.night_amount(hour)) if tonight and weather == "clear" else 0.0
	_aurora_clock += delta
	_aurora_amount = target if force_aurora else move_toward(_aurora_amount, target, delta / 20.0)
	_aurora.visible = _aurora_amount > 0.01
	if not _aurora.visible:
		return
	var rising := _rising if aurora_shape == "" else aurora_shape == "rising"
	_aurora.material.set_shader_parameter("amount", _aurora_amount)
	_aurora.material.set_shader_parameter("clock", _aurora_clock)
	_aurora.material.set_shader_parameter("rising", 1.0 if rising else 0.0)
	if _aurora_amount > 0.5 and not state.is_empty() and int(state.get("aurora_seen_on", -1)) != evening:
		state["aurora_seen_on"] = evening
		state["stats"]["auroras"] = int(state["stats"].get("auroras", 0)) + 1


## The light the hour casts on the land and the sea.
static func light(h: float) -> Color:
	if h < 4.5 or h >= 21.0:
		return Color(0.42, 0.5, 0.78)
	if h < 6.5:
		return Color(0.42, 0.5, 0.78).lerp(Color(1.0, 0.85, 0.76), (h - 4.5) / 2.0)
	if h < 9.0:
		return Color(1.0, 0.85, 0.76).lerp(Color.WHITE, (h - 6.5) / 2.5)
	if h < 17.0:
		return Color.WHITE
	if h < 19.5:
		return Color.WHITE.lerp(Color(1.0, 0.8, 0.66), (h - 17.0) / 2.5)
	return Color(1.0, 0.8, 0.66).lerp(Color(0.42, 0.5, 0.78), (h - 19.5) / 1.5)
