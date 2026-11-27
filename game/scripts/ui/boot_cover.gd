extends CanvasLayer
## The game's first frames repeat the loading screen where Godot drew it, then fade into the title once it is built, so
## the start never shows the empty window between them.

const PICTURE := preload("res://assets/art/ui/loading_screen.png")
const HOLD := 0.15
const FADE := 0.5


func _ready() -> void:
	layer = 100
	var cover := ColorRect.new()
	cover.color = ProjectSettings.get_setting("application/boot_splash/bg_color", Color.BLACK)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cover)
	var picture := TextureRect.new()
	picture.texture = PICTURE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(picture)
	# Godot's cover stretch scales the splash until it fills the window and centres it, so the picture lands on its pixels.
	var place := func():
		var zoom := maxf(cover.size.x / PICTURE.get_width(), cover.size.y / PICTURE.get_height())
		picture.size = PICTURE.get_size() * zoom
		picture.position = (cover.size - picture.size) / 2.0
	cover.resized.connect(place)
	place.call()
	Nav.screen_changed.connect(func(_screen): _fade_out(cover), CONNECT_ONE_SHOT)


func _fade_out(cover: Control) -> void:
	var fade := create_tween()
	fade.tween_interval(HOLD)
	fade.tween_property(cover, "modulate:a", 0.0, FADE)
	fade.tween_callback(queue_free)
