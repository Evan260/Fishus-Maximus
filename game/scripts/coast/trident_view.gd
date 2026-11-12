class_name TridentView
extends Node2D
## The lamp's warm light on the bow at night, which draws fish up to it, and the trident flying where it was aimed.

var screen: Node
var lit := false
var aim := Vector2.ZERO
var thrown_at := Vector2.ZERO
var thrown_left := 0.0
var _lamp: Texture2D = load("res://assets/art/props/lamp.png") if ResourceLoader.exists("res://assets/art/props/lamp.png") else null
var _spear: Sprite2D


func _ready() -> void:
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = glow
	if ResourceLoader.exists("res://assets/art/props/trident.png"):
		_spear = Sprite2D.new()
		_spear.texture = load("res://assets/art/props/trident.png")
		_spear.material = Pixels.look()
		_spear.visible = false
		add_child(_spear)


## Where the lamp's light falls in the world: under the bow, a little below the surface.
func light_at() -> Vector2:
	return screen.bow_reach() + Vector2(-8.0 * screen.facing(), 60.0)


func _draw() -> void:
	var cam: Vector2 = screen.camera.cam
	if lit:
		var bow: Vector2 = screen.bow_reach() + Vector2(-10.0 * screen.facing(), 8.0) - cam
		var flicker := 0.9 + 0.1 * sin(screen.time() * 13.0)
		for k in 6:
			var r := 70.0 - k * 11.0
			Pixels.disc(self, bow + Vector2(0, 30), r, Color(1.0, 0.7, 0.35, 0.035 * flicker))
		Pixels.disc(self, bow, 4.0, Color(1.0, 0.85, 0.5, 0.5 * flicker))
		if _lamp:
			draw_texture(_lamp, bow - (_lamp.get_size() / 2.0).floor() - Vector2(0, 4), Color(1, 1, 1, 0.9))
	if screen.methods.method == "trident" and lit and thrown_left <= 0.0:
		var c := aim - cam
		Pixels.line(self, c - Vector2(4, 0), c + Vector2(4, 0), Color(1, 0.9, 0.7, 0.6))
		Pixels.line(self, c - Vector2(0, 4), c + Vector2(0, 4), Color(1, 0.9, 0.7, 0.6))
	if _spear:
		_spear.visible = thrown_left > 0.0
	if thrown_left > 0.0 and _spear:
		var from: Vector2 = screen.bow_reach() - cam
		var to := thrown_at - cam
		var k := 1.0 - thrown_left / 0.35
		var angle := (to - from).angle()
		# The spear's point leads, so the picture sits behind the point it flies along.
		_spear.position = from.lerp(to, clampf(k, 0.0, 1.0)) - Vector2.from_angle(angle) * _spear.texture.get_width() / 2.0
		_spear.rotation = angle
