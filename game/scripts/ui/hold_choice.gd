class_name HoldChoice
## The choice when a fish is landed into a full hold: let the new fish go, or let one already caught go to make room.


static func ask(fish: Dictionary) -> void:
	if Nav.ui == null:
		return
	# A window, so play waits behind it and a second full-hold catch replaces it rather than stacking another.
	var col := Ui.window("The hold is full", 260, 200)
	var name: String = Data.fish[fish["fish"]]["name"]
	Ui.label(col, "Keep the %s (%s)?" % [name.to_lower(), Units.weight(float(fish["pounds"]))])
	Ui.button(col, "Let the new one go", Ui.close_window)
	var live: bool = fish.get("live", false)
	var list: Array = Game.state["live_well"] if live and Hold.well_room(Game.state) <= 0 and not Game.state["live_well"].is_empty() else Game.state["hold"]
	var from_well: bool = live and list == Game.state["live_well"]
	var shown := 0
	for i in list.size():
		if shown >= 6:
			break
		var held: Dictionary = list[i]

		Ui.button(col, "Let go a %s (%s)" % [Data.fish[held["fish"]]["name"].to_lower(), Units.weight(float(held["pounds"]))], func():
			if Hold.release_fish(Game.state, held):
				Hold.add(Game.state, fish)
			Ui.close_window())
		shown += 1
