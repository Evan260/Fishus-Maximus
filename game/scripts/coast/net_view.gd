class_name NetView
extends Node2D
## The ring the cast net will land on, following the mouse, and the net falling where it was thrown.

const RADIUS := 22.0

var screen: Node
var aim := Vector2.ZERO
var thrown_at := Vector2.ZERO
var thrown_left := 0.0
var _net: Texture2D = load("res://assets/art/props/net.png") if ResourceLoader.exists("res://assets/art/props/net.png") else null


func _draw() -> void:
	var cam: Vector2 = screen.camera.cam
	if screen.methods.method == "net" and thrown_left <= 0.0:
		var c := (aim - cam).round()
		draw_arc(c, RADIUS, 0.0, TAU, 32, Color(1.0, 0.95, 0.8, 0.7), 1.0)
		draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 0.95, 0.8, 0.7))
	if thrown_left > 0.0:
		var c := (thrown_at - cam).round()
		var k := thrown_left / 0.8
		if _net:
			draw_set_transform(c, 0.0, Vector2.ONE * (0.8 + 0.4 * (1.0 - k)))
			draw_texture(_net, -_net.get_size() / 2.0, Color(1, 1, 1, k))
			draw_set_transform(Vector2.ZERO)
		draw_arc(c, RADIUS * (1.0 - k * 0.3), 0.0, TAU, 32, Color(0.9, 0.85, 0.7, k), 1.0)
