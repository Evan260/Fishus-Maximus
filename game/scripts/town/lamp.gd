class_name Lamp
extends Node2D
## A warm light hanging in a picture ashore, as Farmus's lamps are: it brightens the picture round it, and its soft
## halo glows over the flame. Its owner sets how brightly it burns.

const SIZE := 64
## The light mask bit of all the lamp lights; whatever keeps its own colour, as the gold outline does, leaves it off.
const LIT := 1

static var _light_tex: Texture2D
static var _halo_tex: Texture2D

var radius := 40.0
var colour := Color(1.0, 0.7, 0.36)
## How strong the light is when fully lit.
var power := 1.0
var halo_size := 9.0
var light: PointLight2D
var halo: Sprite2D


func _init() -> void:
	light = PointLight2D.new()
	light.texture = _light_texture()
	light.color = colour
	light.energy = 0.0
	light.visible = false
	light.range_item_cull_mask = LIT
	add_child(light)
	halo = Sprite2D.new()
	halo.texture = _halo_texture()
	halo.modulate = Color(colour, 0.0)
	halo.light_mask = 0
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = add
	add_child(halo)


func _ready() -> void:
	light.texture_scale = radius * 2.0 / SIZE
	light.color = colour
	halo.scale = Vector2.ONE * halo_size * 2.0 / SIZE


## 0 is out, 1 is fully lit.
func shine(amount: float) -> void:
	light.visible = amount > 0.01
	light.energy = amount * power
	halo.modulate = Color(colour, amount * 0.55)


## A round light that fades smoothly from the middle to nothing at its edge.
static func _light_texture() -> Texture2D:
	if _light_tex == null:
		_light_tex = _radial([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0)], [0.0, 0.3, 0.65, 1.0])
	return _light_tex


static func _halo_texture() -> Texture2D:
	if _halo_tex == null:
		_halo_tex = _radial([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)], [0.0, 0.35, 1.0])
	return _halo_tex


static func _radial(colours: Array, offsets: Array) -> Texture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray(colours)
	g.offsets = PackedFloat32Array(offsets)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = SIZE
	t.height = SIZE
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t
