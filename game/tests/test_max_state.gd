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
	check(Ponds.stage(s) == Ponds.allowed(s) and Ponds.stage(s) == Ponds.stages(), "the pond is dug as wide as it goes, stage %d" % Ponds.stage(s))
	check(s["tanks"].all(func(t): return t["restored"]), "and every garum tank restored")


func test_its_achievements_are_earned_quietly() -> void:
	Game.max_state()
	var s := Game.state
	check(s["achievements"].size() > 10, "what everything unlocked has met is earned, %d" % s["achievements"].size())
	check(Achievements.check(s).is_empty(), "so no card slides in for any of them")
	check(s["_unlocked"], "and none goes to Steam")
	Catches.record(s, "mullet", 1.0)
	check(Achievements.check(s) == ["first_fish"], "one earned later in the game is still told of")


func test_no_made_up_game_sends_achievements_to_steam() -> void:
	Game.max_state()
	check(not Awards.may_send(), "a game with everything unlocked sends nothing to Steam")
	Game.demo_state()
	check(not Awards.may_send(), "nor one started some way in")
	Game.new_game("Real", "mutt")
	check(not Awards.may_send(), "and nothing is sent while the tests run")
	check(not "Steam" in FileAccess.get_file_as_string("res://scripts/rules/achievements.gd"), "the rules leave Steam to Awards")
