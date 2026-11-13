class_name BayMap
extends Node2D
## The painted map of the bay: a pin for each fishing place, locked until your chapter opens it and you own the boat
## that reaches it. Sailing to a place takes an hour of the day.

const ART := "res://assets/art/map/bay.png"
## The deep sea round the map's edges, which the view carries on past them.
const DEEP := Color8(105, 86, 88)

var _hover := ""
var _sailing := false
var _painter: Node2D
var _stage: Node2D
var _backdrop: Backdrop


## How long the sail to a place takes in minutes of the clock: an hour in the rowing skiff, less in a faster boat.
static func travel_minutes(place: String, boat: String) -> float:
	return float(Data.places[place].get("travel_minutes", 60)) * float(Data.boats["skiff"]["speed"]) / maxf(1.0, float(Data.boats[boat]["speed"]))


## Sails to a place you can reach, or stays put when it is the place you are at; says whether you went.
static func sail(state: Dictionary, place: String) -> bool:
	if locked_reason(state, place) != "":
		return false
	if place != state["place"]:
		var hours := travel_minutes(place, str(state["boat"])) / 60.0
		World.advance(state, Clock.minutes_for_hours(float(state["time"]), hours), Seeds.rng(int(state["seed"]), "sail", Clock.day_of(float(state["time"]))))
		state["stats"]["sails"] = int(state["stats"].get("sails", 0)) + 1
		state["boat_x"] = 150.0
	state["place"] = place
	return true


## Why a place cannot be reached yet, or nothing when it can.
static func locked_reason(state: Dictionary, place: String) -> String:
	# Only a boat built for the open sea puts out in a storm, which is when the swordfish rises off the cape.
	if state.get("weather", "clear") == "storm" and place != "harbour" and place != state["place"] 			and not Data.boats.get(str(state["boat"]), {}).get("storm", false):
		return TranslationServer.translate("The storm keeps the smaller boats in harbour")
	var open: Array = Story.unlocks(int(state["chapter"]))["places"]
	if not place in open:
		for c in Data.chapters:
			if place in c["places"]:
				if Game.in_full_game(int(c["chapter"])):
					return TranslationServer.translate("In the full game")
				return TranslationServer.translate("Opens in chapter %d") % int(c["chapter"])
	var boat: String = Data.places[place]["boat"]
	if Story.boat_rank(boat) > Story.boat_rank(str(state["boat"])):
		return TranslationServer.translate("Needs %s") % Data.lower_of(Data.boats[boat])
	return ""


## Escape and the pad's B leave the map for the coast, as Stay here does.
func go_back() -> bool:
	Nav.go("coast")
	return true


func enter(_args: Dictionary) -> void:
	Controls.ensure()
	if Game.state.is_empty():
		Game.new_game("Marcus", "")
	_stage = Node2D.new()
	add_child(_stage)
	if ResourceLoader.exists(ART):
		_backdrop = Backdrop.new(load(ART), DEEP)
		_stage.add_child(_backdrop)
	_painter = Node2D.new()
	_painter.draw.connect(_draw_pins)
	_stage.add_child(_painter)
	Windowing.view_changed.connect(_place)
	_place()
	var stay := Ui.button(Nav.ui, "Stay here", go_back)
	Ui.hang(stay, "bottom_right", Vector2(4, 4), Vector2(70, 18))
	var day := Clock.day_of(float(Game.state["time"]))
	var note := PanelContainer.new()
	note.position = Vector2(4, 4)
	Nav.ui.add_child(note)
	var events := Events.on(day).map(func(e): return tr({"tuna_run": "the tuna are running", "neptunalia": "the Neptunalia contest in the harbour",
		"saturnalia": "the Saturnalia feasts", "pond_show": "the pond show", "dolphins": "dolphins in the bay"}[e]))
	var when := tr("Day %d, %s, %s") % [day + 1, tr(Clock.season(day)), tr(Weather.for_day(int(Game.state["seed"]), day))]
	Ui.label(note, tr("%s. Today: %s") % [when, Ui.series(events)] if not events.is_empty() else when)


func _place() -> void:
	if is_instance_valid(_stage):
		_stage.position = Nav.offset()
		if _backdrop:
			_backdrop.fit(Rect2(-Nav.offset(), Nav.view()))


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
		Pixels.disc(_painter, at + Vector2(1, 1), 6.0, Color(0, 0, 0, 0.35))
		Pixels.disc(_painter, at, 6.0, UiTheme.CREAM)
		Pixels.disc(_painter, at, 5.0, UiTheme.MUTED if locked else (UiTheme.GOLD if here else UiTheme.RED))
		Pixels.disc(_painter, at, 2.0, UiTheme.CREAM)
		if locked:
			_painter.draw_rect(Rect2(at + Vector2(-2, -1), Vector2(4, 3)), UiTheme.INK)
	if _hover != "":
		var reason := locked_reason(Game.state, _hover)
		var text: String = tr("%s: %s") % [Data.name_of(Data.places[_hover]), reason] if reason != "" else Data.name_of(Data.places[_hover])
		var w := Ui.tag_width(text)
		var at := _pin(_hover) + Vector2(-w / 2.0, -10)
		at.x = clampf(at.x, 4.0, 476.0 - w)
		Ui.draw_tag(_painter, at, text)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and _hover != "" and not _sailing:
		if sail(Game.state, _hover):
			_sailing = true
			Nav.go("coast", {"place": _hover})
		else:
			Toast.say(locked_reason(Game.state, _hover))
