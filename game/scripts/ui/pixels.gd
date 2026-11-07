class_name Pixels
## Shapes and pictures kept to whole game pixels in a port drawn at the window's resolution: lines, rings, discs and
## polygons step in game pixels on the grid of the point they start from, so they slide smoothly with what they belong
## to, and `look()` keeps a picture's pixels whole when it is scaled or turned.

const SHADER := preload("res://scripts/ui/pixels.gdshader")

static var _shrunk := {}


## A material for a Sprite2D drawn centred: its pixels stay whole at any size or turn, and with `wave` above zero its
## tail swings that many texels as `set_swim` beats it.
static func look(wave := 0.0, waves := 0.7) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("edge", 2.0)
	m.set_shader_parameter("wave", wave)
	m.set_shader_parameter("waves", waves)
	return m


static func set_swim(node: CanvasItem, phase: float, wave := -1.0) -> void:
	var m := node.material as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("swim", phase)
	if wave >= 0.0:
		m.set_shader_parameter("wave", wave)


## A picture shrunk to a share of its size at its own pixels, as the game showed it when it was drawn at 480 by 270.
static func shrunk(tex: Texture2D, share: float) -> Texture2D:
	var size := (tex.get_size() * share).round().max(Vector2.ONE)
	var key := [tex.get_rid(), size]
	if not _shrunk.has(key):
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		img.resize(int(size.x), int(size.y), Image.INTERPOLATE_NEAREST)
		_shrunk[key] = ImageTexture.create_from_image(img)
	return _shrunk[key]


## A line `width` game pixels thick from a to b, its first pixel's top left corner at a.
static func line(on: CanvasItem, a: Vector2, b: Vector2, colour: Color, width := 1) -> void:
	var d := (b - a).round()
	var n := int(maxf(absf(d.x), absf(d.y)))
	var across := 1 if absf(d.x) >= absf(d.y) else 0
	var start := 0
	for k in range(1, n + 2):
		if k <= n and _step(d, k, n)[across] == _step(d, start, n)[across]:
			continue
		# Each run of pixels in one row, or one column, is drawn as a single rectangle.
		var p := _step(d, start, n)
		var q := _step(d, k - 1, n)
		on.draw_rect(Rect2(a + p.min(q), (q - p).abs() + Vector2(width, width)), colour)
		start = k


static func _step(d: Vector2, k: int, n: int) -> Vector2:
	return Vector2.ZERO if n == 0 else (d * (float(k) / n)).round()


## A ring one game pixel wide round a centre on the corner between four pixels.
static func ring(on: CanvasItem, centre: Vector2, radius: float, colour: Color) -> void:
	var r := ceili(radius + 0.5)
	for y in range(-r, r):
		var outer := _half(radius + 0.5, y)
		if outer < 0:
			continue
		var inner := _half(radius - 0.5, y)
		if inner < 0:
			on.draw_rect(Rect2(centre + Vector2(-outer, y), Vector2(outer * 2, 1)), colour)
		else:
			on.draw_rect(Rect2(centre + Vector2(-outer, y), Vector2(outer - inner, 1)), colour)
			on.draw_rect(Rect2(centre + Vector2(inner, y), Vector2(outer - inner, 1)), colour)


## A filled disc round a centre on the corner between four pixels.
static func disc(on: CanvasItem, centre: Vector2, radius: float, colour: Color) -> void:
	var r := ceili(radius)
	for y in range(-r, r):
		var half := _half(radius, y)
		if half > 0:
			on.draw_rect(Rect2(centre + Vector2(-half, y), Vector2(half * 2, 1)), colour)


## How many pixels each side of the middle a row of a disc reaches, or -1 when the row misses it.
static func _half(radius: float, row: int) -> int:
	var y := row + 0.5
	if absf(y) > radius:
		return -1
	return int(floorf(sqrt(radius * radius - y * y) + 0.5))


## A filled polygon: each pixel on the grid of `grid`, or of its first point, is filled when its middle is inside.
static func polygon(on: CanvasItem, points: PackedVector2Array, colour: Color, grid := Vector2.INF) -> void:
	if not grid.is_finite():
		grid = points[0]
	var top := INF
	var bottom := -INF
	for p in points:
		top = minf(top, p.y - grid.y)
		bottom = maxf(bottom, p.y - grid.y)
	for y in range(floori(top), ceili(bottom)):
		var mid := y + 0.5
		var cuts: Array[float] = []
		for i in points.size():
			var a := points[i] - grid
			var b := points[(i + 1) % points.size()] - grid
			if (a.y <= mid) != (b.y <= mid):
				cuts.append(a.x + (mid - a.y) / (b.y - a.y) * (b.x - a.x))
		cuts.sort()
		for i in range(0, cuts.size() - 1, 2):
			var x0 := ceili(cuts[i] - 0.5)
			var x1 := floori(cuts[i + 1] - 0.5)
			if x1 >= x0:
				on.draw_rect(Rect2(grid + Vector2(x0, y), Vector2(x1 - x0 + 1, 1)), colour)
