class_name CatchCard
## The banner hung out when a fish is landed: a piece of undyed linen hung by rope ties from a plain wooden pole, a
## sea blue stripe painted round it, and the fish's name painted in ink over the fish itself, its weight and grade, and
## a note when it is new to the logbook or a legend, when a little starfish is also painted in its lower corners. It
## drops in and unfurls, its frayed foot sways, and it rolls up again after a few seconds or when clicked. It is drawn
## in the game's own pixels, one texel to a game pixel, at any interface size. The pictures are made by
## tools/art/make_banner.py.

const TOP := preload("res://assets/art/ui/banner_top.png")
const CLOTH := preload("res://assets/art/ui/banner_cloth.png")
const ROLL := preload("res://assets/art/ui/banner_roll.png")
const STAR := preload("res://assets/art/ui/banner_star.png")
const INK := preload("res://scripts/ui/ink.gdshader")
const SWAY := preload("res://scripts/ui/banner_sway.gdshader")

## The whole banner, and where the cloth hangs under the pole.
const SIZE := Vector2(184, 150)
const HANG := Vector2(7, 13)
## The cloth's rows from where its frayed foot starts swaying to its last thread.
const FRINGE := Vector2(131, 136)
## Where the starfish are painted, on the corners of the stripe at the cloth's foot.
const STAR_AT := [Vector2(1, 123), Vector2(162, 123)]
## The cloth inside its painted stripe, where the words and the fish are laid out.
const INSIDE := Rect2(8, 10, 154, 113)
## The room between the parts laid out on the cloth, and between the two lines of a long name.
const GAP := 4.0
const NAME_GAP := 4.0
## Where each font's capitals start below the top of its line and how tall they are: the name, the weight and the note.
const NAME_CAPS := Vector2(7, 10)
const LINE_CAPS := Vector2(4, 9)
const NOTE_CAPS := Vector2(4, 5)
## How long the banner stays unfurled, in seconds.
const SHOWN := 4.2

## The paint: the name in dark brown ink, the weight in a softer brown, and the note in the stripe's sea blue.
const NAME_INK := Color8(62, 40, 30)
const LINE_INK := Color8(92, 64, 44)
const NOTE_INK := Color8(48, 82, 98)
const FISH_SHADOW := Color(0.3, 0.22, 0.14, 0.22)

static var _open: Control


static func is_open() -> bool:
	return is_instance_valid(_open)


static func show_catch(fish: String, pounds: float, is_new: bool) -> void:
	if Nav.ui == null:
		return
	if is_open():
		_open.queue_free()
	var legend: bool = Data.fish[fish]["legend"]
	# The desktop strip is too short for the banner, so the catch gets one line instead.
	if Windowing.strip:
		var also := " A legend of the bay!" if legend else (" New in your logbook!" if is_new else "")
		Toast.say("%s, %s, %s.%s" % [Data.fish[fish]["name"], Units.weight(pounds), Catalog.grade(fish, pounds), also])
		return
	var card := Control.new()
	card.name = "CatchCard"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.set_meta("mark", is_new or legend)
	Nav.ui.add_child(card)
	_open = card
	card.set_anchors_preset(Control.PRESET_CENTER)
	# The interface may be drawn a step larger or smaller than the game, but the banner's pixels stay the scene's own.
	card.scale = Vector2.ONE * float(Nav.zoom) / float(Nav.ui_zoom)
	var shown := (SIZE * card.scale / 2.0).round()
	card.offset_left = -shown.x
	card.offset_top = -shown.y
	card.offset_right = card.offset_left + SIZE.x
	card.offset_bottom = card.offset_top + SIZE.y
	# The cloth hangs in a clipped strip under the pole, so that it unfurls downwards from it.
	var hang := Control.new()
	hang.name = "Hang"
	hang.clip_contents = true
	hang.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hang.position = HANG
	hang.size = Vector2(CLOTH.get_width(), 0)
	hang.set_meta("full", float(CLOTH.get_height()))
	card.add_child(hang)
	var cloth := _picture(hang, CLOTH, Vector2.ZERO)
	cloth.name = "Cloth"
	cloth.material = _sway(FRINGE.x, FRINGE.y, 1.0, 0.0, 0.9)
	if is_new or legend:
		for at in STAR_AT:
			_picture(hang, STAR, at).name = "Star"
	var note := "A LEGEND OF THE BAY!" if legend else ("NEW IN YOUR LOGBOOK" if is_new else "")
	_lay_out(hang, fish, pounds, note)
	var roll := _picture(card, ROLL, HANG)
	roll.name = "Roll"
	_picture(card, TOP, Vector2.ZERO)
	_unfurl(card, hang)
	card.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: card.queue_free())


## The banner's larger picture of a fish, from tools/art/make_banner_fish.py, or its small one from the logbook.
static func picture_of(fish: String) -> Texture2D:
	for path in ["res://assets/art/fish_banner/%s.png" % fish, "res://assets/art/fish/%s.png" % fish]:
		if ResourceLoader.exists(path):
			return load(path)
	return null


## The name, the fish, the weight and grade, and the note, one under another in the middle of the cloth.
static func _lay_out(hang: Control, fish: String, pounds: float, note: String) -> void:
	var name := _title(str(Data.fish[fish]["name"]).to_upper())
	var lines := name.count("\n") + 1
	var tex := picture_of(fish)
	var fish_tall := tex.get_height() if tex else 0
	var tall := NAME_CAPS.y * lines + NAME_GAP * (lines - 1) + GAP + fish_tall + GAP + LINE_CAPS.y
	if note != "":
		tall += GAP + NOTE_CAPS.y
	var y := INSIDE.position.y + floorf((INSIDE.size.y - tall) / 2.0)
	var title := _words(hang, name, "Title", y - NAME_CAPS.x, NAME_INK)
	title.add_theme_constant_override("line_spacing", int(NAME_CAPS.y + NAME_GAP) - _line_height(title))
	y += NAME_CAPS.y * lines + NAME_GAP * (lines - 1) + GAP
	if tex:
		var at := Vector2(roundf(INSIDE.get_center().x - tex.get_width() / 2.0), y)
		_picture(hang, tex, at + Vector2.ONE).modulate = FISH_SHADOW
		_picture(hang, tex, at).name = "Fish"
	y += fish_tall + GAP
	_words(hang, "%s, %s" % [Units.weight(pounds), Catalog.grade(fish, pounds)], "LightLabel", y - LINE_CAPS.x, LINE_INK)
	y += LINE_CAPS.y + GAP
	if note != "":
		_words(hang, note, "LightHeading", y - NOTE_CAPS.x, NOTE_INK)


static func _line_height(l: Label) -> int:
	return int(l.get_theme_font("font").get_height(l.get_theme_font_size("font_size")))


static func _sway(from_row: float, to_row: float, amount: float, phase: float, ripple: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SWAY
	m.set_shader_parameter("from_row", from_row)
	m.set_shader_parameter("to_row", to_row)
	m.set_shader_parameter("amount", amount)
	m.set_shader_parameter("phase", phase)
	m.set_shader_parameter("ripple", ripple)
	return m


## The banner drops in from a little above and unfurls, waits, then rolls up and fades.
static func _unfurl(card: Control, hang: Control) -> void:
	var y := card.position.y
	card.position.y = y - 18.0
	card.modulate.a = 0.0
	var full: float = hang.get_meta("full")
	var roll: Control = card.get_node("Roll")
	var unroll := func(down: float) -> void:
		hang.size.y = down
		roll.position.y = HANG.y + roundf(down) - 3.0
		roll.visible = down < FRINGE.x
	unroll.call(0.0)
	var tw := card.create_tween()
	card.set_meta("tween", tw)
	if Settings.reduced_motion:
		card.position.y = y
		card.modulate.a = 1.0
		unroll.call(full)
		(hang.get_node("Cloth") as CanvasItem).material = null
		tw.tween_interval(SHOWN)
		tw.tween_callback(card.queue_free)
		return
	tw.tween_property(card, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(card, "position:y", y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(unroll, 0.0, full, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(SHOWN)
	tw.tween_method(unroll, full, 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(card, "modulate:a", 0.0, 0.15)
	tw.tween_callback(card.queue_free)


## The fish's name on one line, or on two split at the space nearest the middle when one would be too wide.
static func _title(name: String) -> String:
	var across := UiTheme.title_font().get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.TITLE).x
	if across <= INSIDE.size.x or not " " in name:
		return name
	var best := -1
	for i in name.length():
		if name[i] == " " and (best < 0 or absi(i - name.length() / 2) < absi(best - name.length() / 2)):
			best = i
	return name.substr(0, best) + "\n" + name.substr(best + 1)


## A line of words painted across the cloth, centred inside the stripe, its top at `top`.
static func _words(hang: Control, text: String, variation: String, top: float, ink: Color) -> Label:
	var l := Ui.label(hang, text, variation)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = Vector2(INSIDE.position.x, top)
	l.size = Vector2(INSIDE.size.x, 0)
	var m := ShaderMaterial.new()
	m.shader = INK
	m.set_shader_parameter("ink", ink)
	l.material = m
	return l


static func _picture(parent: Control, tex: Texture2D, at: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = at
	parent.add_child(r)
	return r
