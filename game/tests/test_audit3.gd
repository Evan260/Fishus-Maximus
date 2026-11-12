extends "res://tests/test_case.gd"
## Bugs found by the third audit: each test shows one, failing before its fix.


func test_the_bots_and_tools_load() -> void:
	for path in ["res://tests/flow_bot.gd", "res://tests/pacing_bot.gd", "res://tools/bench.gd", "res://tools/write_credits.gd",
			"res://tools/trailer/shots.gd", "res://tools/trailer/edit.gd"]:
		var script: GDScript = load(path)
		check(script != null and script.can_instantiate(), "%s loads" % path)
