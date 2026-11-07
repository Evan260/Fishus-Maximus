class_name BoardPanel
## The harbour board: the day's orders, each filled with a fish from the hold or the live well.


static func open() -> void:
	var list := Ui.window("The harbour board", 330, 200)
	if Game.state["orders"].is_empty():
		Ui.label(list, "No orders today. Come back in the morning.", "MutedLabel")
		return
	var today := Clock.day_of(float(Game.state["time"]))
	for i in Game.state["orders"].size():
		var o: Dictionary = Game.state["orders"][i]
		var due := int(o["due"])
		var when := "today" if due <= today else ("tomorrow" if due == today + 1 else "in %d days" % (due - today))
		var text := "%s, %s lb or more%s: %s, +%d name, by %s" % [Data.fish[o["fish"]]["name"], CatchCard.pounds_text(float(o["min_pounds"])),
			", alive" if o["alive"] else "", Ui.coins_text(int(o["reward"])), int(o["reputation"]), when]
		var at := Supply.find(Game.state, o)
		var oi: int = i
		Ui.row(list, text, "Fill", func():
			if Orders.fill_from(Game.state, oi, at):
				Toast.say("Order filled.")
				Game.changed.emit()
			open(), not at.is_empty())


## Where a fish that suits a request is kept, as [index, from the well], or [-1, false] when there is none.
static func find(want: Dictionary) -> Array:
	for from_well in [true, false]:
		var list: Array = Game.state["live_well"] if from_well else Game.state["hold"]
		for i in list.size():
			if Orders.suits(want, list[i], from_well):
				return [i, from_well]
	return [-1, false]
