extends "res://tests/test_case.gd"
## The final review's findings, each pinned by a test.


func test_every_legend_and_request_can_be_baited() -> void:
	Game.new_game("Test", "mutt")
	Game.state["chapter"] = 5
	var wanted := {}
	for id in Data.fish:
		if Data.fish[id]["legend"]:
			wanted[id] = true
	for c in Data.clients.values():
		for step in c["steps"]:
			wanted[step["fish"]] = true
	for id in wanted:
		var f: Dictionary = Data.fish[id]
		var needs_bait: bool = f["methods"].any(func(m): return m in ["line", "trap"])
		if needs_bait and not f["methods"].any(func(m): return m in ["net", "trident"]):
			check(f["baits"].any(func(b): return Shop.on_sale(Game.state, b)), id + " takes a bait that can be bought")


func test_a_live_request_asks_for_a_fish_that_can_be_kept_alive() -> void:
	for c in Data.clients.values():
		for step in c["steps"]:
			if step["alive"]:
				check(Data.fish[step["fish"]].get("live", false), "%s asks for a live %s, which can live" % [c["id"], step["fish"]])


func test_every_waiting_client_comes_to_town_within_a_week() -> void:
	Game.new_game("Test", "mutt")
	Game.state["chapter"] = 5
	var seen := {}
	for day in 7:
		for c in Story.visiting(Game.state, day):
			seen[c] = true
	check(seen.size() == Data.clients.size(), "all six clients visit within a week")
	check(Story.visiting(Game.state, 3).size() <= 2, "no more than two on a day")


func test_time_away_runs_each_morning_on_its_own_day() -> void:
	Game.new_game("Test", "mutt")
	Game.state["pond"] = {"stage": 2, "features": ["rocks", "sand"], "fish": []}
	for i in 10:
		Game.state["pond"]["fish"].append({"fish": "bream", "pounds": 7.0, "name": "B", "finery": "earrings", "age_days": 20, "fed": true})
	var before: int = Game.state["denarii"]
	World.advance(Game.state, Clock.minutes_per_day() * 25.0, Seeds.rng(1, "away"))
	check(int(Game.state["stats"].get("shows_won", 0)) == 1, "the pond show is judged once, on its own day")
	check(int(Game.state["denarii"]) - before < 600, "and pays once")


func test_the_mouse_never_casts_through_a_button() -> void:
	Controls.ensure()
	check(not InputMap.action_get_events("cast").any(func(e): return e is InputEventMouseButton), "the cast key is not the mouse; clicks on the water cast instead")
	var b := Ui.button(Nav, "x", func(): pass)
	check(b.focus_mode == Control.FOCUS_NONE, "buttons never keep the keyboard, so Space always casts")
	b.free()


func test_fishing_on_his_own_leaves_no_bait_for_the_swimmers() -> void:
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	s.cast(0.5)
	s.flight = 0.0
	check(s.hook_baited(), "a cast line is baited once it lands")
	s.methods.set_idle(true)
	check(not s.hook_baited(), "fishing on his own, nothing bites the hand line")
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func test_a_full_hold_leaves_fish_in_the_pot() -> void:
	Game.new_game("Test", "mutt")
	for i in 9:
		Hold.add(Game.state, {"fish": "mullet", "pounds": 1.0, "fresh": 1.0})
	var trap := {"place": "harbour", "x": 300, "depth": 150, "catch": [Pick.catch_of("crab", Seeds.rng(1, "c"), true),
		Pick.catch_of("octopus", Seeds.rng(2, "c"), true), Pick.catch_of("crab", Seeds.rng(3, "c"), true)], "size": 3, "hours": 6.0}
	var got := Traps.empty_into(Game.state, trap)
	check(got.size() == 1 and Game.state["hold"].size() == 10, "one fits")
	check(trap["catch"].size() == 2, "the other two wait in the pot")


func test_the_boy_leaves_fish_in_the_pot_when_the_hold_is_full() -> void:
	Game.new_game("Test", "mutt")
	Game.state["helpers"] = ["boy"]
	for i in 10:
		Hold.add(Game.state, {"fish": "mullet", "pounds": 1.0, "fresh": 1.0})
	Game.state["traps"] = [{"place": "harbour", "x": 300, "depth": 150, "catch": [Pick.catch_of("crab", Seeds.rng(1, "c"), true)], "size": 3, "hours": 2.0}]
	Helpers.morning(Game.state)
	check(Game.state["traps"][0]["catch"].size() >= 1, "nothing is thrown away")


func test_the_second_fisherman_fishes_only_while_you_are_ashore() -> void:
	Game.new_game("Test", "mutt")
	Game.state["helpers"] = ["fisherman"]
	Game.state["_ashore"] = false
	World.advance(Game.state, 30.0, Seeds.rng(1, "f"))
	check(Game.state["hold"].is_empty(), "not into your hold at sea")
	Game.state["_ashore"] = true
	World.advance(Game.state, 30.0, Seeds.rng(2, "f"))
	check(not Game.state["hold"].is_empty(), "but while you are in town")


func test_pond_fish_fill_live_orders_and_requests() -> void:
	Game.new_game("Test", "mutt")
	Game.state["pond"] = {"stage": 2, "features": [], "fish": [
		{"fish": "bream", "pounds": 8.0, "name": "Aurata", "finery": "", "age_days": 30, "fed": false}]}
	Game.state["orders"] = [{"fish": "bream", "min_pounds": 6.0, "alive": true, "reward": 90, "reputation": 5, "due": 3}]
	var at := Supply.find(Game.state, Game.state["orders"][0])
	check(at.get("where", "") == "pond", "the grown bream in the pond suits")
	var before: int = Game.state["denarii"]
	check(Orders.fill_from(Game.state, 0, at) and Game.state["denarii"] == before + 90 and Game.state["pond"]["fish"].is_empty(), "and fills the order")


func test_fishing_on_his_own_carries_on_while_the_game_is_closed() -> void:
	Game.new_game("Test", "mutt")
	Game.state["idle"] = {"place": "harbour", "bait": "worm", "depth": 60.0}
	Game.state["last_real_time"] = Time.get_unix_time_from_system() - 3600.0
	Game.catch_up()
	check(not Game.state["hold"].is_empty(), "the boat has caught something by morning")
