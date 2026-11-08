extends "res://tests/test_case.gd"
## The gold outline round each building in the town: one unbroken line hugging the building's whole shape, the mouse
## finding the building wherever that line encloses it, and the goldsmith standing whole on the street's own paving.

const AROUND := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
const SIDES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


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


func _solid(img: Image, p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() and img.get_pixelv(p).a > 0.5


## The pixels of a building's picture and a pixel round it, as a grid to walk over.
func _grid(img: Image) -> Rect2i:
	return Rect2i(-1, -1, img.get_width() + 2, img.get_height() + 2)


## How many pieces the pixels for which `inside` holds fall into, joined across their sides.
func _pieces(grid: Rect2i, inside: Callable) -> int:
	var seen := {}
	var pieces := 0
	for y in range(grid.position.y, grid.end.y):
		for x in range(grid.position.x, grid.end.x):
			var start := Vector2i(x, y)
			if seen.has(start) or not inside.call(start):
				continue
			pieces += 1
			seen[start] = true
			var todo: Array[Vector2i] = [start]
			while not todo.is_empty():
				var p: Vector2i = todo.pop_back()
				for d in SIDES:
					var q: Vector2i = p + d
					if grid.has_point(q) and not seen.has(q) and inside.call(q):
						seen[q] = true
						todo.append(q)
	return pieces


func test_each_building_is_one_solid_shape() -> void:
	var s := _open()
	for id in s.BUILDINGS:
		var img: Image = s._masks[id]["image"]
		var grid := _grid(img)
		check(_pieces(grid, func(p): return _solid(img, p)) == 1, "%s is one piece, with no specks" % id)
		check(_pieces(grid, func(p): return not _solid(img, p)) == 1, "%s has no holes" % id)
		var gaps := 0
		for y in img.get_height():
			for x in img.get_width():
				var p := Vector2i(x, y)
				if not _solid(img, p) and ((_solid(img, p + Vector2i(1, 0)) and _solid(img, p - Vector2i(1, 0)))
						or (_solid(img, p + Vector2i(0, 1)) and _solid(img, p - Vector2i(0, 1)))):
					gaps += 1
		check(gaps == 0, "%s has no gap or notch a pixel wide, %d found" % [id, gaps])
	_close(s)


func test_each_outline_is_one_unbroken_line_round_its_building() -> void:
	var s := _open()
	for id in s.BUILDINGS:
		var img: Image = s._masks[id]["image"]
		var at: Vector2 = s._masks[id]["at"]
		var line := {}
		for p in s._outlines[id]:
			line[Vector2i(p - at)] = true
		var stray := 0
		for p in line:
			if _solid(img, p) or not AROUND.any(func(d): return _solid(img, p + d)):
				stray += 1
		check(stray == 0, "%s: every pixel of its outline lies just outside it, %d do not" % [id, stray])
		var missing := 0
		var grid := _grid(img)
		for y in range(grid.position.y, grid.end.y):
			for x in range(grid.position.x, grid.end.x):
				var p := Vector2i(x, y)
				if not _solid(img, p) and AROUND.any(func(d): return _solid(img, p + d)) and not line.has(p):
					missing += 1
		check(missing == 0, "%s: its outline runs all the way round, with %d gaps" % [id, missing])
		check(_pieces(grid, func(p): return line.has(p)) == 1, "%s: and is one unbroken line" % id)
	_close(s)


func test_the_mouse_finds_a_building_wherever_its_outline_encloses_it() -> void:
	var s := _open()
	for id in s.BUILDINGS:
		var img: Image = s._masks[id]["image"]
		var at: Vector2 = s._masks[id]["at"]
		var lost := 0
		for y in img.get_height():
			for x in img.get_width():
				if _solid(img, Vector2i(x, y)) and s._building_at(at + Vector2(x, y) + Vector2(0.5, 0.5)) != id:
					lost += 1
		check(lost == 0, "%s: found at every pixel inside its outline, missed at %d" % [id, lost])
		var beyond := 0
		for p in s._outlines[id]:
			if s._building_at(p + Vector2(0.5, 0.5)) == id:
				beyond += 1
		check(beyond == 0, "%s: and not on the outline itself, found at %d" % [id, beyond])
	_close(s)


func test_each_building_is_cut_from_the_street_as_it_is_painted() -> void:
	var s := _open()
	var street: Image = s._street.texture.get_image()
	for id in s.BUILDINGS:
		var img: Image = s._masks[id]["image"]
		var at := Vector2i(Vector2(s._masks[id]["at"]) + s.margin)
		var off := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.5 and not c.is_equal_approx(street.get_pixel(at.x + x, at.y + y)):
					off += 1
		check(off == 0, "%s: its cut-out is the street's own picture of it, %d pixels differ" % [id, off])
	_close(s)


## The mean colour of a box of the street, given in the scene's own pixels.
func _colour(street: Image, margin: Vector2, box: Rect2i) -> Color:
	var sum := Color(0, 0, 0, 0)
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			sum += street.get_pixel(x + int(margin.x), y + int(margin.y))
	return sum / float(box.get_area())


func test_the_goldsmith_stands_on_the_streets_own_paving() -> void:
	var s := _open()
	var street: Image = s._street.texture.get_image()
	var band := _colour(street, s.margin, Rect2i(340, 211, 30, 12)).get_luminance()
	var by_it := _colour(street, s.margin, Rect2i(394, 211, 16, 12)).get_luminance()
	check(absf(by_it - band) < 0.15, "the sunlit paving along the wall runs up to the goldsmith, %.2f against %.2f" % [by_it, band])
	var front := _colour(street, s.margin, Rect2i(410, 223, 60, 6))
	var below := _colour(street, s.margin, Rect2i(410, 232, 60, 10))
	check(maxf(maxf(absf(front.r - below.r), absf(front.g - below.g)), absf(front.b - below.b)) < 0.04,
		"and the paving in front of it has the colour of the paving round it, %s against %s" % [front, below])
	var sky := 0
	for y in range(100, 110):
		for x in range(428, 448):
			if street.get_pixel(x + int(s.margin.x), y + int(s.margin.y)).a < 0.5:
				sky += 1
	check(sky == 0, "its roof is whole, with no sky showing beside its peak, %d pixels open" % sky)
	_close(s)
