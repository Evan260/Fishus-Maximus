class_name CatchCard
## The card shown when a fish is landed: the fish, its weight and grade, and whether it is new to the logbook.

static var _open: Control


static func is_open() -> bool:
	return is_instance_valid(_open)


static func show_catch(fish: String, pounds: float, is_new: bool) -> void:
	if Nav.ui == null:
		return
	if is_open():
		_open.queue_free()
	var col := Ui.panel(Nav.ui, "")
	var card: Control = col.get_parent()
	card.position.y = 40
	card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_open = card
	var f: Dictionary = Data.fish[fish]
	Ui.label(col, f["name"].to_upper(), "Heading").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pic := TextureRect.new()
	var path := "res://assets/art/fish/%s.png" % fish
	pic.texture = load(path) if ResourceLoader.exists(path) else null
	pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	pic.custom_minimum_size = Vector2(110, 52)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	col.add_child(pic)
	var grade := Catalog.grade(fish, pounds)
	var line := Ui.label(col, "%s lb, %s" % [pounds_text(pounds), grade])
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if f["legend"]:
		Ui.label(col, "A legend of the bay!", "Heading").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif is_new:
		Ui.label(col, "New in your logbook!", "MutedLabel").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tw := card.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(card, "modulate:a", 0.0, 0.4)
	tw.tween_callback(card.queue_free)
	card.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: card.queue_free())


static func pounds_text(lb: float) -> String:
	return ("%.2f" % lb) if lb < 1.0 else ("%.1f" % lb)
