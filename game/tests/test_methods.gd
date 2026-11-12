extends "res://tests/test_case.gd"


func test_traps_fill_over_the_hours() -> void:
	var t := {"place": "rocky_shore", "x": 300, "depth": 120, "set_time": 0.0, "catch": [], "size": 3}
	Traps.fill(t, 5.0, Seeds.rng(1, "t"))
	check(t["catch"].size() == 2, "two catches in five hours")
	Traps.fill(t, 40.0, Seeds.rng(2, "t"))
	check(t["catch"].size() == 3, "never more than the trap holds")
	check(t["catch"].all(func(c): return "trap" in Data.fish[c["fish"]]["methods"] and c["live"] == Traps.alive(c["fish"])), "trap fish, kept alive when their kind can be")
	var got := Traps.pull(t)
	check(got.size() == 3 and t["catch"].is_empty(), "pulling empties the trap")


func test_a_pot_puts_an_urchin_in_the_hold_not_the_well() -> void:
	Game.new_game("Marcus", "mutt")
	Game.state["boat"] = "big_boat"
	var t := {"place": "rocky_shore", "x": 300, "depth": 120, "catch": [{"fish": "urchin", "pounds": 0.5, "fresh": 1.0, "live": true},
		{"fish": "crab", "pounds": 0.5, "fresh": 1.0, "live": true}], "size": 3, "hours": 4.0}
	Traps.empty_into(Game.state, t)
	check(Game.state["hold"].map(func(f): return f["fish"]) == ["urchin"], "an urchin, even one from an old pot, goes to the hold")
	check(Game.state["live_well"].map(func(f): return f["fish"]) == ["crab"], "a crab to the well")
	check(not Traps.alive("carteia_octopus") and not Traps.alive("neptune_lobster") and Traps.alive("lobster"), "the legends in pots are not kept alive")
	var pot := {"place": "rocky_shore", "x": 300, "depth": 120, "catch": [], "size": 6}
	Traps.fill(pot, 200.0, Seeds.rng(5, "t"))
	check(pot["catch"].all(func(c): return c["live"] == Traps.alive(c["fish"])), "a filled pot marks each catch as its kind lives")


func test_a_net_catches_more_the_better_it_is_aimed() -> void:
	var net := {"size": 8}
	var good := Nets.throw(9, net, 0.0, Seeds.rng(1, "n"))
	var poor := Nets.throw(9, net, 0.8, Seeds.rng(1, "n"))
	check(good >= 1 and good <= 8, "a good throw catches up to the net's size")
	check(poor >= 1 and poor < good, "a poor one fewer")
	check(Nets.throw(9, net, 1.2, Seeds.rng(1, "n")) == 0, "a miss catches nothing")
	check(Nets.throw(2, net, 0.0, Seeds.rng(1, "n")) <= 2, "never more than the shoal")


func test_the_trident_is_for_the_night_and_needs_a_good_aim() -> void:
	check(not Trident.can_use(9.0, "clay_lamp") and Trident.can_use(23.0, "clay_lamp"), "night only")
	check(not Trident.can_use(23.0, ""), "and only with a lamp")
	check(Trident.hits(Vector2(100, 50), Vector2(104, 53)) and not Trident.hits(Vector2(100, 50), Vector2(110, 50)), "within six pixels")


func test_idle_fishing_is_slower_and_never_legendary() -> void:
	var got := Idle.catches(60.0, "harbour", 60.0, "worm", 100, Seeds.rng(1, "i"))
	check(got.size() >= 15 and got.size() <= 25, "about a third of an hour's active catch")
	check(got.all(func(f): return not Data.fish[f["fish"]]["legend"] and not f.get("live", false)), "no legends, nothing alive")
	check(Idle.catches(600.0, "harbour", 60.0, "worm", 4, Seeds.rng(1, "i")).size() == 4, "it stops when the hold is full")


func test_a_full_hold_asks_before_losing_a_fish() -> void:
	Game.new_game("Test", "mutt")
	Game.state["boat"] = "skiff"
	for i in 10:
		Hold.add(Game.state, {"fish": "mullet", "pounds": 1.0, "fresh": 1.0})
	check(Hold.add(Game.state, {"fish": "bream", "pounds": 2.0, "fresh": 1.0}) == "full", "the eleventh fish asks")
	check(Game.state["hold"].size() == 10, "and nothing was dropped")
	Hold.release(Game.state, 0)
	check(Hold.add(Game.state, {"fish": "bream", "pounds": 2.0, "fresh": 1.0}) == "hold", "letting one go makes room")


func test_live_fish_go_in_the_well() -> void:
	Game.new_game("Test", "mutt")
	Game.state["boat"] = "fishing_boat"
	check(Hold.add(Game.state, {"fish": "octopus", "pounds": 3.0, "fresh": 1.0, "live": true}) == "well", "a live octopus goes in the well")
	Game.state["boat"] = "skiff"
	check(Hold.add(Game.state, {"fish": "octopus", "pounds": 3.0, "fresh": 1.0, "live": true}) == "hold", "a skiff has no well, so it goes in the hold")


func test_freshness_and_salt() -> void:
	Game.new_game("Test", "mutt")
	Hold.add(Game.state, {"fish": "mullet", "pounds": 1.0, "fresh": 1.0})
	Hold.add(Game.state, {"fish": "bream", "pounds": 1.0, "fresh": 1.0})
	Hold.salt(Game.state, 1)
	Hold.freshen(Game.state, 600.0)
	check(Game.state["hold"][0]["fresh"] < 0.3 and is_equal_approx(Game.state["hold"][1]["fresh"], 0.6), "fresh fish go off, salted fish keep")
