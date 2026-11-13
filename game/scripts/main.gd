extends Node
## Opens the title screen, or the screen named with --screen= for checking it on its own, runs the tests, or plays a
## trailer shot.


func _ready() -> void:
	# --as-demo plays by the demo's limits without exporting it, for checking the demo's screens.
	Game.acts_as_demo = Dev.has("as-demo")
	if Dev.has("run-tests"):
		add_child(load("res://tests/run_tests.gd").new())
		return
	if Dev.has("pacing"):
		for seed in Array(Dev.get_arg("seeds", "7,11,23").split(",")).map(func(n): return int(n)):
			var log: Dictionary = load("res://tests/pacing_bot.gd").new().run(Dev.num("hours", 40.0), seed)
			var missing := Data.fish.keys().filter(func(f): return Data.fish[f]["legend"] and not log["legends"].has(f))
			print("PACING seed %d: firsts %s chapters %s boats %s legends %d of 12 (missing %s), name %d" % [seed, log["firsts"], log["chapters"], log["boats"], log["legends"].size(), missing, log["reputation"]])
		Audio.quit()
		return
	if Dev.has("flow"):
		add_child(load("res://tests/flow_bot.gd").new())
		return
	if Dev.has("trailer-shot"):
		add_child(load("res://tools/trailer/shots.gd").new())
		return
	if Dev.has("demo-state"):
		Game.demo_state()
	if Dev.has("max-state"):
		Game.max_state()
	# --seed=N fixes a made-up game's seed, so two runs lay out the same fish and weather for comparing screenshots.
	if Dev.has("seed") and not Game.state.is_empty():
		Game.state["seed"] = int(Dev.get_arg("seed"))
	if Dev.has("boat"):
		Game.state["boat"] = Dev.get_arg("boat")
	if Dev.has("dog"):
		Game.state["dog"] = Dev.get_arg("dog")
	if Dev.has("guide"):
		# A new game with old Rufus's lessons learned up to the one named, for checking that lesson on screen.
		Game.new_game("Marcus", "mutt")
		for s in Data.guide["steps"]:
			if s["id"] == Dev.get_arg("guide"):
				break
			Guide.progress(Game.state)["done"].append(s["id"])
	if Dev.has("reputation"):
		# Raises the name of a new game, or the one made up, to N through the chapters as play would, as for the demo's end card.
		if Game.state.is_empty():
			Game.new_game("Marcus", "mutt")
			Game.state["guide"]["finished"] = true
		Story.add_reputation(Game.state, int(Dev.get_arg("reputation")) - int(Game.state["reputation"]))
	Nav.go.call_deferred(Dev.get_arg("screen", "title"), Dev.args)
	if Dev.has("strip"):
		Windowing.set_strip.call_deferred(true)
