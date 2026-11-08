class_name AchievementCard
## A small card that slides in from the right, in the bottom right corner, when an achievement is earned.

const WIDTH := 150.0
## How far above the bottom edge the card rests: clear of the buttons along the bottom of every screen.
const ABOVE := 4.0 + 30.0 + 4.0

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
	card.set_meta("achievement", id)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(WIDTH, 0)
	Nav.ui.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	card.add_child(col)
	Ui.label(col, "ACHIEVEMENT", "Heading")
	var name := Ui.label(col, a.get("name", id))
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.reset_size()
	var view := Nav.ui_view()
	var rest := Vector2(view.x - 4.0 - card.size.x, view.y - ABOVE - card.size.y).round()
	card.position = Vector2(view.x + 2.0, rest.y)
	var now := Time.get_ticks_msec() / 1000.0
	var wait := maxf(0.0, _free_at - now)
	_free_at = now + wait + 3.8
	card.set_meta("rest", rest)
	card.set_meta("wait", wait)
	var tw := card.create_tween()
	tw.tween_interval(wait)
	tw.tween_callback(func(): Audio.play("pond_bell", -6.0))
	tw.tween_property(card, "position:x", rest.x, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.0)
	tw.tween_property(card, "position:x", view.x + 2.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(card.queue_free)
