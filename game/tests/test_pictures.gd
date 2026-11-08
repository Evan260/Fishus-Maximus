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
		check(b.tooltip_text.length() > 30, "with a tip saying how to fish that way: %s" % b.tooltip_text)
	check(s.hud.method_buttons["line"].get_meta("chosen"), "the way he is fishing now is ringed")
	_clear_ui()
	s.free()


func test_the_bait_and_rod_sit_beside_the_line() -> void:
	var s := _coast()
	s.hud.refresh()
	check(s.hud.bait_tile.visible and s.hud.rod_tile.visible, "with the line out, the bait and the rod show on the bar")
	check("worm" in s.hud.bait_tile.tooltip_text.to_lower(), "the bait's tip names the bait on the hook")
	s.hud.bait_tile.pressed.emit()
	check(Ui.window_open(), "and clicking it opens the tackle to choose another")
	Ui.close_window()
	s.methods.method = "trap"
	s.hud.refresh()
	check(not s.hud.bait_tile.visible, "pots need no bait or rod, so those are put away")
	_clear_ui()
	s.free()


func test_the_tackle_is_pictures() -> void:
	_clear_ui()
	Game.new_game("Test", "hound")
	Game.state["denarii"] = 200
	Shop.buy(Game.state, "ash_rod")
	Game.state["bait"]["shrimp"] = 5
	TacklePanel.open()
	var tips := " ".join(_tiles(Nav.ui).map(func(b): return b.tooltip_text)).to_lower()
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
	check(tiles.any(func(b): return "mullet" in b.tooltip_text.to_lower()), "the market shows the fish in the hold as pictures")
	var help := Helpers.HELP.values().filter(func(h): return int(h["chapter"]) <= int(Game.state["chapter"])).size()
	check(help > 0 and tiles.size() == 1 + help, "and the help for hire this chapter too")
	_clear_ui()
