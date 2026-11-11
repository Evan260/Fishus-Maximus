extends "res://tests/test_case.gd"
## Weights are shown in kilograms, or in pounds when the settings say so, while every weight is kept in pounds.


func _texts(root: Node) -> String:
	var out := []
	for n in root.find_children("*", "", true, false):
		if n is Label or n is Button:
			out.append(n.text)
	return " | ".join(out)


func _clear() -> void:
	Ui.close_window()
	for c in Nav.ui.get_children():
		c.free()


func _in(units: String, f: Callable) -> Variant:
	var was: String = Settings.units
	Settings.units = units
	var out: Variant = f.call()
	Settings.units = was
	return out


func test_kilograms_are_the_default() -> void:
	var fresh: Node = load("res://scripts/autoload/settings.gd").new()
	check(fresh.units == "metric", "a new player sees weights in kilograms")
	var cfg := ConfigFile.new()
	fresh.read_from(cfg)
	check(fresh.units == "metric", "and so does one whose settings file was saved before there was a choice")
	cfg.set_value("display", "units", "furlongs")
	fresh.read_from(cfg)
	check(fresh.units == "metric", "a value that is neither falls back to kilograms")
	fresh.free()


func test_the_choice_is_saved_and_loaded() -> void:
	var a: Node = load("res://scripts/autoload/settings.gd").new()
	a.units = "imperial"
	var cfg := ConfigFile.new()
	a.write_to(cfg)
	var b: Node = load("res://scripts/autoload/settings.gd").new()
	b.read_from(cfg)
	check(b.units == "imperial", "pounds chosen are pounds the next time the game starts")
	b.units = "metric"
	b.write_to(cfg)
	a.read_from(cfg)
	check(a.units == "metric", "and kilograms chosen again are kept too")
	a.free()
	b.free()


func test_a_weight_reads_in_either_unit() -> void:
	check(_in("metric", func(): return Units.weight(3.1)) == "1.4 kg", "3.1 lb reads as 1.4 kg")
	check(_in("metric", func(): return Units.weight(1.2)) == "0.54 kg", "a fish under a kilogram keeps two decimals")
	check(_in("metric", func(): return Units.weight(800.0)) == "362.9 kg", "a tuna reads in kilograms too")
	check(_in("imperial", func(): return Units.weight(3.1)) == "3.1 lb", "in pounds 3.1 lb reads as it is")
	check(_in("imperial", func(): return Units.weight(0.5)) == "0.50 lb", "and a fish under a pound keeps two decimals")


func test_a_requirement_reads_as_a_round_number() -> void:
	check(_in("metric", func(): return Units.need(2.0)) == "0.9 kg", "2 lb asks for 0.9 kg")
	check(_in("metric", func(): return Units.need(3.0)) == "1.4 kg", "3 lb asks for 1.4 kg, not 1.36")
	check(_in("metric", func(): return Units.need(2.2)) == "1 kg", "2.2 lb asks for 1 kg")
	check(_in("metric", func(): return Units.need(80.0)) == "36 kg", "a big fish asks for whole kilograms")
	check(_in("imperial", func(): return Units.need(2.0)) == "2 lb", "in pounds 2 lb asks for 2 lb")
	check(_in("imperial", func(): return Units.need(2.2)) == "2.2 lb", "and 2.2 lb for 2.2 lb")


func test_an_order_on_the_board_reads_in_kilograms() -> void:
	_clear()
	Game.new_game("Test", "hound")
	Game.state["orders"] = [{"fish": "bream", "min_pounds": 3.0, "alive": false, "feast": false, "reward": 40, "reputation": 3,
		"due": Clock.day_of(float(Game.state["time"]))}]
	var words: String = _in("metric", func():
		BoardPanel.open()
		return _texts(Nav.ui.get_node("Window")))
	check("1.4 kg or more" in words and not " lb" in words, "the order asks for 1.4 kg or more: %s" % words)
	_clear()
	words = _in("imperial", func():
		BoardPanel.open()
		return _texts(Nav.ui.get_node("Window")))
	check("3 lb or more" in words and not " kg" in words, "and in pounds for 3 lb or more: %s" % words)
	_clear()


func test_a_client_asks_in_the_chosen_unit() -> void:
	_clear()
	Game.new_game("Test", "hound")
	var words: String = _in("metric", func():
		ClientVisit.open("cook")
		return _texts(Nav.ui.get_node("Window")))
	check("0.9 kg of red mullet" in words, "the cook asks for 0.9 kg of red mullet: %s" % words)
	_clear()
	words = _in("imperial", func():
		ClientVisit.open("cook")
		return _texts(Nav.ui.get_node("Window")))
	check("2 lb of red mullet" in words, "or for 2 lb of it: %s" % words)
	_clear()
	for c in Data.clients.values():
		for step in c["steps"]:
			check(not "pound" in str(step["text"]), "%s names a weight only through the setting: %s" % [c["name"], step["text"]])


func test_the_settings_offer_the_two_units() -> void:
	_clear()
	var was: String = Settings.units
	Settings.units = "metric"
	SettingsPanel.tab = "Display"
	SettingsPanel.open()
	var weights := func() -> Button: return Nav.ui.get_node("Window").find_child("Weights", true, false).find_children("*", "Button", true, false)[0]
	check(weights.call().text == "Kilograms", "the settings offer kilograms and pounds, kilograms chosen")
	weights.call().pressed.emit()
	check(Settings.units == "imperial" and weights.call().text == "Pounds", "a click shows weights in pounds")
	check(Units.weight(3.1) == "3.1 lb", "at once, with no restart")
	weights.call().pressed.emit()
	check(Settings.units == "metric", "and another in kilograms again")
	Settings.units = was
	_clear()


func test_the_banner_and_the_tackle_follow_the_setting() -> void:
	_clear()
	var was: String = Settings.units
	Settings.units = "metric"
	CatchCard.show_catch("mullet", 1.2, false)
	check("0.54 kg" in _texts(CatchCard._open), "the catch banner gives the weight in kilograms")
	check("kg" in TacklePanel.rod_tip("cane_rod", "harbour"), "the rod's tip gives the sizes it suits in kilograms")
	Settings.units = was
	_clear()
