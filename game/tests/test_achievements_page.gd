extends "res://tests/test_case.gd"
## The logbook's achievements: every one listed, earned or still to earn, with what it asks.


func _clear() -> void:
	for c in Nav.ui.get_children():
		c.free()


## The window open now, not one closed and waiting to go.
func _window() -> Node:
	return Nav.ui.get_node("Window")


func _honours() -> Array:
	return _window().find_children("Honour_*", "HBoxContainer", true, false)


func test_the_logbook_has_a_bookmark_for_the_achievements() -> void:
	_clear()
	Game.new_game("Test", "mutt")
	LogbookPanel.open()
	var marks: Array = Nav.ui.find_children("*", "Button", true, false).map(func(b): return b.text)
	check("Achievements" in marks, "the logbook has an Achievements bookmark, %s" % [marks])
	_clear()


func test_every_achievement_is_listed_with_what_it_asks() -> void:
	_clear()
	Game.new_game("Test", "mutt")
	Game.state["achievements"] = ["first_fish"]
	var seen := []
	LogbookPanel.spread = 0
	LogbookPanel.open_achievements()
	var spreads := ceili(Data.achievements.size() / float(LogbookPanel.HONOUR_ROWS * 2))
	for k in spreads:
		LogbookPanel.spread = k
		LogbookPanel.open(LogbookPanel.section)
		var rows := _honours()
		check(rows.size() <= LogbookPanel.HONOUR_ROWS * 2, "spread %d holds at most %d" % [k, LogbookPanel.HONOUR_ROWS * 2])
		for r in rows:
			var id: String = r.name.trim_prefix("Honour_")
			seen.append(id)
			var a := Achievements.find(id)
			var words: Array = r.find_children("*", "Label", true, false).map(func(l): return l.text)
			check(str(a["name"]) in words, "%s shows its name" % id)
			check(" ".join(words.slice(1)).strip_edges() == str(a["text"]), "%s says what it asks, %s" % [id, words])
			var star: TextureRect = r.find_child("Star", true, false)
			var earned: bool = id == "first_fish"
			check(is_equal_approx(star.modulate.a, 1.0 if earned else 0.45), "%s's starfish is %s" % [id, "bright" if earned else "a faint shape"])
			check((r.find_child("Name", true, false) as Label).theme_type_variation == ("" if earned else "MutedLabel"), "%s's name is inked once earned" % id)
	check(seen.size() == Data.achievements.size() and Data.achievements.all(func(a): return a["id"] in seen), "every achievement is on its pages, %d of %d" % [seen.size(), Data.achievements.size()])
	var head: Array = _window().find_children("*", "Label", true, false).map(func(l): return l.text)
	check("1 / %d" % Data.achievements.size() in head, "the head of the pages counts those earned")
	_clear()


func test_each_achievement_fits_its_row() -> void:
	_clear()
	Game.new_game("Test", "mutt")
	LogbookPanel.spread = 0
	LogbookPanel.open_achievements()
	var font := UiTheme.body_font()
	for a in Data.achievements:
		var name_width := font.get_string_size(str(a["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.text_size()).x
		check(name_width <= LogbookPanel.HONOUR.x - 24, "%s's name fits on one line" % a["id"])
		var parts: Array = LogbookPanel._two_lines(str(a["text"]), LogbookPanel.HONOUR.x - 24)
		check(font.get_string_size(parts[1], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.text_size()).x <= LogbookPanel.HONOUR.x - 24, "and what it asks in two, %s" % a["id"])
	_clear()


func test_the_logbook_tip_names_the_achievements() -> void:
	_clear()
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	var tile: Button = s.hud.find_child("Logbook", true, false)
	check("achievements" in str(tile.get_meta("tip", "")), "the logbook's tip says the achievements are in it")
	_clear()
	s.free()
