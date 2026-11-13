class_name DemoEnd
## The demo's end card, shown once when chapter 3 would open: thanks, a glimpse of what the full game holds, and a
## button to wishlist it on Steam, which the title has too.


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
	wishlist_button(row)
	Ui.button(row, "Keep fishing", Ui.close_window)


## The button that opens the full game's store page, hidden until the game has a Steam App ID.
static func wishlist_button(parent: Node) -> Button:
	var b := Ui.button(parent, "Wishlist on Steam", func(): Awards.wishlist())
	b.name = "Wishlist"
	b.visible = Awards.store_app_id() != 0
	return b
