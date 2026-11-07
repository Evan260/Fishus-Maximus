extends "res://tests/test_case.gd"
## Old Rufus's guide for a new player: one lesson at a time, each cleared by doing it, shown on its own screen.


func _done_up_to(id: String) -> void:
	for s in Data.guide["steps"]:
		if s["id"] == id:
			return
		Game.state["guide"]["done"].append(s["id"])


func _clear_ui() -> void:
	for c in Nav.ui.get_children():
		c.free()


func test_a_new_game_starts_with_rowing() -> void:
	Game.new_game("Test", "mutt")
	check(Guide.step(Game.state).get("id", "") == "row", "the first lesson is how to row")
	check("arrow keys" in str(Guide.step(Game.state)["text"]), "and it names the arrow keys")


func test_rowing_a_little_way_counts() -> void:
	_clear_ui()
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	for i in 30:
		s.row(1.0, 0.05)
	check(int(Game.state["stats"].get("rowed", 0)) >= 1, "rowing along the shore is counted")
	_clear_ui()
	s.free()


func test_each_lesson_clears_once_it_is_done_and_stays_cleared() -> void:
	Game.new_game("Test", "mutt")
	Game.state["stats"]["rowed"] = 1
	check(Guide.step(Game.state).get("id", "") == "cast", "after rowing comes casting")
	Game.state["stats"]["casts"] = 1
	check(Guide.step(Game.state).get("id", "") == "strike", "after a cast comes the strike")
	Game.state["stats"]["hooked"] = 1
	check(Guide.step(Game.state).get("id", "") == "reel", "after a strike comes the reeling")
	Game.state["stats"]["hooked"] = 0
	check(Guide.step(Game.state).get("id", "") == "reel", "a lesson once learned is not taught again")
	Catches.record(Game.state, "mullet", 1.0)
	check(Guide.step(Game.state).get("id", "") == "ashore", "with a fish in the hold he says to go and sell it")


func test_the_map_waits_for_the_second_chapter() -> void:
	Game.new_game("Test", "mutt")
	_done_up_to("map")
	check(Guide.step(Game.state).is_empty() and not Guide.finished(Game.state), "nothing to say until the rocky shore opens")
	Game.state["chapter"] = 2
	check(Guide.step(Game.state).get("id", "") == "map", "then he points to the bay map")


func test_the_guide_ends_after_the_last_lesson() -> void:
	Game.new_game("Test", "mutt")
	Game.state["chapter"] = 2
	_done_up_to("")
	check(Guide.step(Game.state).is_empty() and Guide.finished(Game.state), "every lesson done means the guide is over")


func test_an_old_save_with_catches_skips_the_guide() -> void:
	Game.from_dict({"name": "Old", "logbook": {"mullet": {"count": 3, "best": 1.2}}})
	check(Guide.finished(Game.state), "a player who has fished before is not taught to cast")
	Game.from_dict({"name": "Fresh"})
	check(not Guide.finished(Game.state), "a save with nothing caught still gets the guide")


func test_the_things_he_teaches_are_counted() -> void:
	Game.new_game("Test", "mutt")
	Game.state["denarii"] = 100
	Shop.buy(Game.state, "shrimp")
	check(int(Game.state["stats"].get("bought", 0)) == 1, "buying bait is counted")
	Game.state["chapter"] = 2
	Game.state["weather"] = "clear"
	BayMap.sail(Game.state, "rocky_shore")
	check(int(Game.state["stats"].get("sails", 0)) == 1, "sailing somewhere new is counted")
	BayMap.sail(Game.state, "rocky_shore")
	check(int(Game.state["stats"].get("sails", 0)) == 1, "staying put is not a sail")


func test_casting_and_setting_a_pot_are_counted() -> void:
	_clear_ui()
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	s.cast(0.5)
	check(int(Game.state["stats"].get("casts", 0)) == 1, "a cast is counted")
	s.methods.set_method("trap")
	s.methods.use()
	check(int(Game.state["stats"].get("pots_set", 0)) == 1, "a pot set is counted")
	_clear_ui()
	s.free()


func test_rufus_gives_the_lesson_on_its_own_screen() -> void:
	_clear_ui()
	Settings.guide = true
	Game.new_game("Test", "mutt")
	var coast: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(coast)
	coast.enter({"place": "harbour", "first": true})
	var note: GuideNote = GuideNote.find()
	note.refresh()
	check(note != null and note.visible and "arrow keys" in note.text(), "on the boat he explains rowing")
	_clear_ui()
	coast.free()
	var town: Node = load("res://scripts/town/town_screen.gd").new()
	Nav.port.add_child(town)
	town.enter({})
	note = GuideNote.find()
	note.refresh()
	check(not note.visible, "in town he waits, since rowing is done from the boat")
	_clear_ui()
	town.free()


func test_he_points_at_the_pots_button() -> void:
	_clear_ui()
	Settings.guide = true
	Game.new_game("Test", "mutt")
	_done_up_to("pots")
	var coast: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(coast)
	coast.enter({"place": "harbour"})
	var note: GuideNote = GuideNote.find()
	note.refresh()
	var pots: Button = null
	for b in coast.hud.find_children("*", "Button", true, false):
		if b.text == "Pots":
			pots = b
	check(pots != null and note.target_rect() == pots.get_global_rect(), "the arrow is at the Pots button")
	_clear_ui()
	coast.free()


func test_skipping_the_guide_turns_it_off() -> void:
	_clear_ui()
	Settings.guide = true
	Game.new_game("Test", "mutt")
	var coast: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(coast)
	coast.enter({"place": "harbour"})
	var note: GuideNote = GuideNote.find()
	note.skip()
	note.refresh()
	check(not Settings.guide and not note.visible, "Skip the guide hides him and keeps him away")
	Settings.guide = true
	_clear_ui()
	coast.free()


func test_got_it_hides_the_lesson_until_the_next() -> void:
	_clear_ui()
	Settings.guide = true
	Game.new_game("Test", "mutt")
	var coast: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(coast)
	coast.enter({"place": "harbour"})
	var note: GuideNote = GuideNote.find()
	note.refresh()
	note.got_it()
	note.refresh()
	check(not note.visible, "Got it puts the advice away")
	Game.state["stats"]["rowed"] = 1
	note.refresh()
	check(note.visible and "cast" in note.text(), "and he comes back with the next lesson")
	_clear_ui()
	coast.free()


func test_a_cast_made_fishing_on_his_own_teaches_nothing() -> void:
	_clear_ui()
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	s.methods.set_idle(true)
	s.cast(0.6)
	check(int(Game.state["stats"].get("casts", 0)) == 0, "the player has still to cast by hand")
	_clear_ui()
	s.free()


func test_messages_sit_under_rufus_while_he_speaks() -> void:
	_clear_ui()
	Settings.guide = true
	Game.new_game("Test", "mutt")
	var coast: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(coast)
	coast.enter({"place": "harbour"})
	var note: GuideNote = GuideNote.find()
	note.refresh()
	Toast.say("Pot set on the seabed.")
	var box: Control = Toast._box
	check(box.offset_top >= note.offset_bottom, "the message starts below his note, not over it")
	_clear_ui()
	coast.free()


func test_got_it_is_remembered_when_the_screen_opens_again() -> void:
	_clear_ui()
	Settings.guide = true
	Game.new_game("Test", "mutt")
	var coast: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(coast)
	coast.enter({"place": "harbour"})
	GuideNote.find().got_it()
	_clear_ui()
	coast.free()
	coast = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(coast)
	coast.enter({"place": "harbour"})
	var note: GuideNote = GuideNote.find()
	note.refresh()
	check(not note.visible, "back on the boat he does not repeat the advice put away")
	_clear_ui()
	coast.free()


func test_praise_waits_while_a_window_covers_him() -> void:
	_clear_ui()
	Settings.guide = true
	Game.new_game("Test", "mutt")
	_done_up_to("reel")
	var coast: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(coast)
	coast.enter({"place": "harbour"})
	var note: GuideNote = GuideNote.find()
	note.refresh()
	Catches.record(Game.state, "mullet", 1.0)
	note.refresh()
	Ui.window("The netmaker", 200, 100)
	note.refresh()
	note._process(20.0)
	Ui.close_window()
	note.refresh()
	check(note.visible and "first fish" in note.text(), "the praise is still there once the window closes")
	_clear_ui()
	coast.free()


func test_a_message_from_before_rufus_moves_under_him() -> void:
	_clear_ui()
	Settings.guide = true
	Game.new_game("Test", "mutt")
	var coast: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(coast)
	coast.enter({"place": "harbour", "away": Clock.minutes_per_day() * 3.0})
	var note: GuideNote = GuideNote.find()
	note.refresh()
	check(Toast._box.offset_top >= note.offset_bottom, "the time-away message sits under his note")
	_clear_ui()
	coast.free()
