class_name Toast
## Short lines of text that fade away by themselves, stacked so that several at once can all be read.

static var _box: VBoxContainer


static func say(text: String) -> void:
	if Nav.ui == null:
		return
	if not is_instance_valid(_box) or _box.get_parent() != Nav.ui:
		_box = VBoxContainer.new()
		_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.add_theme_constant_override("separation", 1)
		# A window opened after a message is added after it too, so the messages are lifted above every window.
		_box.z_index = 50
		Nav.ui.add_child(_box)
	place()
	while _box.get_child_count() >= (2 if Windowing.strip else 4):
		_box.get_child(0).free()
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "LightLabel"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_outline_color", UiTheme.INK)
	l.add_theme_constant_override("outline_size", 2)
	# The pixel font stays sharp only at whole multiples of its size, so larger text is twice as big.
	if Settings.large_text:
		l.add_theme_font_size_override("font_size", UiTheme.text_size() * 2)
		l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(1.6 + text.length() / 40.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


## Lays the messages out for where they belong now; old Rufus calls it as his note comes and goes.
static func place() -> void:
	if not is_instance_valid(_box):
		return
	# In the desktop strip the lines sit along the bottom, so they never cover the boat; while old Rufus is speaking
	# they sit in a column under his note.
	var low := Windowing.strip
	var note := GuideNote.find()
	var under := not low and note != null and note.visible
	_box.anchor_left = 1.0 if under else 0.0
	_box.anchor_right = 1.0
	_box.anchor_top = 1.0 if low else 0.0
	_box.anchor_bottom = 1.0 if low else 0.0
	_box.offset_left = note.offset_left if under else (80 if low else 16)
	_box.offset_right = note.offset_right if under else -16
	var panel: Control = Nav.ui.find_child("InfoPanel", true, false)
	var below := maxf(30.0, panel.position.y + panel.get_combined_minimum_size().y + 3.0) if panel and panel.is_visible_in_tree() else 30.0
	_box.offset_top = -4 if low else (note.offset_bottom + 3 if under else below)
	_box.offset_bottom = _box.offset_top
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN if low else Control.GROW_DIRECTION_END
