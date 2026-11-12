extends Node
## The trailer's edit: it plays the recorded shots in order with their own sound under the music, with black caption
## cards, the boat in the desktop strip laid over a desktop, and the end card. tools/trailer/make_trailer.py renders it.

const FPS := 30.0
## One beat of the music, in seconds; every cut lands on a beat.
const BEAT := 0.857
const MUSIC := "res://assets/audio/music/adventure_begins.ogg"
const MUSIC_DB := -2.0
## The sea, the gulls, the oars and the reel are recorded beside the music, so they are raised to be heard under it.
const SOUND_DB := 2.0
const INK := Color(0.29, 0.18, 0.14)
const CREAM := Color(0.99, 0.95, 0.86)
## Screen pixels to one pixel of the cards, the logo and the scroll, as the game draws its own pixels at 1080p.
const PIXEL := 4
const LOGO_Y := 40
const SCROLL_Y := 164
## Where the scroll's line of text sits, from the top of its picture, so it is centred on the sheet between the rolls.
const SCROLL_TEXT_TOP := -1
const SCROLL_TEXT_HEIGHT := 54
## The story, told in order: the boat left by an uncle, the first fish, the places along the bay, the logbook, the
## town, a bigger boat, the dog, the pond at home and the strip on the desktop. A shot plays from `from` seconds into
## its recording; a card is black with one line of text; `zoom` shows a shot a whole number of times larger around
## `centre`, in screen pixels.
const TRAILER := [
	{"card": "The Bay of Naples, AD 72.", "beats": 4},
	{"shot": "dawn", "from": 1.5, "beats": 6, "fade_in": 1.2},
	{"card": "Your uncle has left you\nhis old boat.", "beats": 3},
	{"shot": "cast", "from": 1.5, "beats": 5},
	{"shot": "cast", "from": 7.6, "beats": 5},
	{"shot": "cast", "from": 27.2, "beats": 5},
	{"card": "Sixty kinds of fish,\nall ones the Romans knew.", "beats": 3},
	{"shot": "rocky", "from": 1.0, "beats": 3},
	{"shot": "capri", "from": 1.0, "beats": 3},
	{"shot": "misenum", "from": 2.0, "beats": 3},
	{"shot": "night", "from": 1.5, "beats": 6},
	{"shot": "logbook", "from": 1.5, "beats": 5},
	{"card": "Sell your catch in town,\nand save for a bigger boat.", "beats": 3},
	{"shot": "town", "from": 2.0, "beats": 3},
	{"shot": "boatwright", "from": 1.0, "beats": 3},
	{"shot": "sail", "from": 5.0, "beats": 5},
	{"shot": "dog", "from": 1.0, "beats": 3, "zoom": 2.0, "centre": Vector2(1000, 480)},
	{"card": "Keep the best alive\nin your own pond.", "beats": 3},
	{"shot": "pond", "from": 2.0, "beats": 5},
	{"card": "Or let him fish on his own,\nalong the bottom of your screen.", "beats": 3},
	{"desk": "strip", "from": 2.0, "beats": 6},
	{"end": "endcard", "from": 1.0, "beats": 6, "dim": 0.45},
]

var _shots_dir := ""
var _size := Vector2(1920, 1080)
var _frame := 0
var _starts: Array = []
var _total_frames := 0
var _picture: TextureRect
var _texture: ImageTexture
var _strip: TextureRect
var _strip_texture: ImageTexture
var _overlay: SubViewport
var _black: ColorRect
var _shade: ColorRect
var _card_text: Label
var _logo: TextureRect
var _scroll: TextureRect
var _wishlist: Label
var _music: AudioStreamPlayer
var _sound: AudioStreamPlayer
var _current := -1
## A desktop's screenshot for the strip to sit along the bottom of, and how tall its taskbar is.
var _desktop: Texture2D
var _taskbar := 0


func _ready() -> void:
	# The game's own systems start with this scene too: nothing may save, and only the trailer's own sound plays.
	Saves.enabled = false
	RenderingServer.set_default_clear_color(Color.BLACK)
	for bus in ["Music", "Effects"]:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), true)
	var from := 0.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		elif arg.begins_with("--from="):
			from = float(arg.trim_prefix("--from="))
		elif arg.begins_with("--desktop="):
			var shot := Image.load_from_file(arg.trim_prefix("--desktop="))
			if shot:
				_desktop = ImageTexture.create_from_image(shot)
		elif arg.begins_with("--taskbar="):
			_taskbar = int(arg.trim_prefix("--taskbar="))
	var t := 0
	for seg in TRAILER:
		_starts.append(t)
		t += int(round(float(seg["beats"]) * BEAT * FPS))
	_total_frames = t
	_build()
	_music = AudioStreamPlayer.new()
	_music.stream = load(MUSIC)
	add_child(_music)
	_sound = AudioStreamPlayer.new()
	add_child(_sound)
	# A preview can start part way through, to look at one moment without rendering the whole trailer.
	_frame = int(from * FPS)
	_music.play(from)


## A picture kept beside the scripts that make it, outside the game's own files.
static func _outside(name: String) -> Texture2D:
	var path := ProjectSettings.globalize_path("res://").path_join("../tools/trailer/" + name)
	return ImageTexture.create_from_image(Image.load_from_file(path))


func _build() -> void:
	_texture = ImageTexture.create_from_image(Image.create(int(_size.x), int(_size.y), false, Image.FORMAT_RGB8))
	_picture = TextureRect.new()
	_picture.texture = _texture
	_picture.size = _size
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_picture)
	_strip = TextureRect.new()
	_strip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_strip)
	# Cards and the end card are drawn in big pixels and scaled up, like the game.
	var area := _size / float(PIXEL)
	_overlay = SubViewport.new()
	_overlay.size = Vector2i(area)
	_overlay.transparent_bg = true
	_overlay.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_overlay)
	var shown := TextureRect.new()
	shown.texture = _overlay.get_texture()
	shown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shown.size = _size
	shown.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(shown)
	_shade = ColorRect.new()
	_shade.color = Color(0.05, 0.04, 0.06, 0.0)
	_shade.size = area
	_overlay.add_child(_shade)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.size = area
	_overlay.add_child(_black)
	# The text is the interface's own pixel font at twice its size, still whole pixels, to read at a glance.
	_card_text = _label(Vector2(20, area.y / 2.0 - 40.0), area.x - 40.0, 80, UiTheme.text_size() * 2)
	_logo = TextureRect.new()
	_logo.texture = _outside("logo.png")
	_logo.position = Vector2(roundf((area.x - _logo.texture.get_width()) / 2.0), LOGO_Y)
	_overlay.add_child(_logo)
	_scroll = TextureRect.new()
	_scroll.texture = _outside("scroll.png")
	_scroll.position = Vector2(roundf((area.x - _scroll.texture.get_width()) / 2.0), SCROLL_Y)
	_overlay.add_child(_scroll)
	_wishlist = _label(_scroll.position + Vector2(0, SCROLL_TEXT_TOP), _scroll.texture.get_width(), SCROLL_TEXT_HEIGHT, UiTheme.text_size() * 2)
	_wishlist.text = "Wishlist now on Steam"
	_wishlist.add_theme_color_override("font_color", INK)


func _label(at: Vector2, width: float, height: float, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", UiTheme.body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", CREAM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = at
	l.size = Vector2(width, height)
	_overlay.add_child(l)
	return l


func _process(_delta: float) -> void:
	if _frame >= _total_frames:
		get_tree().quit()
		return
	var k := _starts.size() - 1
	while _starts[k] > _frame:
		k -= 1
	var seg: Dictionary = TRAILER[k]
	var local := float(_frame - _starts[k]) / FPS
	var length := float(seg["beats"]) * BEAT
	if k != _current:
		_current = k
		_start_segment(seg)
	_draw_segment(seg, local, length)
	# The music fades away over the end card's last seconds.
	var left := float(_total_frames - _frame) / FPS
	_music.volume_db = MUSIC_DB + linear_to_db(clampf(left / 3.0, 0.0001, 1.0))
	_frame += 1


func _shot_name(seg: Dictionary) -> String:
	return String(seg.get("shot", seg.get("end", seg.get("desk", ""))))


func _start_segment(seg: Dictionary) -> void:
	_sound.stop()
	var name := _shot_name(seg)
	if name == "":
		return
	var wav := _shots_dir.path_join(name).path_join("f.wav")
	if FileAccess.file_exists(wav):
		_sound.stream = AudioStreamWAV.load_from_file(wav)
		_sound.play(float(seg["from"]))


func _draw_segment(seg: Dictionary, local: float, length: float) -> void:
	var is_card := seg.has("card")
	var is_end := seg.has("end")
	var is_desk := seg.has("desk")
	_black.visible = is_card
	_card_text.visible = is_card
	_logo.visible = is_end
	_scroll.visible = is_end
	_wishlist.visible = is_end
	_shade.visible = is_end
	_strip.visible = is_desk
	if is_card:
		_card_text.text = String(seg["card"])
		# The line fades in and out on the black, so cards never jump.
		_card_text.modulate.a = clampf(minf(local / 0.35, (length - local) / 0.35), 0.0, 1.0)
		return
	var index := int(round((float(seg["from"]) + local) * FPS))
	var path := _shots_dir.path_join(_shot_name(seg)).path_join("f%08d.png" % index)
	_picture.texture = _desktop if is_desk and _desktop else _texture
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if is_desk:
			img.convert(Image.FORMAT_RGBA8)
			# The strip's frames are sized as it ran; it sits centred along the bottom of the desktop, above its taskbar.
			if _strip_texture == null:
				_strip_texture = ImageTexture.create_from_image(img)
				_strip.texture = _strip_texture
				_strip.position = Vector2(roundf((_size.x - img.get_width()) / 2.0), _size.y - _taskbar - img.get_height())
			_strip_texture.update(img)
		else:
			img.convert(Image.FORMAT_RGB8)
			_texture.update(img)
	# A small moment is shown a whole number of times larger, so the pixels stay square.
	var zoom := float(seg.get("zoom", 1.0))
	var centre: Vector2 = seg.get("centre", _size / 2.0)
	_picture.scale = Vector2(zoom, zoom)
	_picture.position = (_size / 2.0 - centre * zoom).round().clamp(_size * (1.0 - zoom), Vector2.ZERO)
	var fade_in := float(seg.get("fade_in", 0.0))
	_picture.modulate = Color.WHITE * (clampf(local / fade_in, 0.0, 1.0) if fade_in > 0.0 else 1.0)
	_picture.modulate.a = 1.0
	if is_end:
		# The harbour darkens a little behind the logo, which settles in first, then the scroll unrolls beneath it.
		_shade.color.a = clampf(local / 0.8, 0.0, 1.0) * float(seg.get("dim", 0.0))
		_logo.modulate.a = clampf((local - 0.4) / 0.8, 0.0, 1.0)
		_logo.position.y = LOGO_Y + roundf(4.0 * (1.0 - _logo.modulate.a))
		var s := clampf((local - 1.6) / 0.6, 0.0, 1.0)
		_scroll.modulate.a = s
		_wishlist.modulate.a = s
	# Sound from each shot fades in and out quickly at its cuts, so cuts never click.
	_sound.volume_db = SOUND_DB + linear_to_db(clampf(minf(local / 0.08, (length - local) / 0.08), 0.0001, 1.0))
