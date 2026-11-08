extends "res://tests/test_case.gd"
## Where things stand in the town street: no post on the right of the hall, the goldsmith a stall along the wall like
## the netmaker and the boatwright with the stone pillar whole beside it, and the harbour board at the far left, turned
## to face the street in front of the hall's left post, with the townsfolk turning back before it.

## The hall's left post, its first column and the row its foot stands on, and the stone pillar's lit left side.
const LEFT_POST := Vector2i(46, 217)
const PILLAR_X := 447


func _open() -> Node:
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/town/town_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({})
	return s


func _close(s: Node) -> void:
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func _pixel(s: Node, street: Image, x: int, y: int) -> Color:
	return street.get_pixel(x + int(s.margin.x), y + int(s.margin.y))


## The mean luminance of a box of the street, given in the scene's own pixels.
func _light(s: Node, street: Image, box: Rect2i) -> float:
	var sum := 0.0
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			sum += _pixel(s, street, x, y).get_luminance()
	return sum / float(box.get_area())


## Whether a point of the scene is on a building's own pixels.
func _on(s: Node, id: String, p: Vector2i) -> bool:
	var img: Image = s._masks[id]["image"]
	var q: Vector2i = p - Vector2i(s._masks[id]["at"])
	return q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height() and img.get_pixelv(q).a > 0.5


func test_no_post_stands_on_the_right_of_the_hall() -> void:
	var s := _open()
	var street: Image = s._street.texture.get_image()
	var darkest := 0
	var at := 0
	for x in range(s._masks["boatwright"]["rect"].end.x, PILLAR_X):
		var dark := 0
		for y in range(50, 227):
			var c := _pixel(s, street, x, y)
			if not _on(s, "goldsmith", Vector2i(x, y)) and c.a > 0.5 and c.get_luminance() < 0.3:
				dark += 1
		if dark > darkest:
			darkest = dark
			at = x
	check(darkest < 100, "no dark post comes down from the beam between the boatwright and the pillar, the darkest column, %d, dark on %d of 177 rows" % [at, darkest])
	var open := 0
	for x in range(s._masks["boatwright"]["rect"].end.x, PILLAR_X):
		for y in range(98, 236):
			if _pixel(s, street, x, y).a < 0.5:
				open += 1
	check(open == 0, "and the wall and paving there are whole, %d pixels open to the sky" % open)
	_close(s)


func test_the_goldsmith_is_a_stall_along_the_wall() -> void:
	var s := _open()
	var gold: Rect2 = s._masks["goldsmith"]["rect"]
	var boat: Rect2 = s._masks["boatwright"]["rect"]
	for id in ["netmaker", "boatwright"]:
		var foot: float = s._masks[id]["rect"].end.y
		check(absf(gold.end.y - foot) <= 6.0, "the goldsmith stands against the wall like the %s, its foot at %.0f against %.0f" % [id, gold.end.y, foot])
	check(gold.position.y >= 122.0, "under the wall's coping like the stalls beside it, its roof's peak at %.0f" % gold.position.y)
	check(gold.position.x > boat.end.x, "past the boatwright, from %.0f to the boatwright's %.0f" % [gold.position.x, boat.end.x])
	check(gold.end.x <= PILLAR_X, "and short of the stone pillar, ending at %.0f" % gold.end.x)
	_close(s)


func test_the_stone_pillar_stands_whole_beside_the_goldsmith() -> void:
	var s := _open()
	var street: Image = s._street.texture.get_image()
	var open := 0
	for y in range(0, 229):
		if _pixel(s, street, PILLAR_X + 13, y).a < 0.5:
			open += 1
	check(open == 0, "the pillar runs from the ceiling to the paving, open on %d rows" % open)
	var high := _light(s, street, Rect2i(PILLAR_X + 3, 30, 40, 60))
	var low := _light(s, street, Rect2i(PILLAR_X + 3, 150, 40, 70))
	check(absf(high - low) < 0.05, "its stone is the same at its foot as up high, nothing standing in front of it, %.2f against %.2f" % [low, high])
	var gold: Rect2 = s._masks["goldsmith"]["rect"]
	var behind := 0
	for y in range(int(gold.position.y), int(gold.end.y)):
		for x in range(int(gold.position.x), int(gold.end.x)):
			if _on(s, "goldsmith", Vector2i(x, y)) and x >= PILLAR_X:
				behind += 1
	check(behind == 0, "and no part of the goldsmith stands over it, %d pixels do" % behind)
	_close(s)


func test_the_goldsmith_stands_on_the_streets_own_paving() -> void:
	var s := _open()
	var street: Image = s._street.texture.get_image()
	var gold: Rect2 = s._masks["goldsmith"]["rect"]
	var strip := _light(s, street, Rect2i(300, 215, 50, 8))
	var before := _light(s, street, Rect2i(int(gold.position.x) + 2, 215, int(gold.size.x) - 4, 8))
	check(before > 0.5 and absf(before - strip) < 0.2,
		"the sunlit paving along the wall runs on in front of it, %.2f against %.2f" % [before, strip])
	var front := Color(0, 0, 0, 0)
	var below := Color(0, 0, 0, 0)
	for x in range(int(gold.position.x) + 2, int(gold.end.x) - 2):
		for y in range(223, 229):
			front += _pixel(s, street, x, y) / 6.0
		for y in range(232, 242):
			below += _pixel(s, street, x, y) / 10.0
	front /= gold.size.x - 4.0
	below /= gold.size.x - 4.0
	check(maxf(maxf(absf(front.r - below.r), absf(front.g - below.g)), absf(front.b - below.b)) < 0.04,
		"and the paving in front of it has the colour of the paving round it, %s against %s" % [front, below])
	_close(s)


func test_the_board_stands_at_the_far_left_in_front_of_the_left_post() -> void:
	var s := _open()
	var board: Rect2 = s._masks["board"]["rect"]
	var market: Rect2 = s._masks["market"]["rect"]
	check(board.position.x < LEFT_POST.x and board.end.x <= market.position.x,
		"the board stands at the far left, from %.0f to %.0f, short of the fish market at %.0f" % [board.position.x, board.end.x, market.position.x])
	check(board.end.y > LEFT_POST.y + 4, "on the paving in front of the post, its foot at %.0f and the post's at %d" % [board.end.y, LEFT_POST.y])
	var covered := 0
	for y in range(200, LEFT_POST.y):
		for x in range(LEFT_POST.x, LEFT_POST.x + 14):
			if _on(s, "board", Vector2i(x, y)):
				covered += 1
	check(covered * 2 > 14 * (LEFT_POST.y - 200), "and in front of the post's foot, hiding %d of its %d pixels" % [covered, 14 * (LEFT_POST.y - 200)])
	var feet := _feet(s)
	check(feet[0].y > feet[1].y + 2, "turned to face the street, its near leg standing lower than its far one, %s against %s" % feet)
	check(not _on(s, "board", Vector2i(s.LAMPS[1])), "and the lantern on the left post shows above it")
	_close(s)


## Where the board's legs stand in the scene, the near one first: the lowest row of each half and its middle.
func _feet(s: Node) -> Array:
	var img: Image = s._masks["board"]["image"]
	var feet := []
	for half in 2:
		var lowest := Vector2(0, -1)
		for y in img.get_height():
			var xs := range(img.get_width() / 2 * half, img.get_width() / 2 * (half + 1)).filter(func(x): return img.get_pixel(x, y).a > 0.5)
			if not xs.is_empty():
				lowest = Vector2(xs.reduce(func(a, b): return a + b, 0) / float(xs.size()), y)
		feet.append(lowest + s._masks["board"]["at"])
	return feet


func test_the_board_casts_a_shadow_on_the_paving() -> void:
	var s := _open()
	var street: Image = s._street.texture.get_image()
	var feet := _feet(s)
	var shade := 0.0
	var paving := 0.0
	for x in range(int(feet[0].x) + 5, int(feet[1].x) - 3):
		var ground := roundi(lerpf(feet[0].y, feet[1].y, (x - feet[0].x) / (feet[1].x - feet[0].x)))
		shade += _pixel(s, street, x, ground).get_luminance()
		paving += _pixel(s, street, x, ground + 8).get_luminance()
	check(shade < 0.85 * paving, "the paving along the line between its feet lies in its shadow, %.1f against %.1f" % [shade, paving])
	_close(s)


func test_the_townsfolk_turn_back_before_the_board() -> void:
	var s := _open()
	var board: Rect2 = s._masks["board"]["rect"]
	var nearest := INF
	for f in s._folk:
		f["x"] = s.WALK.x + 4.0
		f["dir"] = -1.0
		f["pause"] = 0.0
		for i in 40:
			s._process(0.1)
			var sprite: Sprite2D = f["sprite"]
			nearest = minf(nearest, sprite.position.x + s._foot(sprite.texture, sprite.flip_h).x - 6.0)
	check(nearest > board.end.x, "no one walks in front of the board, the nearest coming to %.0f and the board ending at %.0f" % [nearest, board.end.x])
	for x in s.CLIENT_SPOTS:
		check(x - 12.0 > board.end.x, "nor does a client stand there, at %.0f" % x)
	_close(s)
