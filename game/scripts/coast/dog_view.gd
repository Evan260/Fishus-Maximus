class_name DogView
extends Node2D
## The dog in the boat: it sits, barks at a bite, wags when a shoal passes below or when petted, and naps while the
## fisherman fishes on his own, sleeping on through passing fish and taking a stroke without waking. A heart floats up
## from it whenever it is petted, as in Farmus Maximus.

## Farmus's little heart, five pixels square.
static var HEART: ImageTexture = _heart_texture()

var screen: Node
var mood := "sit"
var _frames := {}
var _t := 0.0
var _happy_left := 0.0
var _bark_left := 0.0


static func _heart_texture() -> ImageTexture:
	var rows := [".X.X.", "XXXXX", "XXXXX", ".XXX.", "..X.."]
	var img := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in 5:
			if rows[y][x] == "X":
				img.set_pixel(x, y, Color(0.93, 0.36, 0.45))
	return ImageTexture.create_from_image(img)


func setup(s: Node) -> void:
	screen = s
	var breed := str(Game.state.get("dog", "hound"))
	for move in ["sit_east", "sleep_east", "happy_east"]:
		_frames[move] = Dogs.frames(breed, move)


func cheer(seconds := 2.5) -> void:
	if not _asleep():
		_happy_left = seconds


func bark() -> void:
	_bark_left = 0.8
	cheer(1.5)
	Audio.play("dog")


func pet() -> void:
	_heart()
	if _asleep():
		Audio.play("dog", -14.0, 0.8)
		return
	cheer(3.0)
	Audio.play("dog", -6.0, 1.2)


## How many hearts are floating up from it now.
func hearts() -> int:
	return get_children().filter(func(c): return c.has_meta("heart") and not c.is_queued_for_deletion()).size()


func _asleep() -> bool:
	return screen != null and screen.methods.idle


func _heart() -> void:
	var heart := Sprite2D.new()
	heart.texture = HEART
	heart.set_meta("heart", true)
	heart.position = Vector2(0, -42)
	add_child(heart)
	var t := heart.create_tween().set_parallel()
	t.tween_property(heart, "position:y", heart.position.y - 12.0, 1.0)
	t.tween_property(heart, "modulate:a", 0.0, 1.0).set_delay(0.4)
	t.chain().tween_callback(heart.queue_free)


## Where the dog is on screen, for petting it with a click.
func rect() -> Rect2:
	return Rect2(position + Vector2(-18, -40), Vector2(36, 42))


func _process(delta: float) -> void:
	_t += delta
	_happy_left = maxf(0.0, _happy_left - delta)
	_bark_left = maxf(0.0, _bark_left - delta)
	if _asleep():
		mood = "sleep_east"
		_happy_left = 0.0
	elif _happy_left > 0.0:
		mood = "happy_east"
	else:
		mood = "sit_east"
	var facing: float = screen.facing()
	position = screen.boat_screen_position() + screen.dog_seat().round()
	scale = Vector2(1.0 if facing > 0.0 else -1.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var frames: Array = _frames.get(mood, [])
	if frames.is_empty():
		return
	var tex: Texture2D = frames[int(_t * 8.0) % frames.size()]
	draw_texture(tex, -Vector2(tex.get_width() / 2.0, tex.get_height() - 8.0))
	if _bark_left > 0.0:
		draw_string(UiTheme.title_font(), Vector2(-2, -44), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.GOLD)
