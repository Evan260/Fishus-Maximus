class_name ShopPanel
## The town's shops: the fish market, the netmaker, the boatwright and the goldsmith. Everything in them is a picture
## with its price under it, and holding the pointer over one tells what it is.

const TILE := Vector2(40, 40)
const BOAT_TILE := Vector2(96, 62)
const FISH_TILE := Vector2(48, 40)


static func market() -> void:
	var list := Ui.window("The fish market", 320, 210)
	if Game.state["hold"].is_empty():
		Ui.label(list, "Your hold is empty.", "MutedLabel")
		hire_row(list)
		return
	var total := 0
	for f in Game.state["hold"]:
		total += Market.price(Game.state, f["fish"], float(f["pounds"]), float(f.get("fresh", 1.0)))
	Ui.row(list, TranslationServer.translate("The whole hold, about %s") % Ui.coins_text(total), "Sell all", func():
		while not Game.state["hold"].is_empty():
			Market.sell(Game.state, 0)
		Audio.play("coins")
		Game.changed.emit()
		market())
	var fish := _grid(list, FISH_TILE)
	for i in Game.state["hold"].size():
		var f: Dictionary = Game.state["hold"][i]
		var p := Market.price(Game.state, f["fish"], float(f["pounds"]), float(f.get("fresh", 1.0)))
		var idx: int = i
		Ui.price_tile(fish, ItemArt.of(f["fish"]), p, TranslationServer.translate("%s. Sells for %s.") % [Ui.fish_text(f), Ui.coins_text(p)], func():
			Market.sell(Game.state, idx)
			Audio.play("coins")
			Game.changed.emit()
			market(), true, FISH_TILE)
	hire_row(list)


static func netmaker() -> void:
	var list := Ui.window("The netmaker", 320, 210)
	Ui.label(list, Ui.upper(TranslationServer.translate("Bait (box %d of %d)") % [Shop.bait_count(Game.state), Shop.bait_capacity(Game.state)]), "Heading")
	var baits := _grid(list, TILE)
	for id in Data.bait:
		if Shop.on_sale(Game.state, id):
			var b: Dictionary = Data.bait[id]
			_buy_tile(baits, id, Ui.text([TranslationServer.translate("%s, %d for %s. You have %d.") % [Data.name_of(b), int(b["per"]), Ui.coins_text(int(b["price"])),
				int(Game.state["bait"].get(id, 0))], str(b.get("text", ""))]), netmaker)
	Ui.label(list, Ui.upper("Gear"), "Heading")
	var gear := _grid(list, TILE)
	for id in Data.gear:
		var g: Dictionary = Data.gear[id]
		if g["kind"] == "finery" or int(g["price"]) == 0 or not Shop.on_sale(Game.state, id):
			continue
		if Shop.owned(Game.state, id):
			Ui.tile(gear, ItemArt.of(id), "Yours", Ui.text([TranslationServer.translate("%s.") % Data.name_of(g), gear_text(id), "Yours."]), func(): pass, true, true, TILE)
		else:
			_buy_tile(gear, id, Ui.text([TranslationServer.translate("%s.") % Data.name_of(g), gear_text(id), TranslationServer.translate("%s.") % Ui.coins_text(int(g["price"]))]), netmaker)


## What a piece of gear does, in a few words for its tip.
static func gear_text(id: String) -> String:
	var g: Dictionary = Data.gear[id]
	match str(g["kind"]):
		"rod":
			return TacklePanel.rod_tip(id, str(Game.state.get("place", "harbour")))
		"line":
			return TranslationServer.translate("A stronger line, which snaps less often while a fish runs.")
		"hook":
			return TranslationServer.translate("A surer hook, which a resting fish slips less often.")
		"net":
			return TranslationServer.translate("A cast net for shoals near the surface, %d fish at a throw.") % int(g.get("size", 4))
		"trap":
			return TranslationServer.translate("One more pot to set on the seabed, %d in all.") % int(g.get("count", 3))
		"lamp":
			return TranslationServer.translate("A lamp for the trident at night, whose light draws the fish.")
		"bait_box":
			return TranslationServer.translate("A bigger box, holding %d baits.") % int(g.get("capacity", 30))
	return ""


## Help for hire, at the market: the errand boy and, later, a second fisherman.
static func hire_row(list: Control) -> void:
	Ui.label(list, Ui.upper("Help"), "Heading")
	var help := _grid(list, TILE)
	for id in Helpers.HELP:
		var h: Dictionary = Helpers.HELP[id]
		var hid: String = id
		var tip := Ui.text([TranslationServer.translate("%s.") % TranslationServer.translate(h["name"]), str(h["text"])])
		if id in Game.state["helpers"]:
			Ui.tile(help, ItemArt.of("help_" + id), "Hired", Ui.text([tip, "Working for you."]), func(): pass, true, true, TILE)
		elif int(Game.state["chapter"]) >= int(h["chapter"]):
			Ui.price_tile(help, ItemArt.of("help_" + id), int(h["price"]), tip, func():
				if Helpers.hire(Game.state, hid):
					Game.changed.emit()
				market(), int(Game.state["denarii"]) >= int(h["price"]), TILE)


static func boatwright() -> void:
	var list := Ui.window("The boatwright", 320, 200)
	var boats := _grid(list, BOAT_TILE)
	for id in Data.boats:
		var b: Dictionary = Data.boats[id]
		var tip := Ui.text([TranslationServer.translate("%s. Hold %d, well %d.") % [Data.name_of(b), int(b["hold"]), int(b["well"])], str(b.get("text", ""))])
		if Shop.owned(Game.state, id):
			Ui.tile(boats, ItemArt.of(id), "Yours", tip, func(): pass, true, id == Game.state["boat"], BOAT_TILE)
		elif Shop.on_sale(Game.state, id):
			_buy_tile(boats, id, Ui.text([tip, TranslationServer.translate("%s.") % Ui.coins_text(int(b["price"]))]), boatwright, BOAT_TILE)
		else:
			Ui.tile(boats, ItemArt.of(id), "Not yet", tip, func(): pass, false, false, BOAT_TILE)


static func goldsmith() -> void:
	var list := Ui.window("The goldsmith", 300, 160)
	Ui.label(list, "Finery for a named pond fish.", "MutedLabel")
	var finery := _grid(list, TILE)
	for id in Data.gear:
		var g: Dictionary = Data.gear[id]
		if g["kind"] == "finery":
			var have: int = Game.state.get("finery", []).count(id)
			_buy_tile(finery, id, TranslationServer.translate("%s. You have %d. %s.") % [Data.name_of(g), have, Ui.coins_text(int(g["price"]))], goldsmith)


static func _grid(list: Control, tile: Vector2) -> GridContainer:
	var g := GridContainer.new()
	g.columns = maxi(1, int((list.get_parent().custom_minimum_size.x - 8.0) / (tile.x + 2.0)))
	g.add_theme_constant_override("h_separation", 2)
	g.add_theme_constant_override("v_separation", 2)
	list.add_child(g)
	return g


static func _buy_tile(grid: Control, id: String, tip: String, reopen: Callable, size := TILE) -> void:
	Ui.price_tile(grid, ItemArt.of(id), Shop.price(id), tip, func():
		if Shop.buy(Game.state, id):
			Game.changed.emit()
		elif Data.bait.has(id) and int(Game.state["denarii"]) >= Shop.price(id):
			Toast.say("The bait box is full.")
		else:
			Toast.say("Not enough denarii.")
		reopen.call(), int(Game.state["denarii"]) >= Shop.price(id), size)
