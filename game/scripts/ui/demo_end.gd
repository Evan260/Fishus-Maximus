class_name DemoEnd
## The demo's end card, shown once when chapter 3 would open: thanks, a glimpse of what the full game holds, and a
## button to wishlist it on Steam, which the title has too. On a phone, where the free game plays as the demo until the
## full game is bought from the store (`FullGame`), the button unlocks it instead, and the store's answers are told here.

## The group every unlock button joins, so each shows the store's price and hides once the full game is bought.
const UNLOCK := "unlock"


static func open() -> void:
	var list := Ui.window("Thank you for playing", 340, 256)
	list.name = "DemoEnd"
	var boat := TextureRect.new()
	boat.texture = ItemArt.of("big_boat")
	boat.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	list.add_child(boat)
	for line in [["That is the end of the demo. Your name in town has grown enough to open the next chapter.", ""],
			["The full game sails on to the Lucrine Lake and the open bay, the sea caves of Capri and the deep water off Misenum, with the legends of the bay to catch and the big boat to sail.", "MutedLabel"],
			["Your game carries over to the full game.", "MutedLabel"]]:
		var l := Ui.label(list, line[0], line[1])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	list.add_child(row)
	full_game_button(row)
	Ui.button(row, "Keep fishing", Ui.close_window)


## The button that opens the full game's store page, hidden until the game has a Steam App ID, and on a phone, which
## has no Steam.
static func wishlist_button(parent: Node) -> Button:
	var b := Ui.button(parent, "Wishlist on Steam", func(): Awards.wishlist())
	b.name = "Wishlist"
	b.visible = Awards.store_app_id() != 0 and not Windowing.phone
	return b


## Where the demo stops the player: a phone's unlock, the Steam demo's wishlist, or nothing in the full game.
static func full_game_button(parent: Node) -> Button:
	if FullGame.sold_here():
		return unlock_button(parent)
	return wishlist_button(parent) if Game.is_demo() else null


## A phone's button that buys the full game, shown while it is not bought, or null where nothing is for sale.
static func unlock_button(parent: Node) -> Button:
	if not FullGame.sold_here():
		return null
	var b := Ui.button(parent, unlock_text(), func(): FullGame.buy())
	b.name = "Unlock"
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.visible = FullGame.locked()
	b.add_to_group(UNLOCK)
	return b


## The unlock button's words, with the store's own price once it has said it.
static func unlock_text() -> String:
	if FullGame.price() == "":
		return TranslationServer.translate("Unlock the full game")
	return TranslationServer.translate("Unlock the full game: %s") % FullGame.price()


## Brings every unlock button showing up to date with the store.
static func refresh() -> void:
	if Nav.ui == null:
		return
	for b in Nav.ui.get_tree().get_nodes_in_group(UNLOCK):
		(b as Button).text = unlock_text()
		(b as Button).visible = FullGame.locked()


## What the store said about the full game, which can come on the title too, since it is bought from there as well.
static func store_result(result: String) -> void:
	match result:
		"purchased":
			thank_you()
		"restored":
			Toast.say("The full game is unlocked again. Welcome back!")
		"pending":
			Toast.say("Your purchase is waiting for its payment. The whole bay opens as soon as it goes through.")
		"error":
			Toast.say("The purchase did not go through. Please try again later.")
		"unavailable":
			Toast.say("The store cannot be reached right now. Please try again later.")
		"not_found":
			Toast.say("No purchase of the full game was found for this account.")


## The card after buying the full game, in place of any window open, as the whole bay opens with the game as it was.
static func thank_you() -> void:
	var list := Ui.window("", 300, 200)
	list.name = "ThankYou"
	var boat := TextureRect.new()
	boat.texture = ItemArt.of("big_boat")
	boat.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	list.add_child(boat)
	for line in [["Thank you for buying the full game!", ""],
			["The whole bay is open to you now, and your boat and your catch are just as you left them.", "MutedLabel"]]:
		var l := Ui.label(list, line[0], line[1])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	list.add_child(row)
	Ui.button(row, "Keep fishing", Ui.close_window)
	Audio.play("market_bell")
