class_name AchievementCard
## A small card that slides in at the bottom when an achievement is earned.

## When the card on screen will have gone, so that several earned at once take turns.
static var _free_at := 0.0


static func show_earned(id: String) -> void:
	if Nav.ui == null:
		return
	var a := Achievements.find(id)
	# The desktop strip is too short for the card, which would cover the boat, so it gets one line instead.
	if Windowing.strip:
		Audio.play("pond_bell", -6.0)
		Toast.say("Achievement: " + str(a.get("name", id)))
		return
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
	var now := Time.get_ticks_msec() / 1000.0
	var wait := maxf(0.0, _free_at - now)
	_free_at = now + wait + 3.7
	var tw := card.create_tween()
	tw.tween_interval(wait)
	tw.tween_callback(func(): Audio.play("pond_bell", -6.0))
	tw.tween_property(card, "position:y", bottom - 44.0, 0.3)
	tw.tween_interval(3.0)
	tw.tween_property(card, "position:y", bottom + 4.0, 0.3)
	tw.tween_callback(card.queue_free)
