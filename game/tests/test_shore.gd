extends "res://tests/test_case.gd"


func test_a_happy_pond_grows_and_breeds() -> void:
	Game.new_game("Test", "mutt")
	var pond := {"site": 0, "size": "large", "water": "sea", "features": ["rocks", "caves", "weed"], "fish": [
		{"fish": "bream", "pounds": 2.0, "name": "", "finery": "", "age_days": 10, "fed": true},
		{"fish": "bream", "pounds": 2.1, "name": "", "finery": "", "age_days": 10, "fed": true}]}
	Game.state["ponds"] = [pond]
	for d in 6:
		for f in pond["fish"]:
			f["fed"] = true
		Ponds.day(Game.state, Seeds.rng(d, "p"))
	check(pond["fish"][0]["pounds"] > 2.0, "fed fish grow")
	check(pond["fish"].size() == 3, "a happy pair has young")


func test_a_hungry_pond_does_not_grow() -> void:
	Game.new_game("Test", "mutt")
	var pond := {"site": 0, "size": "small", "water": "sea", "features": [], "fish": [{"fish": "moray", "pounds": 4.0, "name": "Hortensia", "finery": "earrings", "age_days": 40, "fed": false}]}
	Game.state["ponds"] = [pond]
	Ponds.day(Game.state, Seeds.rng(1, "p"))
	check(pond["fish"][0]["pounds"] == 4.0 and Ponds.happiness(pond, pond["fish"][0]) < 0.5, "a hungry moray without a cave does not grow")


func test_pond_fish_grow_past_any_caught_wild() -> void:
	Game.new_game("Test", "mutt")
	var pond := {"site": 0, "size": "large", "water": "sea", "features": ["rocks", "sand"], "fish": [{"fish": "bream", "pounds": 6.9, "name": "", "finery": "", "age_days": 10, "fed": true}]}
	Game.state["ponds"] = [pond]
	for d in 200:
		pond["fish"][0]["fed"] = true
		Ponds.day(Game.state, Seeds.rng(d, "p"))
	check(pond["fish"][0]["pounds"] > 7.0 and pond["fish"][0]["pounds"] <= 7.0 * 1.3 + 0.001, "up to 1.3 times the wild maximum")


func test_ponds_are_built_stocked_named_and_dressed() -> void:
	Game.new_game("Test", "mutt")
	Game.state["denarii"] = 1000
	check(Ponds.build(Game.state, 0, "small") and Game.state["ponds"].size() == 1, "a pond cut into the rock")
	check(not Ponds.build(Game.state, 1, "small"), "only one pond in the first chapter")
	check(Ponds.add_feature(Game.state, 0, "rocks") and "rocks" in Game.state["ponds"][0]["features"], "rocks put in")
	Game.state["boat"] = "fishing_boat"
	Hold.add(Game.state, {"fish": "bream", "pounds": 2.0, "fresh": 1.0, "live": true})
	check(Ponds.stock(Game.state, 0, 0) and Game.state["live_well"].is_empty() and Game.state["ponds"][0]["fish"].size() == 1, "a live bream goes from the well to the pond")
	Ponds.name_fish(Game.state, 0, 0, "Aurata")
	Game.state["finery"] = ["earrings"]
	check(Ponds.dress(Game.state, 0, 0, "earrings") and Game.state["ponds"][0]["fish"][0]["finery"] == "earrings" and Game.state["finery"].is_empty(), "named and dressed")
	Ponds.feed(Game.state, 0)
	check(Game.state["ponds"][0]["fish"][0]["fed"], "fed by hand")


func test_garum_grades_by_days_and_fish() -> void:
	Game.new_game("Test", "mutt")
	Game.state["salt"] = 20
	check(Garum.fill(Game.state, 0, [{"fish": "mackerel", "pounds": 10.0}], 5), "the working tank takes fish and salt")
	for d in 20:
		Garum.day(Game.state)
	check(Garum.grade(Game.state["tanks"][0]) == "sociorum", "twenty days of mackerel make the finest")
	check(not Garum.fill(Game.state, 1, [{"fish": "sardine", "pounds": 10.0}], 5), "a ruined tank takes nothing")
	Game.state["tanks"][1]["restored"] = true
	Garum.fill(Game.state, 1, [{"fish": "sardine", "pounds": 10.0}], 5)
	for d in 25:
		Garum.day(Game.state)
	check(Garum.grade(Game.state["tanks"][1]) == "garum", "other fish make plain garum however long")
	check(Garum.export_day(7) and not Garum.export_day(8), "the ship comes every seventh day")
	var got := Garum.take(Game.state, 0)
	check(got["grade"] == "sociorum" and int(got["amphorae"]) >= 1 and Game.state["garum"].get("sociorum", 0) >= 1, "bottled in amphorae")
	check(Garum.grade(Game.state["tanks"][0]) == "", "and the tank is empty again")


func test_stirring_makes_better_garum() -> void:
	Game.new_game("Test", "mutt")
	Game.state["salt"] = 20
	Game.state["tanks"][1]["restored"] = true
	Garum.fill(Game.state, 0, [{"fish": "sardine", "pounds": 10.0}], 5)
	Garum.fill(Game.state, 1, [{"fish": "sardine", "pounds": 10.0}], 5)
	for d in 10:
		Garum.stir(Game.state, 0)
		Garum.day(Game.state)
	check(float(Game.state["tanks"][0]["quality"]) > float(Game.state["tanks"][1]["quality"]), "a stirred tank is better")
	check(Garum.price("garum", 1.0, false) < Garum.price("garum", 1.0, true), "the export ship pays more")


func test_the_shore_opens_with_its_six_pond_sites() -> void:
	Game.new_game("Test", "mutt")
	Game.state["denarii"] = 500
	Ponds.build(Game.state, 0, "small")
	var s: Node = load("res://scripts/shore/shore_screen.gd").new()
	Nav.add_child(s)
	s.enter({})
	check(s.views.size() == 6 and s.views[0].pond().size() > 0 and s.views[1].pond().is_empty(), "six sites, the first one cut")
	for c in Nav.ui.get_children():
		c.free()
	s.free()
