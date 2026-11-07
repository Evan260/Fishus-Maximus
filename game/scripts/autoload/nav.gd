extends Node
## Switches between screens with a short fade. The game is laid out for 480 by 270 and drawn at its own pixels in
## `port`, which is scaled up by a whole number to the window; the view grows a little past that to fill a window of
## another shape, so screens centre their scenery with `offset()` and the interface hangs from the view's edges.

signal screen_changed(screen: String)

const SIZE := Vector2(480, 270)
const SCREENS := {
	"title": "res://scripts/screens/title.gd",
	"coast": "res://scripts/coast/coast_screen.gd",
	"town": "res://scripts/town/town_screen.gd",
	"shore": "res://scripts/shore/shore_screen.gd",
	"map": "res://scripts/map/bay_map.gd",
}

## The game's own pixels: every screen, its interface and the fade are drawn here, at the view's size, and scaled up.
var port: SubViewport
## Drawn behind the game at the window's own resolution, so clouds there drift by fractions of a game pixel.
var sky: CanvasLayer
var world: Node2D
var ui_layer: CanvasLayer
## Window pixels per game pixel.
var zoom := 1
var _frame: SubViewportContainer
var ui: Control
var current: Node
var current_name := ""
var _fade: ColorRect
var _busy := false


func _ready() -> void:
	sky = CanvasLayer.new()
	sky.layer = -1
	add_child(sky)
	_frame = SubViewportContainer.new()
	_frame.name = "Game"
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_frame)
	port = SubViewport.new()
	port.size = SIZE
	port.transparent_bg = true
	port.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_frame.add_child(port)
	world = Node2D.new()
	world.name = "World"
	port.add_child(world)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 5
	port.add_child(ui_layer)
	ui = Control.new()
	ui.name = "UI"
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.theme = UiTheme.build()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ui)
	var top := CanvasLayer.new()
	top.layer = 50
	port.add_child(top)
	_fade = ColorRect.new()
	_fade.color = Color(0.06, 0.05, 0.06, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_fade)


## The view's size in game pixels: at least 480 by 270 tall, and as wide or tall as the window's shape allows.
func view() -> Vector2:
	return Vector2(port.size) if port else SIZE


## Shows the game at `size` game pixels, each `scale` window pixels wide, in the middle of the window, with the sky
## layer scaled to match.
func fit(size: Vector2i, scale: int) -> void:
	zoom = scale
	port.size = size
	_frame.size = Vector2(size)
	_frame.scale = Vector2(scale, scale)
	var room := Vector2(get_window().size) - Vector2(size * scale)
	_frame.position = (room / 2.0).floor()
	sky.transform = Transform2D(0.0, Vector2(scale, scale), 0.0, _frame.position)


## Where a screen laid out for 480 by 270 sits so that it is centred in the view.
func offset() -> Vector2:
	return ((view() - SIZE) / 2.0).round()


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
	for c in sky.get_children():
		c.queue_free()
	await get_tree().process_frame
	var s: Node = load(SCREENS[screen]).new()
	s.name = screen
	port.add_child(s)
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
