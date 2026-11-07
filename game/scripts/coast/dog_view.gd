class_name DogView
extends Node2D
## The dog in the boat: it sits, barks at a bite, wags when a shoal passes below or when petted, and naps while the
## fisherman fishes on his own.

var screen: Node
var mood := "sit"
var _frames := {}
var _t := 0.0
var _happy_left := 0.0
var _bark_left := 0.0


func setup(s: Node) -> void:
	screen = s
	var breed := str(Game.state.get("dog", "hound"))
	for move in ["sit_east", "sleep_east", "happy_east"]:
		_frames[move] = Dogs.frames(breed, move)


func cheer(seconds := 2.5) -> void:
	_happy_left = seconds


func bark() -> void:
	_bark_left = 0.8
	cheer(1.5)
	Audio.play("dog")


func pet() -> void:
	cheer(3.0)
	Audio.play("dog", -6.0, 1.2)


## Where the dog is on screen, for petting it with a click.
func rect() -> Rect2:
	return Rect2(position + Vector2(-18, -40), Vector2(36, 42))


func _process(delta: float) -> void:
	_t += delta
	_happy_left = maxf(0.0, _happy_left - delta)
	_bark_left = maxf(0.0, _bark_left - delta)
	if _happy_left > 0.0:
		mood = "happy_east"
	elif screen.methods.idle:
		mood = "sleep_east"
	else:
		mood = "sit_east"
	var facing: float = screen.facing()
	position = (screen.boat_screen_position() + screen.dog_seat()).round()
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
