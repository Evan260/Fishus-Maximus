class_name LogbookPanel
## The logbook, drawn as an open book: bookmarks down the side choose a place or the legends, the two pages list its
## fish, those not yet caught as dark shapes and a legend by its clue, and clicking one shows its record facing it.

const SHORT := {"harbour": "Harbour", "rocky_shore": "Rocky shore", "lucrine": "Lucrine", "open_bay": "Open bay", "capri": "Capri",
	"misenum": "Misenum", "legends": "Legends"}
const PAGE_W := 186
const PAGE_H := 210
## How many page edges show under each page, the fold between the pages, and the margins of the writing.
const STACK := 3
const SPINE := 4
const TOP := 7
const OUTER := 7
const INNER := 9
const ROWS := 6
const ROW := Vector2(PAGE_W - OUTER - INNER, 30)
const PICTURE := Vector2(62, 30)
const PAPER := Color8(244, 229, 192)
const EDGE := Color8(140, 102, 71)
const TAB := Color8(212, 181, 133)
const LEATHER := Color8(92, 56, 36)
const SHADOW := Color8(68, 49, 37)
const FLIP_TIME := 0.78
const FLIP_SLICES := 48
const FLIP_ROWS := 24

static var section := 0
static var spread := 0
static var selected := ""
static var _paper := {}
static var _shadows := {}
static var _cover: StyleBoxTexture
static var _book: Control
static var _flipping := false


static func open(at := -1) -> void:
	var sections := _sections()
	if at < 0:
		var place := str(Game.state.get("place", "harbour"))
		at = sections.find(place) if place in Data.places else 0
	if at >= 0 and at != section:
		section = at
		spread = 0
		selected = ""
	section = posmod(section, sections.size())
	var here: String = sections[section]
	var all := _entries(here)
	var spreads := maxi(1, ceili(all.size() / float(ROWS * 2)))
	spread = clampi(spread, 0, spreads - 1)
	var shown := all.slice(spread * ROWS * 2, (spread + 1) * ROWS * 2)
	if not shown.has(selected):
		selected = ""
	_prepare()
	var col := Ui.frame("Logbook", 462, 252)
	var win: PanelContainer = col.get_parent()
	win.add_theme_stylebox_override("panel", _cover)
	var top: HBoxContainer = col.get_child(0)
	top.get_child(0).theme_type_variation = "LightHeading"
	if spreads > 1:
		var turn := HBoxContainer.new()
		top.add_child(turn)
		top.move_child(turn, 1)
		Ui.button(turn, "<", func(): _turn(spread - 1)).disabled = spread == 0
		Ui.label(turn, "%d / %d" % [spread + 1, spreads], "LightLabel")
		Ui.button(turn, ">", func(): _turn(spread + 1)).disabled = spread == spreads - 1
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	col.add_child(row)
	var marks := VBoxContainer.new()
	marks.add_theme_constant_override("separation", 1)
	row.add_child(marks)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 5)
	marks.add_child(gap)
	for i in sections.size():
		_bookmark(marks, i, sections[i])
	var book := Control.new()
	book.custom_minimum_size = Vector2(STACK * 2 + PAGE_W * 2 + SPINE, PAGE_H + STACK)
	book.draw.connect(_draw_book.bind(book))
	row.add_child(book)
	_book = book
	var detail_side := 0 if shown.find(selected) >= ROWS else 1
	var pages := [_page(book, STACK + OUTER), _page(book, STACK + PAGE_W + SPINE + INNER)]
	for side in 2:
		var page: VBoxContainer = pages[side]
		if selected != "" and side == detail_side:
			_detail(page, selected)
			continue
		if side == 0:
			_header(page, here, all)
		else:
			_overall(page)
		for id in shown.slice(side * ROWS, (side + 1) * ROWS):
			_entry(page, id)


static func _sections() -> Array:
	return Data.places.keys() + ["legends"]


## The fish written under a place are the ordinary ones first found there; every legend has the legends' own pages.
static func _entries(here: String) -> Array:
	return Data.fish.keys().filter(func(id):
		var f: Dictionary = Data.fish[id]
		var places: Array = f["places"]
		return here == ("legends" if f["legend"] else (str(places[0]) if not places.is_empty() else "harbour")))


static func _turn(to: int) -> void:
	_flip_to(section, to)


## Turn to another section when a location bookmark is chosen.
static func _bookmark_turn(to: int) -> void:
	_flip_to(to, 0)


## Animate either a spread turn or a bookmark change, with the new page revealed on the reverse of the leaf.
static func _flip_to(to_section: int, to_spread: int) -> void:
	if _flipping or (to_section == section and to_spread == spread) or not is_instance_valid(_book):
		return
	_flipping = true
	var direction := 1 if (to_section > section if to_section != section else to_spread > spread) else -1
	var turning_side := 1 if direction > 0 else 0
	var front := await _capture_page_offscreen(_book, turning_side)
	var fixed_side := 0 if direction > 0 else 1
	var fixed := await _capture_page_offscreen(_book, fixed_side)
	Audio.play("page_turn")
	section = to_section
	spread = to_spread
	selected = ""
	open(section)
	if not is_instance_valid(_book):
		_flipping = false
		return
	var reverse_side := 0 if direction > 0 else 1
	var overlay := _flip_overlay(_book, direction, front, fixed, front)
	var back := await _capture_page_offscreen(_book, reverse_side)
	if is_instance_valid(overlay):
		overlay.set_meta("back", back)
		overlay.queue_redraw()


static func _caught(id: String) -> Dictionary:
	return Game.state["logbook"].get(id, {})


## Render an exact paper-and-print snapshot offscreen, preserving the same grain at every page edge.
static func _capture_page_offscreen(book: Control, side: int) -> Texture2D:
	if not is_instance_valid(book) or not book.is_inside_tree():
		return _paper[side == 0]
	var pages: Array[Control] = []
	for child in book.get_children():
		if child is VBoxContainer:
			pages.append(child)
	if side >= pages.size():
		return _paper[side == 0]
	var viewport := SubViewport.new()
	viewport.size = Vector2i(PAGE_W, PAGE_H)
	viewport.transparent_bg = false
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	book.add_child(viewport)
	var root := Control.new()
	root.size = Vector2(PAGE_W, PAGE_H)
	root.theme = Nav.ui.theme
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(root)
	var paper := TextureRect.new()
	paper.texture = _paper[side == 0]
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.size = Vector2(PAGE_W, PAGE_H)
	root.add_child(paper)
	var page := pages[side].duplicate() as Control
	page.position = Vector2(OUTER if side == 0 else INNER, TOP)
	root.add_child(page)
	await RenderingServer.frame_post_draw
	var texture := ImageTexture.create_from_image(viewport.get_texture().get_image())
	viewport.queue_free()
	return texture


## The leather cover and the two pages of paper, made before the book is drawn.
static func _prepare() -> void:
	if _cover == null:
		_cover = StyleBoxTexture.new()
		_cover.texture = _leather()
		_cover.set_texture_margin_all(6)
		_cover.set_content_margin_all(7)
		_cover.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		_cover.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	for gutter_right in [true, false]:
		if not _paper.has(gutter_right):
			_paper[gutter_right] = _make_paper(gutter_right)


## A divider tab beside the book; the open one is the colour of the page.
static func _bookmark(parent: Node, i: int, id: String) -> void:
	var open_now := i == section
	var b := Button.new()
	b.text = SHORT.get(id, str(Data.places.get(id, {}).get("name", id)))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = PAPER if open_now else (TAB.lightened(0.12) if state.begins_with("hover") else TAB)
		box.border_color = EDGE
		box.set_border_width_all(1)
		box.content_margin_left = 5
		box.content_margin_right = 4
		box.content_margin_top = 1
		box.content_margin_bottom = 1
		b.add_theme_stylebox_override(state, box)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, UiTheme.INK if open_now else UiTheme.INK.lightened(0.18))
	b.pressed.connect(func():
		_bookmark_turn(i))
	parent.add_child(b)


static func _page(book: Control, x: int) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.position = Vector2(x, TOP)
	col.custom_minimum_size = Vector2(ROW.x, PAGE_H - TOP - 4)
	col.add_theme_constant_override("separation", 1)
	book.add_child(col)
	return col


## Draw a temporary paper leaf above the next spread and curl it around the spine.
static func _flip_overlay(book: Control, direction: int, front: Texture2D, fixed: Texture2D, back: Texture2D) -> Control:
	var overlay := Control.new()
	overlay.name = "LogbookPageTurn"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay.z_index = 20
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.set_meta("direction", direction)
	overlay.set_meta("progress", 0.0)
	overlay.set_meta("front", front)
	overlay.set_meta("fixed", fixed)
	overlay.set_meta("back", back)
	overlay.draw.connect(func(): _draw_flip(overlay))
	overlay.tree_exiting.connect(func(): _flipping = false)
	book.add_child(overlay)
	var tween := overlay.create_tween()
	tween.tween_method(func(value: float):
		overlay.set_meta("progress", value)
		overlay.queue_redraw(), 0.0, 1.0, FLIP_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(_finish_flip.bind(overlay))
	return overlay


## Hold the exact flat landing for a rendered frame before handing off to the book underneath.
static func _finish_flip(overlay: Control) -> void:
	if not is_instance_valid(overlay):
		return
	overlay.set_meta("progress", 1.0)
	overlay.queue_redraw()
	await RenderingServer.frame_post_draw
	if is_instance_valid(overlay):
		_flipping = false
		overlay.queue_free()


## Render a textured paper leaf as a mesh, with enough rows to bend its free edge into a real curl.
static func _draw_flip(canvas: Control) -> void:
	var progress: float = float(canvas.get_meta("progress"))
	var direction: int = int(canvas.get_meta("direction"))
	var reverse := progress >= 0.5
	var texture: Texture2D = canvas.get_meta("back" if reverse else "front")
	var angle := PI * progress if direction > 0 else PI * (1.0 + progress)
	var hinge := STACK + PAGE_W + SPINE if direction > 0 else STACK + PAGE_W
	# The fold travels across the gutter as the leaf lands on the opposite page.
	hinge -= direction * SPINE * smoothstep(0.0, 1.0, progress)
	var curl := sin(PI * progress)
	var flip_uv := (direction < 0) != reverse
	var fixed_x := STACK if direction > 0 else STACK + PAGE_W + SPINE
	var fixed_alpha := 0.0 if progress >= 1.0 else 1.0
	canvas.draw_texture_rect(canvas.get_meta("fixed"), Rect2(fixed_x, 0, PAGE_W, PAGE_H), false,
		Color(1, 1, 1, fixed_alpha))
	if progress >= 1.0:
		var landing_x := STACK if direction > 0 else STACK + PAGE_W + SPINE
		canvas.draw_texture_rect(texture, Rect2(landing_x, 0, PAGE_W, PAGE_H), false)
		_draw_spine(canvas)
		return
	var mesh_points: Array[PackedVector2Array] = []
	var mesh_uvs: Array[PackedVector2Array] = []
	var mesh_colors: Array[PackedColorArray] = []
	for i in FLIP_SLICES:
		var u0 := float(i) / FLIP_SLICES
		var u1 := float(i + 1) / FLIP_SLICES
		var sx0 := 1.0 - u0 if flip_uv else u0
		var sx1 := 1.0 - u1 if flip_uv else u1
		for j in FLIP_ROWS:
			var v0 := float(j) / FLIP_ROWS
			var v1 := float(j + 1) / FLIP_ROWS
			var y0 := v0 * PAGE_H
			var y1 := v1 * PAGE_H
			var p00 := _flip_point(u0, y0, progress, direction, angle, hinge)
			var p10 := _flip_point(u1, y0, progress, direction, angle, hinge)
			var p11 := _flip_point(u1, y1, progress, direction, angle, hinge)
			var p01 := _flip_point(u0, y1, progress, direction, angle, hinge)
			var points := PackedVector2Array([p00, p10, p11, p01])
			var shadow_shift := Vector2(direction * 4.0 * curl, 2.0 * curl)
			var shadow_color := Color(UiTheme.INK, 0.16 * curl)
			var shadow_points := PackedVector2Array([
				p00 + shadow_shift, p10 + shadow_shift, p11 + shadow_shift, p01 + shadow_shift])
			var shadow_colors := PackedColorArray([shadow_color, shadow_color, shadow_color, shadow_color])
			_draw_flip_triangle(canvas, shadow_points[0], shadow_points[1], shadow_points[2], shadow_colors[0], shadow_colors[1], shadow_colors[2])
			_draw_flip_triangle(canvas, shadow_points[0], shadow_points[2], shadow_points[3], shadow_colors[0], shadow_colors[2], shadow_colors[3])
			var uvs := PackedVector2Array([
				Vector2(sx0, v0), Vector2(sx1, v0), Vector2(sx1, v1), Vector2(sx0, v1)])
			var across := (u0 + u1) * 0.5
			var bend_light := sin(PI * across) * curl
			var light := clampf(0.92 - bend_light * 0.28 + 0.07 * absf(cos(angle)), 0.55, 1.0)
			var color := Color(light, light, light, 1.0)
			mesh_points.append(points)
			mesh_uvs.append(uvs)
			mesh_colors.append(PackedColorArray([color, color, color, color]))
	for i in mesh_points.size():
		_draw_flip_triangle(canvas, mesh_points[i][0], mesh_points[i][1], mesh_points[i][2],
			mesh_colors[i][0], mesh_colors[i][1], mesh_colors[i][2],
			mesh_uvs[i][0], mesh_uvs[i][1], mesh_uvs[i][2], texture)
		_draw_flip_triangle(canvas, mesh_points[i][0], mesh_points[i][2], mesh_points[i][3],
			mesh_colors[i][0], mesh_colors[i][2], mesh_colors[i][3],
			mesh_uvs[i][0], mesh_uvs[i][2], mesh_uvs[i][3], texture)
	_draw_spine(canvas)


## Draw one indexed triangle directly; warped quads can self-intersect and defeat Godot's polygon triangulator.
static func _draw_flip_triangle(canvas: Control, a: Vector2, b: Vector2, c: Vector2,
		color_a: Color, color_b: Color, color_c: Color,
		uv_a := Vector2.ZERO, uv_b := Vector2.ZERO, uv_c := Vector2.ZERO, texture: Texture2D = null) -> void:
	if absf((b - a).cross(c - a)) < 0.001:
		return
	canvas.draw_polygon(PackedVector2Array([a, b, c]), PackedColorArray([color_a, color_b, color_c]),
		PackedVector2Array([uv_a, uv_b, uv_c]), texture)


## Bow the page edges and curl its middle away from the flat plane as it passes the spine.
static func _flip_point(u: float, y: float, progress: float, direction: int, angle: float, hinge: float) -> Vector2:
	var bend := sin(PI * u) * sin(PI * progress)
	var roll := pow(u, 3.0) * sin(PI * progress)
	# Rightward turns rasterize one logical pixel left of the settled page, so ease that side onto its exact landing.
	var landing_shift := smoothstep(0.9, 1.0, progress) if direction < 0 else 0.0
	var x := hinge + u * PAGE_W * cos(angle) - direction * bend * 11.0 - direction * roll * sin(PI * y / PAGE_H) * 48.0 + landing_shift
	var edge_y := (y - PAGE_H * 0.5) / (PAGE_H * 0.5)
	return Vector2(x, y + bend * edge_y * 4.0 + roll * edge_y * 20.0)

static func _header(page: VBoxContainer, here: String, all: Array) -> void:
	var head := HBoxContainer.new()
	head.custom_minimum_size = Vector2(0, 15)
	page.add_child(head)
	var title := "Legends of the bay" if here == "legends" else str(Data.places[here]["name"])
	Ui.label(head, title.to_upper(), "Heading").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var count := Ui.label(head, "%d / %d" % [all.filter(func(id): return not _caught(id).is_empty()).size(), all.size()], "Heading")
	count.add_theme_color_override("font_color", UiTheme.MUTED)


## The logbook's total across the bay, at the head of the right-hand page.
static func _overall(page: VBoxContainer) -> void:
	var head := HBoxContainer.new()
	head.custom_minimum_size = Vector2(0, 15)
	head.alignment = BoxContainer.ALIGNMENT_END
	page.add_child(head)
	var kinds: int = Data.fish.size()
	var l := Ui.label(head, "%d of %d kinds caught" % [Game.state["logbook"].size(), kinds], "MutedLabel")
	l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


## One fish on the page: its picture or its shadow, its name, and how many and how big, or a legend's clue.
static func _entry(page: VBoxContainer, id: String) -> void:
	var f: Dictionary = Data.fish[id]
	var got := _caught(id)
	var b := Button.new()
	b.custom_minimum_size = ROW
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(UiTheme.INK, 0.07)
	for state in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, hover)
	if id == selected:
		var mark := StyleBoxFlat.new()
		mark.bg_color = PAPER.darkened(0.1)
		mark.border_color = EDGE
		mark.set_border_width_all(1)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, mark)
	b.pressed.connect(func():
		Audio.play("click", -8.0)
		selected = "" if selected == id else id
		open(section))
	page.add_child(b)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 4)
	b.add_child(line)
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.add_child(_picture(id, PICTURE, false, got.is_empty()))
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -1)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(words)
	var width := ROW.x - PICTURE.x - 4
	if not got.is_empty():
		_line(words, _short_name(f), "")
		_line(words, "x%d, best %s" % [int(got["count"]), Units.weight(float(got["best"]))], "MutedLabel")
	elif f["legend"]:
		var clue := _two_lines("\"%s\"" % Legends.clue(id), width)
		_line(words, clue[0], "MutedLabel")
		_line(words, clue[1], "MutedLabel")
	else:
		_line(words, f["name"], "MutedLabel")
		var not_yet := _line(words, "Not yet caught", "MutedLabel")
		not_yet.modulate.a = 0.7


## A legend's name without its "The", so the longest still fits beside its picture.
static func _short_name(f: Dictionary) -> String:
	var n := str(f["name"])
	if not n.begins_with("The "):
		return n
	return n.substr(4, 1).to_upper() + n.substr(5)


static func _line(parent: Node, text: String, variation: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
	parent.add_child(l)
	return l


## The first two lines of a long text at this width; the second is cut short by its label when it runs on.
static func _two_lines(text: String, width: float) -> Array:
	var font := UiTheme.body_font()
	var first := ""
	var words := text.split(" ")
	var i := 0
	while i < words.size():
		var next := (first + " " + words[i]).strip_edges()
		if first != "" and font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.TEXT).x > width:
			break
		first = next
		i += 1
	return [first, " ".join(words.slice(i))]


## A fish's picture, or its dark shape, in a box of this size: at its own size when it fits, doubled for the record
## page when that fits too, and otherwise shrunk smoothly to fit.
static func _picture(id: String, box: Vector2, may_double: bool, dark: bool) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = box
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := "res://assets/art/fish/%s.png" % id
	if not ResourceLoader.exists(path):
		return holder
	var tex: Texture2D = _shadow(id, load(path)) if dark else load(path)
	var size := tex.get_size()
	var pic := TextureRect.new()
	pic.texture = tex
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if may_double and size.x * 2.0 <= box.x and size.y * 2.0 <= box.y:
		pic.custom_minimum_size = size * 2.0
	elif size.x <= box.x and size.y <= box.y:
		pic.custom_minimum_size = size
	else:
		pic.custom_minimum_size = (size * minf(box.x / size.x, box.y / size.y)).floor()
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	holder.add_child(pic)
	return holder


## A fish's outline filled with one dark colour, made once for each kind.
static func _shadow(id: String, tex: Texture2D) -> Texture2D:
	if not _shadows.has(id):
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				img.set_pixel(x, y, Color(SHADOW, img.get_pixel(x, y).a))
		_shadows[id] = ImageTexture.create_from_image(img)
	return _shadows[id]


## The whole record of one fish, written on the page facing it, with a button back to the list.
static func _detail(page: VBoxContainer, id: String) -> void:
	var f: Dictionary = Data.fish[id]
	var got := _caught(id)
	var secret: bool = got.is_empty() and f["legend"]
	var head := HBoxContainer.new()
	page.add_child(head)
	var title := _para(head, ("A legend" if secret else str(f["name"])).to_upper(), "Heading")
	title.custom_minimum_size.x = 0
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Ui.button(head, "Back", func():
		selected = ""
		open(section)).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if not got.is_empty() and str(f.get("latin", "")) != "":
		_para(page, str(f["latin"]).substr(0, 1).to_upper() + str(f["latin"]).substr(1), "MutedLabel")
	var frame := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER.darkened(0.08)
	box.border_color = EDGE
	box.set_border_width_all(1)
	box.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", box)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(frame)
	frame.add_child(_picture(id, Vector2(ROW.x - 4, 66), true, got.is_empty()))
	var waters := "Waters: %s." % ", ".join(f["places"].map(func(p): return _lower_first(str(Data.places[p]["name"]))))
	if secret:
		_para(page, "\"%s\"" % Legends.clue(id), "MutedLabel")
	elif got.is_empty():
		_para(page, "Not yet caught.", "")
		_para(page, waters, "MutedLabel")
	else:
		_para(page, "Caught %d. Best %s, %s." % [int(got["count"]), Units.weight(float(got["best"])), Catalog.grade(id, float(got["best"]))], "")
		if f["legend"]:
			_para(page, "A legend of the bay.", "")
		_para(page, waters, "MutedLabel")
		_para(page, "Baits: %s." % ", ".join(f["baits"].map(func(b): return str(Data.bait[b]["name"]).to_lower())), "MutedLabel")


## A paragraph wrapped at the page's width, which it is given before it goes in so it is measured at that width.
static func _para(page: Container, text: String, variation: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(ROW.x, 0)
	l.size.x = ROW.x
	page.add_child(l)
	return l


static func _lower_first(s: String) -> String:
	return s.substr(0, 1).to_lower() + s.substr(1)


## Two pages of paper with the edges of the pages under them showing at the sides and bottom, and a shadow running
## into the fold between them.
static func _draw_book(book: Control) -> void:
	var right_x := STACK + PAGE_W + SPINE
	for k in range(STACK, 0, -1):
		var shade := PAPER.darkened(0.12 + 0.1 * (k % 2))
		book.draw_rect(Rect2(STACK - k, k, PAGE_W, PAGE_H), shade)
		book.draw_rect(Rect2(right_x + k, k, PAGE_W, PAGE_H), shade)
	book.draw_rect(Rect2(0, STACK, 1, PAGE_H), EDGE)
	book.draw_rect(Rect2(right_x + PAGE_W + STACK - 1, STACK, 1, PAGE_H), EDGE)
	book.draw_texture(_paper[true], Vector2(STACK, 0))
	book.draw_texture(_paper[false], Vector2(right_x, 0))
	book.draw_rect(Rect2(STACK, 0, PAGE_W, 1), PAPER)
	book.draw_rect(Rect2(right_x, 0, PAGE_W, 1), PAPER)
	_draw_spine(book)


## Keep all four pixels of the gutter visible above the turning leaf, exactly as on the flat book.
static func _draw_spine(canvas: Control) -> void:
	var x := STACK + PAGE_W
	# Keep the lower three pixels open where the page block parts around the binding.
	# The four bands read as a paper edge, recessed crease, deep fold, and reflected light.
	canvas.draw_rect(Rect2(x, 0, 1, PAGE_H), Color8(151, 113, 78))
	canvas.draw_rect(Rect2(x + 1, 0, 1, PAGE_H), Color8(111, 80, 57))
	canvas.draw_rect(Rect2(x + 2, 0, 1, PAGE_H), Color8(75, 55, 43))
	canvas.draw_rect(Rect2(x + 3, 0, 1, PAGE_H), Color8(133, 99, 70))


## A page of paper: a fine grain, a few fibres and age spots, edges a little browned, and a shadow towards the fold.
static func _make_paper(gutter_right: bool) -> Texture2D:
	var img := Image.create(PAGE_W, PAGE_H, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 if gutter_right else 23
	for y in PAGE_H:
		for x in PAGE_W:
			var c := PAPER
			if rng.randf() < 0.14:
				c = c.darkened(0.035)
			var inner := PAGE_W - 1 - x if gutter_right else x
			var edge := mini(PAGE_W - 1 - inner, PAGE_H - 1 - y)
			if edge < 4:
				c = c.darkened(0.07 * (1.0 - edge / 4.0))
			if inner < 16:
				c = c.darkened(0.2 * pow(1.0 - inner / 16.0, 2.0))
			img.set_pixel(x, y, c)
	for i in 70:
		var x := rng.randi_range(3, PAGE_W - 8)
		var y := rng.randi_range(3, PAGE_H - 4)
		for k in rng.randi_range(2, 5):
			img.set_pixel(x + k, y, img.get_pixel(x + k, y).darkened(0.05))
	for i in 9:
		var at := Vector2i(rng.randi_range(6, PAGE_W - 8), rng.randi_range(6, PAGE_H - 8))
		var spot := Color(0.72, 0.52, 0.32)
		img.set_pixelv(at, img.get_pixelv(at).lerp(spot, 0.22))
		img.set_pixelv(at + Vector2i(1, 0), img.get_pixelv(at + Vector2i(1, 0)).lerp(spot, 0.12))
	return ImageTexture.create_from_image(img)


## The cover: grained leather with a tooled line round its edge and brass caps on its corners, cut as a nine-slice.
static func _leather() -> Texture2D:
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in n:
		for x in n:
			var c := LEATHER
			var r := rng.randf()
			if r < 0.12:
				c = c.darkened(0.08)
			elif r < 0.18:
				c = c.lightened(0.05)
			var edge := mini(mini(x, y), mini(n - 1 - x, n - 1 - y))
			if edge == 0:
				c = LEATHER.darkened(0.5)
			elif edge == 3:
				c = LEATHER.lightened(0.16)
			img.set_pixel(x, y, c)
	var brass := [Color8(226, 180, 98), Color8(194, 139, 58), Color8(152, 106, 45)]
	for corner in [Vector2i(0, 0), Vector2i(n - 1, 0), Vector2i(0, n - 1), Vector2i(n - 1, n - 1)]:
		var dx := 1 if corner.x == 0 else -1
		var dy := 1 if corner.y == 0 else -1
		for i in 5:
			for j in 5 - i:
				var shade: Color = brass[0] if i + j < 2 else (brass[1] if i + j < 4 else brass[2])
				img.set_pixel(corner.x + dx * i, corner.y + dy * j, shade)
	return ImageTexture.create_from_image(img)
