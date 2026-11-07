class_name Hud
extends Control
## The boat's panel on screen: denarii, the day, hour, season and weather, how full the hold and the well are, the bait
## and the fishing method, with buttons for fishing on his own, the logbook, the map and the settings.

var screen: Node
var _info: Label
var _method: Label
var _idle: Button
var _left := 0.0


func setup(s: Node) -> void:
	screen = s
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var top := PanelContainer.new()
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
	for m in [["line", "Line"], ["trap", "Pots"], ["net", "Net"], ["trident", "Trident"]]:
		var id: String = m[0]
		var b := Ui.button(bar, m[1], func(): screen.methods.set_method(id))
		b.tooltip_text = "Keys 1 to 4"
	_idle = Ui.button(bar, "Fish on his own", func():
		screen.methods.set_idle(not screen.methods.idle)
		if screen.methods.idle and screen.line_state() == "reeled":
			screen.cast(0.6))
	Ui.hang(bar, "bottom_left", Vector2(68, 4))
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	add_child(right)
	Ui.button(right, "Logbook", func(): LogbookPanel.open())
	Ui.button(right, "Settings", func(): SettingsPanel.open())
	Ui.button(right, "Menu", func():
		Saves.save()
		Nav.go("title"))
	Ui.hang(right, "top_right", Vector2(4, 4))
	refresh()


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		_left = 0.25
		refresh()


func refresh() -> void:
	var s: Dictionary = Game.state
	var t := float(s["time"])
	var day := Clock.day_of(t)
	var h := Clock.hour(t)
	var boat: Dictionary = Data.boats[s["boat"]]
	var well := ("  Well %d/%d" % [s["live_well"].size(), int(boat["well"])]) if int(boat["well"]) > 0 else ""
	_info.text = "%s   Day %d, %s   %02d:%02d, %s" % [Ui.coins_text(int(s["denarii"])), day + 1, Clock.season(day),
		int(h), int(fmod(h, 1.0) * 60.0), s.get("weather", "clear")]
	var bait: String = screen.bait()
	var method: String = screen.methods.method
	_method.text = "Hold %d/%d%s   %s%s" % [s["hold"].size(), int(boat["hold"]), well, {"line": "Line", "trap": "Pots", "net": "Cast net", "trident": "Trident"}[method],
		(", %s x%d" % [str(Data.bait[bait]["name"]).to_lower(), int(s["bait"][bait])]) if method == "line" and bait != "" else (", no bait" if method == "line" else "")]
	_idle.text = "At the rod" if screen.methods.idle else "Fish on his own"
