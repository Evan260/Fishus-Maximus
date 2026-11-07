class_name ShopPanel
## The town's shops: the fish market, the netmaker, the boatwright and the goldsmith.


static func market() -> void:
	var list := Ui.window("The fish market", 320, 210)
	if Game.state["hold"].is_empty():
		Ui.label(list, "Your hold is empty.", "MutedLabel")
		hire_row(list)
		return
	var total := 0
	for f in Game.state["hold"]:
		total += Market.price(Game.state, f["fish"], float(f["pounds"]), float(f.get("fresh", 1.0)))
	Ui.row(list, "The whole hold, about %s" % Ui.coins_text(total), "Sell all", func():
		while not Game.state["hold"].is_empty():
			Market.sell(Game.state, 0)
		Audio.play("coins")
		Game.changed.emit()
		market())
	for i in Game.state["hold"].size():
		var f: Dictionary = Game.state["hold"][i]
		var p := Market.price(Game.state, f["fish"], float(f["pounds"]), float(f.get("fresh", 1.0)))
		var idx: int = i
		Ui.row(list, "%s: %s" % [Ui.fish_text(f), Ui.coins_text(p)], "Sell", func():
			Market.sell(Game.state, idx)
			Audio.play("coins")
			Game.changed.emit()
			market())
	hire_row(list)


static func netmaker() -> void:
	var list := Ui.window("The netmaker", 320, 210)
	Ui.label(list, "BAIT (box %d of %d)" % [Shop.bait_count(Game.state), Shop.bait_capacity(Game.state)], "Heading")
	for id in Data.bait:
		if Shop.on_sale(Game.state, id):
			var b: Dictionary = Data.bait[id]
			_buy_row(list, id, "%s x%d (you have %d): %s" % [b["name"], int(b["per"]), int(Game.state["bait"].get(id, 0)), Ui.coins_text(int(b["price"]))], netmaker)
	var current: String = str(Game.state.get("current_bait", ""))
	Ui.label(list, "On the hook: " + str(Data.bait.get(current, {"name": "nothing"})["name"]), "MutedLabel")
	for id in Game.state["bait"]:
		if int(Game.state["bait"][id]) > 0 and id != current:
			var bid: String = id
			Ui.row(list, "Bait the hook with %s" % str(Data.bait[id]["name"]).to_lower(), "Use", func():
				Game.state["current_bait"] = bid
				netmaker())
	Ui.label(list, "GEAR", "Heading")
	for id in Data.gear:
		var g: Dictionary = Data.gear[id]
		if g["kind"] == "finery" or int(g["price"]) == 0 or not Shop.on_sale(Game.state, id):
			continue
		if Shop.owned(Game.state, id):
			Ui.row(list, "%s: yours" % g["name"])
		else:
			_buy_row(list, id, "%s: %s" % [g["name"], Ui.coins_text(int(g["price"]))], netmaker)


## Help for hire, at the market: the errand boy and, later, a second fisherman.
static func hire_row(list: Control) -> void:
	Ui.label(list, "HELP", "Heading")
	for id in Helpers.HELP:
		var h: Dictionary = Helpers.HELP[id]
		var hid: String = id
		if id in Game.state["helpers"]:
			Ui.row(list, "%s: working for you" % h["name"])
		elif int(Game.state["chapter"]) >= int(h["chapter"]):
			Ui.row(list, "%s. %s %s" % [h["name"], h["text"], Ui.coins_text(int(h["price"]))], "Hire", func():
				if Helpers.hire(Game.state, hid):
					Game.changed.emit()
				market(), int(Game.state["denarii"]) >= int(h["price"]))


static func boatwright() -> void:
	var list := Ui.window("The boatwright", 320, 200)
	for id in Data.boats:
		var b: Dictionary = Data.boats[id]
		var stats := "%s. Hold %d, well %d." % [b["name"], int(b["hold"]), int(b["well"])]
		if Shop.owned(Game.state, id):
			Ui.row(list, stats + (" Yours." if id == Game.state["boat"] else ""))
		elif Shop.on_sale(Game.state, id):
			_buy_row(list, id, "%s %s" % [stats, Ui.coins_text(int(b["price"]))], boatwright)
		else:
			Ui.row(list, stats + " Not yet.")


static func goldsmith() -> void:
	var list := Ui.window("The goldsmith", 300, 160)
	Ui.label(list, "Finery for a named pond fish.", "MutedLabel")
	for id in Data.gear:
		var g: Dictionary = Data.gear[id]
		if g["kind"] == "finery":
			var have: int = Game.state.get("finery", []).count(id)
			_buy_row(list, id, "%s (you have %d): %s" % [g["name"], have, Ui.coins_text(int(g["price"]))], goldsmith)


static func _buy_row(list: Control, id: String, text: String, reopen: Callable) -> void:
	Ui.row(list, text, "Buy", func():
		if Shop.buy(Game.state, id):
			Game.changed.emit()
		elif Data.bait.has(id) and int(Game.state["denarii"]) >= Shop.price(id):
			Toast.say("The bait box is full.")
		else:
			Toast.say("Not enough denarii.")
		reopen.call(), int(Game.state["denarii"]) >= Shop.price(id))
