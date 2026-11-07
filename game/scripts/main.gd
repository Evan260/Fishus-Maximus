extends Node
## Opens the title screen, or the screen named with --screen= for checking it on its own, or runs the tests.


func _ready() -> void:
	if Dev.has("run-tests"):
		add_child(load("res://tests/run_tests.gd").new())
		return
	if Dev.has("pacing"):
		for seed in [7, 11, 23]:
			var log: Dictionary = load("res://tests/pacing_bot.gd").new().run(Dev.num("hours", 40.0), seed)
			print("PACING seed %d: chapters %s boats %s legends %d of 12, name %d" % [seed, log["chapters"], log["boats"], log["legends"].size(), log["reputation"]])
		get_tree().quit()
		return
	if Dev.has("flow"):
		add_child(load("res://tests/flow_bot.gd").new())
		return
	if Dev.has("demo-state"):
		Game.demo_state()
	Nav.go.call_deferred(Dev.get_arg("screen", "title"), Dev.args)
	if Dev.has("strip"):
		Windowing.set_strip.call_deferred(true)
