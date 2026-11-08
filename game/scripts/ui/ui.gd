class_name Ui
## Small helpers for building the interface the same way everywhere.

## As wide as a button is tall, so a button of one letter comes out square.
const BUTTON_MIN_WIDTH := 22.0

## A denarius, five pixels across, for prices under pictures.
static var COIN: ImageTexture = _coin()


static func _coin() -> ImageTexture:
	var rows := [".ooo.", "oxxxo", "oxoxo", "oxxxo", ".ooo."]
	var img := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	for y in 5:
		for x in 5:
			if rows[y][x] != ".":
				img.set_pixel(x, y, UiTheme.GOLD if rows[y][x] == "x" else UiTheme.GOLD.darkened(0.35))
	return ImageTexture.create_from_image(img)


static func coins_text(n: int) -> String:
	return "1 denarius" if n == 1 else "%d denarii" % n


static func label(parent: Node, text: String, variation := "") -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	parent.add_child(l)
	return l


static func button(parent: Node, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.x = BUTTON_MIN_WIDTH
	b.pressed.connect(Audio.play.bind("click", -6.0))
	b.pressed.connect(action)
	parent.add_child(b)
	return b


## Hangs a control from one corner or edge of the view, `at` pixels in from it, so it stays there whatever the
## window's shape: "top_left", "top_right", "bottom_left", "bottom_right", "top" or "bottom" (centred across).
static func hang(c: Control, where: String, at: Vector2, size := Vector2.ZERO) -> void:
	var right := where.ends_with("right")
	var bottom := where.begins_with("bottom")
	var across := where == "top" or where == "bottom"
	# A control never shrinks below its own size, so one hung in too small a box would grow out of its corner.
	var w := maxf(size.x, c.get_combined_minimum_size().x)
	var h := maxf(size.y, c.get_combined_minimum_size().y)
	c.anchor_left = 0.5 if across else (1.0 if right else 0.0)
	c.anchor_right = c.anchor_left
	c.anchor_top = 1.0 if bottom else 0.0
	c.anchor_bottom = c.anchor_top
	var x0 := -w / 2.0 + at.x if across else (-at.x - w if right else at.x)
	var y0 := -at.y - h if bottom else at.y
	c.offset_left = x0
	c.offset_right = x0 + w
	c.offset_top = y0
	c.offset_bottom = y0 + h


## A centred window with a heading, for panels.
static func panel(parent: Node, title: String) -> VBoxContainer:
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	parent.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	p.add_child(col)
	if title != "":
		label(col, title.to_upper(), "Heading")
	return col


## A window with a heading, a scrolling list and a close button, replacing any window already open. Returns the list.
static func window(title: String, width := 300.0, height := 200.0) -> VBoxContainer:
	var col := frame(title, width, height)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(width - 12, height - 28)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	return list


## An empty, centred window with a heading and a close button, replacing any window already open, over a clear
## backdrop that closes it when clicked. Returns its column, whose first row holds the heading.
static func frame(title: String, width := 300.0, height := 200.0) -> VBoxContainer:
	close_window()
	var back := Control.new()
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	# The backdrop keeps the click, so a click beside a window closes it without also casting or opening a building.
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			back.accept_event()
			close_window())
	Nav.ui.add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var p := PanelContainer.new()
	p.name = "Window"
	p.custom_minimum_size = Vector2(width, 0)
	p.tree_exiting.connect(back.queue_free)
	Nav.ui.add_child(p)
	# Sized before anything goes in, so wrapped words are measured at its width, and grown evenly both ways if taller.
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.offset_left = -roundf(width / 2.0)
	p.offset_right = p.offset_left + width
	p.offset_top = -roundf(height / 2.0)
	p.offset_bottom = p.offset_top + height
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	p.add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	var head := label(top, title.to_upper(), "Heading")
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(top, "x", close_window)
	return col


static func close_window() -> void:
	if Nav.ui and Nav.ui.has_node("Window"):
		var w := Nav.ui.get_node("Window")
		w.name = "Closing"
		w.queue_free()


static func window_open() -> bool:
	return Nav.ui != null and Nav.ui.has_node("Window")


## One line of a list: text on the left, and a button on the right when there is something to do.
static func row(list: Control, text: String, action_text := "", action := Callable(), enabled := true) -> HBoxContainer:
	var r := HBoxContainer.new()
	list.add_child(r)
	var l := label(r, text)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if action_text != "":
		var b := button(r, action_text, action)
		b.disabled = not enabled
	return r


## A button showing a picture with a tip on hover, for the shops, the tackle and the boat's bar: `caption` (a price or
## a count) sits under the picture, and a chosen tile is ringed in gold.
static func tile(parent: Node, picture: Texture2D, caption: String, tip: String, action: Callable, enabled := true,
		chosen := false, size := Vector2(40, 40)) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = size
	b.tooltip_text = wrapped(tip, 46)
	b.disabled = not enabled
	b.pressed.connect(Audio.play.bind("click", -6.0))
	b.pressed.connect(action)
	parent.add_child(b)
	var under := 11.0 if caption != "" else 0.0
	var pic := TextureRect.new()
	pic.name = "Picture"
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = 3
	pic.offset_top = 3
	pic.offset_right = -3
	pic.offset_bottom = -3 - under
	if picture:
		pic.texture = ItemArt.fitted(picture, Vector2(size.x - 6.0, size.y - 6.0 - under))
	pic.modulate.a = 1.0 if enabled else 0.4
	b.add_child(pic)
	if caption != "":
		var l := Label.new()
		l.name = "Caption"
		l.text = caption
		l.theme_type_variation = "Heading"
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		l.offset_top = -under - 4
		l.offset_bottom = -4
		b.add_child(l)
	var ring := Panel.new()
	ring.name = "Ring"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gold := StyleBoxFlat.new()
	gold.draw_center = false
	gold.set_border_width_all(1)
	gold.border_color = UiTheme.GOLD
	ring.add_theme_stylebox_override("panel", gold)
	b.add_child(ring)
	choose(b, chosen)
	return b


## A tile with its price under the picture, after a small gold coin.
static func price_tile(parent: Node, picture: Texture2D, price: int, tip: String, action: Callable, enabled := true,
		size := Vector2(40, 40)) -> Button:
	var t := tile(parent, picture, str(price), tip, action, enabled, false, size)
	var words := UiTheme.title_font().get_string_size(str(price), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.HEADING).x
	var coin := TextureRect.new()
	coin.texture = COIN
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.position = Vector2(roundf((size.x - words) / 2.0) - 4.0, size.y - 12.0)
	t.add_child(coin)
	t.get_node("Caption").offset_left += 3
	t.get_node("Caption").offset_right += 3
	return t


## Rings a tile in gold, or takes the ring away.
static func choose(t: Button, on: bool) -> void:
	t.set_meta("chosen", on)
	t.get_node("Ring").visible = on


## Breaks a tip into lines of at most `width` letters, since Godot's tooltips never wrap.
static func wrapped(text: String, width: int) -> String:
	var lines := []
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" "):
			if line != "" and line.length() + 1 + word.length() > width:
				lines.append(line)
				line = word
			else:
				line = word if line == "" else line + " " + word
		lines.append(line)
	return "\n".join(lines)


## A speech bubble over someone's head, as in Farmus Maximus: a small parchment note with a tail pointing down at them
## that fades after a few seconds; a new one replaces any still showing. `follow` keeps it over a speaker who moves.
static func speech(at: Vector2, text: String, follow := Callable()) -> PanelContainer:
	for old in Nav.ui.get_children():
		if old.has_meta("speech"):
			old.free()
	var paper := Color(0.99, 0.95, 0.86)
	var bubble := PanelContainer.new()
	bubble.set_meta("speech", true)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = paper
	box.border_color = UiTheme.INK
	box.set_border_width_all(1)
	box.set_content_margin_all(4)
	bubble.add_theme_stylebox_override("panel", box)
	Nav.ui.add_child(bubble)
	var words := label(bubble, text)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = 140
	var tail := Control.new()
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.draw.connect(func():
		for k in 4:
			tail.draw_rect(Rect2(-3 + k, k, 7 - k * 2, 1), UiTheme.INK if k == 3 else paper)
			tail.draw_rect(Rect2(-4 + k, k, 1, 1), UiTheme.INK)
			tail.draw_rect(Rect2(3 - k, k, 1, 1), UiTheme.INK))
	bubble.add_child(tail)
	var place := func(_t := 0.0) -> void:
		if not is_instance_valid(bubble):
			return
		var spot: Vector2 = follow.call() if follow.is_valid() else at
		bubble.reset_size()
		var room := Nav.view()
		var pos := (spot - Vector2(bubble.size.x / 2.0, bubble.size.y + 4.0)).round()
		bubble.position = pos.clamp(Vector2(2, 2), room - bubble.size - Vector2(2, 2))
		tail.position = Vector2(roundf(spot.x - bubble.position.x), bubble.size.y - 1.0)
	place.call()
	var tween := bubble.create_tween()
	tween.tween_property(bubble, "modulate:a", 1.0, 0.15).from(0.0)
	tween.parallel().tween_method(place, 0.0, 1.0, 4.0)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.5)
	tween.tween_callback(bubble.queue_free)
	return bubble


static func fish_text(f: Dictionary) -> String:
	var t := "%s, %s lb" % [Data.fish[f["fish"]]["name"], CatchCard.pounds_text(float(f["pounds"]))]
	if f.get("salted", false):
		t += ", salted"
	elif f.get("live", false):
		t += ", alive"
	else:
		t += ", %d%% fresh" % int(roundf(float(f.get("fresh", 1.0)) * 100.0))
	return t
