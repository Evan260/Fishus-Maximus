class_name HoldChoice
## The choice when a fish is landed into a full hold: let the new fish go, or let one already caught go to make room.


static func ask(fish: Dictionary) -> void:
	if Nav.ui == null:
		return
	var col := Ui.panel(Nav.ui, "The hold is full")
	var panel: Control = col.get_parent()
	var name: String = Data.fish[fish["fish"]]["name"]
	Ui.label(col, "Keep the %s (%s lb)?" % [name.to_lower(), CatchCard.pounds_text(float(fish["pounds"]))])
	Ui.button(col, "Let the new one go", panel.queue_free)
	var live: bool = fish.get("live", false)
	var list: Array = Game.state["live_well"] if live and Hold.well_room(Game.state) <= 0 and not Game.state["live_well"].is_empty() else Game.state["hold"]
	var from_well: bool = live and list == Game.state["live_well"]
	var shown := 0
	for i in list.size():
		if shown >= 6:
			break
		var held: Dictionary = list[i]

		Ui.button(col, "Let go a %s (%s lb)" % [Data.fish[held["fish"]]["name"].to_lower(), CatchCard.pounds_text(float(held["pounds"]))], func():
			if not Hold.release_fish(Game.state, held):
				panel.queue_free()
				return
			Hold.add(Game.state, fish)
			panel.queue_free())
		shown += 1
