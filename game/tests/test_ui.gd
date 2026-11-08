extends "res://tests/test_case.gd"


func test_every_achievement_can_be_met() -> void:
	for a in Data.achievements:
		check(Achievements.has_condition(a), a["id"] + " has a condition the game checks")
	check(Data.achievements.size() >= 38, "about forty achievements")


func test_achievements_are_earned_as_you_play() -> void:
	Game.new_game("Test", "mutt")
	check(not Achievements.met("first_fish", Game.state), "nothing yet")
	Catches.record(Game.state, "mullet", 1.0)
	check(Achievements.met("first_fish", Game.state), "the first fish")
	var got := Achievements.check(Game.state)
	check("first_fish" in got and "first_fish" in Game.state["achievements"], "earned once")
	check(not "first_fish" in Achievements.check(Game.state), "and not again")
	Game.state["ponds"] = [{"site": 0, "size": "small", "water": "sea", "features": ["caves"], "fish": [
		{"fish": "moray", "pounds": 4.0, "name": "Hortensia", "finery": "earrings", "age_days": 9, "fed": false}]}]
	check(Achievements.met("moray_earrings", Game.state), "a named moray in earrings")


func test_the_strip_mid_cast_keeps_the_cast() -> void:
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	s.cast(0.8)
	Windowing.set_strip(true)
	s.relayout()
	check(s.line_state() == "sinking" and s.camera.cam.y >= s.camera.top(), "the cast carries on in the strip")
	Windowing.set_strip(false)
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func test_a_new_game_starts_with_a_name_and_a_dog() -> void:
	Game.new_game("Livia", "sheepdog")
	check(Game.state["name"] == "Livia" and Game.state["dog"] == "sheepdog" and Game.state["orders"].size() == 3, "named, with a dog and the day's orders")
	check(Dogs.breeds().size() >= 3 and "sheepdog" in Dogs.breeds(), "the Farmus dogs to choose from")


func test_the_helpers_work_while_you_are_away() -> void:
	Game.new_game("Test", "mutt")
	Game.state["denarii"] = 500
	check(Helpers.hire(Game.state, "boy") and "boy" in Game.state["helpers"], "the boy is hired")
	check(not Helpers.hire(Game.state, "fisherman"), "the second fisherman comes later")
	Game.state["traps"] = [{"place": "harbour", "x": 300, "depth": 150, "set_time": 0.0, "catch": [], "size": 3, "hours": 0.0}]
	Game.state["salt"] = 10
	Garum.fill(Game.state, 0, [{"fish": "sardine", "pounds": 6.0}], 2)
	World.advance(Game.state, Clock.minutes_per_day() * 1.0, Seeds.rng(1, "h"))
	check(not Game.state["hold"].is_empty() and Game.state["traps"][0]["catch"].size() < 3, "he pulls the pots into the hold")
	check(float(Game.state["tanks"][0]["quality"]) > 0.5, "and stirs the tanks")
	Game.state["chapter"] = 4
	Game.state["hold"] = []
	check(Helpers.hire(Game.state, "fisherman"), "the second fisherman")
	World.advance(Game.state, 60.0, Seeds.rng(2, "h"))
	check(Game.state["hold"].size() >= 5, "fishes on his own all day")


func test_the_pacing_bot_reaches_chapter_two() -> void:
	var bot := PacingBot.new()
	var log := bot.run(2.0, 7)
	check(log["chapters"].has(2), "a keen player reaches the rocky shore within two hours")
	check(not log["chapters"].has(3), "but not the lake and the bay yet")


func test_the_sounds_around_you_have_their_own_volume() -> void:
	var was: float = Settings.ambience
	Settings.ambience = 0.25
	Settings.apply()
	var bus := AudioServer.get_bus_index("Ambience")
	check(bus >= 0 and is_equal_approx(AudioServer.get_bus_volume_db(bus), linear_to_db(0.25)), "the sea, the gulls and the rain play at the ambience volume")
	for c in Nav.ui.get_children():
		c.free()
	SettingsPanel.open()
	var names := Nav.ui.find_children("*", "Label", true, false).map(func(l): return l.text)
	check("Ambience" in names, "and the settings have a slider for it")
	for c in Nav.ui.get_children():
		c.free()
	Settings.ambience = was
	Settings.apply()
