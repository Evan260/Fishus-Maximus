class_name CatchCard
## The banner hung out when a fish is landed: a painted Roman vexillum, a gilded eagle over a wooden crossbar with gold
## tassels, and a crimson cloth fringed in gold carrying the fish's name in gilt letters, the fish on a marble tablet
## with handles, its weight and grade, and a note when it is new to the logbook or a legend, when a golden laurel wreath
## also hangs round the eagle's ball. It drops in and unfurls, sways gently, and rolls up again after a few seconds or
## when clicked. The pictures are made by tools/art/make_banner.py.

const TOP := preload("res://assets/art/ui/banner_top.png")
const CLOTH := preload("res://assets/art/ui/banner_cloth.png")
const ROLL := preload("res://assets/art/ui/banner_roll.png")
const PLAQUE := preload("res://assets/art/ui/banner_plaque.png")
const WREATH := preload("res://assets/art/ui/banner_wreath.png")
const TASSELS := [preload("res://assets/art/ui/banner_tassel_left.png"), preload("res://assets/art/ui/banner_tassel_right.png")]
const GILT := preload("res://scripts/ui/gilt.gdshader")
const SWAY := preload("res://scripts/ui/banner_sway.gdshader")

## The whole banner, and where the cloth hangs under the crossbar.
const SIZE := Vector2(232, 188)
const HANG := Vector2(16, 44)
## The cloth's rows from where its fringe starts swaying to its foot.
const FRINGE := Vector2(128, 143)
## Where each tassel hangs (its picture has room to sway either side) and where the wreath hangs round the eagle's ball.
const TASSEL_AT := [Vector2(1, 44), Vector2(217, 44)]
const WREATH_AT := Vector2(102, 11)
## The cloth inside its gold border, where the words and the tablet are laid out.
const INSIDE := Rect2(9, 4, 184, 118)
## The tablet's marble face in the tablet's own pixels, and the most a small fish is enlarged on it. A fish is as wide
## as the face at most but may stand over the frame above and below it, as a trophy mounted in front of its tablet.
const FACE := Rect2(18, 4, 116, 52)
const MOST := 4
## The room between the parts laid out on the cloth, and between the two lines of a long name.
const GAP := 4.0
const NAME_GAP := 4.0
## Where each font's capitals start below the top of its line and how tall they are: the name, the weight and the note.
const NAME_CAPS := Vector2(7, 10)
const LINE_CAPS := Vector2(4, 9)
const NOTE_CAPS := Vector2(4, 5)
## The widest the fish's name may be on one line before it is split onto two.
const NAME_WIDTH := 180.0
## How long the banner stays unfurled, in seconds.
const SHOWN := 4.2

const SHADOW := Color8(64, 14, 14)
const FISH_SHADOW := Color(0.36, 0.2, 0.12, 0.3)

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
		Toast.say("%s, %s lb, %s.%s" % [Data.fish[fish]["name"], pounds_text(pounds), Catalog.grade(fish, pounds), also])
		return
	var card := Control.new()
	card.name = "CatchCard"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.set_meta("wreath", is_new or legend)
	Nav.ui.add_child(card)
	_open = card
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -SIZE.x / 2.0
	card.offset_right = SIZE.x / 2.0
	card.offset_top = -SIZE.y / 2.0
	card.offset_bottom = SIZE.y / 2.0
	# The cloth hangs in a clipped strip under the crossbar, so that it unfurls downwards from it.
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
	var note := "A LEGEND OF THE BAY!" if legend else ("NEW IN YOUR LOGBOOK" if is_new else "")
	_lay_out(hang, fish, pounds, note)
	var roll := _picture(card, ROLL, HANG)
	roll.name = "Roll"
	_picture(card, TOP, Vector2.ZERO)
	for i in TASSELS.size():
		var t := _picture(card, TASSELS[i], TASSEL_AT[i])
		t.material = _sway(0.0, TASSELS[i].get_height(), 1.6, i * 2.3, 0.0)
	if is_new or legend:
		_picture(card, WREATH, WREATH_AT).name = "Wreath"
	_unfurl(card, hang)
	card.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: card.queue_free())


static func pounds_text(lb: float) -> String:
	return ("%.2f" % lb) if lb < 1.0 else ("%.1f" % lb)


## The name, the tablet with the fish, the weight and grade, and the note, one under another in the middle of the cloth.
static func _lay_out(hang: Control, fish: String, pounds: float, note: String) -> void:
	var name := _title(str(Data.fish[fish]["name"]).to_upper())
	var lines := name.count("\n") + 1
	var tall := NAME_CAPS.y * lines + NAME_GAP * (lines - 1) + GAP + PLAQUE.get_height() + GAP + LINE_CAPS.y
	if note != "":
		tall += GAP + NOTE_CAPS.y
	var y := INSIDE.position.y + floorf((INSIDE.size.y - tall) / 2.0)
	var title := _words(hang, name, "Title", y - NAME_CAPS.x)
	title.add_theme_constant_override("line_spacing", int(NAME_CAPS.y + NAME_GAP) - _line_height(title))
	_gild(title, NAME_CAPS, NAME_CAPS.y + NAME_GAP)
	y += NAME_CAPS.y * lines + NAME_GAP * (lines - 1) + GAP
	_tablet(hang, fish, y)
	y += PLAQUE.get_height() + GAP
	_words(hang, "%s lb, %s" % [pounds_text(pounds), Catalog.grade(fish, pounds)], "LightLabel", y - LINE_CAPS.x)
	y += LINE_CAPS.y + GAP
	if note != "":
		var l := _words(hang, note, "LightHeading", y - NOTE_CAPS.x)
		_gild(l, NOTE_CAPS, float(_line_height(l)))


static func _line_height(l: Label) -> int:
	return int(l.get_theme_font("font").get_height(l.get_theme_font_size("font_size")))


## The rows of each line a gilt letter shades down, drawn in white for the shader to gild.
static func _gild(l: Label, caps: Vector2, step: float) -> void:
	l.add_theme_color_override("font_color", Color.WHITE)
	var m := ShaderMaterial.new()
	m.shader = GILT
	m.set_shader_parameter("cap_top", caps.x)
	m.set_shader_parameter("cap_height", caps.y)
	m.set_shader_parameter("line_step", step)
	l.material = m


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
	card.position.y = y - 24.0
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
	if across <= NAME_WIDTH or not " " in name:
		return name
	var best := -1
	for i in name.length():
		if name[i] == " " and (best < 0 or absi(i - name.length() / 2) < absi(best - name.length() / 2)):
			best = i
	return name.substr(0, best) + "\n" + name.substr(best + 1)


## A line of words across the cloth, centred, its top at `top`.
static func _words(hang: Control, text: String, variation: String, top: float) -> Label:
	var l := Ui.label(hang, text, variation)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_shadow_color", SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.position = Vector2(0, top)
	l.size = Vector2(CLOTH.get_width(), 0)
	return l


## The marble tablet with the fish laid on its face at the most whole pixels per pixel that fit, over a soft shadow.
static func _tablet(hang: Control, fish: String, top: float) -> void:
	var box := Control.new()
	box.name = "Tablet"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size = PLAQUE.get_size()
	box.position = Vector2(roundf((CLOTH.get_width() - PLAQUE.get_width()) / 2.0), top)
	hang.add_child(box)
	_picture(box, PLAQUE, Vector2.ZERO)
	var path := "res://assets/art/fish/%s.png" % fish
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	var room := Vector2(FACE.size.x, PLAQUE.get_height())
	var k := clampf(minf(floorf(room.x / tex.get_width()), floorf(room.y / tex.get_height())), 1.0, MOST)
	var at := (FACE.position + (FACE.size - tex.get_size() * k) / 2.0).round()
	var shade := _scaled(box, tex, k, at + Vector2.ONE * maxf(1.0, floorf(k / 2.0)))
	shade.modulate = FISH_SHADOW
	_scaled(box, tex, k, at).name = "Fish"


static func _scaled(parent: Control, tex: Texture2D, k: float, at: Vector2) -> TextureRect:
	var pic := _picture(parent, tex, at)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.size = tex.get_size() * k
	return pic


static func _picture(parent: Control, tex: Texture2D, at: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = at
	parent.add_child(r)
	return r
