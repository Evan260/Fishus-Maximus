class_name Toast
## A short line of text near the top of the screen that fades away by itself.


static func say(text: String) -> void:
	if Nav.ui == null:
		return
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "LightLabel"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_right = 1.0
	l.offset_top = 30
	l.offset_bottom = 44
	l.add_theme_color_override("font_outline_color", UiTheme.INK)
	l.add_theme_constant_override("outline_size", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Nav.ui.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)
