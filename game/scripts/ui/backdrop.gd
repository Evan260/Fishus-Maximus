class_name Backdrop
extends Node2D
## A screen's painted picture with mirror images of it laid round all four sides, so a view wider or taller than the
## picture carries on past its edges without a seam.

var texture: Texture2D


## With `around_only` the middle copy is left out, for a picture that is drawn on its own over the backdrop.
func _init(tex: Texture2D, around_only := false) -> void:
	texture = tex
	var size := tex.get_size()
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if around_only and dx == 0 and dy == 0:
				continue
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.flip_h = dx != 0
			s.flip_v = dy != 0
			s.position = Vector2(dx * size.x, dy * size.y)
			add_child(s)
