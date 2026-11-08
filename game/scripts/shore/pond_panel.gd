class_name PondPanel
## A pond's window: cutting it, its features, its fish with their names and finery, feeding, the bell, and stocking
## it from the boat's live well.


static func open(site: int, view: PondView) -> void:
	var index := Ponds.site_of(Game.state, site)
	var info: Dictionary = Data.ponds["sites"][site]
	var list := Ui.window(info["name"], 330, 210)
	if index < 0:
		if Game.state["ponds"].size() >= Ponds.allowed(Game.state):
			Ui.label(list, "You may cut more ponds as your name grows.", "MutedLabel")
			return
		Ui.label(list, "%s water. Cut a pond into the rock here?" % str(info["water"]).capitalize(), "MutedLabel")
		for size in Data.ponds["sizes"]:
			var sz: String = size
			var price := int(Data.ponds["sizes"][size]["price"])
			Ui.row(list, "A %s pond, room %d: %s" % [size, int(Data.ponds["sizes"][size]["room"]), Ui.coins_text(price)], "Cut", func():
				if Ponds.build(Game.state, site, sz):
					Game.changed.emit()
					view.sync()
				open(site, view), int(Game.state["denarii"]) >= price)
		return
	var p: Dictionary = Game.state["ponds"][index]
	Ui.label(list, "%s, %s water, room %d of %d." % [str(p["size"]).capitalize(), p["water"], Ponds.room_used(p), Ponds.room(p)], "MutedLabel")
	var actions := HBoxContainer.new()
	list.add_child(actions)
	Ui.button(actions, "Feed", func():
		Ponds.feed(Game.state, index)
		Toast.say("The fish are fed.")
		open(site, view))
	Ui.button(actions, "Ring the bell", func():
		view.bell_left = 5.0
		Audio.play("pond_bell")
		Ui.close_window())
	for i in p["fish"].size():
		var f: Dictionary = p["fish"][i]
		var fi: int = i
		var who := ("%s the %s" % [f["name"], str(Data.fish[f["fish"]]["name"]).to_lower()]) if f["name"] != "" else str(Data.fish[f["fish"]]["name"])
		var mood := int(roundf(Ponds.happiness(p, f) * 100.0))
		var line := "%s, %s, %d%% happy%s%s" % [who, Units.weight(float(f["pounds"])), mood, ", fed" if f.get("fed", false) else "",
			", wearing " + str(Data.gear[f["finery"]]["name"]).to_lower() if f.get("finery", "") != "" else ""]
		var r := Ui.row(list, line)
		if f["name"] == "":
			var entry := LineEdit.new()
			entry.placeholder_text = "Name"
			entry.custom_minimum_size = Vector2(60, 0)
			entry.text_submitted.connect(func(t):
				Ponds.name_fish(Game.state, index, fi, t)
				view.sync()
				open(site, view))
			r.add_child(entry)
		elif not Game.state.get("finery", []).is_empty():
			var wear: String = Game.state["finery"][0]
			Ui.button(r, "Dress", func():
				Ponds.dress(Game.state, index, fi, wear)
				open(site, view))
		Ui.button(r, "Sell", func():
			Toast.say("Sold to a villa at Baiae for %s." % Ui.coins_text(Ponds.sell_live(Game.state, index, fi)))
			Game.changed.emit()
			view.sync()
			open(site, view))
	for i in Game.state["live_well"].size():
		var f: Dictionary = Game.state["live_well"][i]
		var wi: int = i
		if Data.fish[f["fish"]].has("pond"):
			Ui.row(list, "From the well: " + Ui.fish_text(f), "Put in", func():
				Ponds.stock(Game.state, index, wi)
				view.sync()
				open(site, view))
	Ui.label(list, "FEATURES", "Heading")
	for feature in Data.ponds["features"]:
		var id: String = feature["id"]
		if id in p["features"]:
			Ui.row(list, "%s: built" % feature["name"])
		elif not feature.has("needs") or feature["needs"] in p["features"]:
			Ui.row(list, "%s, %s. %s" % [feature["name"], Ui.coins_text(int(feature["price"])), feature["text"]], "Build", func():
				if Ponds.add_feature(Game.state, index, id):
					Game.changed.emit()
				open(site, view), int(Game.state["denarii"]) >= int(feature["price"]))
