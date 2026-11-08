class_name Murk
extends Node2D
## The murky water over everything under the waterline: drawn after the fish, it reads back what is already on screen
## below the waterline, mutes its colours a little toward a sea grey and lays the water's colour over it, more
## the deeper it lies, so the sand, the land and plants under the water, the pots and the fish all look seen through
## the same sea while the water itself stays sea-coloured. Plants, pieces on the seabed and fish lose most of their
## colour in their own shaders before this, by the shares below. The lamp's light, the line and the boat are drawn
## after it and stay clear.

const SHADER := preload("res://scripts/coast/murk.gdshader")
## The share of colour the water and everything in it keeps; the rest turns to a grey with the sea's cast.
const KEEP := 0.75
const TINT := Color("#62797c")
## The share of the water's colour over a thing just under the surface, and at the bottom of the place.
const FOG := 0.1
const FOG_DEEP := 0.45
## The share of their own colour that plants, the other pieces on the seabed and the fish keep in murky water.
const PLANT_KEEP := 0.3
const PIECE_KEEP := 0.3
const FISH_KEEP := 0.6
## Plants are dim shapes against the water, and the other pieces on the seabed a little less dim.
const PLANT := Color(0.5, 0.5, 0.5)
const PIECE := Color(0.7, 0.7, 0.7)
const WEIGHTS := Vector3(0.299, 0.587, 0.114)

var cam := Vector2(0, CoastCamera.HOME_Y)
var light := Color.WHITE


func _init() -> void:
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("tint", TINT)
	material.set_shader_parameter("keep", KEEP)
	material.set_shader_parameter("fog", FOG)
	material.set_shader_parameter("fog_deep", FOG_DEEP)
	material.set_shader_parameter("surface", WaterView.SURFACE)
	material.set_shader_parameter("mid", WaterView.MID_WATER)
	material.set_shader_parameter("deep", WaterView.DEEP_WATER)


## The depth over which the water darkens, from the place's own depth.
func set_depth(depth: float) -> void:
	material.set_shader_parameter("depth", WaterView.span(depth))


func place_at(at: Vector2, lit: Color) -> void:
	cam = at
	light = lit
	material.set_shader_parameter("cam_y", cam.y)
	material.set_shader_parameter("light", light)
	queue_redraw()


## The waterline's row on screen, where the murk begins.
func top() -> float:
	return -cam.y


func _draw() -> void:
	var view := Nav.view()
	var from := maxf(0.0, top())
	# The desktop strip shifts the canvas up to the waterline, so the murk runs to the bottom of what is on screen.
	var bottom := view.y - get_canvas_transform().origin.y
	if bottom > from:
		draw_rect(Rect2(0, from, view.x, bottom - from), Color.WHITE)


## What a thing drawn in colour c, already in the hour's light, looks like `below` pixels under the waterline of a
## place `depth` deep, as the shader works it out.
static func colour(c: Color, below: float, depth: float, lit := Color.WHITE) -> Color:
	var l := Vector3(maxf(lit.r, 0.05), maxf(lit.g, 0.05), maxf(lit.b, 0.05))
	var v := Vector3(c.r, c.g, c.b) / l
	var w := WaterView.water_at(floorf(below), depth)
	var d := clampf(floorf(below) / WaterView.span(depth), 0.0, 1.0)
	var m := _mute(v).lerp(_mute(Vector3(w.r, w.g, w.b)), lerpf(FOG, FOG_DEEP, d))
	return Color(m.x * l.x, m.y * l.y, m.z * l.z, c.a)


## A colour with only `keep` of its own colour left, the rest grey, as the plants', pieces' and fishes' shaders drain it.
static func drain(c: Color, keep: float) -> Color:
	var v := Vector3(c.r, c.g, c.b)
	var g := v.dot(WEIGHTS)
	var m := Vector3(g, g, g).lerp(v, keep)
	return Color(m.x, m.y, m.z, c.a)


static func _mute(v: Vector3) -> Vector3:
	var t := Vector3(TINT.r, TINT.g, TINT.b)
	return (t * (v.dot(WEIGHTS) / t.dot(WEIGHTS))).lerp(v, KEEP)


## How a piece on the seabed is drawn before the murk: its shade, and the share of its colour it keeps.
static func shade_for(layer: Dictionary) -> Color:
	return PLANT if layer.get("sway", false) else PIECE


static func keep_for(layer: Dictionary) -> float:
	return PLANT_KEEP if layer.get("sway", false) else PIECE_KEEP
