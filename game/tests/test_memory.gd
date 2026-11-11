extends "res://tests/test_case.gd"
## Going from screen to screen and opening and closing every window, again and again, leaves nothing behind.

const ROUTE := [["coast", {"place": "harbour"}], ["town", {}], ["shore", {}], ["map", {}], ["coast", {"place": "misenum"}],
	["coast", {"place": "capri"}], ["title", {}], ["map", {}]]


func test_screens_and_windows_leave_nothing_behind() -> void:
	var tree := Nav.get_tree()
	var slot: int = Saves.slot
	Saves.slot = 0
	var motion := Settings.reduced_motion
	# Without motion the logbook's pages turn at once and the banners hang out without unfurling.
	Settings.reduced_motion = true
	Game.max_state()
	# The first two rounds fill the caches every later round reuses: fonts, pictures, outlines and slopes.
	for k in 2:
		await _round(tree)
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var resources := Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	for k in 3:
		await _round(tree)
	check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT) <= nodes, "three more rounds of screens leave no extra nodes (%d before, %d after)" % [nodes, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) <= orphans, "and no nodes outside the tree (%d before, %d after)" % [orphans, Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
	check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT) <= resources, "and no extra resources (%d before, %d after)" % [resources, Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)])
	check(Performance.get_monitor(Performance.OBJECT_COUNT) <= objects, "and no extra objects (%d before, %d after)" % [objects, Performance.get_monitor(Performance.OBJECT_COUNT)])
	Settings.reduced_motion = motion
	Saves.slot = slot
	# The later tests expect no screen to be running, as none is before this one.
	Nav.current.queue_free()
	Nav.current = null
	Nav.current_name = ""
	for layer in [Nav.world, Nav.ui, Nav.sky]:
		for c in layer.get_children():
			c.queue_free()
	await tree.process_frame
	Game.state = {}


## Every screen once, with its windows opened and closed on the way, ending on the bay map, where no fish swim.
func _round(tree: SceneTree) -> void:
	for step in ROUTE:
		# The title runs before a game is loaded, so the game is made up again after it.
		if Game.state.is_empty():
			Game.max_state()
		Nav.go(step[0], step[1])
		await _settle(tree)
		match step[0]:
			"coast":
				for open in [func() -> void: LogbookPanel.open(), func() -> void: LogbookPanel.open_achievements(),
						func() -> void: SettingsPanel.open(), func() -> void: TacklePanel.open(),
						func() -> void: HoldChoice.ask({"fish": "bream", "pounds": 2.4})]:
					await _open_and_close(tree, open)
				# A turn of the logbook's pages, which pictures them offscreen.
				LogbookPanel.open()
				await _settle(tree)
				LogbookPanel._bookmark_turn((LogbookPanel.section + 1) % LogbookPanel._sections().size())
				await _settle(tree)
				Ui.close_window()
				await _settle(tree)
			"town":
				for open in [ShopPanel.market, ShopPanel.netmaker, ShopPanel.boatwright, ShopPanel.goldsmith, BoardPanel.open,
						func() -> void: ClientVisit.open(str(Data.clients.keys()[0]))]:
					await _open_and_close(tree, open)
			"shore":
				for open in [func() -> void: PondPanel.open(Nav.current.pond), GarumPanel.open]:
					await _open_and_close(tree, open)
		if step[0] == "title":
			Game.state = {}
	# Time for timers, fades and banners started on the way to run out.
	await tree.create_timer(6.0).timeout


func _open_and_close(tree: SceneTree, open: Callable) -> void:
	open.call()
	await _settle(tree)
	check(Ui.window_open(), "a window opens on the %s" % Nav.current_name)
	while Ui.close_top():
		await tree.process_frame
	await _settle(tree)


## Waits for the screen to finish fading in and for whatever it freed to go.
func _settle(tree: SceneTree) -> void:
	await tree.process_frame
	while Nav._busy:
		await tree.process_frame
	for k in 3:
		await tree.process_frame
