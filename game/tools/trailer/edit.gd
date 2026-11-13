extends Node
## The trailer's and the shorts' edits, cut from the recorded shots under the music; make_trailer.py renders one at a time.

const FPS := 30.0
## One beat of the music, in seconds; every cut lands on a beat.
const BEAT := 0.857
const MUSIC := "res://assets/audio/music/adventure_begins.ogg"
const MUSIC_DB := -2.0
## The sea, the gulls, the oars and the reel are recorded beside the music, so they are raised to be heard under it.
const SOUND_DB := 2.0
const INK := Color(0.29, 0.18, 0.14)
const CREAM := Color(0.99, 0.95, 0.86)
## Where the scroll's line of text sits, from the top of its picture, so it is centred on the sheet between the rolls.
const SCROLL_TEXT_TOP := -1
const SCROLL_TEXT_HEIGHT := 54
## The story, told in order: the boat left by an uncle, the first fish, the places along the bay and a wreck on its
## seabed, the logbook, the town, a bigger boat, the dog, the pond at home and the strip on the desktop. A shot plays
## from `from` seconds into its recording; a card is black with one line of text; `zoom` shows a shot a whole number of
## times larger around `centre`, in screen pixels.
const TRAILER := [
	{"card": "The Bay of Naples, AD 72.", "beats": 4},
	{"shot": "dawn", "from": 1.5, "beats": 6, "fade_in": 1.2},
	{"card": "Your uncle has left you
his old boat.", "beats": 3},
	{"shot": "cast", "from": 0.85, "beats": 16},
	{"card": "Sixty kinds of fish,
all ones the Romans knew.", "beats": 3},
	{"shot": "rocky", "from": 1.0, "beats": 3},
	{"shot": "capri", "from": 1.0, "beats": 3},
	{"shot": "misenum", "from": 2.0, "beats": 3},
	{"shot": "wreck", "from": 2.0, "beats": 4},
	{"shot": "night", "from": 1.5, "beats": 5},
	{"shot": "logbook", "from": 1.5, "beats": 4},
	{"card": "Sell your catch in town,
and save for a bigger boat.", "beats": 3},
	{"shot": "town", "from": 2.0, "beats": 3},
	{"shot": "boatwright", "from": 1.0, "beats": 3},
	{"shot": "sail", "from": 5.0, "beats": 4},
	{"shot": "dog", "from": 1.0, "beats": 3, "zoom": 2.0, "centre": Vector2(1000, 480)},
	{"card": "Keep the best alive
in your own pond.", "beats": 3},
	{"shot": "pond", "from": 2.0, "beats": 4},
	{"card": "Or let him fish on his own,
along the bottom of your screen.", "beats": 3},
	{"desk": "strip", "from": 2.0, "beats": 5},
	{"end": "endcard", "from": 1.0, "beats": 6, "dim": 0.45},
]

## A legend from the dark: the Senator comes up to the bait at night and is fought up onto the catch banner.
const LEGEND := [
	{"shot": "legend", "from": 12.2, "beats": 4, "caption": "something huge is\nunder my boat", "caption_at": 0.0},
	{"shot": "legend", "from": 15.6, "beats": 6, "caption": "it's a legend", "caption_at": 0.0},
	{"shot": "legend", "from": 20.7, "beats": 3, "caption": "older than\nthe town itself", "caption_at": 0.0},
	{"shot": "legend", "from": 24.0, "beats": 6, "caption": "the only one\nin the whole bay", "caption_at": 0.0},
	{"end": "endcard", "from": 1.0, "beats": 5, "dim": 0.45},
]
## The four boats, from the skiff to the big boat, each with the dog aboard.
const BOATS := [
	{"shot": "boat_skiff", "from": 1.5, "beats": 4, "caption": "my first\nfishing boat", "caption_at": 0.0},
	{"shot": "boat_fishing", "from": 1.5, "beats": 3, "caption": "my second", "caption_at": 0.0},
	{"shot": "boat_sailing", "from": 1.5, "beats": 3, "caption": "then a sail", "caption_at": 0.0},
	{"shot": "boat_big", "from": 1.5, "beats": 5, "caption": "and finally,\nthe big boat", "caption_at": 0.0},
	{"end": "endcard", "from": 1.0, "beats": 5, "dim": 0.45},
]
## No music: the harbour at dawn, a cast and its reel, rain on the cliffs, the pond fed and the harbour at night.
const ASMR := [
	{"shot": "dawn", "from": 1.5, "beats": 7, "caption": "turn your\nsound on", "caption_at": 0.0},
	{"shot": "cast", "from": 5.0, "beats": 8},
	{"shot": "rain", "from": 1.5, "beats": 6},
	{"shot": "pond", "from": 1.5, "beats": 5},
	{"shot": "night_harbour", "from": 1.5, "beats": 5},
	{"end": "endcard", "from": 1.0, "beats": 5, "dim": 0.45},
]
## Yes, you can pet the dog, and the other breeds, twice as large; the lapdog sits out of sight behind the boat's side.
const PETS := [
	{"shot": "pet_hound", "from": 1.4, "beats": 4, "zoom": 2.0, "centre": Vector2(740, 780), "caption": "yes, you can\npet the dog", "caption_at": 0.0},
	{"shot": "pet_molossian", "from": 1.4, "beats": 3, "zoom": 2.0, "centre": Vector2(740, 780), "caption": "and the mastiff", "caption_at": 0.0},
	{"shot": "pet_sighthound", "from": 1.4, "beats": 3, "zoom": 2.0, "centre": Vector2(740, 780), "caption": "and the sighthound", "caption_at": 0.0},
	{"shot": "pet_sheepdog", "from": 1.4, "beats": 4, "zoom": 2.0, "centre": Vector2(740, 780), "caption": "and the fluffy one", "caption_at": 0.0},
	{"end": "endcard", "from": 1.0, "beats": 5, "dim": 0.45},
]
## The boat along the bottom of a desktop, then close up on what it gets up to while its owner works.
const DESKTOP := [
	{"desk": "desk", "from": 1.0, "beats": 6, "caption": "I put a Roman\nfishing boat on\nmy desktop", "caption_at": 0.0},
	{"shot": "idle", "from": 2.4, "beats": 4, "caption": "it fishes\nwhile I work", "caption_at": 0.0},
	{"shot": "idle_dog", "from": 1.4, "beats": 4, "zoom": 2.0, "centre": Vector2(740, 780), "caption": "the dog sleeps\non the job", "caption_at": 0.0},
	{"desk": "desk", "from": 6.2, "beats": 4, "caption": "my boss has\nnot noticed yet", "caption_at": 0.0},
	{"end": "endcard", "from": 1.0, "beats": 5, "dim": 0.45},
]
## Down from the boat to the old wreck on the seabed, where a conger lives.
const WRECK := [
	{"shot": "wreck_dive", "from": 1.0, "beats": 4, "caption": "what's under\nmy boat?", "caption_at": 0.0},
	{"shot": "wreck_dive", "from": 4.43, "beats": 4, "caption": "keep going", "caption_at": 0.0},
	{"shot": "wreck_dive", "from": 7.86, "beats": 3, "caption": "a shipwreck", "caption_at": 0.0},
	{"shot": "wreck_dive", "from": 10.43, "beats": 4, "caption": "and something\nlives in it", "caption_at": 0.0},
	{"end": "endcard", "from": 1.0, "beats": 5, "dim": 0.45},
]
## The pond's named fish, which come to the front when the bell is rung, as the Romans' fish came to their names.
const BY_NAME := [
	{"shot": "pond_bell", "from": 1.0, "beats": 4, "caption": "Roman fish came\nwhen called by name", "caption_at": 0.0},
	{"shot": "pond_bell", "from": 4.43, "beats": 3, "caption": "so I tried it", "caption_at": 0.0},
	{"shot": "pond_bell", "from": 7.0, "beats": 5, "caption": "Hortensia, Aurata\nand Lupus", "caption_at": 0.0},
	{"end": "endcard", "from": 1.0, "beats": 5, "dim": 0.45},
]
## Each cut's frame, overlay pixel, caption size, rows in overlay pixels and music start, clear of a phone app's bars.
const CUTS := {
	"trailer": {"edit": TRAILER, "size": Vector2i(1920, 1080), "pixel": 4, "caption_size": 20, "caption_y": 20, "logo_y": 40, "scroll_y": 164, "music_from": 0.0},
	"legend": {"edit": LEGEND, "size": Vector2i(1080, 1920), "pixel": 3, "caption_size": 30, "caption_y": 70, "logo_y": 150, "scroll_y": 400, "music_from": 0.0},
	"first_vs_last": {"edit": BOATS, "size": Vector2i(1080, 1920), "pixel": 3, "caption_size": 30, "caption_y": 70, "logo_y": 150, "scroll_y": 400, "music_from": 0.0},
	"cozy_sounds": {"edit": ASMR, "size": Vector2i(1080, 1920), "pixel": 3, "caption_size": 30, "caption_y": 70, "logo_y": 150, "scroll_y": 400, "music_from": 0.0, "music": false, "sound_db": 6.0},
	"pet_the_dog": {"edit": PETS, "size": Vector2i(1080, 1920), "pixel": 3, "caption_size": 30, "caption_y": 70, "logo_y": 150, "scroll_y": 400, "music_from": 0.0},
	"on_my_desktop": {"edit": DESKTOP, "size": Vector2i(1080, 1920), "pixel": 3, "caption_size": 30, "caption_y": 70, "logo_y": 150, "scroll_y": 400, "music_from": 0.0},
	"shipwreck": {"edit": WRECK, "size": Vector2i(1080, 1920), "pixel": 3, "caption_size": 30, "caption_y": 70, "logo_y": 150, "scroll_y": 400, "music_from": 0.0},
	"fish_by_name": {"edit": BY_NAME, "size": Vector2i(1080, 1920), "pixel": 3, "caption_size": 30, "caption_y": 70, "logo_y": 150, "scroll_y": 400, "music_from": 0.0},
}

var _shots_dir := ""
var _cut: Dictionary = CUTS["trailer"]
var _edit: Array = TRAILER
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
var _caption: Label
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
		elif arg.begins_with("--cut="):
			_cut = CUTS[arg.trim_prefix("--cut=")]
	_edit = _cut["edit"]
	_size = Vector2(_cut["size"])
	var t := 0
	for seg in _edit:
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
	if _cut.get("music", true):
		_music.play(float(_cut["music_from"]) + from)
	# The first frame is laid out here, so a short's opening caption is already in the very first frame recorded.
	_process(0.0)
	_frame -= 1


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
	var area := _size / float(_cut["pixel"])
	_overlay = SubViewport.new()
	_overlay.size = Vector2i(area)
	_overlay.transparent_bg = true
	_overlay.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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
	# Phones are read at arm's length, so the shorts' captions are drawn three times the font's size, outlined in ink.
	_caption = _label(Vector2(10, float(_cut["caption_y"])), area.x - 20.0, 140, int(_cut["caption_size"]))
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_color_override("font_outline_color", INK)
	_caption.add_theme_constant_override("outline_size", 6)
	_logo = TextureRect.new()
	_logo.texture = _outside("logo.png")
	_logo.position = Vector2(roundf((area.x - _logo.texture.get_width()) / 2.0), float(_cut["logo_y"]))
	_overlay.add_child(_logo)
	_scroll = TextureRect.new()
	_scroll.texture = _outside("scroll.png")
	_scroll.position = Vector2(roundf((area.x - _scroll.texture.get_width()) / 2.0), float(_cut["scroll_y"]))
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
	var seg: Dictionary = _edit[k]
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
	_caption.visible = seg.has("caption")
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
	if seg.has("caption"):
		_caption.text = String(seg["caption"])
		# A caption opening a shot is there from its first frame; it fades out as the shot ends.
		var shown_at := float(seg.get("caption_at", 0.6))
		var appear := clampf((local - shown_at) / 0.4, 0.0, 1.0) if shown_at > 0.0 else 1.0
		_caption.modulate.a = minf(appear, clampf((length - local) / 0.3, 0.0, 1.0))
	if is_end:
		# The harbour darkens a little behind the logo, which settles in first, then the scroll unrolls beneath it.
		_shade.color.a = clampf(local / 0.8, 0.0, 1.0) * float(seg.get("dim", 0.0))
		_logo.modulate.a = clampf((local - 0.4) / 0.8, 0.0, 1.0)
		_logo.position.y = float(_cut["logo_y"]) + roundf(4.0 * (1.0 - _logo.modulate.a))
		var s := clampf((local - 1.6) / 0.6, 0.0, 1.0)
		_scroll.modulate.a = s
		_wishlist.modulate.a = s
	# Sound from each shot fades in and out quickly at its cuts, so cuts never click.
	_sound.volume_db = float(_cut.get("sound_db", SOUND_DB)) + linear_to_db(clampf(minf(local / 0.08, (length - local) / 0.08), 0.0001, 1.0))
