extends "res://tests/test_case.gd"
## The spec's smaller rules and the review's minor findings, each pinned by a test.


func test_rain_brings_more_bites_and_wind_spoils_the_net() -> void:
	check(Bite.chance("mullet", "worm", 10.0, "rain") > Bite.chance("mullet", "worm", 10.0, "clear"), "fish bite more in the rain")
	var calm := Nets.throw(9, {"size": 8}, 0.5, Seeds.rng(1, "n"), "clear")
	var windy := Nets.throw(9, {"size": 8}, 0.5, Seeds.rng(1, "n"), "wind")
	check(windy < calm, "a net thrown in the wind brings up fewer")


func test_storms_keep_the_boats_in_harbour() -> void:
	Game.new_game("Test", "mutt")
	Game.state["chapter"] = 2
	Game.state["weather"] = "storm"
	check(not BayMap.sail(Game.state, "rocky_shore") and BayMap.locked_reason(Game.state, "rocky_shore") != "", "no sailing out in a storm")
	Game.state["weather"] = "clear"
	check(BayMap.sail(Game.state, "rocky_shore"), "but on a clear day you can")


func test_the_sailing_boat_sails_faster() -> void:
	check(BayMap.travel_minutes("capri", "sailing_boat") < BayMap.travel_minutes("capri", "fishing_boat"), "a sail is quicker than oars")


func test_the_saturnalia_brings_bigger_orders() -> void:
	Game.new_game("Test", "mutt")
	var normal := Orders.board_size(Game.state)
	Game.state["time"] = Clock.minutes_per_day() * (21 + 2) + 1.0
	check(Orders.board_size(Game.state) > normal, "more orders on the board for the feasts")
	Game.state["orders"] = []
	Orders.new_day(Game.state, Seeds.rng(3, "o"))
	check(Game.state["orders"].all(func(o): return o.get("feast", false)), "and they pay as feast orders")


func test_a_feeder_feeds_the_ponds_each_morning() -> void:
	Game.new_game("Test", "mutt")
	Game.state["denarii"] = 1000
	Game.state["chapter"] = 2
	check(Helpers.hire(Game.state, "feeder"), "a pond feeder is hired")
	Game.state["pond"] = {"stage": 1, "features": ["sand"], "fish": [{"fish": "mullet", "pounds": 1.0, "name": "", "finery": "", "age_days": 9, "fed": false}]}
	Helpers.morning(Game.state)
	check(Game.state["pond"]["fish"][0]["fed"], "the fish are fed without you")


func test_sleeping_until_morning() -> void:
	Game.new_game("Test", "mutt")
	Game.state["time"] = Clock.minutes_per_day() * 2.0 + 21.0
	World.sleep(Game.state, Seeds.rng(1, "s"))
	check(is_equal_approx(float(Game.state["time"]), Clock.minutes_per_day() * 3.0), "you wake at dawn the next day")


func test_the_bait_box_holds_only_so_much() -> void:
	Game.new_game("Test", "mutt")
	Game.state["denarii"] = 1000
	Game.state["bait"] = {"worm": 28}
	check(not Shop.buy(Game.state, "worm"), "a full box takes no more")
	Game.state["gear"]["bait_box"] = "bait_box_2"
	check(Shop.buy(Game.state, "worm"), "a bigger box does")


func test_the_bronze_lamp_draws_fish_from_further() -> void:
	check(Trident.reach("bronze_lamp") > Trident.reach("clay_lamp") and Trident.reach("") == 0.0, "a brighter lamp, a wider light")


func test_each_garum_grade_keeps_its_own_quality() -> void:
	Game.new_game("Test", "mutt")
	Game.state["salt"] = 20
	Game.state["tanks"][1]["restored"] = true
	Garum.fill(Game.state, 0, [{"fish": "sardine", "pounds": 10.0}], 5)
	Garum.fill(Game.state, 1, [{"fish": "sardine", "pounds": 10.0}], 5)
	for d in 12:
		Garum.stir(Game.state, 0)
		Garum.day(Game.state)
	Garum.take(Game.state, 0)
	var good := Garum.price("garum", Garum.quality(Game.state, "garum"), false)
	Garum.fill(Game.state, 2, [], 0)
	for d in 4:
		Garum.day(Game.state)
	Garum.take(Game.state, 1)
	check(Garum.quality(Game.state, "garum") > 0.5 and Garum.price("garum", Garum.quality(Game.state, "garum"), false) <= good, "bottling a poorer tank only dilutes the same grade")


func test_the_pond_show_sees_whether_the_fish_were_fed() -> void:
	Game.new_game("Test", "mutt")
	var fed := {"stage": 2, "features": ["rocks", "sand"], "fish": [{"fish": "bream", "pounds": 5.0, "name": "", "finery": "", "age_days": 9, "fed": true}]}
	Game.state["pond"] = fed
	var with_food := Ponds.show_score(Game.state)
	fed["fish"][0]["fed"] = false
	check(Ponds.show_score(Game.state) < with_food, "fed fish score more")
	Game.state["pond"]["fish"][0]["fed"] = true
	Game.state["time"] = Clock.minutes_per_day() * 19.5
	World.advance(Game.state, Clock.minutes_per_day(), Seeds.rng(1, "w"))
	check(Game.state.has("_show") and float(Game.state["_show"]["score"]) >= with_food - 0.01, "and the show is judged before the morning's hunger")


func test_a_pot_legend_turns_up_in_one_pot_only() -> void:
	Game.new_game("Test", "mutt")
	Game.state["time"] = Clock.minutes_per_day() * 0.95
	var pots := []
	for i in 6:
		pots.append({"place": "rocky_shore", "x": 100 * i, "depth": 120, "catch": [], "size": 3, "hours": 0.0, "bait": "salted_fish"})
	Game.state["traps"] = pots
	for i in 200:
		World.advance(Game.state, 0.05, Seeds.rng(i, "p"))
	var octopus := 0
	for t in Game.state["traps"]:
		octopus += t["catch"].filter(func(c): return c["fish"] == "carteia_octopus").size()
	check(octopus <= 1, "never two of a legend at once")


func test_a_stale_hold_choice_frees_the_fish_it_names() -> void:
	Game.new_game("Test", "mutt")
	for f in ["mullet", "bream", "sardine"]:
		Hold.add(Game.state, {"fish": f, "pounds": 1.0, "fresh": 1.0})
	var bream: Dictionary = Game.state["hold"][1]
	Hold.release(Game.state, 0)
	check(Hold.release_fish(Game.state, bream) and not Game.state["hold"].has(bream) and Game.state["hold"].size() == 1, "the bream goes, not the sardine")
