class_name TacklePanel
## The tackle: the bait on the hook and the rod in his hands, chosen from what he has, each with a tip naming the fish
## here it suits. A rod suits fish of a range of sizes: smaller fish are shy of it, bigger ones fight harder on it.


static func open() -> void:
	var list := Ui.window("Tackle", 340, 220)
	var place := str(Game.state.get("place", "harbour"))
	Ui.label(list, "BAIT ON THE HOOK", "Heading")
	for id in Data.bait:
		var count := int(Game.state["bait"].get(id, 0))
		if count <= 0:
			continue
		var bait_id: String = id
		var on: bool = str(Game.state.get("current_bait", "")) == id
		var choose_bait := func():
			use_bait(bait_id)
			open()
		_tip(Ui.row(list, "%s x%d" % [Data.bait[id]["name"], count], "On the hook" if on else "Use", choose_bait, not on), bait_tip(id, place))
	Ui.label(list, "ROD", "Heading")
	for id in rods_owned(Game.state):
		var rod_id: String = id
		var held: bool = str(Game.state["gear"].get("rod", "")) == id
		var choose_rod := func():
			use_rod(rod_id)
			open()
		_tip(Ui.row(list, str(Data.gear[id]["name"]), "In hand" if held else "Use", choose_rod, not held), rod_tip(id, place))
	Ui.label(list, "Hold the pointer over one to see which fish it suits.", "MutedLabel")


## The rods he has: the best he bought and every lighter one, lightest first.
static func rods_owned(state: Dictionary) -> Array:
	var best := str(state["gear"].get("rod_best", state["gear"].get("rod", "")))
	var top := int(Data.gear.get(best, {}).get("price", 0))
	var rods := Data.gear.keys().filter(func(g): return Data.gear[g]["kind"] == "rod" and int(Data.gear[g]["price"]) <= top)
	rods.sort_custom(func(a, b): return int(Data.gear[a]["price"]) < int(Data.gear[b]["price"]))
	return rods


static func use_rod(id: String) -> void:
	if not id in rods_owned(Game.state):
		return
	var gear: Dictionary = Game.state["gear"]
	if not gear.has("rod_best"):
		gear["rod_best"] = gear.get("rod", id)
	gear["rod"] = id
	Game.changed.emit()


static func use_bait(id: String) -> void:
	if int(Game.state["bait"].get(id, 0)) <= 0:
		return
	Game.state["current_bait"] = id
	Game.changed.emit()


## Which of this place's line fish love a bait and which take it.
static func bait_tip(id: String, place: String) -> String:
	var loved := []
	var taken := []
	for f in _line_fish(place):
		var baits: Array = Data.fish[f]["baits"]
		if baits.find(id) == 0:
			loved.append(str(Data.fish[f]["name"]).to_lower())
		elif id in baits:
			taken.append(str(Data.fish[f]["name"]).to_lower())
	if loved.is_empty() and taken.is_empty():
		return "Nothing here takes %s." % str(Data.bait[id]["name"]).to_lower()
	var parts := []
	if not loved.is_empty():
		parts.append("Loved by " + _and(loved) + ".")
	if not taken.is_empty():
		parts.append(("Also taken by " if not loved.is_empty() else "Taken by ") + _and(taken) + ".")
	return " ".join(parts)


## The sizes of fish a rod suits and some of them here.
static func rod_tip(id: String, place: String) -> String:
	var best: Array = Data.gear[id].get("best", [0, 1000])
	var lo := float(best[0])
	var hi := float(best[1])
	var kind := "small fish" if hi <= 3.0 else ("middling fish" if hi <= 8.0 else ("big fish" if hi <= 30.0 else "the biggest fish"))
	var suits := []
	for f in _line_fish(place):
		var size: Array = Data.fish[f]["pounds"]
		var typical := (float(size[0]) + float(size[1])) / 2.0
		if typical >= lo and typical <= hi:
			suits.append(str(Data.fish[f]["name"]).to_lower())
	var range_text := ("up to %d lb" % int(hi)) if lo <= 0.0 else ("%s lb and over" % _lb(lo) if hi >= 1000.0 else "%s to %d lb" % [_lb(lo), int(hi)])
	var text := "Best for %s, %s" % [kind, range_text]
	text += (", such as %s." % _and(suits.slice(0, 4))) if not suits.is_empty() else "."
	return text + " Smaller fish are shy of a rod too heavy for them, and bigger ones fight harder."


static func _line_fish(place: String) -> Array:
	var out := []
	for f in Data.fish:
		if place in Data.fish[f]["places"] and "line" in Data.fish[f]["methods"] and not Data.fish[f]["legend"]:
			out.append(f)
	return out


static func _and(names: Array) -> String:
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + str(names[-1])


static func _lb(v: float) -> String:
	return str(int(v)) if v == floorf(v) else str(v)


## Godot's tooltips never wrap, so the tip is broken into short lines by hand.
static func _tip(row: Control, text: String) -> void:
	text = wrapped(text, 46)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.tooltip_text = text
	for c in row.get_children():
		if c is Control:
			c.tooltip_text = text
			if c is Label:
				c.mouse_filter = Control.MOUSE_FILTER_PASS


static func wrapped(text: String, width: int) -> String:
	var lines := []
	var line := ""
	for word in text.split(" "):
		if line != "" and line.length() + 1 + word.length() > width:
			lines.append(line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	lines.append(line)
	return "
".join(lines)
