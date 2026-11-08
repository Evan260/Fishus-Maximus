class_name UnderLand
extends Node2D
## The land carried on down under the water behind the fish, as two darker shades of the water itself. The far slope
## lies under the nearest row of land and slides along with it, so its hills and cliffs go on down below the water and
## fall away into the deep between them; the nearer bank, darker, lies behind the seabed in big mounds and shelves and
## rises to the surface where the water is shallow. Each fills down past the seabed, which covers its foot. Both keep
## to the water's depth as the camera goes down, so a slope reaching the surface always meets the waterline.

const SHADER := preload("res://scripts/coast/under_land.gdshader")
const FAR := 0
const NEAR := 1
## How much of the water's light each slope lets through: the far one nearer the water's own colour.
const FAR_SHADE := 0.8
const NEAR_SHADE := 0.64
## How many rows the far slope falls for each column away from the land above it, between its gentlest and steepest.
const FALL := Vector2(1.4, 3.0)
## Land lower than this share of the row's tallest stays under the surface, deeper the lower it is, by SINK rows a row.
const TALL := 0.8
const SINK := 2.2
## Columns over which a row's heights are taken together into the hills they belong to.
const HILL := 31
## How fast the nearer bank slides past, against the fish's water.
const NEAR_FACTOR := 0.78
## Where the bank stands against the seabed between its mounds: just below the sand, so open water runs down to it.
const BANK := -12.0
## Water shallower than this lifts the bank toward the surface.
const SHALLOW := 120.0
## Columns past the place's width, enough for the widest view the window or the desktop strip can show.
const SPARE := 1600

## Each slope's top, per column, in rows below the waterline.
var _tops: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array()]
var _factor: Array[float] = [0.55, NEAR_FACTOR]
var cam := Vector2(0, CoastCamera.HOME_Y)


func _init(place: Dictionary) -> void:
	_build_far(place)
	_build_near(place)
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("far_tops", _texture(_tops[FAR]))
	material.set_shader_parameter("near_tops", _texture(_tops[NEAR]))
	material.set_shader_parameter("far_factor", _factor[FAR])
	material.set_shader_parameter("near_factor", _factor[NEAR])
	material.set_shader_parameter("far_shade", FAR_SHADE)
	material.set_shader_parameter("near_shade", NEAR_SHADE)


## The screen row of a slope's top at a screen column, with the camera at cam; a large number where it lies deep.
func top(slope: int, x: float, at: Vector2) -> float:
	var tops := _tops[slope]
	return tops[clampi(floori(x + at.x * _factor[slope]), 0, tops.size() - 1)] - at.y


func place_at(at: Vector2) -> void:
	cam = at
	material.set_shader_parameter("cam", cam)
	queue_redraw()


func _draw() -> void:
	var view := Nav.view()
	var from := maxf(0.0, -cam.y)
	# The desktop strip shifts the canvas up to the waterline, so the slopes run to the bottom of what is on screen.
	var bottom := view.y - get_canvas_transform().origin.y
	if bottom > from:
		draw_rect(Rect2(0, from, view.x, bottom - from), Color.WHITE)


static func _texture(tops: PackedFloat32Array) -> ImageTexture:
	var img := Image.create(tops.size(), 1, false, Image.FORMAT_RF)
	for x in tops.size():
		img.set_pixel(x, 0, Color(tops[x], 0, 0))
	return ImageTexture.create_from_image(img)


## The far slope from the nearest row of land: under its tall hills and cliffs it reaches up to the surface, under
## lower land it lies deeper, and away from the land it falls steeply into the deep between.
func _build_far(place: Dictionary) -> void:
	var rows: Array = place.get("layers", []).filter(func(l): return l.has("file") and l.has("at") and l.has("factor"))
	var nearest := 0.0
	for l in rows:
		nearest = maxf(nearest, float(l["factor"][0]))
	rows = rows.filter(func(l): return float(l["factor"][0]) == nearest)
	if nearest > 0.0:
		_factor[FAR] = nearest
	var n := int(float(place["width"]) * _factor[FAR]) + SPARE
	var heights := PackedFloat32Array()
	heights.resize(n)
	heights.fill(-1.0)
	for l in rows:
		var path := ParallaxLayers.ART + str(l["file"])
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		var feet := ParallaxLayers.waterlines(tex)
		var w := img.get_width()
		for k in w * int(l.get("repeat", 1)):
			var x := k % w
			if l.get("mirror", false):
				x = w - 1 - x
			var c := int(l["at"][0]) + k
			if feet[x] < 0.0 or c < 0 or c >= n:
				continue
			var y := 0
			while y < img.get_height() and img.get_pixel(x, y).a <= 0.5:
				y += 1
			heights[c] = maxf(heights[c], feet[x] - y)
	var hills := _hills(heights)
	var tall := 0.0
	for h in hills:
		tall = maxf(tall, h)
	var rng := Seeds.rng(1, "under:far:" + str(place.get("id", "")))
	var fall := _wander(n, rng, 0.5, 40)
	var deep := PackedFloat32Array()
	deep.resize(n)
	for c in n:
		deep[c] = (tall * TALL - hills[c]) * SINK if heights[c] >= 0.0 else INF
	for c in range(1, n):
		deep[c] = minf(deep[c], deep[c - 1] + lerpf(FALL.x, FALL.y, fall[c] + 0.5))
	for c in range(n - 2, -1, -1):
		deep[c] = minf(deep[c], deep[c + 1] + lerpf(FALL.x, FALL.y, fall[c] + 0.5))
	var bumps := _wander(n, rng, 7.0, 23)
	var grain := _wander(n, rng, 2.0, 5)
	var tops := PackedFloat32Array()
	tops.resize(n)
	for c in n:
		# The outline wanders only once the slope is under the water, so where it meets the surface it meets it whole.
		var rough := roundf(bumps[c] + grain[c]) * clampf(deep[c] / 12.0, 0.0, 1.0)
		tops[c] = floorf(minf(4000.0, maxf(0.0, deep[c] + rough)))
	_tops[FAR] = tops


## A row's heights over its land taken together into hills: each column as tall as the tallest near it, then evened
## out, so a pine or a tower on a hill does not make a spike under the water.
static func _hills(heights: PackedFloat32Array) -> PackedFloat32Array:
	var n := heights.size()
	var r := HILL / 2
	var top := PackedFloat32Array()
	top.resize(n)
	for c in n:
		var m := 0.0
		for k in range(maxi(0, c - r), mini(n, c + r + 1)):
			m = maxf(m, heights[k])
		top[c] = m
	var out := PackedFloat32Array()
	out.resize(n)
	var sum := 0.0
	for k in mini(n, r):
		sum += top[k]
	for c in n:
		if c + r < n:
			sum += top[c + r]
		if c - r - 1 >= 0:
			sum -= top[c - r - 1]
		out[c] = sum / float(mini(n, c + r + 1) - maxi(0, c - r))
	return out


## The nearer bank behind the seabed: big mounds and flat-topped shelves standing on the sand, and the bank rising
## toward the surface over shallow water. Its column c lies behind the world's x when the camera is centred on it.
func _build_near(place: Dictionary) -> void:
	var f := NEAR_FACTOR
	var n := int(float(place["width"]) * f) + SPARE
	var bed := Seabed.new(place["seabed"])
	var rng := Seeds.rng(1, "under:near:" + str(place.get("id", "")))
	var mounds := PackedFloat32Array()
	mounds.resize(n)
	var c := rng.randi_range(-40, 60)
	while c < n:
		var w := rng.randf_range(70.0, 200.0)
		var h := rng.randf_range(22.0, 64.0)
		var flat := rng.randf() < 0.4
		for k in range(maxi(0, c), mini(n, int(c + w))):
			var u := (k - c) / w * 2.0 - 1.0
			var shape := (1.0 - u * u) if not flat else clampf((1.0 - absf(u)) * 3.0, 0.0, 1.0)
			mounds[k] = maxf(mounds[k], h * shape)
		c += int(w + rng.randf_range(60.0, 220.0))
	var bumps := _wander(n, rng, 4.0, 19)
	var grain := _wander(n, rng, 1.5, 5)
	var tops := PackedFloat32Array()
	tops.resize(n)
	for k in n:
		var wx := (k - Nav.SIZE.x / 2.0 * (1.0 - f)) / f
		var sand := bed.depth_at(wx)
		var lift := maxf(BANK + mounds[k], (SHALLOW - sand) * 1.3)
		tops[k] = floorf(maxf(0.0, sand - lift + roundf(bumps[k] + grain[k])))
	_tops[NEAR] = tops


## A gently wandering line, up to `amount` either way, turning every `step` columns: a slope's outline wanders so it
## reads as rock rather than a ruled line, and its steepness wanders so its cliffs and shelves vary.
static func _wander(n: int, rng: RandomNumberGenerator, amount: float, step: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var knots: Array = []
	for k in n / step + 2:
		knots.append(rng.randf_range(-amount, amount))
	for k in n:
		var t := float(k) / step
		var a: float = knots[int(t)]
		var b: float = knots[int(t) + 1]
		out[k] = lerpf(a, b, smoothstep(0.0, 1.0, t - floorf(t)))
	return out
