extends "res://tests/test_case.gd"
## The one purchase that opens the whole game on a phone: what the store says decides whether the game plays by the
## demo's limits, the answer is kept so it holds without a connection, and a computer sells and locks nothing.

const CACHE := "user://test_store.cfg"
const PRICE := "CA$4.99"

## What each test listens to on FullGame, let go of when the test is done.
var _listening: Array[Callable] = []
var _kept := {}


func _full() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("FullGame")


## FullGame with a fake store that has answered nothing yet, and a cache of its own.
func _shop() -> FakeStore:
	var full := _full()
	_forget()
	_kept = Game.state
	full.cache_path = CACHE
	var store := FakeStore.new()
	full.use_store(store)
	return store


func _forget() -> void:
	if FileAccess.file_exists(CACHE):
		DirAccess.remove_absolute(CACHE)


func _done() -> void:
	var full := _full()
	for c in _listening:
		full.finished.disconnect(c)
	_listening.clear()
	full.use_store(null)
	full.cache_path = "user://store.cfg"
	_forget()
	_clear()
	Game.state = _kept


func _clear() -> void:
	for c in Nav.ui.get_children():
		c.free()


func _results() -> Array:
	var heard := []
	var listen := func(result: String) -> void: heard.append(result)
	_full().finished.connect(listen)
	_listening.append(listen)
	return heard


## A game through the demo: its name has earned chapter 3, which the demo holds back at chapter 2.
func _through_the_demo() -> Dictionary:
	Game.new_game("Test", "mutt")
	Story.add_reputation(Game.state, 80)
	return Game.state


func test_a_computer_sells_nothing_and_locks_nothing() -> void:
	var full := _full()
	check(full != null, "FullGame is an autoload")
	if full == null:
		return
	check(not Engine.has_singleton("SlowSundayPhone") and not full.sold_here(), "a computer has no store to buy the full game from")
	check(not full.locked() and not Game.is_demo(), "so the full game plays in full")
	var holder := Control.new()
	check(DemoEnd.unlock_button(holder) == null, "and offers no unlock")
	full.buy()
	full.restore()
	check(not full.locked(), "and buying or restoring does nothing at all")
	holder.free()


func test_the_store_is_asked_for_the_price_once_it_connects() -> void:
	var store := _shop()
	check(store.calls.has(["billing_start"]), "the store's connection is opened at start")
	check(_full().price() == "", "the price is blank until the store says it")
	store.billing_connected.emit()
	check(store.calls.has(["query_price", "full_game"]), "once connected, the full game's price is asked for")
	store.price_found.emit("full_game", PRICE)
	check(_full().price() == PRICE, "and the store's own price text is kept (%s)" % _full().price())
	store.price_found.emit("other", "CA$1.00")
	check(_full().price() == PRICE, "a price for another product is not taken")
	_done()


func test_not_owned_plays_by_the_demos_limits() -> void:
	var store := _shop()
	check(_full().sold_here() and _full().locked(), "a phone that has not bought the full game is locked")
	check(Game.is_demo(), "so the game plays by the demo's limits")
	var s := _through_the_demo()
	check(int(s["chapter"]) == 2 and s.get("demo_done", false), "it stops at chapter 2 as the demo does, chapter %d" % int(s["chapter"]))
	check(BayMap.locked_reason(s, "capri") == "In the full game", "and the places past the demo wait for the full game")
	check(Shop.full_game_only(s, "fishing_boat"), "as do the boats past the demo")
	store.owned_found.emit(PackedStringArray())
	check(_full().locked(), "a store that lists nothing owned keeps it locked")
	_done()


func test_owned_opens_everything() -> void:
	var store := _shop()
	store.owned_found.emit(PackedStringArray(["full_game"]))
	check(_full().owned() and not _full().locked(), "a store that lists the full game unlocks it")
	check(not Game.is_demo(), "and the game is no longer limited")
	var s := _through_the_demo()
	check(int(s["chapter"]) == 3 and not s.has("demo_done"), "so its name opens chapter 3, chapter %d" % int(s["chapter"]))
	check(not Shop.full_game_only(s, "fishing_boat"), "and nothing in the shops is kept for the full game")
	_done()


func test_buying_unlocks_at_once_and_keeps_the_game() -> void:
	var store := _shop()
	var heard := _results()
	var s := _through_the_demo()
	s["denarii"] = 1234
	Catches.record(s, "bream", 2.4)
	var before := Game.to_dict()
	check(BayMap.locked_reason(s, "lucrine") == "In the full game", "the Lucrine Lake waits for the full game")
	_full().buy()
	check(store.calls.has(["buy", "full_game"]), "buying opens the store's purchase for the full game")
	store.purchase_finished.emit("full_game", "purchased")
	check(_full().owned() and not Game.is_demo(), "a finished purchase opens the full game straight away")
	check(int(Game.state["chapter"]) == 3 and not Game.state.has("demo_done"), "the chapter the name has earned opens at once, chapter %d" % int(Game.state["chapter"]))
	check(int(Game.state.get("_chapter_seen", 3)) == 2, "and is announced as a new chapter")
	check(BayMap.locked_reason(Game.state, "lucrine") != "In the full game", "so the Lucrine Lake is open to a boat that can reach it")
	var after := Game.to_dict()
	for key in before:
		if key != "chapter" and key != "demo_done":
			check(JSON.stringify(after.get(key)) == JSON.stringify(before[key]), "with the game's %s as it was" % key)
	check(heard == ["purchased"], "and the game hears it was bought, to say thank you (%s)" % str(heard))
	_done()


func test_a_game_loaded_before_the_store_answers_opens_when_it_does() -> void:
	var store := _shop()
	var saved := _through_the_demo().duplicate(true)
	Game.from_dict(saved)
	check(int(Game.state["chapter"]) == 2, "a game loaded while the store has not answered plays by the demo's limits")
	store.owned_found.emit(PackedStringArray(["full_game"]))
	check(int(Game.state["chapter"]) == 3, "and opens its earned chapter once the store says the full game is owned")
	_done()


func test_a_pending_purchase_waits_for_the_payment() -> void:
	var store := _shop()
	var heard := _results()
	_full().buy()
	store.purchase_finished.emit("full_game", "pending")
	check(_full().locked(), "a purchase waiting for payment does not unlock anything yet")
	check(heard == ["pending"], "and the game hears that it waits (%s)" % str(heard))
	store.owned_found.emit(PackedStringArray(["full_game"]))
	check(not _full().locked(), "once the payment goes through the store lists it and the game opens")
	check(heard == ["pending", "purchased"], "with the thank-you then (%s)" % str(heard))
	_done()


func test_a_cancelled_or_failed_purchase_leaves_it_locked() -> void:
	var store := _shop()
	var heard := _results()
	for status in ["cancelled", "error", "unavailable"]:
		_full().buy()
		store.purchase_finished.emit("full_game", status)
		check(_full().locked(), "a purchase that ended %s leaves the game locked" % status)
	check(heard == ["cancelled", "error", "unavailable"], "and each ending is passed on (%s)" % str(heard))
	store.purchase_finished.emit("other", "purchased")
	check(_full().locked(), "buying some other product unlocks nothing")
	_done()


func test_restoring_asks_the_store_what_was_bought() -> void:
	var store := _shop()
	var heard := _results()
	_full().restore()
	check(store.calls.has(["query_owned"]), "restoring asks the store again what the player owns")
	store.owned_found.emit(PackedStringArray(["full_game"]))
	check(not _full().locked() and heard == ["restored"], "a purchase found unlocks the game and says so (%s)" % str(heard))
	store = _shop()
	heard = _results()
	_full().restore()
	store.owned_found.emit(PackedStringArray())
	check(_full().locked() and heard == ["not_found"], "with nothing bought it says none was found (%s)" % str(heard))
	heard.clear()
	_full().restore()
	store.billing_unavailable.emit("Billing service unavailable on device.")
	check(heard == ["unavailable"], "and a store that cannot be reached says that (%s)" % str(heard))
	heard.clear()
	store.owned_found.emit(PackedStringArray(["full_game"]))
	check(heard.is_empty() and not _full().locked(), "a later answer at start unlocks quietly, as on a new phone")
	_done()


func test_the_answer_is_kept_for_when_the_store_cannot_be_reached() -> void:
	var store := _shop()
	store.purchase_finished.emit("full_game", "purchased")
	check(FileAccess.file_exists(CACHE), "owning the full game is written down")
	var full := _full()
	var offline := FakeStore.new()
	full.use_store(offline)
	offline.billing_unavailable.emit("Network is down")
	check(full.owned() and not full.locked(), "so a later start without a connection still has the full game")
	offline.owned_found.emit(PackedStringArray())
	check(full.locked(), "a store that no longer lists it, as after a refund, locks it again")
	full.use_store(FakeStore.new())
	check(full.locked(), "and that is written down too")
	_done()


func test_the_unlock_button_shows_the_price_and_buys() -> void:
	var store := _shop()
	_clear()
	var b: Button = DemoEnd.unlock_button(_holder())
	check(b != null and b.visible and b.text == tr("Unlock the full game"), "before the store answers the button has no price (%s)" % (b.text if b else "none"))
	store.billing_connected.emit()
	store.price_found.emit("full_game", PRICE)
	check(b != null and b.text == tr("Unlock the full game: %s") % PRICE, "then it shows the store's price (%s)" % (b.text if b else "none"))
	var where: Button = DemoEnd.full_game_button(_holder())
	check(where != null and where.visible and where.name == "Unlock", "a phone that sells the full game offers it where the demo stops")
	if b:
		b.pressed.emit()
	check(store.calls.has(["buy", "full_game"]), "pressing it buys the full game")
	store.purchase_finished.emit("full_game", "purchased")
	check(b != null and not b.visible and not where.visible, "and once it is owned there is nothing left to offer")
	var later: Button = DemoEnd.full_game_button(_holder())
	check(later == null or not later.visible, "nor anywhere it is offered afterwards")
	_done()


func test_each_ending_says_what_happened() -> void:
	var store := _shop()
	_clear()
	for ending in [["error", "The purchase did not go through. Please try again later."],
			["unavailable", "The store cannot be reached right now. Please try again later."]]:
		store.purchase_finished.emit("full_game", ending[0])
		check(_shown(ending[1]), "a purchase that ended %s says so" % ending[0])
	store.purchase_finished.emit("full_game", "pending")
	check(_shown("Your purchase is waiting for its payment. The whole bay opens as soon as it goes through."), "one waiting for its payment says the bay opens once it is paid")
	_full().restore()
	store.owned_found.emit(PackedStringArray())
	check(_shown("No purchase of the full game was found for this account."), "a restore that finds nothing says so")
	_full().restore()
	store.owned_found.emit(PackedStringArray(["full_game"]))
	check(_shown("The full game is unlocked again. Welcome back!"), "and one that finds it welcomes the player back")
	_done()


func test_buying_says_thank_you() -> void:
	var store := _shop()
	_clear()
	_through_the_demo()
	Game.state["demo_card_seen"] = false
	check(Game.show_demo_end(), "the demo's end card opens when chapter 3 would")
	_full().buy()
	store.purchase_finished.emit("full_game", "purchased")
	var w: Node = Nav.ui.get_node_or_null("Window")
	check(w != null and w.find_child("ThankYou", true, false) != null, "a purchase opens a thank-you card in its place")
	check(_shown("Thank you for buying the full game!") and _shown("The whole bay is open to you now, and your boat and your catch are just as you left them."),
		"which thanks the player and says the bay is open")
	_done()


func test_a_phone_offers_the_unlock_at_the_end_of_the_demo() -> void:
	var store := _shop()
	_clear()
	store.billing_connected.emit()
	store.price_found.emit("full_game", PRICE)
	_through_the_demo()
	check(Game.show_demo_end(), "the end card opens when chapter 3 would")
	var w: Node = Nav.ui.get_node_or_null("Window")
	var unlock: Button = w.find_child("Unlock", true, false) if w else null
	check(unlock != null and unlock.visible and unlock.text == tr("Unlock the full game: %s") % PRICE, "a phone's end card offers the full game with its price")
	check(w != null and w.find_child("Wishlist", true, false) == null, "in place of the wishlist button")
	_done()


func test_a_computer_offers_the_wishlist_as_before() -> void:
	_kept = Game.state
	_clear()
	Game.acts_as_demo = true
	_through_the_demo()
	check(Game.show_demo_end(), "the Steam demo's end card opens when chapter 3 would")
	var w: Node = Nav.ui.get_node_or_null("Window")
	check(w != null and w.find_child("Wishlist", true, false) != null and w.find_child("Unlock", true, false) == null,
		"with its wishlist button and no unlock")
	_clear()
	SettingsPanel.tab = "Gameplay"
	SettingsPanel.open()
	check(_button("Restore purchase") == null, "and its settings offer no purchase to restore")
	Game.acts_as_demo = false
	_clear()
	Game.state = _kept


func test_phones_offer_to_restore_a_purchase_in_the_settings() -> void:
	var store := _shop()
	_clear()
	SettingsPanel.tab = "Gameplay"
	SettingsPanel.open()
	var restore := _button("Restore purchase")
	check(restore != null, "a phone that has not bought the full game offers to restore a purchase")
	check(_shown("Already bought the full game?"), "beside the question of whether the full game was bought already")
	if restore:
		restore.pressed.emit()
	check(store.calls.has(["query_owned"]), "which asks the store what was bought")
	store.owned_found.emit(PackedStringArray(["full_game"]))
	check(SettingsPanel.is_settings_open() and _button("Restore purchase") == null, "once it is owned the settings stop offering it")
	_done()


func test_the_title_offers_the_unlock_and_says_thank_you() -> void:
	var store := _shop()
	store.billing_connected.emit()
	store.price_found.emit("full_game", PRICE)
	Game.state = {}
	_clear()
	var title: Node = load("res://scripts/screens/title.gd").new()
	Nav.port.add_child(title)
	title.enter({})
	var demo: Label = Nav.ui.find_child("Demo", true, false)
	# App Review refuses a game that calls itself a demo, so a phone selling the full game never shows the word.
	check(demo == null or not demo.visible, "the title does not say Demo where the full game is sold")
	check(_button("Unlock the full game: %s" % PRICE) != null, "and offers the full game with its price")
	check(Nav.ui.find_child("Wishlist", true, false) == null, "in place of the wishlist button")
	_full().buy()
	store.purchase_finished.emit("full_game", "purchased")
	var unlock := _button("Unlock the full game: %s" % PRICE)
	check(unlock == null or not unlock.visible, "and stops offering it once bought")
	check(demo == null or not demo.visible, "the title no longer says Demo")
	check(_shown("Thank you for buying the full game!"), "and a card thanks the player")
	title.free()
	_done()


## A row of its own in the interface, as a window's or the title's.
func _holder() -> HBoxContainer:
	var row := HBoxContainer.new()
	Nav.ui.add_child(row)
	return row


## Whether a label or button showing these words is in the interface, leaving out a window on its way out.
func _shown(text: String) -> bool:
	return Nav.ui.find_children("*", "", true, false).any(func(n: Node) -> bool:
		return (n is Label or n is Button) and _live(n) and (n.text == tr(text) or n.text == text))


func _button(text: String) -> Button:
	for b in Nav.ui.find_children("*", "Button", true, false):
		if _live(b) and (b.text == tr(text) or b.text == text):
			return b
	return null


func _live(n: Node) -> bool:
	if not (n as CanvasItem).is_visible_in_tree():
		return false
	while n != null:
		if n.is_queued_for_deletion():
			return false
		n = n.get_parent()
	return true


## The SlowSundayPhone plugin's purchase methods and signals, answered by hand.
class FakeStore:
	signal billing_connected
	signal billing_unavailable(message: String)
	signal price_found(product_id: String, price: String)
	signal purchase_finished(product_id: String, status: String)
	signal owned_found(product_ids: PackedStringArray)

	var calls: Array = []

	func billing_start() -> void:
		calls.append(["billing_start"])

	func billing_ready() -> bool:
		return true

	func query_price(product_id: String) -> void:
		calls.append(["query_price", product_id])

	func buy(product_id: String) -> void:
		calls.append(["buy", product_id])

	func query_owned() -> void:
		calls.append(["query_owned"])
