class_name AchievementCard
## A small card that slides in from the right, in the bottom right corner, when an achievement is earned. Several
## earned at once take turns, and none slides in while a landed fish's banner is hung out, which it would cover.

const WIDTH := 150.0
## How far above the bottom edge the card rests: clear of the buttons along the bottom of every screen.
const ABOVE := 4.0 + 30.0 + 4.0

## The cards waiting their turn, and whether one is on screen or waiting for the banner to go.
static var _queue: Array = []
static var _busy := false


static func show_earned(id: String) -> void:
	# Pictures taken with --no-hud show the scene alone.
	if Nav.ui == null or Dev.has("no-hud"):
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
	card.set_meta("rest", rest)
	_queue.append(card)
	if not _busy:
		_next()


## Slides in the next card waiting, once no banner is hung out; each card that goes, however it goes, calls the next.
static func _next() -> void:
	_busy = false
	while not _queue.is_empty() and (not is_instance_valid(_queue[0]) or _queue[0].is_queued_for_deletion()):
		_queue.pop_front()
	if _queue.is_empty() or Nav.ui == null:
		return
	_busy = true
	if CatchCard.is_open():
		Nav.get_tree().create_timer(0.25).timeout.connect(func(): _next())
		return
	var card: Control = _queue.pop_front()
	card.set_meta("shown", true)
	card.tree_exiting.connect(func(): _next(), CONNECT_ONE_SHOT)
	var rest: Vector2 = card.get_meta("rest")
	Audio.play("pond_bell", -6.0)
	var tw := card.create_tween()
	tw.tween_property(card, "position:x", rest.x, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.0)
	tw.tween_property(card, "position:x", card.position.x, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(card.queue_free)
