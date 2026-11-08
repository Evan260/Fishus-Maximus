extends "res://tests/test_case.gd"
## The game with everything open and the best of everything, which the launcher next to the exe starts.


func test_every_chapter_is_open() -> void:
	Game.max_state()
	var s := Game.state
	var last: Dictionary = Data.chapters[Data.chapters.size() - 1]
	check(int(s["chapter"]) == int(last["chapter"]), "the last chapter is open")
	check(Story.chapter_for(int(s["reputation"])) == int(last["chapter"]), "and the name in town to go with it")
	check(s["guide"]["finished"], "with old Rufus's lessons done")


func test_the_best_of_everything_is_owned() -> void:
	Game.max_state()
	var s := Game.state
	check(s["boat"] == Data.boats.keys()[Data.boats.size() - 1], "the biggest boat")
	for id in Data.gear:
		if Data.gear[id]["kind"] != "finery":
			check(Shop.owned(s, id), "%s is owned or bettered" % id)
	check(Shop.bait_capacity(s) == 100, "the biggest bait box")
	for id in Data.bait:
		check(int(s["bait"].get(id, 0)) > 0, "some %s" % id)
	check(Shop.bait_count(s) <= Shop.bait_capacity(s), "no more bait than the box holds")
	for id in Helpers.HELP:
		check(id in s["helpers"], "%s is hired" % id)
	check(int(s["denarii"]) >= 10000, "and money to spare")


func test_every_pond_and_tank_is_open() -> void:
	Game.max_state()
	var s := Game.state
	check(s["ponds"].size() == Ponds.allowed(s), "every pond the last chapter allows is dug, %d" % s["ponds"].size())
	check(s["ponds"].all(func(p): return p["size"] == "large" and p["water"] == Data.ponds["sites"][int(p["site"])]["water"]), "each one large")
	check(s["tanks"].all(func(t): return t["restored"]), "and every garum tank restored")
