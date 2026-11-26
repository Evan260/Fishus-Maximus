extends "res://tests/test_case.gd"
## A phone's reminders while the game is put away: when they come, that each tells what the player then finds, that
## nothing already so when the game was put away is news, and that none is sent before the player allows them.


## A game as a phone saves it on being put away, at a fixed moment so the time away is played the same every run.
func _game() -> void:
	Game.new_game("Test", "mutt")
	Game.state["last_real_time"] = 1800000000.0


func _depth_with_pot_fish() -> float:
	for depth in range(10, 300, 10):
		if not Traps.kinds("harbour", float(depth)).is_empty():
			return float(depth)
	return -1.0


func _pot(depth: float, catch := []) -> Dictionary:
	return {"place": "harbour", "x": 300.0, "depth": depth, "set_time": 0.0, "catch": catch, "size": 3, "hours": 0.0, "bait": ""}


func _crabs(depth: float) -> Array:
	var kind: String = Traps.kinds("harbour", depth)[0]
	return [0, 1, 2].map(func(_i): return {"fish": kind, "pounds": 0.5, "live": Traps.alive(kind)})


## The game after so many seconds away from the moment it was saved, lived as the return lives it.
func _back_after(saved: Dictionary, seconds: float) -> Dictionary:
	Game.from_dict(saved.duplicate(true))
	Game.catch_up(seconds)
	return Game.state


func _ids(plan: Array) -> Array:
	return plan.map(func(n): return n["id"])


func test_the_pots_reminder_comes_as_the_last_pot_fills() -> void:
	var depth := _depth_with_pot_fish()
	check(depth > 0.0, "the harbour has pot fish at some depth")
	_game()
	Game.state["traps"] = [_pot(depth), _pot(depth)]
	var saved := Game.to_dict()
	var plan := PhoneNotices.plan(saved)
	check(_ids(plan) == ["pots"], "two empty pots bring one reminder: %s" % [_ids(plan)])
	if plan.is_empty():
		return
	var n: Dictionary = plan[0]
	check(n["title"] == "Your pots are full" and n["text"] == "Row over them to haul them up.", "saying the pots are full: %s" % [n])
	var at: float = n["seconds"]
	check(at > 60.0 and at < Data.num("time.away_cap_hours", 8) * 3600.0, "some minutes after the game was put away: %.0f s" % at)
	check(PhoneNotices.pots_full(_back_after(saved, at)), "and a player who comes back then finds every pot full")
	check(not PhoneNotices.pots_full(_back_after(saved, at - 90.0)), "though not a minute and a half sooner")


func test_the_boat_reminder_comes_when_the_hold_is_full() -> void:
	_game()
	Game.state["idle"] = {"place": "harbour", "bait": "worm", "depth": 60.0}
	Game.state["bait"] = {"worm": 100}
	var saved := Game.to_dict()
	var plan := PhoneNotices.plan(saved)
	check(_ids(plan) == ["boat"], "a boat left fishing on its own brings one reminder: %s" % [_ids(plan)])
	if plan.is_empty():
		return
	check(plan[0]["title"] == "Your boat has stopped fishing" and plan[0]["text"] == "The hold is full.", "its hold full: %s" % [plan[0]])
	var at: float = plan[0]["seconds"]
	check(Hold.room(_back_after(saved, at)) == 0, "and a player who comes back then finds the hold full")
	check(Hold.room(_back_after(saved, at - 90.0)) > 0, "though not a minute and a half sooner")


func test_the_boat_reminder_comes_when_the_bait_runs_out() -> void:
	_game()
	Game.state["boat"] = "big_boat"
	Game.state["idle"] = {"place": "harbour", "bait": "worm", "depth": 60.0}
	Game.state["bait"] = {"worm": 3}
	var saved := Game.to_dict()
	var plan := PhoneNotices.plan(saved)
	check(_ids(plan) == ["boat"] and plan[0]["text"] == "Out of bait.", "a boat with three worms stops when they are gone: %s" % [plan])
	if plan.is_empty():
		return
	var back := _back_after(saved, plan[0]["seconds"])
	check(int(back["bait"]["worm"]) == 0 and Hold.room(back) > 0, "with room still in the hold")


func test_what_was_so_when_the_game_was_put_away_is_not_news() -> void:
	var depth := _depth_with_pot_fish()
	_game()
	Game.state["traps"] = [_pot(depth, _crabs(depth))]
	check(PhoneNotices.plan(Game.to_dict()).is_empty(), "pots left full stay full, and nobody is told")
	_game()
	Game.state["idle"] = {"place": "harbour", "bait": "worm", "depth": 60.0}
	for i in Hold.room(Game.state):
		Catches.record(Game.state, "mullet", 1.0, false)
	check(Hold.room(Game.state) == 0 and PhoneNotices.plan(Game.to_dict()).is_empty(), "nor is a boat left with its hold full")
	_game()
	Game.state["traps"] = [_pot(depth), _pot(9999.0)]
	check(Traps.kinds("harbour", 9999.0).is_empty() and PhoneNotices.plan(Game.to_dict()).is_empty(), "nor pots that can never all fill")


func test_full_pots_the_boy_empties_are_news_once_they_fill_again() -> void:
	var depth := _depth_with_pot_fish()
	_game()
	Game.state["helpers"] = ["boy"]
	Game.state["traps"] = [_pot(depth, _crabs(depth))]
	var saved := Game.to_dict()
	var plan := PhoneNotices.plan(saved)
	var dawn := Clock.minutes_per_day() * 60.0
	check(_ids(plan) == ["pots"] and float(plan[0]["seconds"]) > dawn, "Tertius empties them at dawn, and they fill again after: %s" % [plan])
	if not plan.is_empty():
		var back := _back_after(saved, plan[0]["seconds"])
		check(PhoneNotices.pots_full(back) and not back["hold"].is_empty(), "with the first catch in the hold")


func test_each_kind_can_be_turned_off() -> void:
	var depth := _depth_with_pot_fish()
	_game()
	Game.state["traps"] = [_pot(depth)]
	Game.state["idle"] = {"place": "harbour", "bait": "worm", "depth": 60.0}
	var saved := Game.to_dict()
	check(_ids(PhoneNotices.plan(saved)) == ["pots", "boat"], "both, soonest first")
	check(_ids(PhoneNotices.plan(saved, false, true)) == ["boat"], "the boat alone")
	check(_ids(PhoneNotices.plan(saved, true, false)) == ["pots"], "the pots alone")
	for n in PhoneNotices.plan(saved):
		check(float(n["seconds"]) <= Data.num("time.away_cap_hours", 8) * 3600.0, "none past the cap on time away")


func test_no_reminder_before_the_player_allows_them() -> void:
	var depth := _depth_with_pot_fish()
	_game()
	Game.state["traps"] = [_pot(depth)]
	var kept := [Settings.reminders, Saves.slot, Nav.current_name]
	Saves.slot = 1
	Nav.current_name = "coast"
	Settings.reminders = false
	check(PhoneServices.notices().is_empty(), "nothing is planned until the player taps Allow")
	Settings.reminders = true
	check(_ids(PhoneServices.notices()) == ["pots"], "and the pots are once they have")
	Nav.current_name = "title"
	check(PhoneServices.notices().is_empty(), "but never for a game left on the title, which loads it afresh")
	Settings.reminders = kept[0]
	Saves.slot = kept[1]
	Nav.current_name = kept[2]


func test_a_long_frame_is_lived_as_time_away() -> void:
	var depth := _depth_with_pot_fish()
	_game()
	Game.state["traps"] = [_pot(depth)]
	Game.state["helpers"] = ["fisherman"]
	Game.state["_ashore"] = true
	var kept := [Game.wall_clock, Saves.slot, Nav.current_name]
	var now := [5000.0]
	Game.wall_clock = func() -> float: return now[0]
	Saves.slot = 1
	Nav.current_name = "town"
	Game._last_wall = 0.0
	Game._watch_clock()
	var start := float(Game.state["time"])
	now[0] += 5.0
	Game._watch_clock()
	check(float(Game.state["time"]) == start, "a short pause is only a slow frame")
	now[0] += 3600.0
	Game._watch_clock()
	check(absf(float(Game.state["time"]) - start - 60.0) < 0.01, "an hour put away is an hour of the clock: %.2f minutes" % (float(Game.state["time"]) - start))
	check(PhoneNotices.pots_full(Game.state), "the pot filled meanwhile")
	check(Game.state["hold"].is_empty() and Game.state.get("_ashore", false), "the second fisherman fishes only while you are really ashore, as when the game is closed")
	Nav.current_name = "title"
	Game._watch_clock()
	now[0] += 3600.0
	Game._watch_clock()
	check(absf(float(Game.state["time"]) - start - 60.0) < 0.01, "and nothing passes on the title")
	Game.wall_clock = kept[0]
	Saves.slot = kept[1]
	Nav.current_name = kept[2]
	Game._last_wall = 0.0


func test_a_phone_has_a_notifications_tab_off_until_allowed() -> void:
	for c in Nav.ui.get_children():
		c.free()
	var kept := [Windowing.phone, SettingsPanel.tab, Settings.reminders]
	Windowing.phone = false
	check(not "Notifications" in SettingsPanel.tabs(), "a computer is sent no reminders")
	Windowing.phone = true
	check(SettingsPanel.tabs() == ["Sound", "Display", "Gameplay", "Notifications"], "a phone has the tab in place of the keys")
	Settings.reminders = false
	SettingsPanel.tab = "Notifications"
	SettingsPanel.open()
	var rows := func() -> Array:
		var page: Control = Nav.ui.get_node("Window").find_child("Notifications", true, false)
		return page.get_children().filter(func(r): return r is HBoxContainer).map(func(r): return r.get_child(0).text)
	check(rows.call() == ["Notifications are off", "Your pots are full", "Your boat has stopped fishing"], "off until allowed: %s" % [rows.call()])
	var allow: Button = Nav.ui.get_node("Window").find_child("allow", true, false).get_child(1)
	check(allow.text == "Allow", "with Allow beside it")
	allow.pressed.emit()
	check(Settings.reminders, "which turns the reminders on")
	check(rows.call()[0] == "Your phone has notifications turned off for this game", "and while the phone says no, its settings are a tap away: %s" % [rows.call()])
	Windowing.phone = kept[0]
	SettingsPanel.tab = kept[1]
	Settings.reminders = kept[2]
	for c in Nav.ui.get_children():
		c.free()
