class_name Backdrop
extends Node2D
## A screen's painted picture over a plain colour that fills the rest of the view. On each side where the view
## reaches past the picture, the picture's edge fades into that colour over a few of its pixels, so it never ends in
## a straight cut.

## The most picture pixels an edge fades over.
const FADE := 20.0
const SHADER := preload("res://scripts/ui/backdrop.gdshader")

var texture: Texture2D
var colour: Color
var _view := Rect2()
var _picture: Sprite2D


func _init(tex: Texture2D, plain: Color) -> void:
	texture = tex
	colour = plain
	_picture = Sprite2D.new()
	_picture.texture = tex
	_picture.centered = false
	_picture.material = ShaderMaterial.new()
	_picture.material.shader = SHADER
	_picture.material.set_shader_parameter("plain", plain)
	_picture.material.set_shader_parameter("size", tex.get_size())
	add_child(_picture)
	fit(Rect2(Vector2.ZERO, tex.get_size()))


## Fits the backdrop to the view, given in the picture's own pixels.
func fit(view: Rect2) -> void:
	_view = view
	var size := texture.get_size()
	var room := Vector4(-view.position.x, -view.position.y, view.end.x - size.x, view.end.y - size.y)
	_picture.material.set_shader_parameter("fade", fades(room))
	queue_redraw()


## How many pixels each edge (left, top, right, bottom) fades over, given how far the view reaches past it.
static func fades(room: Vector4) -> Vector4:
	return Vector4(clampf(room.x, 0.0, FADE), clampf(room.y, 0.0, FADE), clampf(room.z, 0.0, FADE), clampf(room.w, 0.0, FADE))


func _draw() -> void:
	draw_rect(_view, colour)
