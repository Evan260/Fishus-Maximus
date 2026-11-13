class_name GuideNote
extends PanelContainer
## Old Rufus in the top right corner with the lesson for this screen: his face, his advice, Got it and Skip the
## guide, and an arrow bobbing over the thing to click. He steps aside while a window is open or in the strip, and when
## the last lesson is learned he says goodbye once.

const PORTRAIT := "res://assets/art/portraits/rufus.png"
## Narrow enough to sit beside the boat's panel in the top left corner.
const WIDTH := 190.0
## How long a word of praise and the goodbye stay before he moves on, in seconds.
const PRAISE_SECONDS := 7.0
const FAREWELL_SECONDS := 14.0

var screen: Node
var screen_name := ""
var _text: Label
## The lesson with the controller's buttons drawn in it, shown instead of `_text` while the controller is in use.
var _rich: RichTextLabel
var _arrow: Control
var _shown := ""
var _last := ""
var _praise := ""
var _praise_left := 0.0
var _farewell_left := -1.0
var _wait := 0.0
var _t := 0.0


## Puts him on a screen, named as the lessons name it ("coast" or "town"), which answers guide_target(id) with where a
## lesson's target is.
static func add(on: Node, name: String) -> GuideNote:
	var g := GuideNote.new()
	g.screen = on
	g.screen_name = name
	Nav.ui.add_child(g)
	return g


static func find() -> GuideNote:
	if not Nav.ui:
		return null
	for c in Nav.ui.get_children():
		if c is GuideNote and not c.is_queued_for_deletion():
			return c
	return null


func _ready() -> void:
	visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	add_child(row)
	var face := TextureRect.new()
	if ResourceLoader.exists(PORTRAIT):
		var crop := AtlasTexture.new()
		crop.atlas = load(PORTRAIT)
		crop.region = Rect2(8, 2, 48, 48)
		face.texture = crop
	face.custom_minimum_size = Vector2(48, 48)
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(face)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	_text = Ui.label(col, "")
	_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(WIDTH, 0)
	_rich = RichTextLabel.new()
	_rich.bbcode_enabled = true
	_rich.fit_content = true
	_rich.scroll_active = false
	_rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rich.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rich.add_theme_color_override("default_color", UiTheme.INK)
	_rich.add_theme_constant_override("line_separation", 0)
	_rich.visible = false
	col.add_child(_rich)
	col.move_child(_rich, _text.get_index() + 1)
	var buttons := HBoxContainer.new()
	col.add_child(buttons)
	var name := Ui.label(buttons, "Old Rufus", "MutedLabel")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.button(buttons, "Skip the guide", skip)
	Ui.button(buttons, "Got it", got_it)
	_arrow = Control.new()
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.draw.connect(_draw_arrow)
	_arrow.visible = false
	add_child(_arrow)
	_arrow.top_level = true
	refresh()


func _process(delta: float) -> void:
	_t += delta
	# Praise and the goodbye only run down while they can be read.
	if visible:
		_praise_left -= delta
		if _farewell_left > 0.0:
			_farewell_left -= delta
			if _farewell_left <= 0.0:
				_say_goodbye()
	_wait -= delta
	if _wait <= 0.0:
		_wait = 0.25
		refresh()
	if _arrow.visible:
		_place_arrow()


## Works out what he has to say on this screen now, and shows or hides him.
func refresh() -> void:
	var say := ""
	var id := ""
	if Settings.guide and not Game.state.is_empty():
		var step := Guide.step(Game.state)
		var now := str(step.get("id", ""))
		if now != _last:
			var before := Guide.lesson(_last)
			if before.has("praise") and Guide.met(Game.state, before["done"]):
				_praise = str(before["praise"])
				_praise_left = PRAISE_SECONDS
			_last = now
		if _praise_left > 0.0:
			say = tr(_praise)
			id = "praise " + _praise
		elif not step.is_empty() and step["screen"] == screen_name:
			say = Controls.fill_pad(tr(step["text"])) if Pad.active else Controls.fill(tr(step["text"]))
			id = now
		elif Guide.farewell_due(Game.state):
			say = tr(str(Data.guide.get("farewell", "")))
			id = "farewell"
			if _farewell_left < 0.0:
				_farewell_left = FAREWELL_SECONDS
	var away := Windowing.strip or Ui.window_open() or CatchCard.is_open()
	_shown = id
	var was := visible
	# What he was told to put away is kept with the game, so it stays away on every screen until he has news.
	visible = say != "" and id != str(Game.state.get("_guide_dismissed", "")) and not away
	var big := Settings.message_scale()
	var rich := say.contains("[img")
	if _text.text != say or _rich.visible != rich or _text.custom_minimum_size.x != WIDTH * big:
		_text.text = say
		_text.custom_minimum_size.x = WIDTH * big
		_text.add_theme_font_size_override("font_size", UiTheme.text_size() * big)
		_text.visible = not rich
		_rich.visible = rich
		_rich.text = say if rich else ""
		_rich.custom_minimum_size.x = WIDTH * big
		_rich.add_theme_font_override("normal_font", UiTheme.body_font())
		_rich.add_theme_font_size_override("normal_font_size", UiTheme.text_size() * big)
		reset_size()
	Ui.hang(self, "top_right", Vector2(4, _top()))
	_arrow.visible = visible and target_rect().has_area()
	if visible != was:
		Toast.place()


## How far down he stands: under the pictures in the top right corner, or under the panel in the top left corner too
## when the interface is too narrow for him beside it.
func _top() -> float:
	var y := 38.0
	var mine := Rect2(Nav.ui_view().x - 4.0 - size.x, y, size.x, size.y)
	for p in Nav.ui.find_children("*", "PanelContainer", true, false):
		var r: Rect2 = p.get_global_rect()
		if p != self and r.position == Vector2(4, 4) and p.is_visible_in_tree() and r.intersects(mine):
			y = maxf(y, r.end.y + 3.0)
	return y


## The rect, in interface pixels, of what the lesson asks the player to click, or an empty one.
func target_rect() -> Rect2:
	var step := Guide.lesson(_shown)
	if step.is_empty() or not step.has("target") or not screen or not screen.has_method("guide_target"):
		return Rect2()
	return screen.guide_target(str(step["target"]))


func text() -> String:
	return _text.text


## Puts this piece of advice away until he has something new to say.
func got_it() -> void:
	Game.state["_guide_dismissed"] = _shown
	if _shown == "farewell":
		_say_goodbye()
	refresh()


## Turns the guide off; the settings can turn it back on.
func skip() -> void:
	Settings.set_value("guide", false)
	refresh()


func _say_goodbye() -> void:
	Guide.progress(Game.state)["finished"] = true
	_farewell_left = -1.0


## The arrow sits over its target and bobs, or under it when the target is at the top of the view.
func _place_arrow() -> void:
	var r := target_rect()
	var below := r.position.y < 24.0
	var bob := 0.0 if Settings.reduced_motion else roundf(sin(_t * 5.0) * 2.0)
	_arrow.size = Vector2(19, 13)
	_arrow.position = Vector2(roundf(r.get_center().x - 9.0), r.end.y + 2.0 - bob if below else r.position.y - 15.0 + bob)
	_arrow.set_meta("up", below)
	_arrow.queue_redraw()


func _draw_arrow() -> void:
	var up: bool = _arrow.get_meta("up", false)
	var flip := func(p: Vector2) -> Vector2: return Vector2(p.x, 13.0 - p.y) if up else p
	# A pale rim round the dark edge keeps the arrow clear over rock and dark water alike.
	for layer in [[0.0, UiTheme.CREAM], [1.5, UiTheme.INK], [3.0, UiTheme.GOLD]]:
		var k: float = layer[0]
		var points := PackedVector2Array([Vector2(k * 1.4, k * 0.8), Vector2(19.0 - k * 1.4, k * 0.8), Vector2(9.5, 13.0 - k * 1.3)].map(flip))
		Pixels.polygon(_arrow, points, layer[1], Vector2.ZERO)
