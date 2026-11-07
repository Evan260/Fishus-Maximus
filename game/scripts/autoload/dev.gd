extends Node
## Command-line options for checking the game without a hand on the mouse: screenshots, bursts of frames, window size.
## --shot=PATH [--shot-at=SECONDS] saves one screenshot; --burst=PREFIX [--burst-start, --burst-gap, --burst-count]
## saves several; --quit closes the game after the last one; --window=WxH sets the window size; --no-save keeps every
## save slot untouched.

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
	# --click=X,Y (window pixels, at --click-at seconds) clicks for screenshots.
	if args.has("click"):
		var xy: PackedStringArray = args["click"].split(",")
		get_tree().create_timer(float(args.get("click-at", "1.5"))).timeout.connect(_click.bind(Vector2(float(xy[0]), float(xy[1]))))
	if args.has("quit") and _shots.is_empty():
		get_tree().create_timer(float(args.get("quit-at", "3.0"))).timeout.connect(get_tree().quit)


func has(key: String) -> bool:
	return args.has(key)


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


func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var b := InputEventMouseButton.new()
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = pressed
		b.position = at
		b.global_position = at
		get_viewport().push_input(b)
