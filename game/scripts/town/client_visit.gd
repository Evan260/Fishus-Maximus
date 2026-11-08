class_name ClientVisit
## A client come to town with a request: the portrait, what they want, and the fish to give them.


static func open(client: String) -> void:
	var c: Dictionary = Data.clients[client]
	var step := Story.client_step(Game.state, client)
	var list := Ui.window(c["name"], 320, 190)
	var top := HBoxContainer.new()
	list.add_child(top)
	var pic := TextureRect.new()
	if ResourceLoader.exists(c["portrait"]):
		pic.texture = load(c["portrait"])
	pic.custom_minimum_size = Vector2(64, 64)
	pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	top.add_child(pic)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(words)
	var title := Ui.label(words, str(c["title"]).capitalize() if str(c["title"]).begins_with("the") else str(c["title"]), "MutedLabel")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if step.is_empty():
		Ui.label(words, "Nothing more today, thank you.").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	Ui.label(words, "\"%s\"" % Units.fill(step["text"], float(step.get("min_pounds", 0.0)))).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Ui.label(list, "Pays %s and +%d name." % [Ui.coins_text(int(step["reward"])), int(step["reputation"])], "MutedLabel")
	var at := Supply.find(Game.state, step)
	var what := ("Give the %s%s" % [str(Data.fish[step["fish"]]["name"]).to_lower(), " from your pond" if at.get("where", "") == "pond" else ""]) \
		if not at.is_empty() else "You have nothing that suits yet."
	Ui.row(list, what, "Give", func():
		var thanks: String = step["thanks"]
		if Story.deliver_from(Game.state, client, at):
			Game.changed.emit()
			Ui.close_window()
			Toast.say("%s: \"%s\"" % [c["name"], thanks]), not at.is_empty())
