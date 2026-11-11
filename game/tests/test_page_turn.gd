extends "res://tests/test_case.gd"
## The logbook's turning leaf: it starts flat on the page it turns, lands flat on the other, rises over the gutter
## between, and never jumps from one frame to the next.


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
