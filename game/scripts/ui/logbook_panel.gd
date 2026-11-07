class_name LogbookPanel
## The logbook: a page for every kind of fish, with its picture and record once caught, and for a legend its clue
## until it is caught.

static var page := 0


static func open(at := -1) -> void:
	var kinds := Data.fish.keys()
	if at >= 0:
		page = at
	page = posmod(page, kinds.size())
	var id: String = kinds[page]
	var f: Dictionary = Data.fish[id]
	var entry: Dictionary = Game.state["logbook"].get(id, {})
	var caught := not entry.is_empty()
	var list := Ui.window("Logbook  %d of %d" % [Game.state["logbook"].size(), kinds.size()], 300, 200)
	var nav := HBoxContainer.new()
	list.add_child(nav)
	Ui.button(nav, "<", func():
		Audio.play("page_turn")
		open(page - 1))
	var name := Ui.label(nav, (f["name"] if caught or not f["legend"] else "A legend") + ("" if caught else "  (not yet caught)"), "Heading")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.button(nav, ">", func():
		Audio.play("page_turn")
		open(page + 1))
	var pic := TextureRect.new()
	var path := "res://assets/art/fish/%s.png" % id
	if ResourceLoader.exists(path):
		pic.texture = load(path)
	pic.custom_minimum_size = Vector2(120, 56)
	pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	if not caught:
		pic.modulate = Color(0.1, 0.12, 0.15, 0.85)
	list.add_child(pic)
	var places := ", ".join(f["places"].map(func(p): return str(Data.places[p]["name"]).to_lower()))
	if caught:
		Ui.label(list, "Caught %d. Best: %s lb, %s." % [int(entry["count"]), CatchCard.pounds_text(float(entry["best"])), Catalog.grade(id, float(entry["best"]))])
		Ui.label(list, "Found in %s, on %s." % [places, ", ".join(f["baits"].map(func(b): return str(Data.bait[b]["name"]).to_lower()))], "MutedLabel").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif f["legend"]:
		Ui.label(list, "\"%s\"" % Legends.clue(id), "MutedLabel").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		Ui.label(list, "Found in %s." % places, "MutedLabel").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
