extends "res://tests/test_case.gd"


func _built(p: Dictionary) -> ParallaxLayers:
	var layers := ParallaxLayers.new()
	Nav.port.add_child(layers)
	layers.build(p["layers"])
	return layers


func _land(p: Dictionary) -> Array:
	var factors: Array = p["layers"].filter(func(l): return l.has("band")).map(func(l): return l["factor"])
	return p["layers"].filter(func(l): return l.has("file") and l.has("at") and factors.has(l.get("factor")))


func test_every_row_of_land_is_mirrored_in_its_band() -> void:
	for p in Data.places.values():
		var layers := _built(p)
		var rows := _land(p)
		check(rows.size() >= 2 and layers.reflections().size() == rows.size(), p["id"] + ": each row of land over a band has a reflection, and nothing else does")
		for r in layers.reflections():
			var land: Sprite2D = _land_of(layers, r)
			var glints: Node = layers.get_children().filter(func(n): return n is ParallaxLayers.Glints and n.get_index() > r.get_index())[0]
			check(r.z_index == glints.z_index and r.z_index < land.z_index, p["id"] + ": a reflection lies on its band under the glints, and under the land")
			check(r.material.get_shader_parameter("sea") is Color, p["id"] + ": tinted toward its band's sea")
		layers.free()


func _land_of(layers: ParallaxLayers, r: Sprite2D) -> Sprite2D:
	return layers.get_children().filter(func(n): return n is Sprite2D and n.texture == r.texture and n != r)[0]


func test_a_reflection_slides_with_its_own_land() -> void:
	var p: Dictionary = Data.places["harbour"]
	var layers := _built(p)
	layers.place(Vector2(700, -160))
	for r in layers.reflections():
		var land := _land_of(layers, r)
		check(r.position.x == land.position.x, "the reflection keeps under its land as the camera moves")
		check(r.position.y == land.position.y + r.texture.get_height() - ParallaxLayers.SHORE_SCAN, "and starts at its shore")
	layers.free()


func test_rain_breaks_up_the_reflections() -> void:
	var layers := _built(Data.places["lucrine"])
	layers.rough = 1.8
	check(layers.reflections().all(func(r): return r.material.get_shader_parameter("rough") == 1.8), "rain ripples every reflection")
	layers.free()


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
