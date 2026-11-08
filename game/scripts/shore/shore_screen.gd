extends Node2D
## The shore below the villa: the garum works above, and below the grass a cut through the ground showing the six pond
## sites, each either a stone-lined basin of water with its fish, or a plot marked out with pegs and rope.

const ART := "res://assets/art/shore/"
const WALL_TOP := 134.0
const GARUM := Rect2(300, 24, 180, 110)

var views: Array = []
var _rng: RandomNumberGenerator
var _top: Label
var _hover := -2
var _painter: Node2D
var _stage: Node2D
var _lining: Texture2D


func enter(_args: Dictionary) -> void:
	Controls.ensure()
	if Game.state.is_empty():
		Game.new_game("Marcus", "")
	_rng = Seeds.rng(int(Game.state["seed"]), "shore", Clock.day_of(float(Game.state["time"])))
	_stage = Node2D.new()
	add_child(_stage)
	_lining = load(ART + "wall.png")
	for name in ["back", "ground"]:
		if ResourceLoader.exists(ART + name + ".png"):
			var b := Backdrop.new(load(ART + name + ".png"))
			# The grass along the ground's top stands in front of the terrace, so the gaps between its blades show stone.
			b.position = Vector2(0, 0 if name == "back" else WALL_TOP - 13.0)
			# The view above carries on into sky, and below into more ground, never the other picture.
			for c in b.get_children():
				if (name == "back" and c.position.y > 0.0) or (name == "ground" and c.position.y < 0.0):
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


## Where a pond's basin is dug into the ground, its water starting just below the grass.
static func window(site: int) -> Rect2:
	return Rect2(Vector2(12 + site * 76, WALL_TOP + 20), PondView.SIZE)


func _place() -> void:
	if is_instance_valid(_stage):
		_stage.transform = Nav.cover()


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
			# The basin's lining of cut stone, from the grass down its sides and across its floor.
			var lip := 4.0
			_painter.draw_texture_rect_region(_lining, Rect2(r.position + Vector2(-lip, -6), Vector2(lip, r.size.y + 6 + lip)), Rect2(site * 40, 0, lip, r.size.y + 6 + lip))
			_painter.draw_texture_rect_region(_lining, Rect2(r.position + Vector2(r.size.x, -6), Vector2(lip, r.size.y + 6 + lip)), Rect2(site * 40 + 20, 0, lip, r.size.y + 6 + lip))
			_painter.draw_texture_rect_region(_lining, Rect2(r.position + Vector2(0, r.size.y), Vector2(r.size.x, lip)), Rect2(site * 30, 60, r.size.x, lip))
			_painter.draw_rect(Rect2(r.position + Vector2(-lip, -7), Vector2(r.size.x + 2 * lip, 2)), Color("#e8dcc0"))
		else:
			# An empty site is a plot marked out on the grass with two pegs and a rope.
			var y := WALL_TOP + 12.0
			for px in [r.position.x + 4.0, r.end.x - 6.0]:
				_painter.draw_rect(Rect2(px, y - 13, 3, 14), Color("#6b4526"))
				_painter.draw_rect(Rect2(px, y - 13, 1, 14), Color("#a87a4a"))
				_painter.draw_rect(Rect2(px, y - 14, 3, 1), Color("#c79a62"))
			for k in int(r.size.x - 10):
				var sag := sin(float(k) / (r.size.x - 10) * PI) * 3.0
				_painter.draw_rect(Rect2(r.position.x + 7 + k, roundf(y - 11 + sag), 1, 1), Color("#f0dca8"))
				_painter.draw_rect(Rect2(r.position.x + 7 + k, roundf(y - 10 + sag), 1, 1), Color("#a8845a"))
		if _hover == site:
			var label := str(Data.ponds["sites"][site]["name"]) if built else ("Dig a pond here" if Game.state["ponds"].size() < Ponds.allowed(Game.state) else "Not yet")
			_tip(r.position + Vector2(r.size.x / 2.0, -14), label)
			_painter.draw_rect(r.grow(5), UiTheme.GOLD, false, 1.0)
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
