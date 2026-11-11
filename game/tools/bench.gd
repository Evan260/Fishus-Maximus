extends Node
## Measures how smoothly one scene runs: --bench=NAME [--bench-seconds=20 --bench-warmup=3 --bench-out=FILE].
## On the coast the boat is rowed end to end and back, unless NAME is "deep", "fight" or "fishing"; "logbook" turns to
## the next section every 1.5 seconds; "windows" opens and closes every window and goes from screen to screen; "fishing"
## fishes with --demo-cast and rows to a new spot every 30 seconds; "minimised" and "unfocused" keep the game's own frame
## rate cap with the window minimised or behind other windows. Every other scene runs with the frame rate uncapped, so
## the frame time shows the work done. The results are appended to FILE as one line of JSON, with objects, nodes,
## orphans and memory sampled every ten seconds. --bench-skip=NAME stops every node whose script path contains NAME
## from processing, to see what its scripts cost.

const HISTOGRAM := 10000
const ROW_SPEED := 3.0
const WINDOWS := ["logbook", "achievements", "settings:Sound", "settings:Display", "settings:Gameplay", "settings:Keys",
	"tackle", "hold", "town", "board", "client", "market", "netmaker", "boatwright", "goldsmith", "shore", "pond", "garum",
	"map", "coast"]

var scene := ""
var seconds := 20.0
var warmup := 3.0
var out := ""
var _clock := 0.0
var _last_usec := 0
## Running totals rather than every frame's numbers, so a long run measures memory without growing its own.
var _frames := 0
var _sums := {"frame": 0.0, "process": 0.0, "scripts": 0.0, "draw_calls": 0.0, "objects": 0.0, "gpu": 0.0, "render_cpu": 0.0,
	"flush": 0.0, "render": 0.0, "present": 0.0}
## How many frames took each tenth of a millisecond, for the slowest one percent.
var _histogram := PackedInt32Array()
var _first: Node
var _start := {}
var _row_dir := 1.0
var _timer := 0.0
var _window := 0
var _series: Array = []
var _sample_timer := 0.0
## When this frame's scripts ended, its drawing began and ended, to split the frame into its parts.
var _process_end := 0
var _pre_draw := 0
var _post_draw := 0


func _ready() -> void:
	scene = Dev.get_arg("bench")
	seconds = Dev.num("bench-seconds", 20.0)
	warmup = Dev.num("bench-warmup", 3.0)
	out = Dev.get_arg("bench-out", "user://bench.jsonl")
	process_priority = 100000
	_histogram.resize(HISTOGRAM)
	# A node that processes before every other one marks when the frame's scripts begin.
	_first = Node.new()
	_first.process_priority = -100000
	_first.set_script(_Mark)
	add_child(_first)
	RenderingServer.frame_pre_draw.connect(func() -> void: _pre_draw = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func() -> void: _post_draw = Time.get_ticks_usec())


func _paced() -> bool:
	return scene in ["minimised", "unfocused"]


func _process(delta: float) -> void:
	if scene == "minimised" and get_window().mode != Window.MODE_MINIMIZED and _clock > 1.0:
		get_window().mode = Window.MODE_MINIMIZED
	elif scene == "unfocused" and _clock > 1.0 and not has_meta("behind"):
		set_meta("behind", true)
		get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	if not _paced():
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var now := Time.get_ticks_usec()
	_clock += delta
	_drive(delta)
	if _clock < warmup:
		_last_usec = now
		return
	if _start.is_empty():
		_start = _monitors()
		for vp in [get_viewport(), Nav.port]:
			RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)
	_sample_timer -= delta
	if _sample_timer <= 0.0:
		_sample_timer = 10.0
		_series.append(_monitors())
	var frame := (now - _last_usec) / 1000.0
	_last_usec = now
	# The last frame's parts: the drawing callbacks after the scripts, the rendering, and the wait to show it.
	if _process_end > 0 and _pre_draw > _process_end and _post_draw > _pre_draw:
		_sums["flush"] += (_pre_draw - _process_end) / 1000.0
		_sums["render"] += (_post_draw - _pre_draw) / 1000.0
		_sums["present"] += (int(_first.get("at")) - _post_draw) / 1000.0
	_frames += 1
	_histogram[mini(int(frame * 10.0), HISTOGRAM - 1)] += 1
	_sums["frame"] += frame
	_sums["process"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_sums["scripts"] += (now - _first.get("at")) / 1000.0
	_sums["draw_calls"] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_sums["objects"] += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	for vp in [get_viewport(), Nav.port]:
		_sums["gpu"] += RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid())
		_sums["render_cpu"] += RenderingServer.viewport_get_measured_render_time_cpu(vp.get_viewport_rid())
	_process_end = Time.get_ticks_usec()
	if _clock >= warmup + seconds:
		_finish()


func _drive(delta: float) -> void:
	if Dev.has("bench-skip") and Engine.get_process_frames() % 60 == 0:
		_skip(get_tree().root, Dev.get_arg("bench-skip"))
	var s: Node = Nav.current
	if scene == "logbook":
		_timer -= delta
		if _timer <= 0.0 and _clock > 1.5:
			_timer = 1.5
			LogbookPanel._bookmark_turn((LogbookPanel.section + 1) % LogbookPanel._sections().size())
		return
	if scene == "windows":
		_timer -= delta
		if _timer <= 0.0 and not Nav._busy:
			_timer = 1.0
			_next_window()
		return
	if s == null or Nav.current_name != "coast" or s.get("methods") == null:
		return
	if scene == "fishing":
		_timer -= delta
		if _timer <= 0.0:
			_timer = 30.0
			_row_dir = -_row_dir
			set_meta("rowing", 4.0)
		if float(get_meta("rowing", 0.0)) > 0.0:
			set_meta("rowing", float(get_meta("rowing")) - delta)
			_row(s, delta)
	elif not scene in ["deep", "fight", "minimised", "unfocused", "strip"]:
		_row(s, delta)


## Rows the boat along the place and turns back at either end.
func _row(s: Node, delta: float) -> void:
	if s.boat_x >= s._end() - 1.0:
		_row_dir = -1.0
	elif s.boat_x <= 1.0:
		_row_dir = 1.0
	s.row(_row_dir, delta * ROW_SPEED)


## Closes the open window, or else opens the next window or screen in the round.
func _next_window() -> void:
	if Ui.close_top():
		return
	var which: String = WINDOWS[_window % WINDOWS.size()]
	_window += 1
	match which:
		"town", "shore", "map", "coast":
			Nav.go(which)
		"tackle":
			if Nav.current_name == "coast":
				TacklePanel.open()
		"market", "netmaker", "boatwright", "goldsmith":
			if Nav.current_name == "town":
				var open: Callable = {"market": ShopPanel.market, "netmaker": ShopPanel.netmaker,
					"boatwright": ShopPanel.boatwright, "goldsmith": ShopPanel.goldsmith}[which]
				open.call()
		"board", "client":
			if Nav.current_name == "town":
				Dev.open_panel(which)
		"pond", "garum":
			if Nav.current_name == "shore":
				Dev.open_panel(which)
		_:
			Dev.open_panel(which)


func _skip(node: Node, name: String) -> void:
	var script: Script = node.get_script()
	if script and script.resource_path.contains(name) and node != self:
		node.set_process(false)
	for child in node.get_children():
		_skip(child, name)


func _monitors() -> Dictionary:
	return {
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"texture_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		"video_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
	}


func _mean(key: String) -> float:
	return _sums[key] / maxf(1.0, _frames)


## The mean of the slowest one percent of frames, to the nearest tenth of a millisecond.
func _worst() -> float:
	var left := maxi(1, _frames / 100)
	var total := 0.0
	var counted := 0
	for bin in range(HISTOGRAM - 1, -1, -1):
		var take := mini(_histogram[bin], left - counted)
		total += take * (bin + 0.5) / 10.0
		counted += take
		if counted >= left:
			break
	return total / maxf(1.0, counted)


func _canvas_items(node: Node) -> int:
	var count := 1 if node is CanvasItem and node.is_visible_in_tree() else 0
	for child in node.get_children():
		count += _canvas_items(child)
	return count


func _finish() -> void:
	set_process(false)
	var end := _monitors()
	var result := {
		"scene": scene,
		"frames": _frames,
		"fps": _frames / maxf(0.001, seconds),
		"frame_ms": _mean("frame"),
		"worst1_ms": _worst(),
		"process_ms": _mean("process"),
		"scripts_ms": _mean("scripts"),
		"gpu_ms": _mean("gpu"),
		"flush_ms": _mean("flush"),
		"render_ms": _mean("render"),
		"present_ms": _mean("present"),
		"render_cpu_ms": _mean("render_cpu"),
		"draw_calls": _mean("draw_calls"),
		"objects_drawn": _mean("objects"),
		"canvas_items": _canvas_items(get_tree().root),
		"start": _start,
		"end": end,
		"series": _series,
	}
	var f := FileAccess.open(out, FileAccess.READ_WRITE if FileAccess.file_exists(out) else FileAccess.WRITE)
	f.seek_end()
	f.store_line(JSON.stringify(result))
	f.close()
	print("bench ", JSON.stringify(result))
	if Audio.has_method("quit"):
		Audio.quit()
	else:
		get_tree().quit()


static var _Mark: GDScript = _mark_script()


static func _mark_script() -> GDScript:
	var g := GDScript.new()
	g.source_code = "extends Node
var at := 0
func _process(_d: float) -> void:
	at = Time.get_ticks_usec()
"
	g.reload()
	return g
