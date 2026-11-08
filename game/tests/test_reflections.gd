extends "res://tests/test_case.gd"


func _built(p: Dictionary) -> ParallaxLayers:
	var layers := ParallaxLayers.new()
	Nav.port.add_child(layers)
	layers.build(p["layers"])
	return layers


func _land(p: Dictionary) -> Array:
	var factors: Array = p["layers"].filter(func(l): return l.has("band")).map(func(l): return l["factor"])
	return p["layers"].filter(func(l): return l.has("file") and l.has("at") and factors.has(l.get("factor")))


func test_every_row_of_land_stands_in_its_band() -> void:
	for p in Data.places.values():
		var layers := _built(p)
		var rows := _land(p)
		check(rows.size() >= 2 and layers.reflections().size() == rows.size(), p["id"] + ": each row of land over a band has the sea below it, and nothing else does")
		for land in layers.reflections():
			var sea = land.material.get_shader_parameter("sea")
			var band: Array = layers.bands().filter(func(b): return b.material.get_shader_parameter("sea") == sea)
			check(band.size() == 1 and land.z_index > band[0].z_index, p["id"] + ": a row of land and the sea it stands in are drawn over its band, tinted toward it")
		layers.free()


func test_the_sea_under_the_land_reaches_down_to_the_nearer_water() -> void:
	for p in Data.places.values():
		var layers := _built(p)
		var bands: Array = p["layers"].filter(func(l): return l.has("band"))
		var rows := _land(p)
		for k in rows.size():
			var top: float = bands.filter(func(b): return b["factor"] == rows[k]["factor"])[0]["at"][1]
			var nearer: Array = bands.map(func(b): return float(b["at"][1])).filter(func(t): return t > top) + [-CoastCamera.HOME_Y]
			var until: float = nearer.min() - float(rows[k]["at"][1])
			var land: Sprite2D = layers.reflections()[k]
			check(land.material.get_shader_parameter("until") == until, "%s: %s's sea is covered by the next band down" % [p["id"], rows[k]["file"]])
			check(land.region_rect.size.y == maxf(land.texture.get_height(), until), "and the picture reaches on down that far")
		layers.free()


func test_a_reflection_slides_with_its_own_land() -> void:
	var p: Dictionary = Data.places["harbour"]
	var layers := _built(p)
	layers.place(Vector2(700.5, -160))
	var rows := _land(p)
	for k in rows.size():
		var at := Vector2(rows[k]["at"][0], rows[k]["at"][1])
		var want: Vector2 = at - Vector2(700.5, 0) * Vector2(rows[k]["factor"][0], rows[k]["factor"][1])
		check(layers.reflections()[k].position.is_equal_approx(want), "the sea under the land is drawn with the land, sliding with it by fractions of a pixel")
	layers.free()


func test_rain_breaks_up_the_reflections() -> void:
	var layers := _built(Data.places["lucrine"])
	layers.rough = 1.8
	check(layers.reflections().all(func(r): return r.material.get_shader_parameter("rough") == 1.8), "rain ripples every reflection")
	check(layers.bands().all(func(b): return b.material.get_shader_parameter("rough") == 1.8), "and the open sea")
	layers.free()


func test_land_with_no_sea_painted_is_mirrored_from_its_foot() -> void:
	for file in ["places/harbour/cape.png", "places/harbour/mid.png", "places/lucrine/mid.png", "places/lucrine/near.png", "places/capri/near.png"]:
		var tex: Texture2D = load("res://assets/art/" + file)
		var img := tex.get_image()
		var lines := ParallaxLayers.waterlines(tex)
		var h := img.get_height()
		var wrong := range(img.get_width()).filter(func(x):
			var foot := -1
			for y in range(h - 1, -1, -1):
				if img.get_pixel(x, y).a > 0.5:
					foot = y + 1
					break
			return foot >= h - ParallaxLayers.SHORE_SCAN and lines[x] != foot)
		check(wrong.is_empty(), "%s is mirrored about the foot of its land in every column" % file)
		var empty := range(img.get_width()).filter(func(x): return range(h).all(func(y): return img.get_pixel(x, y).a == 0.0))
		check(empty.all(func(x): return lines[x] == -1.0), "and where there is no land there is nothing to mirror")


func test_no_picture_is_mirrored_from_far_above_its_bottom() -> void:
	for p in Data.places.values():
		for l in _land(p):
			var tex: Texture2D = load("res://assets/art/" + str(l["file"]))
			var h := tex.get_height()
			var lines := ParallaxLayers.waterlines(tex)
			check(Array(lines).all(func(y): return y == -1.0 or (y >= h - ParallaxLayers.SHORE_SCAN and y <= h)),
				"%s: %s is turned over only about rows near the water" % [p["id"], l["file"]])


## The longest stretch of a picture's bottom where land meets the water along one row, leaving out painted sea that fades into the band.
func _straightest(img: Image) -> int:
	var w := img.get_width()
	var h := img.get_height()
	var best := 1
	var run := 1
	var last := -1
	for x in w:
		var bottom := -1
		for y in range(h - 1, maxi(-1, h - 21), -1):
			if img.get_pixel(x, y).a > 0.5:
				bottom = y
				break
		var faded := bottom >= 0 and bottom < h - 1 and img.get_pixel(x, bottom + 1).a > 0.03
		if bottom >= 0 and not faded and bottom == last:
			run += 1
			best = maxi(best, run)
		else:
			run = 1
		last = bottom if not faded else -1
	return best


func test_no_shore_runs_ruler_straight() -> void:
	for p in Data.places.values():
		for l in _land(p):
			var img: Image = (load("res://assets/art/" + str(l["file"])) as Texture2D).get_image()
			img.decompress()
			check(_straightest(img) < 100, "%s: %s meets the water with rocks, coves and beaches, never along a ruler" % [p["id"], l["file"]])
