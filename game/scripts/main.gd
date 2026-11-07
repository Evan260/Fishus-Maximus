extends Node
## Opens the title screen, or the screen named with --screen= for checking it on its own, or runs the tests.


func _ready() -> void:
	if Dev.has("run-tests"):
		add_child(load("res://tests/run_tests.gd").new())
		return
	if Dev.has("pacing"):
		for seed in Array(Dev.get_arg("seeds", "7,11,23").split(",")).map(func(n): return int(n)):
			var log: Dictionary = load("res://tests/pacing_bot.gd").new().run(Dev.num("hours", 40.0), seed)
			var missing := Data.fish.keys().filter(func(f): return Data.fish[f]["legend"] and not log["legends"].has(f))
			print("PACING seed %d: chapters %s boats %s legends %d of 12 (missing %s), name %d" % [seed, log["chapters"], log["boats"], log["legends"].size(), missing, log["reputation"]])
		get_tree().quit()
		return
	if Dev.has("flow"):
		add_child(load("res://tests/flow_bot.gd").new())
		return
	if Dev.has("demo-state"):
		Game.demo_state()
		if Dev.has("boat"):
			Game.state["boat"] = Dev.get_arg("boat")
	Nav.go.call_deferred(Dev.get_arg("screen", "title"), Dev.args)
	if Dev.has("strip"):
		Windowing.set_strip.call_deferred(true)
