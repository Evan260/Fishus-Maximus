extends "res://tests/test_case.gd"


func _coast(place: String, hour: float, weather := "clear") -> Node:
	Game.new_game("Test", "mutt")
	Game.state["weather"] = weather
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": place})
	s.hour = hour
	s.weather = weather
	s.relayout()
	return s


func _close(s: Node) -> void:
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func _average(path: String) -> Color:
	var img := (load(path) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var sum := Vector3.ZERO
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				sum += Vector3(c.r, c.g, c.b)
				n += 1
	sum /= maxf(1.0, n)
	return Color(sum.x, sum.y, sum.z)


## How far a colour is from grey, whatever its brightness.
func _chroma(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))


func _shaded(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


func test_the_water_stays_a_muted_sea() -> void:
	for p in Data.places.values():
		var depth := float(p["depth"])
		var last := 2.0
		for below in [4.0, depth * 0.3, depth * 0.6, depth]:
			var painted := WaterView.water_at(below, depth)
			var c := Murk.colour(painted, below, depth)
			check(c.h > 0.42 and c.h < 0.6, "%s: %d pixels down the water is still a blue-green sea" % [p["id"], below])
			check(c.s < painted.s and c.s > painted.s * 0.6, "%s: %d pixels down it keeps most of its colour, a little muted" % [p["id"], below])
			check(c.get_luminance() < last, "%s: %d pixels down it is darker than above" % [p["id"], below])
			last = c.get_luminance()


func test_deeper_things_are_darker() -> void:
	var depth := 300.0
	for c: Color in [Color("#c0c8cc"), Color("#7a6a3a"), Color("#d23a2a")]:
		var high := Murk.colour(c, 10.0, depth)
		var mid := Murk.colour(c, 150.0, depth)
		var low := Murk.colour(c, 290.0, depth)
		check(high.get_luminance() > mid.get_luminance() and mid.get_luminance() > low.get_luminance(), "%s darkens with depth" % c.to_html(false))


func test_sea_plants_and_pieces_are_dim_shapes_in_the_seas_colour() -> void:
	for p in Data.places.values():
		var seen := {}
		for l in p["layers"]:
			if not l.has("world") or l.get("through", false) or seen.has(l["file"]):
				continue
			seen[l["file"]] = true
			var painted := _average("res://assets/art/" + str(l["file"]))
			var drawn := Murk.drain(painted * Murk.shade_for(l), Murk.keep_for(l))
			check(_chroma(drawn) <= _chroma(painted) * 0.35, "%s: %s keeps little of its own colour" % [p["id"], l["file"]])
			check(drawn.get_luminance() < painted.get_luminance(), "%s: %s is dim" % [p["id"], l["file"]])
			var below := float(l["world"][1]) + 20.0
			var on_screen := Murk.colour(drawn, below, float(p["depth"]))
			var water := Murk.colour(WaterView.water_at(below, float(p["depth"])), below, float(p["depth"]))
			check(on_screen.s < 0.12 or absf(on_screen.h - water.h) < 0.08, "%s: %s shows the sea's colour rather than its own" % [p["id"], l["file"]])


func test_fish_keep_more_colour_than_plants_and_stand_out() -> void:
	var golden := _average("res://assets/art/fish/golden_mullet.png")
	check(_chroma(Murk.drain(golden, Murk.FISH_KEEP)) > _chroma(Murk.drain(golden, Murk.PLANT_KEEP)) * 1.5, "a fish keeps more of its colour than a plant")
	var water := Murk.colour(WaterView.water_at(150.0, 300.0), 150.0, 300.0)
	var mullet := Murk.colour(Murk.drain(_average("res://assets/art/fish/grey_mullet.png"), Murk.FISH_KEEP), 150.0, 300.0)
	check(mullet.get_luminance() - water.get_luminance() > 0.1, "a silvery fish stands out from the water")


func test_the_murk_covers_what_is_under_the_water_but_not_the_lamp() -> void:
	var s := _coast("harbour", 12.0)
	var murk: Murk = s.get("_murk")
	check(murk != null, "the coast has the murk")
	check(murk.z_index == s.swimmers.z_index and murk.get_index() > s.get("_lit").get_index(), "it lies over the fish, drawn after them")
	check(murk.z_index < s.methods.trident_view.z_index, "and under the lamp's light, so the lamp still glows")
	check(murk.z_index < s.get("_line").z_index, "and under the line, so the line stays clear")
	check(murk.material.get_shader_parameter("light") == s.get("_lit").modulate, "it knows the hour's light already on what lies under it")
	check(is_equal_approx(murk.top(), -s.camera.cam.y), "it starts at the waterline, so the sea above it still mirrors the sky")
	_close(s)
	var night := _coast("harbour", 23.0)
	murk = night.get("_murk")
	check(murk.material.get_shader_parameter("light") == night.get("_lit").modulate, "at night it keeps the night's light")
	var land: UnderLand = night.get("_land")
	check(land.z_index == night.get("_water").z_index and land.get_index() > night.get("_lit").get_index(), "the land under the water shades the water drawn before it")
	_close(night)


func test_a_hooked_fish_is_murky_under_water_and_clear_in_the_air() -> void:
	var s := _coast("harbour", 12.0)
	var line: LineView = s.get("_line")
	var fish: Sprite2D = line.get("_fish")
	check(line.z_index + fish.z_index <= s.get("_murk").z_index, "a fish on the line under the water is seen through the murk like the rest")
	_close(s)


func test_the_seabed_is_smooth_sand() -> void:
	for p in Data.places.values():
		var img := (load("res://assets/art/" + str(p["floor"]["file"])) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		var bright := 0
		var coloured := 0
		var rim := 0.0
		var body := 0.0
		for x in img.get_width():
			var top := 0
			while top < img.get_height() and img.get_pixel(x, top).a < 0.5:
				top += 1
			rim += img.get_pixel(x, top).get_luminance()
			body += img.get_pixel(x, top + 8).get_luminance()
			for y in range(top, img.get_height()):
				var c := img.get_pixel(x, y)
				# Only the band of sand above where it darkens into the ground is seen as sand.
				if y < top + 16 and _chroma(c) > 0.08:
					coloured += 1
				# A pebble or a shell is a pixel much brighter than the sand just above and below it.
				if y > top + 2 and y < img.get_height() - 2:
					var around := (img.get_pixel(x, y - 2).get_luminance() + img.get_pixel(x, y + 2).get_luminance()) / 2.0
					if c.get_luminance() > around + 0.09:
						bright += 1
		check(bright == 0, "%s: no pebbles or shells stand out of the sand (%d)" % [p["id"], bright])
		check(coloured == 0, "%s: the sand is a soft grey (%d coloured pixels)" % [p["id"], coloured])
		check(rim > body, "%s: its top edge is lighter than the sand below" % p["id"])


func test_the_land_carries_on_under_the_water() -> void:
	for p in Data.places.values():
		var u := UnderLand.new(p)
		var bed := Seabed.new(p["seabed"])
		var reaches := false
		var open := false
		var gap := false
		var cam_max := Vector2(float(p["width"]) - 480.0, float(p["depth"]) + 40.0 - 270.0)
		for k in 9:
			var cam := Vector2(cam_max.x * k / 8.0, CoastCamera.HOME_Y)
			var deep := Vector2(cam.x, cam_max.y)
			for x in range(0, 480, 4):
				if u.top(UnderLand.FAR, x, cam) <= -cam.y + 1.0:
					reaches = true
				if u.top(UnderLand.FAR, x, cam) > 270.0 and u.top(UnderLand.NEAR, x, cam) > 270.0:
					open = true
				if u.top(UnderLand.NEAR, x, deep) > bed.depth_at(cam.x + x) - deep.y:
					gap = true
		check(reaches, p["id"] + ": the land behind reaches up to the surface somewhere")
		check(open, p["id"] + ": and somewhere the water is open from the surface to the bottom of the view")
		check(gap, p["id"] + ": the nearer bank leaves the sand open to the water somewhere")
		u.free()
	var water := WaterView.water_at(100.0, 300.0)
	var far := Murk.colour(_shaded(water, UnderLand.FAR_SHADE), 100.0, 300.0)
	var near := Murk.colour(_shaded(water, UnderLand.NEAR_SHADE), 100.0, 300.0)
	var clear := Murk.colour(water, 100.0, 300.0)
	check(far.get_luminance() < clear.get_luminance() and near.get_luminance() < far.get_luminance(), "the far slope is a darker shade of the water and the near one darker still")
	check(absf(far.h - clear.h) < 0.03 and absf(near.h - clear.h) < 0.03, "both in the water's own colour")


func test_no_old_reef_picture_stands_behind_the_water() -> void:
	for p in Data.places.values():
		check(p["layers"].all(func(l): return not str(l.get("file", "")).ends_with("deep_far.png")), p["id"] + ": the land under the water replaces the old reef picture")
