class_name Ui
## Small helpers for building the interface the same way everywhere.


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
	var w := size.x if size.x > 0.0 else c.get_combined_minimum_size().x
	var h := size.y if size.y > 0.0 else c.get_combined_minimum_size().y
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
	close_window()
	var p := PanelContainer.new()
	p.name = "Window"
	p.custom_minimum_size = Vector2(width, 0)
	p.size = Vector2(width, height)
	p.position = ((Nav.view() - Vector2(width, height)) / 2.0).round()
	Nav.ui.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	p.add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	var head := label(top, title.to_upper(), "Heading")
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(top, "x", close_window)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(width - 12, height - 28)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	return list


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


static func fish_text(f: Dictionary) -> String:
	var t := "%s, %s lb" % [Data.fish[f["fish"]]["name"], CatchCard.pounds_text(float(f["pounds"]))]
	if f.get("salted", false):
		t += ", salted"
	elif f.get("live", false):
		t += ", alive"
	else:
		t += ", %d%% fresh" % int(roundf(float(f.get("fresh", 1.0)) * 100.0))
	return t
