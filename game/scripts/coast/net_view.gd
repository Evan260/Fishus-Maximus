class_name NetView
extends Node2D
## The ring the cast net will land on, following the mouse, and the net falling where it was thrown.

const RADIUS := 22.0

var screen: Node
var aim := Vector2.ZERO
var thrown_at := Vector2.ZERO
var thrown_left := 0.0
var _net: Sprite2D


func _ready() -> void:
	if ResourceLoader.exists("res://assets/art/props/net.png"):
		_net = Sprite2D.new()
		_net.texture = load("res://assets/art/props/net.png")
		_net.material = Pixels.look()
		_net.show_behind_parent = true
		_net.visible = false
		add_child(_net)


func _draw() -> void:
	var cam: Vector2 = screen.camera.cam
	if screen.methods.method == "net" and thrown_left <= 0.0:
		var c := aim - cam
		Pixels.ring(self, c, RADIUS, Color(1.0, 0.95, 0.8, 0.7))
		draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 0.95, 0.8, 0.7))
	if _net:
		_net.visible = thrown_left > 0.0
	if thrown_left > 0.0:
		var c := thrown_at - cam
		var k := thrown_left / 0.8
		if _net:
			_net.position = c
			_net.scale = Vector2.ONE * (0.8 + 0.4 * (1.0 - k))
			_net.modulate.a = k
		Pixels.ring(self, c, RADIUS * (1.0 - k * 0.3), Color(0.9, 0.85, 0.7, k))
