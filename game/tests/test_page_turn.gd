extends "res://tests/test_case.gd"
## The logbook's turning leaf: it starts flat on the page it turns, lands flat on the other, rises over the gutter
## between, and never jumps from one frame to the next; turning the logbook's pages leaves nothing behind.


func _leaf(direction: int) -> PageTurn:
	var turn := PageTurn.new()
	turn.direction = direction
	turn.left_page = Rect2(3, 0, 186, 210)
	turn.right_page = Rect2(193, 0, 186, 210)
	return turn


func test_the_leaf_lies_flat_at_both_ends_of_its_turn() -> void:
	for direction in [1, -1]:
		var turn := _leaf(direction)
		var turning := turn.right_page if direction > 0 else turn.left_page
		var landing := turn.left_page if direction > 0 else turn.right_page
		var start: Array = turn.leaf(0.0)
		var end: Array = turn.leaf(1.0)
		var inner := turning.position.x if direction > 0 else turning.end.x
		var outer := turning.end.x if direction > 0 else turning.position.x
		check(absf(start[0].x - inner) < 0.01 and absf(start[-1].x - outer) < 0.5, "turning %d: it starts on its own page, from %.1f to %.1f" % [direction, start[0].x, start[-1].x])
		var land_inner := landing.end.x if direction > 0 else landing.position.x
		var land_outer := landing.position.x if direction > 0 else landing.end.x
		check(absf(end[0].x - land_inner) < 0.01 and absf(end[-1].x - land_outer) < 0.5, "and lands on the other, from %.1f to %.1f" % [end[0].x, end[-1].x])
		var middle: Array = turn.leaf(0.5)
		check(absf(middle[-1].x - middle[0].x) < turning.size.x * 0.6 and middle[-1].y > turning.size.x * 0.3, "half way over it stands up over the gutter")
		turn.free()


func test_the_leaf_moves_smoothly() -> void:
	var turn := _leaf(1)
	var last: Array = turn.leaf(0.0)
	var worst := 0.0
	for i in range(1, 61):
		var now: Array = turn.leaf(i / 60.0)
		for k in now.size():
			worst = maxf(worst, Vector2(now[k].x, now[k].y).distance_to(Vector2(last[k].x, last[k].y)))
		last = now
	check(worst < 20.0, "no point of the leaf jumps more than a little from one frame to the next, at most %.1f pixels" % worst)
	turn.free()


func test_turning_pages_leaves_nothing_behind() -> void:
	var tree := Nav.get_tree()
	var slot: int = Saves.slot
	Saves.slot = 0
	var motion := Settings.reduced_motion
	Settings.reduced_motion = false
	Game.max_state()
	LogbookPanel.open(0)
	# The first two rounds fill the caches every later round reuses: fonts, pictures and the pages' paper.
	for k in 2:
		await _turns(tree)
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var resources := Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	for k in 2:
		await _turns(tree)
	check(Nav.ui.find_children("*", "SubViewport", true, false).is_empty(), "every page's picture is freed once its leaf lands or is cut short")
	check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT) <= nodes, "turning more pages leaves no extra nodes (%d before, %d after)" % [nodes, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) <= orphans, "and no nodes outside the tree (%d before, %d after)" % [orphans, Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
	check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT) <= resources, "and no extra resources (%d before, %d after)" % [resources, Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)])
	check(Performance.get_monitor(Performance.OBJECT_COUNT) <= objects, "and no extra objects (%d before, %d after)" % [objects, Performance.get_monitor(Performance.OBJECT_COUNT)])
	Ui.close_window()
	await tree.process_frame
	Settings.reduced_motion = motion
	Saves.slot = slot


## Three pages turned to the end, then two cut short by closing the book, one before its new page is pictured.
func _turns(tree: SceneTree) -> void:
	for to in [1, 2, 0]:
		LogbookPanel._bookmark_turn(to)
		await _landed(tree)
	for wait in [0, 3]:
		LogbookPanel._bookmark_turn(1 - LogbookPanel.section % 2)
		for i in wait:
			await tree.process_frame
		Ui.close_window()
		await _landed(tree)
		check(not LogbookPanel._turning, "a book closed mid-turn can turn again")
		LogbookPanel.open(LogbookPanel.section)
		await tree.process_frame


func _landed(tree: SceneTree) -> void:
	while LogbookPanel._turning:
		await tree.process_frame
	for i in 3:
		await tree.process_frame
