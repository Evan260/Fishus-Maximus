extends Node
## Command-line options for checking the game without a hand on the mouse: screenshots, bursts of frames, window size.
## --shot=PATH [--shot-at=SECONDS] saves one screenshot; --burst=PREFIX [--burst-start, --burst-gap, --burst-count]
## saves several as PREFIX_00.png and on; --quit closes the game after the last one; --window=WxH sets the window size;
## --hover=X,Y and --click=X,Y point and click in interface pixels; --panel=NAME opens a window; --achievement[=ID]
## slides in an achievement's card; --ui-size=N sets the interface size for the run; --no-save writes nothing anywhere.

const BENCH := "res://tools/bench.gd"

var args := {}
var time := 0.0
var _shots: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if args.has("window"):
		var wh: PackedStringArray = args["window"].split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
	if args.has("shot"):
		_shots.append([float(args.get("shot-at", "1.0")), args["shot"]])
	if args.has("burst"):
		var start := float(args.get("burst-start", "1.0"))
		var gap := float(args.get("burst-gap", "0.05"))
		for k in int(args.get("burst-count", "8")):
			_shots.append([start + k * gap, "%s_%02d.png" % [args["burst"], k]])
	_shots.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	# --hover=X,Y and --click=X,Y (interface pixels, at --hover-at and --click-at seconds) point and click for screenshots.
	if args.has("hover"):
		get_tree().create_timer(float(args.get("hover-at", "1.5"))).timeout.connect(func(): _point(_at("hover")))
	if args.has("click"):
		get_tree().create_timer(float(args.get("click-at", "1.5"))).timeout.connect(func(): _click(_at("click")))
	# --catch=ID (at --catch-at seconds) hangs out the banner for that fish, as if it had just been landed for the first time.
	if args.has("catch"):
		get_tree().create_timer(float(args.get("catch-at", "1.0"))).timeout.connect(func():
			var lb: Array = Data.fish[args["catch"]]["pounds"]
			CatchCard.show_catch(args["catch"], (float(lb[0]) + float(lb[1])) / 2.0, true))
	# --panel=NAME (at --panel-at seconds) opens that window, for screenshots.
	if args.has("panel"):
		get_tree().create_timer(float(args.get("panel-at", "1.0"))).timeout.connect(open_panel.bind(args["panel"]))
	if args.has("achievement"):
		get_tree().create_timer(float(args.get("achievement-at", "1.0"))).timeout.connect(_show_achievement)
	if args.has("quit") and _shots.is_empty():
		get_tree().create_timer(float(args.get("quit-at", "3.0"))).timeout.connect(get_tree().quit)
	if args.has("bench") and ResourceLoader.exists(BENCH):
		add_child(load(BENCH).new())


func has(key: String) -> bool:
	return args.has(key)


## Whether this run made up its game, which is then never saved or sent to Steam.
func made_up() -> bool:
	return has("demo-state") or has("max-state")


func get_arg(key: String, fallback: String = "") -> String:
	return args.get(key, fallback)


func num(key: String, fallback: float) -> float:
	return float(args[key]) if args.has(key) and args[key] != "" else fallback


func _process(delta: float) -> void:
	time += delta
	while not _shots.is_empty() and time >= _shots[0][0]:
		_take_shot(_shots.pop_front()[1], _shots.is_empty())


func _take_shot(path: String, last: bool) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
	if last and args.has("quit"):
		get_tree().quit()


## Opens a window by name: logbook, logbook:FISH (its page), achievements, settings or settings:TAB, board, client,
## garum, pond (on the shore), hold (the full-hold choice), and on the title new_game, load, or delete,
## which leaves slot 1 waiting for the word typed, deleting nothing.
func open_panel(window: String) -> void:
	if window == "logbook":
		LogbookPanel.open()
		# --turn-at=S turns to the next section S seconds after the logbook opens (--turn-back the other way), for checks.
		if args.has("turn-at"):
			get_tree().create_timer(float(args["turn-at"])).timeout.connect(func():
				LogbookPanel._bookmark_turn(LogbookPanel.section + (-1 if args.has("turn-back") else 1)))
	elif window.begins_with("logbook:"):
		var fish := window.get_slice(":", 1)
		var f: Dictionary = Data.fish[fish]
		LogbookPanel.open(LogbookPanel._sections().find("legends" if f["legend"] else str(f["places"][0])))
		LogbookPanel.selected = fish
		LogbookPanel.open(LogbookPanel.section)
	elif window == "achievements":
		LogbookPanel.open_achievements()
	elif window == "board":
		BoardPanel.open()
	elif window == "client":
		ClientVisit.open(str(Data.clients.keys()[0]))
	elif window == "garum":
		GarumPanel.open()
	elif window == "pond" and Nav.current and "pond" in Nav.current:
		PondPanel.open(Nav.current.pond)
	elif window == "hold":
		HoldChoice.ask({"fish": "bream", "pounds": 2.4})
	elif window.begins_with("settings"):
		if window.contains(":"):
			SettingsPanel.tab = window.get_slice(":", 1)
		SettingsPanel.open()
	elif Nav.current and Nav.current.has_method("_load"):
		match window:
			"new_game":
				Nav.current.call("_new_game")
			"load":
				Nav.current.call("_load")
			"delete":
				var info := Saves.slot_info(1)
				if not info.is_empty():
					Nav.current.call("_confirm_delete", 1, info)


## Slides in the card for the achievement named by --achievement=ID, or the first one, without earning it.
func _show_achievement() -> void:
	var id := get_arg("achievement")
	for a in Data.achievements:
		if id == "" or a["id"] == id:
			AchievementCard.show_earned(str(a["id"]))
			return


## A point given in interface pixels, in window pixels.
func _at(key: String) -> Vector2:
	var xy: PackedStringArray = args[key].split(",")
	return Nav.ui_to_window(Vector2(float(xy[0]), float(xy[1])))


func _point(at: Vector2) -> void:
	for k in 2:
		var m := InputEventMouseMotion.new()
		m.position = at + Vector2(k, 0)
		m.global_position = m.position
		m.relative = Vector2(1, 0)
		get_viewport().push_input(m)


func _click(at: Vector2) -> void:
	_point(at)
	for pressed in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = pressed
		b.position = at
		b.global_position = at
		get_viewport().push_input(b)
