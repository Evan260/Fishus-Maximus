class_name GarumPanel
## The garum works: each tank's state, filling one from the hold, stirring, bottling, and selling the amphorae at the
## market or, every seventh day, to the export ship.


static func open() -> void:
	var list := Ui.window("The garum works", 340, 214)
	var day := Clock.day_of(float(Game.state["time"]))
	var export := Garum.export_day(day)
	Ui.label(list, "Salt: %d measures. The export ship %s." % [int(Game.state.get("salt", 0)),
		"is in the harbour today" if export else ship_text(day)], "MutedLabel")
	var salt: Dictionary = Data.garum["salt"]
	Ui.row(list, "Buy %d measures of salt: %s" % [int(salt["per"]), Ui.coins_text(int(salt["price"]))], "Buy", func():
		if int(Game.state["denarii"]) >= int(salt["price"]):
			Game.state["denarii"] = int(Game.state["denarii"]) - int(salt["price"])
			Game.state["salt"] = int(Game.state.get("salt", 0)) + int(salt["per"])
			Game.changed.emit()
		open(), int(Game.state["denarii"]) >= int(salt["price"]))
	for i in Game.state["tanks"].size():
		var t: Dictionary = Game.state["tanks"][i]
		var ti: int = i
		if not t["restored"]:
			var price := int(Data.garum["restore"]["price"])
			Ui.row(list, "Tank %d: a ruin. Restore it for %s" % [i + 1, Ui.coins_text(price)], "Restore", func():
				if Garum.restore(Game.state, ti):
					Game.changed.emit()
				else:
					Toast.say("More tanks can be restored as your name grows.")
				open(), int(Game.state["denarii"]) >= price)
		elif float(t["pounds"]) <= 0.0:
			var fish := _garum_fish()
			var pounds := 0.0
			for f in fish:
				pounds += float(f["pounds"])
			var need := Garum.salt_needed(pounds)
			Ui.row(list, "Tank %d: empty. Fill it with the hold's %s of fish and %d salt" % [i + 1, Units.weight(pounds), need], "Fill", func():
				if Garum.fill(Game.state, ti, fish, need):
					for f in fish:
						Game.state["hold"].erase(f)
					Game.changed.emit()
				else:
					Toast.say("Not enough salt.")
				open(), pounds > 0.0 and int(Game.state.get("salt", 0)) >= need)
		else:
			var g := Garum.grade(t)
			var name: String = Garum.grade_info(g).get("name", "not ready")
			var r := Ui.row(list, "Tank %d: %s, day %d, %s%s" % [i + 1, Units.weight(float(t["pounds"])), int(t["days"]), name.to_lower(),
				", stirred" if t["stirred"] else ""])
			if not t["stirred"]:
				Ui.button(r, "Stir", func():
					Garum.stir(Game.state, ti)
					open())
			if g != "":
				Ui.button(r, "Bottle", func():
					var got := Garum.take(Game.state, ti)
					Toast.say("%s of %s." % [amphorae(int(got["amphorae"])), str(Garum.grade_info(got["grade"])["name"]).to_lower()])
					open())
	for g in Data.garum["grades"]:
		var id: String = g["id"]
		var n := int(Game.state["garum"].get(id, 0))
		if n > 0:
			var p := Garum.price(id, Garum.quality(Game.state, id), export)
			Ui.row(list, "%s of %s, %s each%s" % [amphorae(n), str(g["name"]).to_lower(), Ui.coins_text(p), " to the ship" if export else ""], "Sell one", func():
				Garum.sell(Game.state, id, export)
				Game.changed.emit()
				open())


## The fish in the hold that go into a tank: whatever is past its best, or all of it when nothing is.
static func _garum_fish() -> Array:
	var stale: Array = Game.state["hold"].filter(func(f): return float(f.get("fresh", 1.0)) < 0.7 or f.get("salted", false))
	return stale if not stale.is_empty() else Game.state["hold"].duplicate()


static func amphorae(n: int) -> String:
	return "%d amphora" % n if n == 1 else "%d amphorae" % n


## When the export ship comes, on a day it is not in the harbour.
static func ship_text(day: int) -> String:
	var left := 7 - day % 7
	return "comes in %d day%s" % [left, "" if left == 1 else "s"]
