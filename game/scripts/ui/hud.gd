class_name Hud
extends Control
## The boat's panel on screen: denarii, the day, hour, season and weather, how full the hold and the well are, the bait
## and the fishing method, a button for fishing on his own, and pictures for the logbook, the settings and the menu.
## Along the bottom the ways of fishing are pictures; clicking the line opens the tackle above it, to choose the bait
## and the rod.

const TILE := Vector2(30, 30)
## What each way of fishing does, for its tip, with its key and the casting key filled in.
const METHOD_TIPS := {
	"line": "Line (key %s). Click to choose the bait and the rod. Hold %s or the mouse to cast, wait for the float to go under, then click to strike and hold to reel in.",
	"trap": "Pots (key %s). Sink a pot to the seabed for crabs, lobsters and octopus, then row back over it later to haul it up.",
	"net": "Cast net (key %s). Throw it over a shoal swimming near the surface. The netmaker in town sells them.",
	"trident": "Trident (key %s). At night, with a lamp, spear the fish that come up to its light.",
}

var screen: Node
var _info: Label
var _method: Label
var _idle: Button
## The method tiles along the bottom, by method.
var method_buttons := {}
var _left := 0.0


func setup(s: Node) -> void:
	screen = s
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top := PanelContainer.new()
	top.name = "InfoPanel"
	top.position = Vector2(4, 4)
	add_child(top)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	top.add_child(col)
	_info = Ui.label(col, "")
	_method = Ui.label(col, "", "MutedLabel")
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 2)
	add_child(bar)
	for m in CoastMethods.METHODS:
		var id: String = m
		method_buttons[id] = Ui.tile(bar, ItemArt.of(id), "", method_tip(id), func(): screen.methods.set_method(id), true, false, TILE)
	var line: Button = method_buttons["line"]
	line.pressed.connect(func():
		if screen.methods.method == "line":
			TacklePanel.open(line))
	_idle = Ui.button(bar, "Fish on his own", func():
		screen.methods.set_idle(not screen.methods.idle)
		if screen.methods.idle and screen.line_state() == "reeled":
			screen.cast(0.6))
	# It starts just past the bay map's picture, which the coast hangs in the corner.
	Ui.hang(bar, "bottom_left", Vector2(8 + TILE.x, 4))
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	add_child(right)
	_corner_tile(right, "Logbook", "Logbook: the fish you have caught, those still to find, and your achievements.", func(): LogbookPanel.open())
	_corner_tile(right, "Settings", "Settings", func(): SettingsPanel.open())
	_corner_tile(right, "Menu", "Save and go back to the title", _to_title)
	Ui.hang(right, "top_right", Vector2(4, 4))
	refresh()


static func method_tip(id: String) -> String:
	var keys := [Controls.key_name("method_" + id)]
	if id == "line":
		keys.append(Controls.key_name("cast"))
	return TranslationServer.translate(METHOD_TIPS[id]) % keys


func _corner_tile(row: HBoxContainer, id: String, tip: String, action: Callable) -> void:
	Ui.tile(row, ItemArt.of(id.to_lower()), "", tip, action, true, false, TILE).name = id


func _to_title() -> void:
	Saves.save()
	Nav.go("title")


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		_left = 0.25
		refresh()


func refresh() -> void:
	var s: Dictionary = Game.state
	var t := float(s["time"])
	var day := Clock.day_of(t)
	var boat: Dictionary = Data.boats[s["boat"]]
	var well: String = ("  " + tr("Well %d/%d") % [s["live_well"].size(), int(boat["well"])]) if int(boat["well"]) > 0 else ""
	# No clock ticks by here: the sky tells the hour, and a player should never feel he is watching time pass.
	_info.text = "%s   %s" % [Ui.coins_text(int(s["denarii"])), tr("Day %d, %s, %s") % [day + 1, tr(Clock.season(day)), tr(str(s.get("weather", "clear")))]]
	var bait: String = screen.bait()
	var method: String = screen.methods.method
	var way: String = tr({"line": "Line", "trap": "Pots", "net": "Cast net", "trident": "Trident"}[method])
	if method == "line":
		way = tr("%s, %s x%d") % [way, Data.lower_of(Data.bait[bait]), int(s["bait"][bait])] if bait != "" else tr("%s, no bait") % way
	_method.text = "%s%s   %s" % [tr("Hold %d/%d") % [s["hold"].size(), int(boat["hold"])], well, way]
	_idle.text = tr("At the rod") if screen.methods.idle else tr("Fish on his own")
	for m in method_buttons:
		Ui.choose(method_buttons[m], m == method)
		# The keys named in the tips may have been changed in the settings since the boat was set out.
		Ui.tip_on(method_buttons[m], method_tip(m))
	var usable := {"net": str(s["gear"].get("net", "")) != "", "trident": Trident.can_use(screen.hour, str(s["gear"].get("lamp", "")))}
	for m in usable:
		(method_buttons[m].get_node("Picture") as TextureRect).modulate.a = 1.0 if usable[m] else 0.4

