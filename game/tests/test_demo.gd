extends "res://tests/test_case.gd"
## The free demo: chapters 1 and 2 only, everything later shown as the full game's, an end card when chapter 3 would
## open, and a game that carries over to the full game.


class FakeSteam:
	extends RefCounted
	var app := 0
	var sent := []

	func getAppID() -> int:
		return app

	func setAchievement(id: String) -> bool:
		sent.append(id)
		return true

	func storeStats() -> bool:
		return true

	func run_callbacks() -> void:
		pass


func _clear() -> void:
	for c in Nav.ui.get_children():
		c.free()


func _demo_game() -> Dictionary:
	Game.new_game("Test", "mutt")
	return Game.state


func test_the_demo_stops_at_chapter_two() -> void:
	Game.acts_as_demo = true
	var s := _demo_game()
	var opened := Story.add_reputation(s, 17)
	check(opened == 2 and int(s["chapter"]) == 2 and not s.has("demo_done"), "chapter 2 opens in the demo")
	opened = Story.add_reputation(s, 100)
	check(opened == 0 and int(s["chapter"]) == 2, "chapter 3 never opens in the demo, chapter %d" % int(s["chapter"]))
	check(s.get("demo_done", false), "and the game is marked as through the demo")
	check(int(s["reputation"]) == 117, "the name still grows")
	Game.acts_as_demo = false
	var full := _demo_game()
	Story.add_reputation(full, 117)
	check(int(full["chapter"]) == 3 and not full.has("demo_done"), "the full game opens every chapter its name earns")


func test_later_things_are_the_full_games() -> void:
	Game.acts_as_demo = true
	var s := _demo_game()
	Story.add_reputation(s, 40)
	s["denarii"] = 99999
	for boat in ["fishing_boat", "sailing_boat", "big_boat"]:
		check(Shop.full_game_only(s, boat) and not Shop.on_sale(s, boat), "the %s is the full game's" % boat)
		check(not Shop.buy(s, boat), "and cannot be bought")
	check(not Shop.full_game_only(s, "skiff"), "the skiff is not")
	s["chapter"] = 1
	check(Shop.full_game_only(s, "big_boat") and not Shop.full_game_only(s, "cast_net"), "in chapter 1 only the boats say so")
	s["chapter"] = 2
	check(Shop.full_game_only(s, "cast_net") and not Shop.full_game_only(s, "yew_rod"), "gear past chapter 2 is the full game's, chapter 2's is not")
	check(Shop.full_game_only(s, "seaweed") and not Shop.full_game_only(s, "squid"), "and bait the same")
	s["gear"]["traps"] = 4
	check(Shop.full_game_only(s, "trap_5") and not Shop.full_game_only(s, "trap_6"), "of the pots, only the next one shows")
	for place in ["lucrine", "open_bay", "capri", "misenum"]:
		check(BayMap.locked_reason(s, place) == "In the full game", "%s says it is in the full game: %s" % [place, BayMap.locked_reason(s, place)])
		check(not BayMap.sail(s, place), "and cannot be sailed to")
	check(BayMap.locked_reason(s, "rocky_shore") == "", "the rocky shore is open")
	Game.acts_as_demo = false
	check(not Shop.full_game_only(s, "fishing_boat"), "the full game sells nothing as the full game's")
	check(BayMap.locked_reason(s, "capri").begins_with("Opens in chapter"), "and its map names the chapter")


func test_the_shops_show_the_full_games_things() -> void:
	Game.acts_as_demo = true
	_clear()
	var s := _demo_game()
	Story.add_reputation(s, 40)
	ShopPanel.boatwright()
	var w: Node = Nav.ui.get_node("Window")
	var later := w.find_children("FullGame_*", "", true, false)
	check(later.size() == 3, "the boatwright shows the three later boats as the full game's: %d" % later.size())
	check(later.all(func(b): return b.disabled), "none can be bought")
	ShopPanel.netmaker()
	w = Nav.ui.get_node("Window")
	check(w.find_child("FullGame_cast_net", true, false) != null, "the netmaker shows the cast net as the full game's")
	Game.acts_as_demo = false
	ShopPanel.boatwright()
	w = Nav.ui.get_node("Window")
	check(w.find_children("FullGame_*", "", true, false).is_empty(), "the full game's boatwright shows nothing so")
	Ui.close_window()
	_clear()


func test_the_end_card_shows_once_when_chapter_three_would_open() -> void:
	Game.acts_as_demo = true
	_clear()
	var s := _demo_game()
	Story.add_reputation(s, 17)
	check(not Game.show_demo_end() and not Nav.ui.has_node("Window"), "no end card in chapter 2")
	Story.add_reputation(s, 60)
	check(Game.show_demo_end(), "the end card opens when chapter 3 would")
	var w: Node = Nav.ui.get_node_or_null("Window")
	check(w != null and w.find_child("DemoEnd", true, false) != null, "the end card opens when chapter 3 would")
	var wish: Button = w.find_child("Wishlist", true, false) if w else null
	check(wish != null and not wish.visible, "its wishlist button hides while the App ID is 0")
	check(s.get("demo_card_seen", false), "and it is remembered as seen")
	Ui.close_window()
	_clear()
	check(not Game.show_demo_end(), "it shows only once")
	Game.acts_as_demo = false
	_clear()


func test_the_wishlist_button_shows_with_an_app_id() -> void:
	var steam: Dictionary = Data.balance["steam"]
	steam["app_id"] = 123456
	_clear()
	var b := DemoEnd.wishlist_button(Nav.ui)
	check(b.visible and Awards.store_app_id() == 123456, "with an App ID the button shows")
	steam["app_id"] = 0
	_clear()


func test_the_title_says_demo() -> void:
	Game.acts_as_demo = true
	Game.state = {}
	_clear()
	var title: Node = load("res://scripts/screens/title.gd").new()
	Nav.port.add_child(title)
	title.enter({})
	check(Nav.ui.find_child("Demo", true, false) != null, "the title says Demo")
	check(Nav.ui.find_child("Wishlist", true, false) != null, "and has the wishlist button")
	title.free()
	_clear()
	Game.acts_as_demo = false
	title = load("res://scripts/screens/title.gd").new()
	Nav.port.add_child(title)
	title.enter({})
	check(Nav.ui.find_child("Demo", true, false) == null and Nav.ui.find_child("Wishlist", true, false) == null, "the full game's title does not")
	title.free()
	_clear()


func test_a_demo_game_carries_over() -> void:
	Game.acts_as_demo = true
	var s := _demo_game()
	Story.add_reputation(s, 80)
	var saved := Game.to_dict()
	check(saved.get("demo_done", false) and int(saved["chapter"]) == 2, "the demo saves its game at chapter 2")
	Game.acts_as_demo = false
	Game.from_dict(JSON.parse_string(JSON.stringify(saved)))
	check(int(Game.state["chapter"]) == 3, "the full game opens chapter 3 at once, %d" % int(Game.state["chapter"]))
	check(not Game.state.has("demo_done"), "and forgets the demo's mark")
	check(int(Game.state["_chapter_seen"]) == 2, "so the new chapter is announced")
	Game.acts_as_demo = true
	Game.from_dict(JSON.parse_string(JSON.stringify(saved)))
	check(int(Game.state["chapter"]) == 2, "the demo loads it still at chapter 2")
	Game.acts_as_demo = false


func test_the_demo_sends_achievements_only_as_the_full_game() -> void:
	var before: Object = Awards._steam
	var fake := FakeSteam.new()
	Awards._steam = fake
	var steam: Dictionary = Data.balance["steam"]
	Game.acts_as_demo = true
	Game.state = {"achievements": []}
	var real := Awards.may_send()
	fake.app = 999
	Awards.unlock("first_catch")
	check(fake.sent.is_empty(), "with no App ID set the demo sends nothing")
	steam["app_id"] = 4242
	Awards.unlock("first_catch")
	check(fake.sent.is_empty(), "nor when Steam runs it as another app")
	fake.app = 4242
	Awards.unlock("first_catch")
	check(fake.sent == (["first_catch"] if real else []), "but as the full game it sends them as the game does")
	steam["app_id"] = 0
	Game.acts_as_demo = false
	Awards._steam = before
