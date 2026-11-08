class_name TacklePanel
## The tackle: the bait on the hook and the rod in his hands, chosen from what he has, each with a tip naming the fish
## here it suits. A rod suits fish of a range of sizes: smaller fish are shy of it, bigger ones fight harder on it.


const TILE := Vector2(36, 36)


## Opens the tackle, just above `under` when given, such as the line's picture on the boat's bar.
static func open(under: Control = null) -> void:
	var list := Ui.window("Tackle", 220, 150)
	var place := str(Game.state.get("place", "harbour"))
	Ui.label(list, "BAIT ON THE HOOK", "Heading")
	var baits := _grid(list)
	for id in Data.bait:
		var count := int(Game.state["bait"].get(id, 0))
		if count <= 0:
			continue
		var bait_id: String = id
		var on: bool = str(Game.state.get("current_bait", "")) == id
		Ui.tile(baits, ItemArt.of(id), "x%d" % count, "%s, %d left. %s" % [Data.bait[id]["name"], count, bait_tip(id, place)], func():
			use_bait(bait_id)
			open(under), true, on, TILE)
	Ui.label(list, "ROD", "Heading")
	var rods := _grid(list)
	for id in rods_owned(Game.state):
		var rod_id: String = id
		var held: bool = str(Game.state["gear"].get("rod", "")) == id
		Ui.tile(rods, ItemArt.of(id), "", "%s. %s" % [Data.gear[id]["name"], rod_tip(id, place)], func():
			use_rod(rod_id)
			open(under), true, held, TILE)
	var hint := Ui.label(list, "Hold the pointer over one to see which fish it suits.", "MutedLabel")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 180
	if is_instance_valid(under):
		_hang_above(Nav.ui.get_node("Window"), under)


## Moves a window to sit just above a control, kept inside the view.
static func _hang_above(window: Control, under: Control) -> void:
	var at := under.get_global_rect()
	var size := Vector2(window.offset_right - window.offset_left, window.offset_bottom - window.offset_top).max(window.get_combined_minimum_size())
	window.set_anchors_preset(Control.PRESET_TOP_LEFT)
	window.grow_horizontal = Control.GROW_DIRECTION_END
	window.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var x := clampf(at.position.x, 4.0, Nav.view().x - size.x - 4.0)
	var y := maxf(4.0, at.position.y - size.y - 2.0)
	window.offset_left = x
	window.offset_top = y
	window.offset_right = x + size.x
	window.offset_bottom = y + size.y


static func _grid(list: Control) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 2)
	g.add_theme_constant_override("v_separation", 2)
	list.add_child(g)
	return g


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
