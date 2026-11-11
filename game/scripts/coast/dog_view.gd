class_name DogView
extends Node2D
## The dog in the boat: it sits, barks at a bite, wags when a shoal passes below or when petted, and naps while the
## fisherman fishes on his own, sleeping on through passing fish and taking a stroke without waking. A heart floats up
## from it whenever it is petted, as in Farmus Maximus.

## Farmus's little heart, five pixels square.
static var HEART: ImageTexture = _heart_texture()

## Sitting down and lying down are painted from standing, so they play once and then hold their last frame.
const SETTLES := ["sit_east", "sleep_east"]
const FPS := 8.0
## How many rows of a lying dog's body stay tucked behind the gunwale.
const TUCK := 3.0

var screen: Node
var mood := "sit_east"
var _frames := {}
## Seconds since the dog changed what it is doing.
var _since := 0.0
## How far below its seat the dog is drawn; the hull's near side hides the rest, and the keel curves up above its feet.
var cut := INF
var _happy_left := 0.0
var _bark_left := 0.0
static var _lowest := {}


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
		_frames[move] = Dogs.frames(breed, move, str(Game.state.get("dog_coat", "golden")))


func cheer(seconds := 2.5) -> void:
	if not _asleep():
		_happy_left = seconds


func bark() -> void:
	if _asleep():
		return
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


func frames_of(move: String) -> Array:
	return _frames.get(move, [])


## The frame it shows now: wagging goes round and round, while sitting or lying down stops once it is done.
func frame() -> int:
	var count := frames_of(mood).size()
	if count == 0:
		return 0
	var i := int(_since * FPS)
	return mini(i, count - 1) if mood in SETTLES else i % count


## Where the dog is on screen, for petting it with a click.
func rect() -> Rect2:
	return Rect2(position + Vector2(-18, -40), Vector2(36, 42))


func _process(delta: float) -> void:
	_since += delta
	_happy_left = maxf(0.0, _happy_left - delta)
	_bark_left = maxf(0.0, _bark_left - delta)
	var was := mood
	if _asleep():
		mood = "sleep_east"
		_happy_left = 0.0
	elif _happy_left > 0.0:
		mood = "happy_east"
	else:
		mood = "sit_east"
	if mood != was:
		_since = 0.0
	var facing: float = screen.facing()
	position = screen.boat_screen_position() + screen.dog_seat().round()
	cut = screen.dog_cut() - roundf(screen.dog_seat().y)
	scale = Vector2(1.0 if facing > 0.0 else -1.0, 1.0)
	queue_redraw()


## The lowest row of a frame with any of the dog in it.
static func _lowest_row(tex: Texture2D) -> int:
	if not _lowest.has(tex):
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		var y := img.get_height() - 1
		while y > 0 and not range(img.get_width()).any(func(x): return img.get_pixel(x, y).a > 0.5):
			y -= 1
		_lowest[tex] = y
	return _lowest[tex]


## The row, from the dog's seat, below which the boat's near side hides it.
func _hidden_from() -> float:
	return minf(cut, screen.dog_rail() - roundf(screen.dog_seat().y)) if screen else cut


## How far up the dog is drawn as it lies down, so its body comes to rest just over the gunwale instead of below it.
func lift() -> float:
	var frames: Array = frames_of(mood)
	if mood != "sleep_east" or frames.is_empty() or screen == null:
		return 0.0
	var last: Texture2D = frames[frames.size() - 1]
	var bottom := _lowest_row(last) + 1.0 - (last.get_height() - 8.0)
	var k := clampf(float(frame() + 1) / frames.size(), 0.0, 1.0)
	return minf(0.0, roundf((_hidden_from() + TUCK - bottom) * k))


## How many rows of the dog show over the boat's near side now.
func shown_rows() -> int:
	var frames: Array = frames_of(mood)
	if frames.is_empty():
		return 0
	var tex: Texture2D = frames[frame()]
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var top := -(tex.get_height() - 8.0) + lift()
	var n := 0
	for y in img.get_height():
		if top + y < _hidden_from() and range(img.get_width()).any(func(x): return img.get_pixel(x, y).a > 0.5):
			n += 1
	return n


func _draw() -> void:
	var frames: Array = frames_of(mood)
	if frames.is_empty():
		return
	var tex: Texture2D = frames[frame()]
	var top := -Vector2(tex.get_width() / 2.0, tex.get_height() - 8.0) + Vector2(0, lift())
	var rows := clampf(cut - top.y, 0.0, tex.get_height())
	draw_texture_rect_region(tex, Rect2(top, Vector2(tex.get_width(), rows)), Rect2(0, 0, tex.get_width(), rows))
	if _bark_left > 0.0:
		draw_string(UiTheme.name_font(), Vector2(-2, -44), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.GOLD)
