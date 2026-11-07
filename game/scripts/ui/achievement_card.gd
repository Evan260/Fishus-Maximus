class_name AchievementCard
## A small card that slides in at the bottom when an achievement is earned.


static func show_earned(id: String) -> void:
	if Nav.ui == null:
		return
	var a := Achievements.find(id)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(180, 0)
	var bottom := Nav.view().y
	card.position = Vector2(roundf((Nav.view().x - 180.0) / 2.0), bottom)
	Nav.ui.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	card.add_child(col)
	Ui.label(col, "ACHIEVEMENT", "Heading")
	Ui.label(col, a.get("name", id))
	Audio.play("pond_bell", -6.0)
	var tw := card.create_tween()
	tw.tween_property(card, "position:y", bottom - 44.0, 0.3)
	tw.tween_interval(3.0)
	tw.tween_property(card, "position:y", bottom + 4.0, 0.3)
	tw.tween_callback(card.queue_free)
