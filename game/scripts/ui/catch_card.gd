class_name CatchCard
## The banner hung out when a fish is landed, a Roman vexillum: a red cloth fringed in gold on a wooden crossbar, with
## the fish's name in gold, the fish drawn large on a tablet with handles, its weight and grade, and a golden laurel
## wreath on the staff when the fish is new to the logbook. It drops in and unfurls, and rolls up again after a few
## seconds or when clicked.

## The cloth's least and greatest width, the gold fringe under it, the crossbar, and the room above the bar for the
## staff's head.
const NARROWEST := 156.0
const WIDEST := 204.0
const FRINGE := 7
const BAR := 5
const HEAD := 27
## How far the crossbar runs past the cloth at each end, to its gold knobs.
const OVERHANG := 10
## The tablet the fish lies on, the handles at its sides, and the most a small fish is enlarged on it.
const TABLET := Vector2(146, 64)
const EAR := 8
const MOST := 4
## How long the banner stays unfurled, in seconds.
const SHOWN := 3.2

const DEEP := Color8(104, 30, 28)
const DARK_RED := Color8(136, 40, 35)
const LIGHT_RED := Color8(186, 66, 54)
const DARK_GOLD := Color8(176, 126, 52)
const LIGHT_GOLD := Color8(252, 232, 160)
const LIGHT_WOOD := Color8(152, 104, 66)
const DARK_WOOD := Color8(76, 46, 30)
const SHADOW := Color8(84, 22, 20)
## A laurel wreath round the staff: two branches of gold leaves curving up from a red ribbon, open at the top.
const WREATH := [
	".....l.......l.....",
	"....g..l...l..g....",
	"....gd.g...g.dg....",
	"..l.dd..g.g..dd.l..",
	"..gddgg.....ggddg..",
	"..gd.g.......g.dg..",
	"...dgg.......ggd...",
	".gddg.........gddg.",
	".gdgg.........ggdg.",
	"..ddg.........gdd..",
	"lg.dgg.......ggd.gl",
	"..gd.g.......g.dg..",
	"...ddggg...gggdd...",
	"..lgdd.g...g.ddgl..",
	"....gdddd.ddddg....",
	".......rrRrr.......",
	"........r.r........",
	".......r...r.......",
]

static var _open: Control


static func is_open() -> bool:
	return is_instance_valid(_open)


static func show_catch(fish: String, pounds: float, is_new: bool) -> void:
	if Nav.ui == null:
		return
	if is_open():
		_open.queue_free()
	var f: Dictionary = Data.fish[fish]
	var legend: bool = f["legend"]
	var card := Control.new()
	card.name = "CatchCard"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.set_meta("wreath", is_new or legend)
	Nav.ui.add_child(card)
	_open = card
	# The writing is laid out first, so that the cloth is cut to fit it.
	var title := _title(str(f["name"]).to_upper())
	var across := 0.0
	for line in title.split("\n"):
		across = maxf(across, UiTheme.title_font().get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.TITLE).x)
	var w := roundf(clampf(across + 24.0, NARROWEST, WIDEST) / 2.0) * 2.0
	# The cloth hangs in a clipped strip under the crossbar, so that it unfurls downwards from it.
	var hang := Control.new()
	hang.name = "Hang"
	hang.clip_contents = true
	hang.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hang.position = Vector2(OVERHANG, HEAD + BAR - 1)
	card.add_child(hang)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 1)
	hang.add_child(col)
	_words(col, title, "Title")
	_tablet(col, fish)
	_words(col, "%s lb, %s" % [pounds_text(pounds), Catalog.grade(fish, pounds)], "LightLabel")
	if legend:
		_words(col, "A LEGEND OF THE BAY!", "LightHeading")
	elif is_new:
		_words(col, "NEW IN YOUR LOGBOOK", "LightHeading")
	var h := 9.0 + col.get_combined_minimum_size().y + 8.0
	var size := Vector2(w + OVERHANG * 2, HEAD + BAR - 1 + h + FRINGE)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -roundf(size.x / 2.0)
	card.offset_right = card.offset_left + size.x
	card.offset_top = -roundf(size.y / 2.0)
	card.offset_bottom = card.offset_top + size.y
	hang.size = Vector2(w, 0)
	hang.set_meta("full", h + FRINGE)
	var cloth := _picture(hang, _cloth(int(w), int(h)), Vector2.ZERO)
	cloth.name = "Cloth"
	hang.move_child(cloth, 0)
	col.position = Vector2(0, 8)
	col.size = Vector2(w, col.get_combined_minimum_size().y)
	_picture(card, _standard(int(size.x), is_new or legend), Vector2.ZERO)
	var roll := _picture(card, _roll(int(w)), hang.position)
	roll.name = "Roll"
	_unfurl(card, hang)
	card.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: card.queue_free())


static func pounds_text(lb: float) -> String:
	return ("%.2f" % lb) if lb < 1.0 else ("%.1f" % lb)


## The banner drops in from a little above and unfurls, waits, then rolls up and fades.
static func _unfurl(card: Control, hang: Control) -> void:
	var y := card.position.y
	card.position.y = y - 24.0
	card.modulate.a = 0.0
	var full: float = hang.get_meta("full")
	var roll: Control = card.get_node("Roll")
	var unroll := func(down: float) -> void:
		hang.size.y = down
		roll.position.y = hang.position.y + roundf(down) - 2.0
		roll.visible = down < full
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
	if across + 24.0 <= WIDEST or not " " in name:
		return name
	var best := -1
	for i in name.length():
		if name[i] == " " and (best < 0 or absi(i - name.length() / 2) < absi(best - name.length() / 2)):
			best = i
	return name.substr(0, best) + "\n" + name.substr(best + 1)


static func _words(col: Control, text: String, variation: String) -> Label:
	var l := Ui.label(col, text, variation)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


## The tablet with its handles, the fish laid on it at the most whole pixels per pixel that fit.
static func _tablet(col: Control, fish: String) -> void:
	var box := Control.new()
	box.name = "Tablet"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = TABLET
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(box)
	_picture(box, _tablet_art(), Vector2.ZERO)
	var path := "res://assets/art/fish/%s.png" % fish
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	var room := TABLET - Vector2(EAR * 2 + 6, 6)
	var k := clampf(minf(floorf(room.x / tex.get_width()), floorf(room.y / tex.get_height())), 1.0, MOST)
	var pic := _picture(box, tex, Vector2.ZERO)
	pic.name = "Fish"
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.size = tex.get_size() * k
	pic.position = ((TABLET - pic.size) / 2.0).round()


static func _picture(parent: Control, tex: Texture2D, at: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = at
	parent.add_child(r)
	return r


## The red cloth: folds down its length, the top rows in the crossbar's shadow, a gold line inset round it, a gold hem
## and a fringe of gold threads below.
static func _cloth(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h + FRINGE, false, Image.FORMAT_RGBA8)
	for x in w:
		var fold := sin(float(x) / w * TAU * 2.5 + 0.7)
		var tone := UiTheme.RED
		if fold > 0.8:
			tone = LIGHT_RED
		elif fold > 0.45:
			tone = UiTheme.RED.lerp(LIGHT_RED, 0.5)
		elif fold < -0.8:
			tone = DARK_RED
		elif fold < -0.45:
			tone = UiTheme.RED.lerp(DARK_RED, 0.5)
		if x < 2 or x >= w - 2:
			tone = DARK_RED
		for y in h:
			img.set_pixel(x, y, tone)
		img.set_pixel(x, 0, DEEP)
		img.set_pixel(x, 1, DEEP)
		img.set_pixel(x, 2, DARK_RED)
		img.set_pixel(x, h - 2, DARK_GOLD)
		img.set_pixel(x, h - 1, UiTheme.GOLD)
	for x in range(4, w - 4):
		img.set_pixel(x, 5, UiTheme.GOLD)
		img.set_pixel(x, h - 6, UiTheme.GOLD)
	for y in range(5, h - 5):
		img.set_pixel(4, y, UiTheme.GOLD)
		img.set_pixel(w - 5, y, UiTheme.GOLD)
	for x in range(0, w, 2):
		var length := FRINGE - (x * 7 / 2) % 3
		var thread := UiTheme.GOLD if x % 4 == 0 else DARK_GOLD
		for y in length:
			img.set_pixel(x, h + y, LIGHT_GOLD if y == length - 1 else thread)
	return ImageTexture.create_from_image(img)


## The cloth still rolled up, a red cylinder lit from above, drawn at the edge of what has unfurled.
static func _roll(w: int) -> ImageTexture:
	var img := Image.create(w, 5, false, Image.FORMAT_RGBA8)
	var tones := [LIGHT_RED, UiTheme.RED, UiTheme.RED, DARK_RED, DEEP]
	for y in 5:
		for x in w:
			img.set_pixel(x, y, DARK_RED if x == 0 or x == w - 1 else tones[y])
	for x in range(3, w - 3, 2):
		img.set_pixel(x, 4, DARK_GOLD)
	return ImageTexture.create_from_image(img)


## The staff with its gold spearhead, the crossbar with gold knobs at its ends, and the laurel wreath when it is won.
static func _standard(width: int, wreath: bool) -> ImageTexture:
	var img := Image.create(width, HEAD + BAR, false, Image.FORMAT_RGBA8)
	var cx := width / 2
	for y in range(7, HEAD + BAR):
		img.set_pixel(cx - 1, y, LIGHT_WOOD)
		img.set_pixel(cx, y, UiTheme.WOOD)
		img.set_pixel(cx + 1, y, DARK_WOOD)
	_rows(img, Vector2i(cx - 2, 0), ["..l..", ".lgg.", ".lgd.", "lgggd", "lgggd", ".ggd.", "..d..", ".ddd."])
	for x in range(3, width - 3):
		img.set_pixel(x, HEAD, LIGHT_WOOD)
		for y in range(HEAD + 1, HEAD + BAR - 1):
			img.set_pixel(x, y, UiTheme.WOOD)
		img.set_pixel(x, HEAD + BAR - 1, DARK_WOOD)
	var knob := [".lgg.", "lgggd", "ggggd", "gggdd", ".ddd."]
	_rows(img, Vector2i(0, HEAD), knob)
	_rows(img, Vector2i(width - 5, HEAD), knob)
	if wreath:
		_rows(img, Vector2i(cx - 9, 8), WREATH, {"r": UiTheme.RED, "R": DEEP})
	return ImageTexture.create_from_image(img)


static func _dot(img: Image, at: Vector2, colour: Color) -> void:
	var p := Vector2i(roundi(at.x), roundi(at.y))
	if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
		img.set_pixel(p.x, p.y, colour)


## The tablet with handles, a tabula ansata: a gold rim round a pale face, lit from above.
static func _tablet_art() -> ImageTexture:
	var w := int(TABLET.x)
	var h := int(TABLET.y)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			if not _on_tablet(x, y):
				continue
			var edge := not (_on_tablet(x - 1, y) and _on_tablet(x + 1, y) and _on_tablet(x, y - 1) and _on_tablet(x, y + 1))
			var near := not (_on_tablet(x - 2, y) and _on_tablet(x + 2, y) and _on_tablet(x, y - 2) and _on_tablet(x, y + 2))
			var face := UiTheme.PARCHMENT.lightened(0.25)
			if not _on_tablet(x, y - 3):
				face = UiTheme.CREAM.lightened(0.3)
			elif not _on_tablet(x, y + 3):
				face = UiTheme.PARCHMENT
			img.set_pixel(x, y, DARK_GOLD if edge else (UiTheme.GOLD if near else face))
	return ImageTexture.create_from_image(img)


## Whether a pixel is on the tablet: its face, or a handle narrowing to a point at either side.
static func _on_tablet(x: int, y: int) -> bool:
	var w := int(TABLET.x)
	var h := int(TABLET.y)
	if x < 0 or y < 0 or x >= w or y >= h:
		return false
	if x >= EAR and x < w - EAR:
		return true
	var from_edge := float(x if x < EAR else w - 1 - x)
	return absf(y - (h - 1) / 2.0) <= h * 0.32 * from_edge / EAR


## Writes rows of letters into a picture: l, g and d are light, mid and dark gold unless `colours` names others.
static func _rows(img: Image, at: Vector2i, rows: Array, colours := {}) -> void:
	var ink := {"l": LIGHT_GOLD, "g": UiTheme.GOLD, "d": DARK_GOLD}.merged(colours, true)
	for y in rows.size():
		for x in String(rows[y]).length():
			var c := String(rows[y])[x]
			if ink.has(c):
				_dot(img, Vector2(at.x + x, at.y + y), ink[c])
