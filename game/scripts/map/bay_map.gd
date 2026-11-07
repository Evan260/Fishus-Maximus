class_name BayMap
extends Node2D
## The painted map of the bay: a pin for each fishing place, locked until your chapter opens it and you own the boat
## that reaches it. Sailing to a place takes an hour of the day.

const ART := "res://assets/art/map/bay.png"

var _hover := ""
var _sailing := false
var _painter: Node2D
var _stage: Node2D


## How long the sail to a place takes in minutes of the clock: an hour in the rowing skiff, less in a faster boat.
static func travel_minutes(place: String, boat: String) -> float:
	return float(Data.places[place].get("travel_minutes", 60)) * float(Data.boats["skiff"]["speed"]) / maxf(1.0, float(Data.boats[boat]["speed"]))


## Sails to a place you can reach; says whether you went.
static func sail(state: Dictionary, place: String) -> bool:
	if locked_reason(state, place) != "":
		return false
	if place != state["place"]:
		var hours := travel_minutes(place, str(state["boat"])) / 60.0
		World.advance(state, hours * Clock.minutes_per_day() / 24.0, Seeds.rng(int(state["seed"]), "sail", Clock.day_of(float(state["time"]))))
	state["place"] = place
	state["boat_x"] = 150.0
	return true


## Why a place cannot be reached yet, or nothing when it can.
static func locked_reason(state: Dictionary, place: String) -> String:
	if state.get("weather", "clear") == "storm" and place != "harbour" and place != state["place"]:
		return "The storm keeps the boats in harbour"
	var open: Array = Story.unlocks(int(state["chapter"]))["places"]
	if not place in open:
		for c in Data.chapters:
			if place in c["places"]:
				return "Opens in chapter %d" % int(c["chapter"])
	var boat: String = Data.places[place]["boat"]
	if Story.boat_rank(boat) > Story.boat_rank(str(state["boat"])):
		return "Needs " + str(Data.boats[boat]["name"]).to_lower()
	return ""


func enter(_args: Dictionary) -> void:
	Controls.ensure()
	if Game.state.is_empty():
		Game.new_game("Marcus", "")
	_stage = Node2D.new()
	add_child(_stage)
	if ResourceLoader.exists(ART):
		_stage.add_child(Backdrop.new(load(ART)))
	_painter = Node2D.new()
	_painter.draw.connect(_draw_pins)
	_stage.add_child(_painter)
	_stage.position = Nav.offset()
	var stay := Ui.button(Nav.ui, "Stay here", func(): Nav.go("coast"))
	Ui.hang(stay, "bottom_right", Vector2(4, 4), Vector2(70, 18))
	var day := Clock.day_of(float(Game.state["time"]))
	var note := PanelContainer.new()
	note.position = Vector2(4, 4)
	Nav.ui.add_child(note)
	var events := Events.on(day).map(func(e): return {"tuna_run": "the tuna are running", "neptunalia": "the Neptunalia contest in the harbour",
		"saturnalia": "the Saturnalia feasts", "pond_show": "the pond show", "dolphins": "dolphins in the bay"}[e])
	Ui.label(note, "Day %d, %s, %s%s" % [day + 1, Clock.season(day), Weather.for_day(int(Game.state["seed"]), day),
		(". Today: " + ", ".join(events)) if not events.is_empty() else ""])


func _pin(place: String) -> Vector2:
	var at: Array = Data.places[place].get("map", [240, 135])
	return Vector2(at[0], at[1])


func _process(_delta: float) -> void:
	_hover = ""
	var mouse := _stage.get_local_mouse_position()
	for id in Data.places:
		if mouse.distance_to(_pin(id)) < 9.0:
			_hover = id
	_painter.queue_redraw()


func _draw_pins() -> void:
	for id in Data.places:
		var at := _pin(id)
		var locked := locked_reason(Game.state, id) != ""
		var here: bool = id == Game.state["place"]
		_painter.draw_circle(at + Vector2(1, 1), 6.0, Color(0, 0, 0, 0.35))
		_painter.draw_circle(at, 6.0, UiTheme.CREAM)
		_painter.draw_circle(at, 5.0, UiTheme.MUTED if locked else (UiTheme.GOLD if here else UiTheme.RED))
		_painter.draw_circle(at, 2.0, UiTheme.CREAM)
		if locked:
			_painter.draw_rect(Rect2(at + Vector2(-2, -1), Vector2(4, 3)), UiTheme.INK)
	if _hover != "":
		var reason := locked_reason(Game.state, _hover)
		var text: String = Data.places[_hover]["name"] + ((": " + reason) if reason != "" else "")
		var font := UiTheme.title_font()
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var at := _pin(_hover) + Vector2(-w / 2.0, -10)
		at.x = clampf(at.x, 4.0, 476.0 - w)
		_painter.draw_rect(Rect2(at + Vector2(-3, -8), Vector2(w + 6, 11)), Color(UiTheme.INK, 0.85))
		_painter.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.CREAM)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and _hover != "" and not _sailing:
		if sail(Game.state, _hover):
			_sailing = true
			Nav.go("coast", {"place": _hover, "boat_x": 150.0})
		else:
			Toast.say(locked_reason(Game.state, _hover))
