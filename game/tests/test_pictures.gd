extends "res://tests/test_case.gd"
## The ways of fishing, the tackle and the shops shown as pictures, each with a tip saying what it is.


func _clear_ui() -> void:
	for c in Nav.ui.get_children():
		c.free()


## The picture tiles in a window or bar: buttons that show a picture and no words.
func _tiles(node: Node) -> Array:
	return node.find_children("*", "Button", true, false).filter(func(b): return b.text == "" and b.find_children("*", "TextureRect", true, false).any(func(t): return t.texture != null))


func test_everything_for_sale_has_a_picture() -> void:
	for id in Data.bait:
		check(ItemArt.of(id) != null, "a picture of the %s bait" % id)
	for id in Data.gear:
		check(ItemArt.of(id) != null, "a picture of the %s" % id)
	for id in Helpers.HELP:
		check(ItemArt.of("help_" + id) != null, "a picture of %s" % Helpers.HELP[id]["name"])
	for m in CoastMethods.METHODS:
		check(ItemArt.of(m) != null, "a picture for fishing by %s" % m)


func test_a_big_picture_is_shrunk_to_fit_its_tile() -> void:
	var boat: Texture2D = ItemArt.of("skiff")
	var fitted: Texture2D = ItemArt.fitted(boat, 40.0)
	check(maxf(fitted.get_width(), fitted.get_height()) <= 40.0, "the skiff fits a tile forty pixels wide")
	check(ItemArt.fitted(ItemArt.of("worm"), 40.0) == ItemArt.of("worm"), "and a small picture is shown at its own size")


func _coast() -> Node:
	_clear_ui()
	Game.new_game("Test", "hound")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	return s


func test_the_ways_of_fishing_are_pictures_with_tips() -> void:
	var s := _coast()
	for m in CoastMethods.METHODS:
		var b: Button = s.hud.method_buttons[m]
		check(b in _tiles(s.hud), "%s is shown as a picture" % m)
		check(str(b.get_meta("tip", "")).length() > 30, "with a tip saying how to fish that way: %s" % str(b.get_meta("tip", "")))
	check(s.hud.method_buttons["line"].get_meta("chosen"), "the way he is fishing now is ringed")
	_clear_ui()
	s.free()


func test_the_map_logbook_settings_and_menu_are_pictures_with_tips() -> void:
	var s := _coast()
	var tiles := _tiles(Nav.ui)
	var buttons := {"Bay map": s._sail}
	for id in ["Logbook", "Settings", "Menu"]:
		buttons[id] = s.hud.find_child(id, true, false)
	for id in buttons:
		var b: Button = buttons[id]
		check(b != null and b in tiles, "%s is a picture" % id)
		if b:
			check(str(b.get_meta("tip", "")).begins_with(id), "with a tip naming it: %s" % str(b.get_meta("tip", "")))
			check(b.size == Hud.TILE, "as big as the ways of fishing, not %s" % b.size)
	for id in ["bay_map", "logbook", "settings", "menu"]:
		var pic: Texture2D = ItemArt.of(id)
		check(pic != null and pic.get_width() <= 24 and pic.get_height() <= 24, "%s is painted small enough for its tile" % id)
	buttons["Settings"].pressed.emit()
	check(Ui.window_open() and Nav.ui.get_node("Window").has_meta("settings"), "the settings picture opens the settings")
	Ui.close_window()
	_clear_ui()
	s.free()


func test_clicking_the_line_opens_the_tackle_above_it() -> void:
	var s := _coast()
	s.hud.refresh()
	check(not "bait_tile" in s.hud and not "rod_tile" in s.hud, "the bait and the rod are no longer tiles of their own on the bar")
	var line: Button = s.hud.method_buttons["line"]
	line.pressed.emit()
	check(Ui.window_open(), "clicking the line opens the tackle")
	var window: Control = Nav.ui.get_node("Window")
	var at := line.get_global_rect()
	var box := Rect2(window.position, window.size)
	check(box.end.y <= at.position.y + 0.5 and box.position.x <= at.end.x and box.end.x >= at.position.x, "just above the line's picture, at %s over %s" % [box, at])
	Ui.close_window()
	s.methods.method = "trap"
	s.hud.method_buttons["line"].pressed.emit()
	check(s.methods.method == "line", "and it picks the line too")
	_clear_ui()
	s.free()


func test_the_tackle_is_pictures() -> void:
	_clear_ui()
	Game.new_game("Test", "hound")
	Game.state["denarii"] = 200
	Shop.buy(Game.state, "ash_rod")
	Game.state["bait"]["shrimp"] = 5
	TacklePanel.open()
	var tips := " ".join(_tiles(Nav.ui).map(func(b): return str(b.get_meta("tip", "")))).to_lower()
	for name in ["worm", "shrimp", "cane rod", "ash rod"]:
		check(name in tips, "the tackle shows the %s as a picture with its tip" % name)
	_clear_ui()


func test_the_shops_are_pictures() -> void:
	_clear_ui()
	Game.new_game("Test", "hound")
	ShopPanel.netmaker()
	var on_sale := Data.bait.keys().filter(func(id): return Shop.on_sale(Game.state, id)).size()
	on_sale += Data.gear.keys().filter(func(id): return Data.gear[id]["kind"] != "finery" and int(Data.gear[id]["price"]) > 0 and Shop.on_sale(Game.state, id)).size()
	check(_tiles(Nav.ui).size() >= on_sale, "the netmaker shows each thing for sale as a picture (%d of %d)" % [_tiles(Nav.ui).size(), on_sale])
	_clear_ui()
	ShopPanel.boatwright()
	check(_tiles(Nav.ui).size() == Data.boats.size(), "the boatwright shows each boat as a picture")
	_clear_ui()
	ShopPanel.goldsmith()
	check(_tiles(Nav.ui).size() == Data.gear.values().filter(func(g): return g["kind"] == "finery").size(), "the goldsmith shows each piece of finery")
	Game.state["hold"].append({"fish": "mullet", "pounds": 1.2, "fresh": 1.0})
	_clear_ui()
	ShopPanel.market()
	var tiles := _tiles(Nav.ui)
	check(tiles.any(func(b): return "mullet" in str(b.get_meta("tip", "")).to_lower()), "the market shows the fish in the hold as pictures")
	var help := Helpers.HELP.values().filter(func(h): return int(h["chapter"]) <= int(Game.state["chapter"])).size()
	check(help > 0 and tiles.size() == 1 + help, "and the help for hire this chapter too")
	_clear_ui()
