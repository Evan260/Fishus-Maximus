class_name PondPanel
## The pond's window: digging it and widening it, its features, its fish with their names and finery, feeding, the
## bell, and stocking it from the boat's live well.


static func open(view: PondView) -> void:
	var list := Ui.window(view.tr("The fish pond"), 330, 210)
	var price := Ponds.next_price(Game.state)
	var stage := Ponds.stage(Game.state)
	if not Ponds.dug(Game.state):
		Ui.label(list, view.tr("A basin cut into the rock by the shore, fed by the sea."), "MutedLabel")
		Ui.row(list, view.tr("Dig the pond, room %d: %s") % [int(Data.ponds["stages"][0]["room"]), Ui.coins_text(price)], view.tr("Dig"), func():
			if Ponds.widen(Game.state):
				Game.changed.emit()
				view.sync()
			open(view), int(Game.state["denarii"]) >= price)
		return
	var p := Ponds.of(Game.state)
	Ui.label(list, view.tr("Stage %d of %d, room %d of %d.") % [stage, Ponds.stages(), Ponds.room_used(p), Ponds.room(p)], "MutedLabel")
	if price >= 0:
		if stage < Ponds.allowed(Game.state):
			Ui.row(list, view.tr("Widen it to room %d: %s") % [int(Data.ponds["stages"][stage]["room"]), Ui.coins_text(price)], view.tr("Widen"), func():
				if Ponds.widen(Game.state):
					Game.changed.emit()
					view.sync()
				open(view), int(Game.state["denarii"]) >= price)
		else:
			Ui.label(list, view.tr("You may widen it further as your name grows."), "MutedLabel")
	var actions := HBoxContainer.new()
	list.add_child(actions)
	Ui.button(actions, view.tr("Feed"), func():
		Ponds.feed(Game.state)
		Toast.say(view.tr("The fish are fed."))
		view.feed()
		open(view))
	Ui.button(actions, view.tr("Ring the bell"), func():
		view.ring()
		Audio.play("pond_bell")
		Ui.close_window())
	for i in p["fish"].size():
		var f: Dictionary = p["fish"][i]
		var fi: int = i
		var who := (view.tr("%s the %s") % [f["name"], str(Data.fish[f["fish"]]["name"]).to_lower()]) if f["name"] != "" else str(Data.fish[f["fish"]]["name"])
		var mood := int(roundf(Ponds.happiness(p, f) * 100.0))
		var line := view.tr("%s, %s, %d%% happy") % [who, Units.weight(float(f["pounds"])), mood]
		if f.get("fed", false):
			line += view.tr(", fed")
		if f.get("finery", "") != "":
			line += view.tr(", wearing %s") % str(Data.gear[f["finery"]]["name"]).to_lower()
		var r := Ui.row(list, line)
		if f["name"] == "":
			var entry := LineEdit.new()
			entry.placeholder_text = view.tr("Name")
			entry.custom_minimum_size = Vector2(60, 0)
			entry.text_submitted.connect(func(t):
				Ponds.name_fish(Game.state, fi, t)
				view.sync()
				open(view))
			r.add_child(entry)
		elif not Game.state.get("finery", []).is_empty():
			var wear: String = Game.state["finery"][0]
			Ui.button(r, view.tr("Dress"), func():
				Ponds.dress(Game.state, fi, wear)
				view.sync()
				open(view))
		Ui.button(r, view.tr("Sell"), func():
			Toast.say(view.tr("Sold to a villa at Baiae for %s.") % Ui.coins_text(Ponds.sell_live(Game.state, fi)))
			Game.changed.emit()
			view.sync()
			open(view))
	for i in Game.state["live_well"].size():
		var f: Dictionary = Game.state["live_well"][i]
		var wi: int = i
		if Data.fish[f["fish"]].has("pond"):
			Ui.row(list, view.tr("From the well: ") + Ui.fish_text(f), view.tr("Put in"), func():
				Ponds.stock(Game.state, wi)
				view.sync()
				open(view))
	Ui.label(list, view.tr("FEATURES"), "Heading")
	for feature in Data.ponds["features"]:
		var id: String = feature["id"]
		if id in p["features"]:
			Ui.row(list, view.tr("%s: built") % feature["name"])
		elif not feature.has("needs") or feature["needs"] in p["features"]:
			Ui.row(list, "%s, %s. %s" % [feature["name"], Ui.coins_text(int(feature["price"])), feature["text"]], view.tr("Build"), func():
				if Ponds.add_feature(Game.state, id):
					Game.changed.emit()
					view.sync()
				open(view), int(Game.state["denarii"]) >= int(feature["price"]))
