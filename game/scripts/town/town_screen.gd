extends Node2D
## The harbour town: a street of buildings, each opening its shop or the order board when clicked, with townsfolk
## walking past who have gossip to share, and clients waiting with their requests.

const ART := "res://assets/art/town/"
const BUILDINGS := {"market": "The fish market", "netmaker": "The netmaker", "boatwright": "The boatwright",
	"board": "The harbour board", "goldsmith": "The goldsmith"}
## Where people's feet are on the paving, and where waiting clients stand.
const STREET_Y := 250.0
const CLIENT_SPOTS := [146.0, 318.0]
const PEOPLE := "res://assets/art/people/"

var hovered := ""
var _masks := {}
var _outlines := {}
var _folk: Array = []
var _clients: Array = []
var _bubble: Label
var _rng: RandomNumberGenerator
var _top: Label
var _sleep: Button
var _painter: Node2D
var _stage: Node2D


func enter(args: Dictionary) -> void:
	Controls.ensure()
	if Game.state.is_empty():
		Game.new_game("Marcus", "")
	_rng = Seeds.rng(int(Game.state["seed"]), "town", Clock.day_of(float(Game.state["time"])))
	_stage = Node2D.new()
	add_child(_stage)
	if ResourceLoader.exists(ART + "street.png"):
		_stage.add_child(Backdrop.new(load(ART + "street.png")))
	Windowing.view_changed.connect(_place)
	_place()
	var spots := {}
	if FileAccess.file_exists(ART + "town.json"):
		spots = JSON.parse_string(FileAccess.get_file_as_string(ART + "town.json"))
	for id in BUILDINGS:
		var path: String = ART + id + ".png"
		if not ResourceLoader.exists(path) or not spots.has(id):
			continue
		var b := Sprite2D.new()
		b.texture = load(path)
		b.centered = false
		b.position = Vector2(spots[id][0], spots[id][1])
		_stage.add_child(b)
		var img: Image = b.texture.get_image()
		var used := img.get_used_rect()
		_masks[id] = {"image": img, "at": b.position, "rect": Rect2(b.position + Vector2(used.position), used.size)}
		_outlines[id] = _outline(img, b.position)
	_painter = Node2D.new()
	_painter.draw.connect(_draw_over)
	_painter.z_index = 2
	_stage.add_child(_painter)
	_spawn_folk()
	_place_clients()
	_build_ui()
	Game.state["stats"]["town_visits"] = int(Game.state["stats"].get("town_visits", 0)) + 1
	Game.changed.connect(_refresh_ui)
	if args.get("slept", false):
		Toast.say("You sleep at the inn and wake at dawn.")


func _build_ui() -> void:
	var bar := PanelContainer.new()
	bar.position = Vector2(4, 4)
	Nav.ui.add_child(bar)
	_top = Ui.label(bar, "")
	var back := Ui.button(Nav.ui, "Back to the boat", func(): Nav.go("coast", {"place": "harbour", "boat_x": 110.0}))
	Ui.hang(back, "bottom_right", Vector2(4, 4), Vector2(108, 18))
	var ponds := Ui.button(Nav.ui, "To the ponds", func(): Nav.go("shore"))
	Ui.hang(ponds, "bottom_right", Vector2(116, 4), Vector2(88, 18))
	_sleep = Ui.button(Nav.ui, "Sleep till dawn", _sleep_now)
	Ui.hang(_sleep, "bottom_right", Vector2(208, 4), Vector2(88, 18))
	if not Dev.has("no-hud"):
		GuideNote.add(self, "town")
	_refresh_ui()
	# --shop=market, netmaker, boatwright or goldsmith opens that shop, for screenshots.
	match Dev.get_arg("shop"):
		"market":
			ShopPanel.market()
		"netmaker":
			ShopPanel.netmaker()
		"boatwright":
			ShopPanel.boatwright()
		"goldsmith":
			ShopPanel.goldsmith()


## A night at the inn: the pots fill, the ponds and tanks have their morning, and the day starts fresh.
func _sleep_now() -> void:
	World.sleep(Game.state, Seeds.rng(int(Game.state["seed"]), "sleep", Clock.day_of(float(Game.state["time"]))))
	Audio.play("click", -6.0)
	Game.changed.emit()
	Nav.go("town", {"slept": true})


## Where a lesson of the guide points, in interface pixels: one of the buildings, or nothing.
func guide_target(id: String) -> Rect2:
	if not _masks.has(id):
		return Rect2()
	var r: Rect2 = _masks[id]["rect"]
	return Rect2(r.position + _stage.position, r.size)


func _place() -> void:
	if is_instance_valid(_stage):
		_stage.position = Nav.offset()


func _refresh_ui() -> void:
	if not is_instance_valid(_top):
		return
	var day := Clock.day_of(float(Game.state["time"]))
	_sleep.visible = Clock.hour(float(Game.state["time"])) >= 16.0 or Clock.is_night(float(Game.state["time"]))
	var ch: Dictionary = Data.chapters[int(Game.state["chapter"]) - 1]
	_top.text = "%s   Day %d, %s   %s: name %d   Hold %d/%d" % [Ui.coins_text(int(Game.state["denarii"])), day + 1,
		Clock.season(day), ch["name"], int(Game.state["reputation"]), Game.state["hold"].size(),
		int(Data.boats[Game.state["boat"]]["hold"])]


## The pixels just outside a building's edge, drawn in gold when the mouse is over it.
func _outline(img: Image, at: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and img.get_pixelv(q).a > 0.5:
					out.append(at + Vector2(x, y))
					break
	return out


## The townsfolk who walk the street, each with their walk and a standing pose for when they stop to talk.
func _spawn_folk() -> void:
	var ids := Data.townsfolk.keys().filter(func(id): return ResourceLoader.exists(PEOPLE + id + "/walk_east/frame_00.png"))
	ids.shuffle()
	for i in mini(5, ids.size()):
		var walk: Array[Texture2D] = []
		for k in 12:
			var path := PEOPLE + "%s/walk_east/frame_%02d.png" % [ids[i], k]
			if not ResourceLoader.exists(path):
				break
			walk.append(load(path))
		var s := Sprite2D.new()
		s.texture = walk[0]
		s.centered = false
		s.z_index = 1
		_stage.add_child(s)
		_folk.append({"id": ids[i], "sprite": s, "walk": walk, "stand": load(PEOPLE + ids[i] + "/east.png"),
			"x": _rng.randf_range(20, 420), "dir": -1.0 if _rng.randf() < 0.5 else 1.0, "speed": _rng.randf_range(12, 18),
			"pause": 0.0, "phase": _rng.randf() * 8.0})


## Clients with something to ask stand in the street; at most two come to town on any one day.
func _place_clients() -> void:
	var waiting := Story.visiting(Game.state, Clock.day_of(float(Game.state["time"])))
	for i in waiting.size():
		var path: String = PEOPLE + waiting[i] + "/south.png"
		if not ResourceLoader.exists(path):
			continue
		var pic := Sprite2D.new()
		pic.texture = load(path)
		pic.centered = false
		pic.position = Vector2(CLIENT_SPOTS[i] - 24.0, STREET_Y - 46.0)
		pic.z_index = 2
		_stage.add_child(pic)
		_clients.append({"id": waiting[i], "x": CLIENT_SPOTS[i], "sprite": pic})


func _process(delta: float) -> void:
	World.advance(Game.state, delta / 60.0, _rng)
	Audio.set_ambience({"market": 0.5, "gulls": 0.2})
	var light := Color.WHITE.lerp(SkyView.light(Clock.hour(float(Game.state["time"]))), 0.5)
	modulate = light
	for f in _folk:
		var s: Sprite2D = f["sprite"]
		if f["pause"] > 0.0:
			f["pause"] -= delta
		else:
			f["x"] += f["dir"] * f["speed"] * delta
			if f["x"] < -8.0 or f["x"] > 440.0:
				f["dir"] = -f["dir"]
			if _rng.randf() < delta * 0.08:
				f["pause"] = _rng.randf_range(1.5, 4.0)
		var walking: bool = f["pause"] <= 0.0
		f["phase"] += delta * 9.0 if walking else 0.0
		s.texture = f["walk"][int(f["phase"]) % f["walk"].size()] if walking else f["stand"]
		s.flip_h = f["dir"] < 0.0
		s.position = Vector2(roundf(f["x"]), STREET_Y - 46.0)
	var mouse := _stage.get_local_mouse_position()
	hovered = "" if Ui.window_open() else _building_at(mouse)
	_painter.queue_redraw()


func _building_at(at: Vector2) -> String:
	var ids := _masks.keys()
	ids.reverse()
	for id in ids:
		var img: Image = _masks[id]["image"]
		var p := Vector2i(at - _masks[id]["at"])
		if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() and img.get_pixelv(p).a > 0.5:
			return id
	return ""


func _draw_over() -> void:
	if hovered != "":
		for p in _outlines[hovered]:
			_painter.draw_rect(Rect2(p, Vector2.ONE), UiTheme.GOLD)
		var name: String = BUILDINGS[hovered]
		var font := UiTheme.title_font()
		var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var at := _stage.get_local_mouse_position() + Vector2(-w / 2.0, -10)
		_painter.draw_rect(Rect2(at + Vector2(-3, -8), Vector2(w + 6, 11)), Color(UiTheme.INK, 0.85))
		_painter.draw_string(font, at, name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.CREAM)
	# A gold mark bobs over each client who has something to ask.
	for c in _clients:
		var bob := roundf(sin(Time.get_ticks_msec() / 300.0) * 1.5)
		var at := Vector2(c["x"] - 2.0, STREET_Y - 46.0 + bob)
		_painter.draw_rect(Rect2(at + Vector2(-3, -9), Vector2(10, 11)), Color(UiTheme.INK, 0.8))
		_painter.draw_string(UiTheme.title_font(), at + Vector2(0, 0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.GOLD)


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or Ui.window_open():
		return
	var at: Vector2 = _stage.get_local_mouse_position()
	for c in _clients:
		if Rect2(Vector2(c["x"] - 12.0, STREET_Y - 40.0), Vector2(24, 40)).has_point(at):
			ClientVisit.open(c["id"])
			return
	for f in _folk:
		var s: Sprite2D = f["sprite"]
		if Rect2(s.position + Vector2(12, 8), Vector2(24, 40)).has_point(at):
			_gossip(f)
			return
	match _building_at(at):
		"market":
			ShopPanel.market()
		"netmaker":
			ShopPanel.netmaker()
		"boatwright":
			ShopPanel.boatwright()
		"goldsmith":
			ShopPanel.goldsmith()
		"board":
			BoardPanel.open()


## A line from a townsperson: something of their own, a hint about a fish, or a legend's clue.
func _gossip(f: Dictionary) -> void:
	f["pause"] = 3.0
	var person: Dictionary = Data.townsfolk[f["id"]]
	var line: String = person["lines"][_rng.randi() % person["lines"].size()]
	var roll := _rng.randf()
	var legends := Data.fish.values().filter(func(x): return x["legend"] and not Game.state["legends"].has(x["id"]))
	if roll < 0.3 and not legends.is_empty():
		line = "They say %s" % str(legends[_rng.randi() % legends.size()]["clue"]).to_lower()
	elif roll < 0.6:
		line = Gossip.habit(Game.state, _rng)
	Toast.say("%s the %s: \"%s\"" % [person["name"], person["trade"], line])
