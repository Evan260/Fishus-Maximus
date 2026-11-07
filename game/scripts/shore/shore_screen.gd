extends Node2D
## The shore below the villa: the garum works above the terrace, and the six ponds cut into the terrace wall, each
## seen through the stone as if cut away.

const ART := "res://assets/art/shore/"
const WALL_TOP := 134.0
const GARUM := Rect2(300, 24, 180, 110)

var views: Array = []
var _rng: RandomNumberGenerator
var _top: Label
var _hover := -2
var _painter: Node2D
var _stage: Node2D


func enter(_args: Dictionary) -> void:
	Controls.ensure()
	if Game.state.is_empty():
		Game.new_game("Marcus", "")
	_rng = Seeds.rng(int(Game.state["seed"]), "shore", Clock.day_of(float(Game.state["time"])))
	_stage = Node2D.new()
	add_child(_stage)
	for name in ["back", "wall"]:
		if ResourceLoader.exists(ART + name + ".png"):
			var b := Backdrop.new(load(ART + name + ".png"))
			b.position = Vector2(0, 0 if name == "back" else WALL_TOP)
			# The view above carries on into sky, and below into more wall, never the other picture.
			for c in b.get_children():
				if (name == "back" and c.position.y > 0.0) or (name == "wall" and c.position.y < 0.0):
					c.queue_free()
			_stage.add_child(b)
	Windowing.view_changed.connect(_place)
	_place()
	for site in 6:
		var v := PondView.new()
		v.site = site
		v.position = window(site).position
		_stage.add_child(v)
		v.sync()
		views.append(v)
	_painter = Node2D.new()
	_painter.draw.connect(_draw_over)
	_painter.z_index = 2
	_stage.add_child(_painter)
	var bar := PanelContainer.new()
	bar.position = Vector2(4, 4)
	Nav.ui.add_child(bar)
	_top = Ui.label(bar, "")
	var back := Ui.button(Nav.ui, "Back to town", func(): Nav.go("town"))
	Ui.hang(back, "bottom_right", Vector2(4, 4), Vector2(90, 18))
	Game.changed.connect(_refresh)
	_refresh()


## Where a pond's window is cut into the terrace wall.
static func window(site: int) -> Rect2:
	return Rect2(Vector2(12 + site * 76, WALL_TOP + 26), PondView.SIZE)


func _place() -> void:
	if is_instance_valid(_stage):
		_stage.position = Nav.offset()


func _refresh() -> void:
	if is_instance_valid(_top):
		_top.text = "%s   Ponds %d of %d   Salt %d" % [Ui.coins_text(int(Game.state["denarii"])), Game.state["ponds"].size(),
			Ponds.allowed(Game.state), int(Game.state.get("salt", 0))]


func _process(delta: float) -> void:
	World.advance(Game.state, delta / 60.0, _rng)
	Audio.set_ambience({"sea": 0.5, "gulls": 0.3})
	modulate = Color.WHITE.lerp(SkyView.light(Clock.hour(float(Game.state["time"]))), 0.5)
	_hover = -2 if Ui.window_open() else _thing_at(_stage.get_local_mouse_position())
	_painter.queue_redraw()


func _thing_at(at: Vector2) -> int:
	if GARUM.has_point(at):
		return -1
	for site in 6:
		if window(site).grow(3).has_point(at):
			return site
	return -2


func _draw_over() -> void:
	for site in 6:
		var r := window(site)
		var built := Ponds.site_of(Game.state, site) >= 0
		if built:
			# The stone lip and inner shadow of a basin cut into the wall.
			_painter.draw_rect(Rect2(r.position - Vector2(3, 3), Vector2(r.size.x + 6, 3)), Color("#e8dcc0"))
			_painter.draw_rect(Rect2(r.position - Vector2(3, 0), Vector2(3, r.size.y + 3)), Color("#8a7a62"))
			_painter.draw_rect(Rect2(r.position + Vector2(r.size.x, 0), Vector2(3, r.size.y + 3)), Color("#6e5f4a"))
			_painter.draw_rect(Rect2(r.position + Vector2(-3, r.size.y), Vector2(r.size.x + 6, 3)), Color("#5a4c3a"))
		if _hover == site:
			var label := str(Data.ponds["sites"][site]["name"]) if built else ("Cut a pond here" if Game.state["ponds"].size() < Ponds.allowed(Game.state) else "Not yet")
			_tip(r.position + Vector2(r.size.x / 2.0, -6), label)
			_painter.draw_rect(r.grow(4), UiTheme.GOLD, false, 1.0)
	if _hover == -1:
		_painter.draw_rect(GARUM, UiTheme.GOLD, false, 1.0)
		_tip(GARUM.position + Vector2(GARUM.size.x / 2.0, 10), "The garum works")


func _tip(at: Vector2, text: String) -> void:
	var font := UiTheme.title_font()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	_painter.draw_rect(Rect2(at + Vector2(-w / 2.0 - 3, -8), Vector2(w + 6, 11)), Color(UiTheme.INK, 0.85))
	_painter.draw_string(font, at + Vector2(-w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.CREAM)


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or Ui.window_open():
		return
	var thing := _thing_at(_stage.get_local_mouse_position())
	if thing == -1:
		GarumPanel.open()
	elif thing >= 0:
		PondPanel.open(thing, views[thing])
