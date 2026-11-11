class_name ParallaxLayers
extends Node2D
## A place's painted layers, each sliding with the camera at its own speed. A layer is {"file" (under assets/art),
## "at": [x, y] (where it sits on screen with the camera at home) or "world": [x, y] for pieces that move with the
## water, "factor": [fx, fy], "z", "mirror", "alpha", "repeat": n (side by side n times, for pictures that join
## seamlessly onto themselves), "sway" (a plant swaying in the water)}. A "band" layer is the sea under a row of land,
## mirroring the sky from its top edge down, so land never floats over the sky however far the camera dips. A
## "through" layer crosses the waterline, so a tinted copy of its lower part is laid over it to look seen through the
## water. Land that slides with a band, at the band's speed, stands in it: below each column's waterline, over any sea
## painted in the picture, the sea mirrors the sky and the land. A "front" layer is a dark plant right in front of the
## view, standing up from its "bottom" edge on its own bank, whose waterline lies on the sea's, or hanging from its "top":
## "x" is the place along the coast it stands in front of, "factor" above 1 slides it faster than the boat, and it
## breaks away in pixel blocks while the boat, the float, a fish fight or a button along the bottom of the screen is
## behind it.

const HOME := Vector2(0, CoastCamera.HOME_Y)
const ART := "res://assets/art/"
const THROUGH := Color(0.45, 0.72, 0.78, 0.8)
const SEA := preload("res://scripts/coast/sea.gdshader")
const REFLECTION := preload("res://scripts/coast/reflection.gdshader")
const SWAY := preload("res://scripts/coast/sway.gdshader")
const FRONT := preload("res://scripts/coast/front.gdshader")
## Seconds a plant in front takes to break away or come back, and the size of its blocks in game pixels.
const FRONT_SECONDS := 0.6
const FRONT_CELL := 2.0
## How near the boat or the float may come to a plant in front before it breaks away.
const FRONT_ROOM := 24.0
## How far the view may dip into the water before the plants standing at the bottom break away.
const FRONT_DIP := 24.0
## Rows of the bank under a plant standing at the bottom that lie below its waterline, as make_front.py paints them.
const FRONT_DEPTH := 140
const BED := preload("res://scripts/coast/bed.gdshader")
## How far up from a picture's bottom a column's waterline may lie; land ending higher hangs over the water.
const SHORE_SCAN := 28
const MAX_REACH := 40.0
## Rows over which a band shades into the one behind it.
const RAMP := 6
## How near a colour must be to one of the painted sea's to count as sea.
const SEA_LIKE := 0.04
## The share of the faded pixels a colour needs to be one of the painted sea's.
const SEA_SHARE := 0.02
## Painted sea lies level: most of the row either side is sea too, and its colour changes only a few times there.
const SEA_SPAN := 6
const SEA_LEVEL := 0.75
const SEA_CALM := 5
## How many columns either side settle a column's waterline against its neighbours'.
const SETTLE := 12
## Where the sun and the moon are put while they are down.
const NOWHERE := Vector2(-10000, -10000)

## Each picture's waterlines, found once.
static var _waterlines := {}
## Each picture's visible part, found once.
static var _used := {}

var _nodes: Array = []
## Every node drawing sea: the bands and the land standing in them.
var _waters: Array = []
var _bands: Array = []
var _reflections: Array = []
var _swaying: Array = []
## The plants in front: {"node", "x", "factor", "edge", "used", "progress"}.
var _fronts: Array = []
## What the plants in front must not hide this frame, in view pixels, and whether a fish is being fought.
var _clear: Array = []
var _fight := false
var _front_time := 0.0
var _bed_look: ShaderMaterial
var time := 0.0
## The sky the sea mirrors; without one the sea shows a clear noon.
var sky: SkyView
## How broken the water is: 1 on a calm day, more in rain.
var rough := 1.0:
	set(v):
		if v == rough:
			return
		rough = v
		for w in _waters:
			w.material.set_shader_parameter("rough", v)


func build(layers: Array) -> void:
	for n in _nodes:
		n["node"].queue_free()
	_nodes.clear()
	_waters.clear()
	_bands.clear()
	_reflections.clear()
	_swaying.clear()
	_fronts.clear()
	var tops: Array = []
	for l in layers:
		if l.has("band"):
			tops.append(float(l["at"][1]))
	var seas := {}
	for l in layers:
		if l.has("front"):
			# --no-front leaves the plants in front out, for marketing pictures cut from the view.
			if not Dev.has("no-front"):
				_front(l)
			continue
		var factor := Vector2(l["factor"][0], l["factor"][1]) if l.has("factor") else Vector2.ONE
		var at := Vector2(l["world"][0], l["world"][1]) - HOME if l.has("world") else Vector2(l["at"][0], l["at"][1])
		if l.has("band"):
			var band := Band.new()
			band.z_index = int(l.get("z", 0))
			band.ramp = RAMP if tops.any(func(t): return t < at.y) else 0
			band.material = _water(SEA, Color(str(l["band"])), at)
			band.material.set_shader_parameter("ramp", float(band.ramp))
			add_child(band)
			_nodes.append({"node": band, "at": at, "factor": factor})
			_waters.append(band)
			_bands.append(band)
			seas[factor] = {"colour": Color(str(l["band"])), "top": at.y}
			continue
		var path := ART + str(l["file"])
		if not ResourceLoader.exists(path):
			push_warning("missing layer " + path)
			continue
		var s := Sprite2D.new()
		s.texture = load(path)
		s.centered = false
		s.flip_h = bool(l.get("mirror", false))
		if int(l.get("repeat", 1)) > 1:
			s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			s.region_enabled = true
			s.region_rect = Rect2(0, 0, s.texture.get_width() * int(l["repeat"]), s.texture.get_height())
		s.z_index = int(l.get("z", 0))
		if l.has("alpha"):
			s.modulate.a = float(l["alpha"])
		if l.has("world") and not l.get("through", false):
			s.self_modulate = Murk.shade_for(l)
			if not l.get("sway", false):
				s.material = _bed()
		add_child(s)
		_nodes.append({"node": s, "at": at, "factor": factor})
		if l.get("sway", false):
			_sway(s, float(l.get("world", [0, 0])[0]))
		if seas.has(factor) and not l.has("world"):
			_reflect(s, at, factor, seas[factor], tops)
		if l.get("through", false):
			var under := Sprite2D.new()
			under.texture = s.texture
			under.centered = false
			under.flip_h = s.flip_h
			under.region_enabled = true
			var waterline := int(-(at + HOME).y) + 1
			under.region_rect = Rect2(0, waterline, s.texture.get_width(), s.texture.get_height() - waterline)
			under.modulate = THROUGH
			under.z_index = s.z_index
			add_child(under)
			_nodes.append({"node": under, "at": at + Vector2(0, waterline), "factor": factor})


func _water(shader: Shader, colour: Color, at: Vector2) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("sea", colour)
	m.set_shader_parameter("home", at)
	m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("moon_colour", SkyView.MOON_LIGHT)
	return m


## Stands a row of land in its band: the picture reaches on down to where the nearer water covers it, and below each
## column's waterline it draws the sea mirroring the sky and the land above, darker and tinted toward the sea.
func _reflect(land: Sprite2D, at: Vector2, factor: Vector2, sea: Dictionary, tops: Array) -> void:
	var h := float(land.texture.get_height())
	var next := -HOME.y
	for t in tops:
		if t > sea["top"] and t < next:
			next = t
	var near := clampf((factor.y - 0.1) / 0.45, 0.0, 1.0)
	var m := _water(REFLECTION, sea["colour"], at)
	m.set_shader_parameter("waterline", ImageTexture.create_from_image(_line_image(waterlines(land.texture))))
	m.set_shader_parameter("tint", lerpf(0.35, 0.18, near))
	m.set_shader_parameter("dark", lerpf(0.86, 0.72, near))
	m.set_shader_parameter("strength", lerpf(0.9, 1.0, near))
	m.set_shader_parameter("until", next - at.y)
	m.set_shader_parameter("reach", MAX_REACH)
	land.material = m
	var w := land.region_rect.size.x if land.region_enabled else float(land.texture.get_width())
	land.region_enabled = true
	land.region_rect = Rect2(0, 0, w, maxf(h, next - at.y))
	_waters.append(land)
	_reflections.append(land)


## The part of a picture with anything in it, read back from the picture once and kept by its path.
static func used_rect(texture: Texture2D) -> Rect2i:
	var key := texture.resource_path
	if key == "":
		return texture.get_image().get_used_rect()
	if not _used.has(key):
		_used[key] = texture.get_image().get_used_rect()
	return _used[key]


func _line_image(rows: PackedFloat32Array) -> Image:
	var img := Image.create(rows.size(), 1, false, Image.FORMAT_RF)
	for x in rows.size():
		img.set_pixel(x, 0, Color(rows[x], 0, 0))
	return img


## Each column's waterline in a picture of land, as a row: the foot of its land, or where the sea painted below the
## land begins, or -1 where no land comes down near the bottom.
static func waterlines(texture: Texture2D) -> PackedFloat32Array:
	if _waterlines.has(texture.resource_path):
		return _waterlines[texture.resource_path]
	var img := texture.get_image()
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var sea := _sea_pixels(img, _sea_colours(img))
	var feet := PackedInt32Array()
	var seas := PackedInt32Array()
	feet.resize(w)
	seas.resize(w)
	var runs: Array = []
	for x in w:
		feet[x] = -1
		seas[x] = -1
		var b := h - 1
		while b >= 0 and img.get_pixel(x, b).a <= 0.5:
			b -= 1
		if b < 0:
			continue
		feet[x] = b + 1
		var top := _painted_sea(img, x, sea)
		if top >= 0:
			seas[x] = top
			runs.append(h - top)
	# Sea is painted in a strip of much the same height, so a column reaching far above the rest has run into land.
	runs.sort()
	var cap: int = clampi(mini(runs[int(runs.size() * 0.9)], runs[runs.size() / 2] + 10) if not runs.is_empty() else 0, 4, SHORE_SCAN)
	var out := PackedFloat32Array()
	out.resize(w)
	for x in w:
		var line := float(feet[x])
		if seas[x] >= 0:
			var around: Array = []
			for k in range(maxi(0, x - SETTLE), mini(w, x + SETTLE + 1)):
				if seas[k] >= 0:
					around.append(seas[k])
			around.sort()
			line = float(maxi(maxi(seas[x], h - cap), around[around.size() / 2]))
		out[x] = line if feet[x] >= 0 and line >= h - SHORE_SCAN else -1.0
	_waterlines[texture.resource_path] = out
	return out


## The lowest visible row of a column when it fades into the band, as painted sea does, or -1.
static func _fading(img: Image, x: int) -> int:
	var y := img.get_height() - 1
	while y >= 0 and img.get_pixel(x, y).a <= 0.03:
		y -= 1
	return y if y >= 0 and img.get_pixel(x, y).a < 0.78 else -1


## The colours of the sea painted along a picture's bottom, taken from its rows fading into the band, leaving out any
## too rare to be sea rather than the odd rock it fades past.
static func _sea_colours(img: Image) -> Array:
	var counts := {}
	var total := 0
	for x in img.get_width():
		var y := _fading(img, x)
		while y >= 0 and img.get_pixel(x, y).a < 0.78:
			var key := img.get_pixel(x, y).to_rgba32() | 0xff
			counts[key] = int(counts.get(key, 0)) + 1
			total += 1
			y -= 1
	return counts.keys().filter(func(k): return counts[k] >= SEA_SHARE * total).map(func(k): return Color.hex(k))


## Which pixels near a picture's bottom are painted sea: one of the sea's colours, in a calm row mostly of them, since
## the sea lies level in long strokes while bluish rock matching its colours is broken up every way.
static func _sea_pixels(img: Image, colours: Array) -> PackedByteArray:
	var w := img.get_width()
	var h := img.get_height()
	var alike := {}
	var out := PackedByteArray()
	out.resize(w * h)
	var coloured := PackedByteArray()
	coloured.resize(w)
	var sums := PackedInt32Array()
	sums.resize(w + 1)
	var changes := PackedInt32Array()
	changes.resize(w + 1)
	for y in range(maxi(0, h - SHORE_SCAN - 2), h):
		var last := -1
		for x in w:
			var c := img.get_pixel(x, y)
			var key := c.to_rgba32() | 0xff
			if not alike.has(key):
				alike[key] = colours.any(func(s: Color): return Vector3(c.r - s.r, c.g - s.g, c.b - s.b).length() < SEA_LIKE)
			coloured[x] = 1 if c.a >= 0.78 and alike[key] else 0
			sums[x + 1] = sums[x] + coloured[x]
			changes[x + 1] = changes[x] + (1 if x > 0 and key != last else 0)
			last = key
		for x in w:
			var many := sums[mini(w, x + SEA_SPAN + 1)] - sums[maxi(0, x - SEA_SPAN)] >= SEA_LEVEL * (2 * SEA_SPAN + 1)
			var calm := changes[mini(w, x + SEA_SPAN + 1)] - changes[maxi(0, x - SEA_SPAN + 1)] <= SEA_CALM
			out[y * w + x] = 1 if coloured[x] == 1 and many and calm else 0
	return out


## Where the sea painted at the foot of a column begins, or -1: it fades into the band along the picture's bottom and
## reaches up the column as far as it carries on.
static func _painted_sea(img: Image, x: int, sea: PackedByteArray) -> int:
	var w := img.get_width()
	var y := _fading(img, x)
	while y >= 0 and img.get_pixel(x, y).a < 0.78:
		y -= 1
	if y < 0:
		return -1
	var first := img.get_pixel(x, y)
	if not (first.b > first.r + 0.024 and first.b >= first.g - 0.047 and first.get_luminance() < 0.63):
		return -1
	var top := y
	var misses := 0
	y -= 1
	while y >= 0 and misses < 2:
		if sea[y * w + x] == 1:
			top = y
			misses = 0
		else:
			misses += 1
		y -= 1
	return top


## Sways a plant on the sea floor, out of step with the others along the coast.
func _sway(s: Sprite2D, x: float) -> void:
	var used := used_rect(s.texture)
	var m := ShaderMaterial.new()
	m.shader = SWAY
	m.set_shader_parameter("top", float(used.position.y))
	m.set_shader_parameter("root", float(used.end.y))
	m.set_shader_parameter("amount", clampf(used.size.y / 22.0, 1.0, 2.2))
	m.set_shader_parameter("phase", x * 0.37)
	m.set_shader_parameter("keep", Murk.PLANT_KEEP)
	s.material = m
	_swaying.append(s)


func _front(l: Dictionary) -> void:
	var path := ART + str(l["file"])
	if not ResourceLoader.exists(path):
		push_warning("missing layer " + path)
		return
	var s := Sprite2D.new()
	s.texture = load(path)
	s.centered = false
	s.flip_h = bool(l.get("mirror", false))
	s.z_index = int(l.get("z", 5))
	var m := ShaderMaterial.new()
	m.shader = FRONT
	m.set_shader_parameter("cell", FRONT_CELL)
	m.set_shader_parameter("progress", 0.0)
	s.material = m
	add_child(s)
	var used := used_rect(s.texture)
	if s.flip_h:
		used.position.x = s.texture.get_width() - used.end.x
	_fronts.append({"node": s, "x": float(l["x"]), "factor": Vector2(l["factor"][0], l["factor"][1]),
		"edge": str(l["front"]), "used": used, "progress": 0.0})


## What the plants in front must keep clear of this frame, as rectangles in view pixels, and whether a fish is on.
func keep_clear(rects: Array, fight: bool) -> void:
	_clear = rects
	_fight = fight


func fronts() -> Array:
	return _fronts.map(func(f): return f["node"])


## Slides each plant in front across the view faster than the boat, around the place it stands in front of, and lets
## it break away while anything that must stay seen is behind it. A branch rises out past the top as the view dips
## into the water, and a plant at the bottom breaks away then; otherwise each keeps to its edge, which never shows.
func _place_fronts(cam: Vector2) -> void:
	var dt := clampf(time - _front_time, 0.0, 0.25)
	_front_time = time
	var view := Nav.view()
	var lift := HOME.y - cam.y
	for f in _fronts:
		var s: Sprite2D = f["node"]
		var size := s.texture.get_size()
		var factor: Vector2 = f["factor"]
		var used: Rect2i = f["used"]
		var x: float = view.x / 2.0 + (f["x"] - cam.x - view.x / 2.0) * factor.x - size.x / 2.0
		var bottom: bool = f["edge"] == "bottom"
		var y: float = -used.position.y + minf(0.0, lift) * factor.y
		if bottom:
			# The bank's waterline sits on the sea's, but never so high that the bank's foot comes into the view.
			y = maxf(-cam.y - (size.y - FRONT_DEPTH), view.y - used.end.y)
		s.position = Vector2(x, y)
		s.visible = not Windowing.strip
		var area := Rect2(s.position + Vector2(used.position), Vector2(used.size)).grow(FRONT_ROOM)
		var away := _fight or (bottom and lift < -FRONT_DIP) or _clear.any(func(r: Rect2): return area.intersects(r, true))
		f["progress"] = move_toward(f["progress"], 1.0 if away else 0.0, dt / FRONT_SECONDS)
		s.material.set_shader_parameter("progress", f["progress"])
## The look of a piece lying on the seabed, its colours mostly drained by the murky water; one is shared by them all.
func _bed() -> ShaderMaterial:
	if _bed_look == null:
		_bed_look = ShaderMaterial.new()
		_bed_look.shader = BED
		_bed_look.set_shader_parameter("keep", Murk.PIECE_KEEP)
	return _bed_look


func reflections() -> Array:
	return _reflections


func bands() -> Array:
	return _bands


func swaying() -> Array:
	return _swaying


func place(cam: Vector2) -> void:
	for n in _nodes:
		n["node"].position = n["at"] - (cam - HOME) * n["factor"]
	for b in _bands:
		b.waterline = -cam.y
		b.queue_redraw()
	for s in _swaying:
		s.material.set_shader_parameter("time", time)
	_place_fronts(cam)
	_mirror()


## Shows the hour's sky in every band of sea and in the water under the land, with the paths of the sun and the moon.
func _mirror() -> void:
	var look: Dictionary = sky.look() if is_instance_valid(sky) else SkyPalette.at(12.0)
	var sky_x := sky.position.x if is_instance_valid(sky) else 0.0
	var sun: Vector2 = look.get("sun", NOWHERE)
	var moon: Vector2 = look.get("moon", NOWHERE)
	var grey: float = look.get("grey", 0.0)
	var dark: float = look.get("dark", 0.0)
	var sun_light := 0.0
	var height := 0.0
	if not is_nan(sun.x):
		height = clampf((SkyView.HORIZON - sun.y) / SkyView.RISE, 0.0, 1.0)
		# The sun's path dims under cloud, goes with a storm and sinks with the sun below the far sea.
		sun_light = (1.0 - 0.85 * grey) * (1.0 - dark) * clampf((SkyView.HORIZON + SkyView.SUN_R - sun.y) / SkyView.SUN_R, 0.0, 1.0)
	else:
		sun = NOWHERE
	if is_nan(moon.x):
		moon = NOWHERE
	var moon_light := float(look.get("moon_light", 0.0)) * (1.0 - 0.8 * grey)
	for n in _waters:
		var m: ShaderMaterial = n.material
		for key in ["zenith", "middle", "low", "glow"]:
			m.set_shader_parameter(key, look[key])
		m.set_shader_parameter("glow_radius", float(look.get("glow_radius", SkyView.GLOW.y)))
		m.set_shader_parameter("sun", sun)
		m.set_shader_parameter("sun_colour", Color(look.get("sun_colour", Color.WHITE), 1.0))
		m.set_shader_parameter("sun_light", sun_light)
		m.set_shader_parameter("sun_width", lerpf(34.0, 14.0, height))
		m.set_shader_parameter("moon", moon)
		m.set_shader_parameter("moon_light", moon_light)
		m.set_shader_parameter("to_sky", n.global_position.x - sky_x)
		m.set_shader_parameter("time", time)


## The sea under a row of land, drawn by sea.gdshader from a few rows above its top edge down to the near waterline on
## screen, where the water in front takes over.
class Band extends Node2D:
	var ramp := 0
	var waterline := -HOME.y

	func _draw() -> void:
		var bottom := waterline - position.y + 1.0
		if bottom > -ramp:
			draw_rect(Rect2(-position.x, -ramp, Nav.view().x, bottom + ramp), Color.WHITE)
