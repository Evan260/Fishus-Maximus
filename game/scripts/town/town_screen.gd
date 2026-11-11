extends Node2D
## The harbour town: a street of buildings, each opening its shop or the order board when clicked, with townsfolk
## walking past who have gossip to share, and clients waiting with their requests.

const ART := "res://assets/art/town/"
const BUILDINGS := {"market": "The fish market", "netmaker": "The netmaker", "boatwright": "The boatwright",
	"board": "The harbour board", "goldsmith": "The goldsmith"}
## The row behind the wall where the live sky meets the sea.
const HORIZON := 104.0
## Where people's feet are on the paving, and where waiting clients stand.
const STREET_Y := 250.0
const CLIENT_SPOTS := [146.0, 318.0]
const PEOPLE := "res://assets/art/people/"
const AROUND := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
## Where the townsfolk turn back: past the harbour board at the left, so they never stand in front of it.
const WALK := Vector2(92.0, 440.0)
## The flames of the town's lamps, in the scene's pixels: the lantern in the goldsmith's stall, the hall's lantern on
## its left post, and the oil lamp hanging under the fish market's awning.
const LAMPS := [Vector2(394.5, 175.5), Vector2(40.5, 159.5), Vector2(103.5, 153.5)]
## The green of the light at night, when the lamps burn their brightest.
const NIGHT_GREEN := 0.5

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
## The street, the buildings and the people, lit by the hour; the gold outline and the names over them stay bright.
var _lit: Node2D
var _street: Sprite2D
var _sky: AshoreSky
var lamps: Array[Lamp] = []
## Seconds since the street opened, which the lamps' flames waver by.
var _clock := 0.0
## How far the street picture is painted past the 480 by 270 scene on each side.
var margin := Vector2.ZERO


## Escape and the pad's B go back to the boat, as Back to the boat does.
func go_back() -> bool:
	Nav.go("coast", {"place": "harbour", "boat_x": 110.0})
	return true


func enter(args: Dictionary) -> void:
	Controls.ensure()
	if Game.state.is_empty():
		Game.new_game("Marcus", "")
	if Dev.has("hour"):
		Game.state["time"] = Clock.at_hour(float(Game.state["time"]), Dev.num("hour", 12.0))
	_rng = Seeds.rng(int(Game.state["seed"]), "town", Clock.day_of(float(Game.state["time"])))
	_sky = AshoreSky.new(HORIZON)
	add_child(_sky)
	_stage = Node2D.new()
	add_child(_stage)
	_lit = Node2D.new()
	_stage.add_child(_lit)
	if ResourceLoader.exists(ART + "street.png"):
		_street = Sprite2D.new()
		_street.texture = load(ART + "street.png")
		_street.centered = false
		margin = ((_street.texture.get_size() - Nav.SIZE) / 2.0).floor()
		_street.position = -margin
		_lit.add_child(_street)
	for at in LAMPS:
		var lamp := Lamp.new()
		lamp.position = at
		lamp.radius = 50.0
		# Lamplight adds to the street's own colour, which the night has already dimmed, so it burns strong.
		lamp.power = 2.2
		lamp.halo_size = 12.0
		_stage.add_child(lamp)
		lamps.append(lamp)
	Windowing.view_changed.connect(_place)
	_place()
	_relight()
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
		_lit.add_child(b)
		var img: Image = b.texture.get_image()
		var used := img.get_used_rect()
		_masks[id] = {"image": img, "at": b.position, "rect": Rect2(b.position + Vector2(used.position), used.size)}
		_outlines[id] = _outline(img, b.position)
	_painter = Node2D.new()
	_painter.draw.connect(_draw_over)
	_painter.z_index = 2
	_painter.light_mask = 0
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
	# Each button is as wide as its words need, and the next one stands to its left.
	var right := 4.0
	var back := Ui.button(Nav.ui, "Back to the boat", go_back)
	Ui.hang(back, "bottom_right", Vector2(right, 4), Vector2(108, 18))
	right += maxf(108.0, back.get_combined_minimum_size().x) + 4.0
	var ponds := Ui.button(Nav.ui, "To the pond", func(): Nav.go("shore"))
	Ui.hang(ponds, "bottom_right", Vector2(right, 4), Vector2(88, 18))
	right += maxf(88.0, ponds.get_combined_minimum_size().x) + 4.0
	_sleep = Ui.button(Nav.ui, "Sleep till dawn", _sleep_now)
	Ui.hang(_sleep, "bottom_right", Vector2(right, 4), Vector2(88, 18))
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


## A night at the inn: the pots fill, the pond and tanks have their morning, and the day starts fresh.
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
	return Nav.rect_to_ui(Rect2(_stage.transform * r.position, r.size * _stage.scale))


func _place() -> void:
	if is_instance_valid(_stage):
		_stage.transform = Nav.cover(margin)
	_refresh_ui()


## Lays the live sky behind the street and lights the street for the hour and the weather, and the lamps the more the
## darker it is, each flame wavering on its own.
func _relight() -> void:
	var light := _sky.follow(_stage.transform)
	_lit.modulate = light
	var dark := clampf((1.0 - light.g) / (1.0 - NIGHT_GREEN), 0.0, 1.0)
	for i in lamps.size():
		var t := _clock + i * 2.3
		lamps[i].shine((0.2 + 0.8 * dark) * (0.85 + 0.1 * sin(t * 9.0) + 0.05 * sin(t * 23.0)))


func _refresh_ui() -> void:
	if not is_instance_valid(_top):
		return
	var day := Clock.day_of(float(Game.state["time"]))
	_sleep.visible = Clock.hour(float(Game.state["time"])) >= 16.0 or Clock.is_night(float(Game.state["time"]))
	var ch: Dictionary = Data.chapters[int(Game.state["chapter"]) - 1]
	var first := "%s   %s" % [Ui.coins_text(int(Game.state["denarii"])), tr("Day %d, %s") % [day + 1, tr(Clock.season(day))]]
	var second := "%s   %s" % [tr("%s: name %d") % [tr(ch["name"]), int(Game.state["reputation"])],
		tr("Hold %d/%d") % [Game.state["hold"].size(), int(Data.boats[Game.state["boat"]]["hold"])]]
	var line := first + "   " + second
	# A larger interface can leave too little room across for one line, so the chapter and the hold then go on a second.
	if UiTheme.body_font().get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.text_size()).x + 24.0 > Nav.ui_view().x:
		line = first + "\n" + second
	_top.text = line
	_top.get_parent().reset_size()


## The pixels touching a building on a side or a corner, past its picture's edges too, drawn in gold round it on hover.
func _outline(img: Image, at: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for y in range(-1, img.get_height() + 1):
		for x in range(-1, img.get_width() + 1):
			var p := Vector2i(x, y)
			if _solid(img, p):
				continue
			for d in AROUND:
				if _solid(img, p + d):
					out.append(at + Vector2(p))
					break
	return out


## Whether a pixel of a building's picture is the building, which the mouse and the outline both go by.
static func _solid(img: Image, p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() and img.get_pixelv(p).a > 0.5


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
		_lit.add_child(s)
		_folk.append({"id": ids[i], "sprite": s, "walk": walk, "stand": load(PEOPLE + ids[i] + "/east.png"),
			"x": _rng.randf_range(WALK.x, WALK.y - 20.0), "dir": -1.0 if _rng.randf() < 0.5 else 1.0, "speed": _rng.randf_range(12, 18),
			"pause": 0.0, "phase": _rng.randf() * 8.0})


## Clients with something to ask stand in the street; at most two come to town on any one day.
## The clients in the street who still have something to ask, whom the gold mark bobs over.
func marked_clients() -> Array:
	return _clients.map(func(c): return c["id"]).filter(func(id): return not Story.client_step(Game.state, id).is_empty())


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
		_lit.add_child(pic)
		_clients.append({"id": waiting[i], "x": CLIENT_SPOTS[i], "sprite": pic})


func _process(delta: float) -> void:
	World.advance(Game.state, delta / 60.0, _rng)
	# --talk has the first townsperson stop in the middle of the street and speak, for screenshots.
	if Dev.has("talk") and not _folk.is_empty() and not has_meta("talked") and Time.get_ticks_msec() > 1500:
		set_meta("talked", true)
		_folk[0]["x"] = 200.0
		_gossip(_folk[0])
	Audio.set_ambience({"market": 0.5, "gulls": 0.2})
	# The top bar and the bed follow the hour and the hold, which change while you stay in town.
	if floori(_clock + delta) > floori(_clock):
		_refresh_ui()
	_clock += delta
	_relight()
	for f in _folk:
		var s: Sprite2D = f["sprite"]
		if f["pause"] > 0.0:
			f["pause"] -= delta
		else:
			f["x"] += f["dir"] * f["speed"] * delta
			if f["x"] < WALK.x or f["x"] > WALK.y:
				f["dir"] = -f["dir"]
			if _rng.randf() < delta * 0.08:
				f["pause"] = _rng.randf_range(1.5, 4.0)
		var walking: bool = f["pause"] <= 0.0
		f["phase"] += delta * 9.0 if walking else 0.0
		s.texture = f["walk"][int(f["phase"]) % f["walk"].size()] if walking else f["stand"]
		s.flip_h = f["dir"] < 0.0
		# The standing picture is smaller than the walking ones, so it is set down on the same feet.
		var shift := Vector2.ZERO if walking else _foot(f["walk"][0], s.flip_h) - _foot(s.texture, s.flip_h)
		s.position = Vector2(roundf(f["x"]), STREET_Y - 46.0) + shift
	hovered = "" if Ui.window_open() else _building_at(_pointer())
	_painter.queue_redraw()


## Where the mouse is on the street; --outline=ID holds it over that building, and --outline=none off them all, for screenshots.
func _pointer() -> Vector2:
	if Dev.has("outline"):
		var id := Dev.get_arg("outline")
		return _masks[id]["rect"].get_center() if _masks.has(id) else Vector2(-100, -100)
	return _stage.get_local_mouse_position()


func _building_at(at: Vector2) -> String:
	var ids := _masks.keys()
	ids.reverse()
	for id in ids:
		if _solid(_masks[id]["image"], Vector2i((at - _masks[id]["at"]).floor())):
			return id
	return ""


func _draw_over() -> void:
	if hovered != "":
		for p in _outlines[hovered]:
			_painter.draw_rect(Rect2(p, Vector2.ONE), UiTheme.GOLD)
		var name := tr(BUILDINGS[hovered])
		var w := Ui.tag_width(name)
		var at := _pointer() + Vector2(-w / 2.0, -10)
		# Kept inside the scene, which every window shows whole, so the name of the board at its edge is not cut off.
		at.x = clampf(at.x, 3.0, Nav.SIZE.x - w - 3.0)
		Ui.draw_tag(_painter, at, name)
	# A gold mark bobs over each client who has something to ask.
	for c in _clients.filter(func(c): return c["id"] in marked_clients()):
		var bob := roundf(sin(Time.get_ticks_msec() / 300.0) * 1.5)
		var at := Vector2(c["x"] - 2.0, STREET_Y - 46.0 + bob)
		_painter.draw_rect(Rect2(at + Vector2(-3, -9), Vector2(10, 11)), Color(UiTheme.INK, 0.8))
		_painter.draw_string(UiTheme.name_font(), at + Vector2(0, 0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.GOLD)


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
		var foot := s.position + _foot(s.texture, s.flip_h)
		if Rect2(foot + Vector2(-12, -44), Vector2(24, 44)).has_point(at):
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
## Where a picture of a person stands: the middle of their head and body, which a stride does not move, and the row
## under their feet.
static var _feet := {}


static func _foot(tex: Texture2D, flipped: bool) -> Vector2:
	if not _feet.has(tex):
		var img := tex.get_image()
		var used := img.get_used_rect()
		var upper := img.get_region(Rect2i(used.position, Vector2i(used.size.x, used.size.y / 2))).get_used_rect()
		_feet[tex] = [used.position.x + upper.position.x + (upper.size.x - 1) / 2.0, float(used.end.y), float(used.position.y), float(tex.get_width())]
	var f: Array = _feet[tex]
	return Vector2(f[3] - 1.0 - f[0] if flipped else f[0], f[1])


## The top of a townsperson's head on the screen, for the bubble they speak in.
func head_on_screen(f: Dictionary) -> Vector2:
	var s: Sprite2D = f["sprite"]
	var top := Vector2(_foot(s.texture, s.flip_h).x, _feet[s.texture][2])
	return s.get_global_transform_with_canvas() * top


func _gossip(f: Dictionary) -> void:
	f["pause"] = 4.0
	var person: Dictionary = Data.townsfolk[f["id"]]
	var line: String = person["lines"][_rng.randi() % person["lines"].size()]
	var roll := _rng.randf()
	var legends := Data.fish.values().filter(func(x): return x["legend"] and not Game.state["legends"].has(x["id"]))
	if roll < 0.3 and not legends.is_empty():
		line = str(legends[_rng.randi() % legends.size()]["clue"])
	elif roll < 0.6:
		line = Gossip.habit(Game.state, _rng)
	Ui.speech(head_on_screen(f), tr(line), func(): return head_on_screen(f))
