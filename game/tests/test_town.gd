extends "res://tests/test_case.gd"


func test_selling_the_same_fish_lowers_its_price() -> void:
	Game.new_game("Test", "mutt")
	for i in 5:
		Hold.add(Game.state, {"fish": "mullet", "pounds": 1.0, "fresh": 1.0})
	var first := Market.price(Game.state, "mullet", 1.0, 1.0)
	var before: int = Game.state["denarii"]
	var paid := Market.sell(Game.state, 0)
	check(paid == first and Game.state["denarii"] == before + first and Game.state["hold"].size() == 4, "a sale pays and empties a basket")
	for i in 3:
		Market.sell(Game.state, 0)
	check(Market.price(Game.state, "mullet", 1.0, 1.0) < first, "the fifth mullet sells for less than the first")
	check(Market.price(Game.state, "bream", 1.0, 1.0) == Catalog.value("bream", 1.0, 1.0), "other kinds keep their price")
	Market.new_day(Game.state)
	Market.new_day(Game.state)
	Market.new_day(Game.state)
	check(Market.price(Game.state, "mullet", 1.0, 1.0) == first, "and the price recovers in a few days")


func test_orders_only_ask_for_reachable_fish() -> void:
	Game.new_game("Test", "mutt")
	Orders.new_day(Game.state, Seeds.rng(1, "o"))
	check(Game.state["orders"].size() == 3, "three orders on the first morning")
	for o in Game.state["orders"]:
		var places: Array = Data.fish[o["fish"]]["places"]
		check(places.any(func(p): return Data.places[p]["boat"] == "skiff" and p in Story.unlocks(1)["places"]), "an order the skiff can fill")
		check(not Data.fish[o["fish"]]["legend"], "no legends before the deep")
	Game.state["chapter"] = 3
	Game.state["orders"] = []
	Orders.new_day(Game.state, Seeds.rng(2, "o"))
	check(Game.state["orders"].size() == 5, "more orders as your name grows")


func test_filling_an_order_pays_and_raises_your_name() -> void:
	Game.new_game("Test", "mutt")
	Game.state["orders"] = [{"fish": "mullet", "min_pounds": 1.0, "alive": false, "reward": 20, "reputation": 3, "due": 3}]
	Hold.add(Game.state, {"fish": "mullet", "pounds": 0.6, "fresh": 1.0})
	Hold.add(Game.state, {"fish": "mullet", "pounds": 1.4, "fresh": 1.0})
	var before: int = Game.state["denarii"]
	check(not Orders.fill(Game.state, 0, 0), "too small a mullet is turned down")
	check(Orders.fill(Game.state, 0, 1) and Game.state["denarii"] == before + 20 and Game.state["reputation"] == 3, "paid and known")
	check(Game.state["orders"].is_empty() and Game.state["hold"].size() == 1, "the order and the fish are gone")


func test_orders_run_out_of_time() -> void:
	Game.new_game("Test", "mutt")
	Game.state["orders"] = [{"fish": "mullet", "min_pounds": 1.0, "alive": false, "reward": 20, "reputation": 3, "due": 0}]
	Game.state["time"] = Clock.minutes_per_day() * 1.5
	Orders.expire(Game.state)
	check(Game.state["orders"].is_empty(), "yesterday's order is taken down")


func test_chapters_open_with_your_name() -> void:
	check(Story.chapter_for(0) == 1 and Story.chapter_for(100000) == 5, "five chapters")
	check(Story.unlocks(1)["places"] == ["harbour"] and "rocky_shore" in Story.unlocks(2)["places"], "each opens new water")
	for c in Data.clients.values():
		check(c["steps"].size() >= 3 and c.has("portrait"), c["id"] + " has a story and a face")


func test_a_client_story_goes_step_by_step() -> void:
	Game.new_game("Test", "mutt")
	var step := Story.client_step(Game.state, "cook")
	check(not step.is_empty() and step.has("fish"), "the cook asks for something at once")
	Story.advance_client(Game.state, "cook")
	check(Story.client_step(Game.state, "cook") != step, "and something else next")
	check(Story.client_step(Game.state, "widow").is_empty(), "the widow waits for the deep")


func test_the_shops_sell_only_what_is_open_and_affordable() -> void:
	Game.new_game("Test", "mutt")
	Game.state["denarii"] = 100
	check(Shop.buy(Game.state, "ash_rod") and Game.state["gear"]["rod"] == "ash_rod" and Game.state["denarii"] == 40, "a rod bought and in hand")
	check(not Shop.buy(Game.state, "ash_rod"), "not twice")
	check(not Shop.buy(Game.state, "yew_rod"), "nor what the netmaker has not got yet")
	check(not Shop.buy(Game.state, "fishing_boat"), "nor a boat before the bay opens")
	var worms: int = Game.state["bait"].get("worm", 0)
	check(Shop.buy(Game.state, "worm") and Game.state["bait"]["worm"] == worms + 5, "bait comes in packs")
	Game.state["denarii"] = 0
	check(not Shop.buy(Game.state, "shrimp"), "nothing without the money")


func test_a_new_day_comes_to_town() -> void:
	Game.new_game("Test", "mutt")
	Game.state["boat"] = "fishing_boat"
	Hold.add(Game.state, {"fish": "octopus", "pounds": 3.0, "fresh": 1.0, "live": true})
	Game.state["market"]["mullet"] = 0.5
	World.advance(Game.state, Clock.minutes_per_day(), Seeds.rng(1, "w"))
	check(Game.state["live_well"].is_empty() and Game.state["hold"].size() == 1, "a fish left in the well overnight dies into the hold")
	check(Market.demand(Game.state, "mullet") > 0.5 and Game.state["orders"].size() >= 3, "prices climb back and the board fills")


func test_the_town_opens_with_every_building_clickable() -> void:
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/town/town_screen.gd").new()
	Nav.add_child(s)
	s.enter({})
	for id in ["market", "netmaker", "boatwright", "board", "goldsmith"]:
		check(s._masks.has(id), id + " can be clicked on its outline")
	for c in Nav.ui.get_children():
		c.free()
	s.free()
