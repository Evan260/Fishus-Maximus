class_name ParallaxLayers
extends Node2D
## A place's painted layers, each sliding with the camera at its own speed. A layer is {"file" (under assets/art),
## "at": [x, y] (where it sits on screen with the camera at home) or "world": [x, y] for pieces that move with the
## water, "factor": [fx, fy], "z", "mirror", "alpha", "repeat": n (side by side n times, for pictures that join
## seamlessly onto themselves)}. A "band" layer is the sea under a row of land, a colour from its
## top edge down, so land never floats over the sky however far the camera dips. A "through" layer crosses the
## waterline, so a tinted copy of its lower part is laid over it to look seen through the water. Land that slides
## with a band, at the band's speed, is mirrored in it.

const HOME := Vector2(0, CoastCamera.HOME_Y)
const ART := "res://assets/art/"
const THROUGH := Color(0.45, 0.72, 0.78, 0.8)
const REFLECTION := preload("res://scripts/coast/reflection.gdshader")
## How far up from a picture's bottom its shore is looked for, column by column.
const SHORE_SCAN := 20
const MAX_REACH := 32
## Rows over which a band shades into the one behind it.
const RAMP := 6

var _nodes: Array = []
var _bands: Array = []
var _reflections: Array = []
var time := 0.0
## How broken the reflections are: 1 on a calm day, more in rain.
var rough := 1.0:
	set(v):
		if v == rough:
			return
		rough = v
		for r in _reflections:
			r.material.set_shader_parameter("rough", v)


func build(layers: Array) -> void:
	for n in _nodes:
		n["node"].queue_free()
	_nodes.clear()
	_bands.clear()
	_reflections.clear()
	var tops: Array = []
	for l in layers:
		if l.has("band"):
			tops.append(float(l["at"][1]))
	var seas := {}
	for l in layers:
		var factor := Vector2(l["factor"][0], l["factor"][1]) if l.has("factor") else Vector2.ONE
		var at := Vector2(l["world"][0], l["world"][1]) - HOME if l.has("world") else Vector2(l["at"][0], l["at"][1])
		if l.has("band"):
			var band := Band.new()
			band.colour = Color(str(l["band"]))
			band.z_index = int(l.get("z", 0))
			band.ramp = RAMP if tops.any(func(t): return t < at.y) else 0
			add_child(band)
			var glints := Glints.new()
			glints.factor = factor
			glints.z_index = band.z_index
			add_child(glints)
			_bands.append(glints)
			_nodes.append({"node": band, "at": at, "factor": factor})
			_nodes.append({"node": glints, "at": at, "factor": factor})
			seas[factor] = {"colour": band.colour, "glints": glints, "top": at.y}
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
		add_child(s)
		_nodes.append({"node": s, "at": at, "factor": factor})
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


## The land's reflection, drawn over its band and under the band's glints, reaching down until the next band or the
## near water covers it.
func _reflect(land: Sprite2D, at: Vector2, factor: Vector2, sea: Dictionary, tops: Array) -> void:
	var h := land.texture.get_height()
	var bottom := at.y + h
	var next := -HOME.y
	for t in tops:
		if t > sea["top"] and t < next:
			next = t
	var reach := clampf(next - bottom, 4.0, MAX_REACH)
	var near := clampf((factor.y - 0.1) / 0.45, 0.0, 1.0)
	var m := ShaderMaterial.new()
	m.shader = REFLECTION
	m.set_shader_parameter("sea", sea["colour"])
	m.set_shader_parameter("tint", lerpf(0.35, 0.18, near))
	m.set_shader_parameter("dark", lerpf(0.86, 0.72, near))
	m.set_shader_parameter("strength", lerpf(0.9, 1.0, near))
	m.set_shader_parameter("reach", reach)
	m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("scan", float(SHORE_SCAN))
	var r := Sprite2D.new()
	r.texture = land.texture
	r.centered = false
	r.flip_h = land.flip_h
	r.material = m
	r.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED if land.region_enabled else CanvasItem.TEXTURE_REPEAT_DISABLED
	r.region_enabled = true
	var w := land.region_rect.size.x if land.region_enabled else float(land.texture.get_width())
	r.region_rect = Rect2(0, h - SHORE_SCAN, w, SHORE_SCAN + reach)
	r.z_index = sea["glints"].z_index
	add_child(r)
	move_child(r, sea["glints"].get_index())
	_reflections.append(r)
	_nodes.append({"node": r, "at": at + Vector2(0, h - SHORE_SCAN), "factor": factor})


func reflections() -> Array:
	return _reflections


func place(cam: Vector2) -> void:
	for n in _nodes:
		n["node"].position = (n["at"] - (cam - HOME) * n["factor"]).round()
	for b in _bands:
		b.cam = cam
		b.time = time
		b.queue_redraw()


## The sea under a row of land, a colour from its top edge down, shading into the band behind it over a few rows.
class Band extends Node2D:
	var colour := Color.BLUE
	var ramp := 0

	func _draw() -> void:
		draw_rect(Rect2(-position.x, 0, Nav.view().x, Nav.view().y + 600.0), colour)
		for k in range(1, ramp + 1):
			draw_rect(Rect2(-position.x, -k, Nav.view().x, 1), Color(colour, 1.0 - float(k) / (ramp + 1)))


## Glints drifting across a band, over the land's reflection, and a patch of sparkle below the sun.
class Glints extends Node2D:
	var factor := Vector2.ONE
	var cam := HOME
	var time := 0.0

	func _draw() -> void:
		for i in 26:
			var row := 2 + (i * 7) % 40
			var x := fposmod(i * 53.0 - (cam.x - HOME.x) * factor.x + time * (3.0 + i % 4), 520.0) - 20.0 - position.x
			draw_rect(Rect2(roundf(x), row, 4 + i % 5, 1), Color(1, 1, 1, 0.12))
		var sun_x := 264.0 - (cam.x - HOME.x) * 0.05 - position.x
		for i in 18:
			if sin(time * 2.6 + i * 1.3) > 0.2:
				draw_rect(Rect2(roundf(sun_x - 18 + (i * 11) % 36), 1 + (i * 5) % 22, 3, 1), Color(1.0, 0.95, 0.85, 0.7))
