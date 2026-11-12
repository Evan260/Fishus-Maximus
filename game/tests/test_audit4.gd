extends "res://tests/test_case.gd"
## Bugs found by the fourth audit: each test shows one, failing before its fix.


func test_the_neptunalia_can_be_won_in_every_chapter() -> void:
	var heaviest := 0.0
	for hour in range(8, 12):
		for depth in range(0, int(Data.places["harbour"]["depth"]), 10):
			for id in Catalog.available("harbour", float(depth), float(hour), "summer", "clear", "line"):
				heaviest = maxf(heaviest, float(Data.fish[id]["pounds"][1]))
	for chapter in range(1, 6):
		Game.new_game("Test", "mutt")
		Game.state["chapter"] = chapter
		var day := 3
		Game.state["time"] = Clock.at_hour(day * Clock.minutes_per_day(), 13.0)
		Game.state["contest"] = {"day": day, "best": heaviest - 0.2, "fish": "bream", "done": false}
		World.advance(Game.state, 0.01, Seeds.rng(1, "contest"))
		check(Game.state["contest"]["done"] and int(Game.state["stats"].get("neptunalia_won", 0)) == 1,
			"a %s lb fish, near the harbour's heaviest in the contest's hours, wins in chapter %d" % [heaviest - 0.2, chapter])
