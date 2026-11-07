extends Node
## Switches between screens with a short fade. The game is laid out for 480 by 270 and the window scales it up by a
## whole number; the view grows a little past that to fill a window of another shape, so screens centre their scenery
## with `offset()` and the interface hangs from the view's edges.

signal screen_changed(screen: String)

const SIZE := Vector2(480, 270)
const SCREENS := {
	"title": "res://scripts/screens/title.gd",
	"coast": "res://scripts/coast/coast_screen.gd",
	"town": "res://scripts/town/town_screen.gd",
	"shore": "res://scripts/shore/shore_screen.gd",
	"map": "res://scripts/map/bay_map.gd",
}

var world: Node2D
var ui_layer: CanvasLayer
var ui: Control
var current: Node
var current_name := ""
var _fade: ColorRect
var _busy := false


func _ready() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 5
	add_child(ui_layer)
	ui = Control.new()
	ui.name = "UI"
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.theme = UiTheme.build()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ui)
	var top := CanvasLayer.new()
	top.layer = 50
	add_child(top)
	_fade = ColorRect.new()
	_fade.color = Color(0.06, 0.05, 0.06, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_fade)


## The view's size in game pixels: at least 480 by 270 tall, and as wide or tall as the window's shape allows.
func view() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else SIZE


## Where a screen laid out for 480 by 270 sits so that it is centred in the view.
func offset() -> Vector2:
	return ((view() - SIZE) / 2.0).round()


## Window pixels per game pixel, for turning a point in the game into one on the screen.
func scale_factor() -> int:
	var s := DisplayServer.window_get_size()
	return maxi(1, mini(int(s.x / SIZE.x), int(s.y / SIZE.y)))


func go(screen: String, args: Dictionary = {}) -> void:
	if _busy or not SCREENS.has(screen):
		return
	_busy = true
	if Saves.slot > 0 and not Game.state.is_empty():
		Saves.save()
	if current:
		var out := create_tween()
		out.tween_property(_fade, "color:a", 1.0, 0.14)
		await out.finished
		current.queue_free()
		current = null
	for c in world.get_children():
		c.queue_free()
	for c in ui.get_children():
		c.queue_free()
	await get_tree().process_frame
	var s: Node = load(SCREENS[screen]).new()
	s.name = screen
	add_child(s)
	current = s
	current_name = screen
	if not Game.state.is_empty():
		Game.state["_ashore"] = screen != "coast"
	if s.has_method("enter"):
		s.enter(args)
	screen_changed.emit(screen)
	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, 0.2)
	await back.finished
	_busy = false
