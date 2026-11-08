extends "res://tests/test_case.gd"
## Bugs found by the second audit: each test shows one, failing before its fix.


func test_a_clients_title_keeps_its_own_capitals() -> void:
	check(ClientVisit.title_of({"title": "the freedman with the biggest dinners on the bay"}) == "The freedman with the biggest dinners on the bay",
		"only the first letter of a title starting with 'the' is raised, not every word")
	check(ClientVisit.title_of({"title": "cook of the Elephant tavern"}) == "cook of the Elephant tavern", "other titles are left as written")


func test_the_garum_works_count_in_good_latin_and_english() -> void:
	check(GarumPanel.amphorae(1) == "1 amphora", "one amphora, not '%s'" % GarumPanel.amphorae(1))
	check(GarumPanel.amphorae(3) == "3 amphorae", "and several amphorae")
	check(GarumPanel.ship_text(6) == "comes in 1 day", "the ship comes in 1 day, not '%s'" % GarumPanel.ship_text(6))
	check(GarumPanel.ship_text(5) == "comes in 2 days", "or in 2 days")


func _hooked() -> Node:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	s.cast(0.5)
	for i in 600:
		s.sink(0.05)
	s._on_bite({"id": "mullet", "lb": 1.0, "state": "bit", "heading": 1.0})
	while s.line_state() == "nibble":
		s.bite_step(0.05)
	s.strike()
	return s


func _done(s: Node) -> void:
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func test_a_hooked_fish_waits_while_a_window_is_open() -> void:
	var s := _hooked()
	check(s.line_state() == "fighting", "a fish is on")
	var was: float = s.fight.distance
	var tension: float = s.fight.tension
	Ui.window("Settings", 200, 100)
	for i in 200:
		s._process(0.05)
	check(s.line_state() == "fighting" and s.fight != null, "ten seconds in the settings do not lose the fish")
	check(is_equal_approx(s.fight.distance, was) and is_equal_approx(s.fight.tension, tension), "nor move the fight on at all")
	_done(s)


func test_the_way_of_fishing_cannot_change_with_a_fish_on() -> void:
	var s := _hooked()
	s.methods.set_method("trap")
	check(s.methods.method == "line" and s.fight != null, "picking pots while a fish is on keeps the line and the fish")
	_done(s)


func test_a_nibbling_fish_keeps_its_mouth_on_the_drifting_bait() -> void:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	s.cast(0.5)
	for i in 600:
		s.sink(0.05)
	s.swimmers.populate()
	var f: Dictionary = s.swimmers.fish[0]
	f["state"] = "bit"
	s._on_bite(f)
	check(s.line_state() == "nibble", "the fish is at the bait")
	s.hook.x += 4.0
	for i in 3:
		s._process(0.05)
	check(Swimmers.mouth_at(f).distance_to(s.hook + Swimmers.BAIT_MIDDLE) <= 2.0, "and its mouth stays on the bait as the hook drifts, %s against %s" % [Swimmers.mouth_at(f), s.hook + Swimmers.BAIT_MIDDLE])
	_done(s)


func _coast_at(place: String) -> Node:
	for c in Nav.ui.get_children():
		c.free()
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": place})
	return s


func test_a_game_saved_while_he_fished_on_his_own_carries_on_so() -> void:
	Game.new_game("Test", "mutt")
	Game.state["idle"] = {"place": "harbour", "bait": "worm", "depth": 30.0, "water": 60.0}
	var s := _coast_at("harbour")
	s._process(0.05)
	check(s.methods.idle, "back at the same place, he is still fishing on his own")
	_done(s)
	Game.state["idle"] = {"place": "rocky_shore", "bait": "worm", "depth": 30.0, "water": 60.0}
	s = _coast_at("harbour")
	s._process(0.05)
	check(not s.methods.idle and not Game.state.has("idle"), "and elsewhere it is over, not left set in the save")
	_done(s)


func test_fishing_on_his_own_while_away_uses_bait() -> void:
	Game.new_game("Test", "mutt")
	Game.state["bait"] = {"worm": 3}
	Game.state["idle"] = {"place": "harbour", "bait": "worm", "depth": 30.0, "water": 60.0}
	Game.state["last_real_time"] = Time.get_unix_time_from_system() - 8 * 3600
	var before: int = Game.state["hold"].size() + Game.state["live_well"].size()
	Game.catch_up()
	var caught: int = Game.state["hold"].size() + Game.state["live_well"].size() - before
	check(caught > 0 and caught <= 3, "with three worms he catches at most three fish while you are away, %d" % caught)
	check(int(Game.state["bait"]["worm"]) == 3 - caught, "using a worm for each")
	Game.new_game("Test", "mutt")
	Game.state["bait"] = {}
	Game.state["idle"] = {"place": "harbour", "bait": "", "depth": 30.0, "water": 60.0}
	Game.state["last_real_time"] = Time.get_unix_time_from_system() - 8 * 3600
	Game.catch_up()
	check(Game.state["hold"].is_empty(), "and with no bait he catches nothing")


func test_he_will_not_fish_on_his_own_without_bait() -> void:
	Game.new_game("Test", "mutt")
	Game.state["bait"] = {}
	Game.state["current_bait"] = ""
	var s := _coast_at("harbour")
	s.methods.set_idle(true)
	check(not s.methods.idle and not Game.state.has("idle"), "with no bait he stays at the rod")
	_done(s)


func test_the_save_knows_how_deep_his_bait_hangs() -> void:
	Game.new_game("Test", "mutt")
	var s := _coast_at("harbour")
	s.methods.set_idle(true)
	s.cast(0.6)
	for i in 800:
		s._process(0.05)
	check(float(Game.state["idle"]["depth"]) > 15.0, "once it has sunk, the depth kept for fishing while away is where it hangs, %.0f" % float(Game.state["idle"]["depth"]))
	_done(s)


func test_back_at_the_rod_with_pots_picked_brings_the_line_in() -> void:
	Game.new_game("Test", "mutt")
	var s := _coast_at("harbour")
	s.methods.set_method("trap")
	s.methods.set_idle(true)
	s.cast(0.6)
	for i in 100:
		s._process(0.05)
	s.methods.set_idle(false)
	for i in 200:
		s._process(0.05)
	check(s.line_state() == "reeled", "the float he cast comes back in, so the pots work again, not left in the water: %s" % s.line_state())
	_done(s)


## Whether a node or anything it sits in is on its way out of the tree.
func _going(n: Node) -> bool:
	while n != null:
		if n.is_queued_for_deletion():
			return true
		n = n.get_parent()
	return false


func test_the_full_hold_choice_is_a_window_of_its_own() -> void:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "mutt")
	for i in 10:
		Game.state["hold"].append({"fish": "mullet", "pounds": 1.0, "fresh": 1.0})
	HoldChoice.ask({"fish": "bream", "pounds": 2.0})
	check(Ui.window_open(), "it holds play while it is open, as every window does")
	HoldChoice.ask({"fish": "bream", "pounds": 3.0})
	var shown := Nav.ui.find_children("*", "Label", true, false).filter(func(l): return l.text.to_upper() == "THE HOLD IS FULL" and not _going(l))
	check(shown.size() == 1, "and a second full-hold catch replaces it rather than stacking a copy, %d shown" % shown.size())
	for c in Nav.ui.get_children():
		c.free()


func test_the_dog_still_shows_when_it_naps() -> void:
	for id in ["skiff", "fishing_boat", "sailing_boat", "big_boat"]:
		for breed in ["hound", "sighthound", "lapdog"]:
			Game.new_game("Test", breed)
			Game.state["boat"] = id
			var s := _coast_at("harbour")
			s.methods.idle = true
			for i in 40:
				s.dog._process(0.05)
			check(s.dog.mood == "sleep_east", "%s, %s: the dog naps while he fishes on his own" % [id, breed])
			check(s.dog.shown_rows() >= 8, "%s, %s: and enough of it shows over the gunwale to see it lying there, %d rows" % [id, breed, s.dog.shown_rows()])
			_done(s)


func test_a_tank_needs_an_amphoras_worth_of_fish() -> void:
	Game.new_game("Test", "mutt")
	Game.state["salt"] = 20
	var each := float(Data.garum["pounds_per_amphora"])
	check(not Garum.fill(Game.state, 0, [{"fish": "mackerel", "pounds": 0.3}], 1), "one little mackerel is not enough to fill a tank")
	check(Garum.fill(Game.state, 0, [{"fish": "mackerel", "pounds": each * 2.4}], Garum.salt_needed(each * 2.4)), "a tank's worth of fish fills it")
	Game.state["tanks"][0]["days"] = 30
	check(int(Garum.take(Game.state, 0)["amphorae"]) == 2, "and gives an amphora for each %.0f lb of fish" % each)


func test_a_pot_partly_emptied_does_not_fill_again_at_once() -> void:
	Game.new_game("Test", "mutt")
	var pot := {"place": "rocky_shore", "x": 100.0, "depth": 60.0, "catch": [], "size": 3, "hours": 0.0, "bait": ""}
	var rng := Seeds.rng(1, "pot")
	Traps.fill(pot, 12.0, rng)
	check(pot["catch"].size() == 3, "a pot left long enough fills up")
	for i in Data.boats[Game.state["boat"]]["hold"] - 1:
		Game.state["hold"].append({"fish": "mullet", "pounds": 1.0, "fresh": 1.0})
	var taken := Traps.empty_into(Game.state, pot)
	check(taken.size() == 1 and pot["catch"].size() == 2, "with room for one, one comes out and two stay")
	Traps.fill(pot, 0.01, rng)
	check(pot["catch"].size() == 2, "and the pot does not fill its empty basket the moment after, %d in it" % pot["catch"].size())


func test_pots_are_bought_one_at_a_time() -> void:
	Game.new_game("Test", "mutt")
	Game.state["chapter"] = 4
	check(Shop.on_sale(Game.state, "trap_3"), "with two pots the third is for sale")
	check(not Shop.on_sale(Game.state, "trap_6"), "but not the sixth, which would skip the price of the ones between")


## The orders the board posts over many mornings, from a game at this chapter.
func _orders(chapter: int, mornings := 150, setup := Callable()) -> Array:
	Game.new_game("Test", "mutt")
	Game.state["chapter"] = chapter
	if setup.is_valid():
		setup.call()
	var out := []
	var rng := Seeds.rng(5, "board")
	for i in mornings:
		Game.state["orders"] = []
		Game.state["time"] = float(i) * 1440.0
		Orders.new_day(Game.state, rng)
		out.append_array(Game.state["orders"])
	return out


func test_the_board_never_asks_for_a_legend_already_caught() -> void:
	var asked := _orders(5, 150, func():
		for id in Data.fish:
			if Data.fish[id]["legend"]:
				Game.state["legends"][id] = true)
	var legends := asked.filter(func(o): return Data.fish[o["fish"]]["legend"])
	check(legends.is_empty(), "with every legend caught, none is ordered, %d were" % legends.size())


func test_the_board_asks_only_for_fish_you_can_catch_now() -> void:
	var asked := _orders(1, 200)
	var gearless := asked.filter(func(o): return not Data.fish[o["fish"]]["methods"].any(func(m): return m in ["line", "trap"]))
	check(gearless.is_empty(), "in the first chapter, with only a rod and pots, nothing is ordered that needs a net or a trident, %d were" % gearless.size())
	var unseasonal := _orders(5, 200).filter(func(o):
		var seasons: Array = Data.fish[o["fish"]]["seasons"]
		return not seasons.is_empty() and not Clock.season(int(o["due"])) in seasons and not Clock.season(int(o["due"]) - 2) in seasons)
	check(unseasonal.is_empty(), "nor a fish out of its season, %d were" % unseasonal.size())


func test_orders_for_the_smallest_fish_ask_a_fair_weight() -> void:
	var asked := _orders(3, 300)
	var small := asked.filter(func(o): return float(Data.fish[o["fish"]]["pounds"][1]) < 1.0)
	check(not small.is_empty(), "the board orders small fish too")
	for o in small:
		var r: Array = Data.fish[o["fish"]]["pounds"]
		var lb := float(o["min_pounds"])
		check(lb > float(r[0]) * 0.99 and lb < float(r[1]), "%s: asks %.3f lb, inside its %.2f to %.2f lb, not nothing and not its very biggest" % [o["fish"], lb, r[0], r[1]])
		check(Units.need(lb) != "0 kg" and Units.need(lb) != "0 lb", "%s: and the board shows a weight, not %s" % [o["fish"], Units.need(lb)])


func test_the_helpers_morning_work_shows_all_day() -> void:
	Game.new_game("Test", "mutt")
	Game.state["helpers"] = ["boy", "feeder"]
	Game.state["ponds"] = [{"site": 0, "size": "large", "water": "sea", "features": ["rocks"], "fish": [
		{"fish": "bream", "pounds": 2.0, "name": "", "finery": "", "age_days": 9, "fed": false}]}]
	Game.state["tanks"][0] = {"restored": true, "fish": {"sardine": 6.0}, "pounds": 6.0, "days": 1, "quality": 0.5, "stirred": false}
	World.new_day(Game.state, Seeds.rng(1, "morning"))
	check(Game.state["ponds"][0]["fish"][0]["fed"], "the fish Lucilla fed this morning count as fed all day")
	check(Game.state["tanks"][0]["stirred"], "and the tank Tertius stirred counts as stirred")
	var before := float(Game.state["ponds"][0]["fish"][0]["pounds"])
	World.new_day(Game.state, Seeds.rng(2, "morning"))
	check(float(Game.state["ponds"][0]["fish"][0]["pounds"]) > before, "and the fed fish grows overnight")


func _pot_legend(place: String, depth: float, bait: String, season_day: int, sleep: bool, seed: int) -> bool:
	Game.new_game("Test", "mutt")
	Game.state["chapter"] = 5
	Game.state["time"] = float(season_day) * Clock.minutes_per_day() + 14.0
	Game.state["traps"] = [{"place": place, "x": 100.0, "depth": depth, "catch": [], "size": 6, "hours": 0.0, "bait": bait}]
	var rng := Seeds.rng(seed, "pot legend")
	if sleep:
		World.sleep(Game.state, rng)
	else:
		for i in 300:
			World.advance(Game.state, 0.05, rng)
	return Game.state["traps"][0]["catch"].any(func(c): return Data.fish[c["fish"]]["legend"])


func test_the_carteia_octopus_comes_to_a_pot_while_you_sleep() -> void:
	var nights := 0
	for seed in 60:
		if _pot_legend("rocky_shore", 250.0, "salted_fish", 1, true, seed):
			nights += 1
	check(nights >= 5, "a pot baited for it, left over a night slept through, sometimes takes it, %d of 60" % nights)


func test_a_pot_legend_keeps_to_its_own_depth() -> void:
	var winter := 22
	var shallow := 0
	var deep := 0
	for seed in 40:
		if _pot_legend("capri", 115.0, "sardine_strip", winter, false, seed):
			shallow += 1
		if _pot_legend("capri", 450.0, "sardine_strip", winter, false, seed):
			deep += 1
	check(shallow == 0, "Neptune's lobster never comes to a shallow pot, %d did" % shallow)
	check(deep > 0, "only to one down in the deepest water, %d did" % deep)


func test_a_legend_a_client_still_wants_can_be_found_again() -> void:
	Game.new_game("Test", "mutt")
	Game.state["chapter"] = 4
	Game.state["legends"]["sleeping_sunfish"] = true
	Game.state["clients"]["priest"] = 3
	check(Legends.can_appear("sleeping_sunfish", "open_bay", 14.0, "summer", "clear", Game.state),
		"the sunfish sold before the priest asked for it comes again, so his story can still end")
	Game.state["hold"].append({"fish": "sleeping_sunfish", "pounds": 300.0, "fresh": 1.0})
	check(not Legends.can_appear("sleeping_sunfish", "open_bay", 14.0, "summer", "clear", Game.state), "but not while one is kept for him")
	Game.state["hold"].clear()
	Game.state["clients"]["priest"] = 4
	check(not Legends.can_appear("sleeping_sunfish", "open_bay", 14.0, "summer", "clear", Game.state), "nor once nobody wants it")
	var rep := int(Game.state["reputation"])
	Game.state["clients"]["priest"] = 3
	Catches.record(Game.state, "sleeping_sunfish", 300.0, false)
	check(int(Game.state["reputation"]) == rep, "and catching it again does not raise your name again")


func _town_at(hour: float) -> Node:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "mutt")
	var t := Clock.minutes_per_day()
	while Clock.hour(t) < hour:
		t += 0.05
	Game.state["time"] = t
	var s: Node = load("res://scripts/town/town_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({})
	return s


func test_the_town_keeps_up_with_the_hour() -> void:
	var s := _town_at(15.5)
	check(not s._sleep.visible, "at half past three there is no going to bed yet")
	while Clock.hour(float(Game.state["time"])) < 16.5:
		s._process(0.5)
	check(s._sleep.visible, "but staying on in town past four, the bed is offered without leaving and coming back")
	_done(s)


func test_a_client_with_nothing_left_to_ask_has_no_mark() -> void:
	var s := _town_at(10.0)
	Game.state["chapter"] = 5
	s._clients.clear()
	s._place_clients()
	check(not s._clients.is_empty(), "clients are in town")
	var id: String = s._clients[0]["id"]
	check(id in s.marked_clients(), "a client with a request has the gold mark over them")
	Game.state["clients"][id] = Data.clients[id]["steps"].size()
	check(not id in s.marked_clients(), "and once their story is done the mark goes")
	_done(s)


func test_the_title_menu_forgets_a_deleted_save() -> void:
	for c in Nav.ui.get_children():
		c.free()
	for n in range(1, Saves.SLOTS + 1):
		Saves.delete(n)
	Game.new_game("Test", "mutt")
	Saves.save(1)
	var t: Node = load("res://scripts/screens/title.gd").new()
	Nav.port.add_child(t)
	t.enter({})
	var words := func(): return t._menu.get_children().filter(func(b): return b is Button and not _going(b)).map(func(b): return b.text)
	check("Continue" in words.call(), "with a save the title offers to continue it")
	t._load()
	var confirm: LineEdit = Nav.ui.find_children("*", "LineEdit", true, false).filter(func(l): return not _going(l))[0]
	confirm.text = "delete"
	confirm.text_changed.emit("delete")
	check(not "Continue" in words.call() and not "Load" in words.call(), "once the only save is deleted, Continue and Load go: %s" % [words.call()])
	t.free()
	for c in Nav.ui.get_children():
		c.free()


func test_sailing_on_the_bay_map_is_not_being_ashore() -> void:
	check(Nav.ashore_on("town") and Nav.ashore_on("shore"), "in town and at the ponds you are ashore, while the second fisherman fills the hold")
	check(not Nav.ashore_on("coast") and not Nav.ashore_on("map"), "but not at sea, nor sailing across the bay on the map")


func test_the_ponds_on_the_shore_show_a_new_day() -> void:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "mutt")
	Game.state["ponds"] = [{"site": 0, "size": "large", "water": "sea", "features": ["rocks"], "fish": [
		{"fish": "bream", "pounds": 2.0, "name": "", "finery": "", "age_days": 9, "fed": true}]}]
	Game.state["time"] = Clock.minutes_per_day() * 2.0 - 0.2
	var s: Node = load("res://scripts/shore/shore_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({})
	Game.state["ponds"][0]["fish"].append({"fish": "bream", "pounds": 0.3, "name": "", "finery": "", "age_days": 0, "fed": false})
	for i in 60:
		s._process(0.5)
	check(s.views[0]._fish.size() == 2, "the young born overnight swim in the pond's picture without leaving and coming back, %d shown" % s.views[0]._fish.size())
	_done(s)


func test_filling_an_order_takes_the_fish_you_would_give() -> void:
	Game.new_game("Test", "mutt")
	Game.state["live_well"] = [{"fish": "bream", "pounds": 2.0, "live": true}]
	Game.state["hold"] = [{"fish": "bream", "pounds": 2.0, "fresh": 1.0}]
	check(Supply.find(Game.state, {"fish": "bream", "min_pounds": 1.0, "alive": false})["where"] == "hold",
		"an order for a dead bream takes the one in the hold, keeping the live one in the well")
	Game.state["live_well"] = []
	Game.state["ponds"] = [{"site": 0, "size": "large", "water": "sea", "features": [], "fish": [
		{"fish": "bream", "pounds": 4.2, "name": "Aurata", "finery": "gold_ring", "age_days": 30, "fed": true},
		{"fish": "bream", "pounds": 3.1, "name": "", "finery": "", "age_days": 30, "fed": true}]}]
	var at := Supply.find(Game.state, {"fish": "bream", "min_pounds": 1.0, "alive": true})
	check(at["where"] == "pond" and int(at["index"]) == 1, "and a live order from the ponds takes the unnamed bream, not Aurata in her gold ring")


func test_the_neptunalia_is_judged_wherever_you_are() -> void:
	Game.new_game("Test", "mutt")
	Game.state["chapter"] = 1
	var day := 3
	Game.state["time"] = day * Clock.minutes_per_day() + 6.0
	Game.state["contest"] = {"day": day, "best": 9.0, "fish": "bream", "done": false}
	var money := int(Game.state["denarii"])
	World.sleep(Game.state, Seeds.rng(1, "contest"))
	check(Game.state["contest"]["done"], "a contest won in the morning is judged though you spent the afternoon and night in town")
	check(int(Game.state["denarii"]) > money and int(Game.state["stats"].get("neptunalia_won", 0)) == 1, "and its prize is paid")
	check(Game.state.has("_contest"), "with word of it waiting to be told")


func test_the_dolphins_help_only_where_they_come() -> void:
	Game.new_game("Test", "mutt")
	Game.state["chapter"] = 5
	Game.state["boat"] = "big_boat"
	var day := 0
	while not "dolphins" in Events.on(day) and day < 400:
		day += 1
	check("dolphins" in Events.on(day), "there is a dolphin day")
	Game.state["time"] = day * Clock.minutes_per_day() + 8.0
	var s := _coast_at("harbour")
	s._process(0.05)
	check(not "dolphins" in s.swimmers.events, "in the harbour, where no dolphins come, the shoals and the net are as on any day")
	_done(s)
	s = _coast_at("open_bay")
	s._process(0.05)
	check("dolphins" in s.swimmers.events, "but in the open bay the dolphins drive the shoals up")
	_done(s)


func test_the_town_net_button_keeps_out_of_the_strip() -> void:
	Game.new_game("Test", "mutt")
	Game.state["chapter"] = 3
	Game.state["boat"] = "fishing_boat"
	var day := 0
	while not "tuna_run" in Events.on(day):
		day += 1
	Game.state["time"] = day * Clock.minutes_per_day() + 8.0
	var s := _coast_at("open_bay")
	var button: Button = s.events._haul_button
	check(is_instance_valid(button) and button.visible, "in the open bay during the tuna run the town's net can be joined")
	Windowing.strip = true
	s._on_view_changed()
	check(not button.visible, "but its button is hidden in the desktop strip, as the other panels are")
	Windowing.strip = false
	s._on_view_changed()
	check(button.visible, "and back when the window is whole again")
	_done(s)
