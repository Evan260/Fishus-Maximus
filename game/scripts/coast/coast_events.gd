class_name CoastEvents
extends Node2D
## The day's events on the water: dolphins leaping and herding the shoals up, the town's great tuna net in the open
## bay during the tuna run, and the Neptunalia fishing contest in the harbour.

const CONTEST_HOURS := [8.0, 12.0]

var screen: Node
var _dolphins: Array = []
var _dolphin: Texture2D = load("res://assets/art/props/dolphin.png") if ResourceLoader.exists("res://assets/art/props/dolphin.png") else null
var _haul_button: Button
var _announced := false


func setup(s: Node) -> void:
	screen = s
	screen.caught.connect(_on_caught)
	refresh()


## Sets out the day's events at this place: on arrival, and again each morning while the boat stays out.
func refresh() -> void:
	for d in _dolphins:
		d["sprite"].queue_free()
	_dolphins.clear()
	if is_instance_valid(_haul_button):
		_haul_button.queue_free()
	_announced = false
	var day := Clock.day_of(float(Game.state["time"]))
	var events := Events.on(day)
	if "dolphins" in events and screen.place_id in ["open_bay", "capri", "misenum"] and _dolphin != null:
		for i in 4:
			var s := Sprite2D.new()
			s.texture = _dolphin
			s.material = Pixels.look()
			s.scale = Vector2.ONE * 0.8
			add_child(s)
			_dolphins.append({"x": randf_range(0, Nav.view().x), "phase": i * 1.7, "speed": randf_range(30, 45), "sprite": s})
	if "tuna_run" in events and screen.place_id == "open_bay" and Nav.ui and int(Game.state.get("tuna_haul_day", -1)) != day:
		_haul_button = Ui.button(Nav.ui, "Join the town's net", _open_haul)
		Ui.hang(_haul_button, "top_right", Vector2(4, 24), Vector2(120, 18))
	if "neptunalia" in events and screen.place_id == "harbour":
		Game.state["contest"] = Game.state.get("contest", {"day": day, "best": 0.0, "fish": "", "done": false})
		if int(Game.state["contest"]["day"]) != day:
			Game.state["contest"] = {"day": day, "best": 0.0, "fish": "", "done": false}


func _announce() -> void:
	_announced = true
	var day := Clock.day_of(float(Game.state["time"]))
	for e in Events.on(day):
		match e:
			"tuna_run":
				Toast.say("The tuna are running in the open bay!" if screen.place_id != "open_bay" else "The tuna are here! The town's boats are out with the great net.")
			"neptunalia":
				Toast.say("The Neptunalia: the heaviest fish caught in the harbour by noon wins.")
			"dolphins":
				if not _dolphins.is_empty():
					Toast.say("Dolphins! They are driving the shoals up to the surface.")
			"saturnalia":
				Toast.say("The Saturnalia: the town wants fish for its feasts.")
	if Game.state.has("_show"):
		var show: Dictionary = Game.state["_show"]
		Game.state.erase("_show")
		Toast.say(("Your ponds won the pond show! +%s" % Ui.coins_text(int(show["prize"]))) if show["won"] else "The widow's ponds won the pond show this year.")


func _process(delta: float) -> void:
	if not _announced and screen.time() > 1.0:
		_announce()
	var surface: float = -screen.camera.cam.y
	var t: float = screen.time()
	for d in _dolphins:
		d["x"] = fposmod(d["x"] + d["speed"] * delta, Nav.view().x + 80.0)
		var arc := sin(t * 1.6 + d["phase"])
		var s: Sprite2D = d["sprite"]
		s.visible = arc > 0.0
		s.position = Vector2(d["x"] - 40.0, surface - arc * 16.0 - 6.0)
		s.rotation = -cos(t * 1.6 + d["phase"]) * 0.5
	_check_contest()


func _on_caught(fish: String, pounds: float) -> void:
	if not Game.state.has("contest") or Game.state["contest"]["done"] or screen.place_id != "harbour":
		return
	var hour := Clock.hour(float(Game.state["time"]))
	if hour >= CONTEST_HOURS[0] and hour < CONTEST_HOURS[1] and pounds > float(Game.state["contest"]["best"]):
		Game.state["contest"]["best"] = pounds
		Game.state["contest"]["fish"] = fish
		Toast.say("Your best in the contest: %s lb." % CatchCard.pounds_text(pounds))


## At noon the contest is judged against the best of the town's fishermen.
func _check_contest() -> void:
	if not Game.state.has("contest") or Game.state["contest"]["done"]:
		return
	var c: Dictionary = Game.state["contest"]
	if Clock.day_of(float(Game.state["time"])) != int(c["day"]) or Clock.hour(float(Game.state["time"])) < CONTEST_HOURS[1]:
		return
	c["done"] = true
	var bar := 2.5 + int(Game.state["chapter"]) * 1.5
	if float(c["best"]) > bar:
		var prize := 40 * int(Game.state["chapter"])
		Game.state["denarii"] = int(Game.state["denarii"]) + prize
		Story.add_reputation(Game.state, 10)
		Game.state["stats"]["neptunalia_won"] = int(Game.state["stats"].get("neptunalia_won", 0)) + 1
		Toast.say("You won the Neptunalia with a %s lb %s! +%s" % [CatchCard.pounds_text(float(c["best"])), str(Data.fish[c["fish"]]["name"]).to_lower(), Ui.coins_text(prize)])
	else:
		Toast.say("The Neptunalia went to old Rufus with a %s lb fish." % CatchCard.pounds_text(bar + 0.4))


## The town's net: a marker runs along a bar, and hauling while it is in the gold brings up the most tuna.
func _open_haul() -> void:
	var list := Ui.window("The town's net", 260, 90)
	Ui.label(list, "Haul when the marker is in the gold.", "MutedLabel")
	var bar := HaulBar.new()
	bar.custom_minimum_size = Vector2(230, 14)
	list.add_child(bar)
	Ui.button(list, "Haul!", func():
		var good := 1.0 - clampf(absf(bar.at - 0.5) / 0.5, 0.0, 1.0)
		var n := int(roundf(1.0 + good * 3.0))
		var rng := Seeds.rng(int(Game.state["seed"]), "haul", Clock.day_of(float(Game.state["time"])))
		var kept := 0
		for i in n:
			if Hold.room(Game.state) > 0:
				Catches.record(Game.state, "tuna", Catalog.roll_pounds("tuna", rng), false)
				kept += 1
		Game.state["tuna_haul_day"] = Clock.day_of(float(Game.state["time"]))
		Ui.close_window()
		if is_instance_valid(_haul_button):
			_haul_button.queue_free()
		Toast.say("Your share of the haul: %d tuna." % kept if kept > 0 else "Your hold had no room for tuna."))


class HaulBar extends Control:
	var at := 0.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		at = 0.5 + 0.5 * sin(_t * 3.2)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UiTheme.WOOD)
		draw_rect(Rect2(Vector2(size.x * 0.42, 1), Vector2(size.x * 0.16, size.y - 2)), UiTheme.GOLD)
		draw_rect(Rect2(Vector2(size.x * at - 1, 0), Vector2(3, size.y)), UiTheme.CREAM)
