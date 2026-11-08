extends "res://tests/test_case.gd"
## The dark plants standing in front of the view, which break away in pixel blocks as the boat comes near.

const PIECE := {"file": "front/palm.png", "front": "bottom", "x": 900, "factor": [1.6, 1.3], "z": 5}


func _built(layers: Array) -> ParallaxLayers:
	var l := ParallaxLayers.new()
	Nav.port.add_child(l)
	l.build(layers)
	return l


## Runs the layers for some seconds with the boat at a place on the coast and the camera following it.
func _run(l: ParallaxLayers, boat_x: float, seconds: float, fight := false, cam_y := CoastCamera.HOME_Y) -> void:
	var cam := Vector2(boat_x + 52.0 - Nav.view().x / 2.0, cam_y)
	for i in int(seconds * 30.0):
		l.time += 1.0 / 30.0
		l.keep_clear([Rect2(boat_x - cam.x, 0.0, 105.0, Nav.view().y)], fight)
		l.place(cam)


func _progress(s: Sprite2D) -> float:
	return float(s.material.get_shader_parameter("progress"))


func test_a_piece_breaks_away_as_the_boat_comes_near_and_comes_back_as_it_leaves() -> void:
	var l := _built([PIECE])
	check(l.fronts().size() == 1, "a piece in front is built from its layer")
	var s: Sprite2D = l.fronts()[0]
	_run(l, 600.0, 1.0)
	check(_progress(s) == 0.0 and s.visible, "with the boat far off the plant stands whole")
	_run(l, 900.0 - 52.0, 0.2)
	var part := _progress(s)
	check(part > 0.0 and part < 1.0, "as the boat comes near it starts breaking away")
	_run(l, 900.0 - 52.0, 1.0)
	check(_progress(s) == 1.0, "and is gone once the boat is at it")
	_run(l, 600.0, 0.2)
	check(_progress(s) > 0.0 and _progress(s) < 1.0, "it comes back as the boat leaves")
	_run(l, 600.0, 1.0)
	check(_progress(s) == 0.0, "whole again once the boat is away")
	l.free()


func test_a_piece_breaks_away_in_blocks_of_two_pixels() -> void:
	var l := _built([PIECE])
	var s: Sprite2D = l.fronts()[0]
	check(s.material.get_shader_parameter("cell") == 2.0, "the blocks are two game pixels square, as Farmus's dissolve")
	check(s.z_index > 1, "the plant stands in front of the boat, the line and the net")
	l.free()


func test_a_fight_clears_every_piece() -> void:
	var l := _built([PIECE, PIECE.merged({"front": "top", "x": 300}, true)])
	_run(l, 600.0, 1.0, true)
	check(l.fronts().all(func(s): return _progress(s) == 1.0), "no plant hides a fish fight")
	l.free()


func test_the_pieces_are_hidden_in_the_strip() -> void:
	var l := _built([PIECE])
	_run(l, 600.0, 0.5)
	Windowing.strip = true
	_run(l, 600.0, 0.1)
	var hidden: bool = not l.fronts()[0].visible
	Windowing.strip = false
	_run(l, 600.0, 0.1)
	check(hidden and l.fronts()[0].visible, "the desktop strip shows no plants in front")
	l.free()


func test_a_piece_slides_faster_than_the_boat() -> void:
	var l := _built([PIECE])
	var s: Sprite2D = l.fronts()[0]
	_run(l, 400.0, 0.1)
	var a := s.position.x
	_run(l, 410.0, 0.1)
	check(is_equal_approx(a - s.position.x, 16.0), "rowing ten pixels slides it sixteen across the view")
	l.free()


## The opaque rows of a piece on screen, top and bottom.
func _rows(s: Sprite2D) -> Vector2:
	var used := s.texture.get_image().get_used_rect()
	return Vector2(s.position.y + used.position.y, s.position.y + used.end.y)


func test_a_piece_never_shows_the_edge_it_stands_on() -> void:
	var l := _built([PIECE, PIECE.merged({"front": "top", "x": 1000}, true)])
	var bottom: Sprite2D = l.fronts()[0]
	var top: Sprite2D = l.fronts()[1]
	for cam_y in [CoastCamera.HOME_Y, CoastCamera.ROW_SEA - Nav.view().y, CoastCamera.HOME_Y - 50.0, 300.0]:
		_run(l, 600.0, 0.1, false, cam_y)
		check(_rows(bottom).y >= Nav.view().y, "a plant standing at the bottom reaches below the view with the camera at %d" % cam_y)
		check(_rows(top).x <= 0.0, "a branch hanging from the top reaches above the view with the camera at %d" % cam_y)
	_run(l, 600.0, 0.1, false, CoastCamera.ROW_SEA - Nav.view().y)
	check(_rows(bottom).x < Nav.view().y - 20.0, "the plant at the bottom still stands in the view while he rows with the view raised")
	_run(l, 600.0, 1.0, false, 300.0)
	var dipped := top.position.y
	check(_progress(bottom) == 1.0, "with the view down in the water the plant at the bottom has broken away")
	_run(l, 600.0, 1.0)
	check(dipped < top.position.y and _progress(bottom) == 0.0, "the branch at the top rose out of the view as it dipped, and both are back at home")
	l.free()


func test_every_place_has_a_few_dark_plants_in_front() -> void:
	for p in Data.places.values():
		var fronts: Array = p["layers"].filter(func(l): return l.has("front"))
		check(fronts.size() >= 3, p["id"] + " has a few plants in front of the view")
		for f in fronts:
			check(f["front"] in ["top", "bottom"] and f["factor"][0] > 1.0, "%s: %s stands on an edge and slides faster than the boat" % [p["id"], f["file"]])
			var img: Image = (load("res://assets/art/" + str(f["file"])) as Texture2D).get_image()
			img.decompress()
			var light := 0.0
			var n := 0
			for y in range(0, img.get_height(), 2):
				for x in range(0, img.get_width(), 2):
					var c := img.get_pixel(x, y)
					if c.a > 0.5:
						light += c.get_luminance()
						n += 1
			check(n > 0 and light / n < 0.22, "%s: %s is much darker than the scene" % [p["id"], f["file"]])
			var w := img.get_width()
			var h := img.get_height()
			var far_row := h - 1 if f["front"] == "top" else 0
			var clear := range(h).all(func(y): return img.get_pixel(0, y).a == 0.0 and img.get_pixel(w - 1, y).a == 0.0) \
				and range(w).all(func(x): return img.get_pixel(x, far_row).a == 0.0)
			check(clear, "%s: %s ends inside its picture on every side but the one it stands on" % [p["id"], f["file"]])


## Each opaque run of a row of a picture, as [first, last] columns.
func _runs(img: Image, y: int) -> Array:
	var out: Array = []
	var start := -1
	for x in img.get_width() + 1:
		var solid := x < img.get_width() and img.get_pixel(x, y).a > 0.5
		if solid and start < 0:
			start = x
		elif not solid and start >= 0:
			out.append([start, x - 1])
			start = -1
	return out


func test_every_plant_standing_up_from_below_grows_out_of_land_rising_past_the_waterline() -> void:
	for p in Data.places.values():
		for f in p["layers"].filter(func(l): return l.get("front", "") == "bottom"):
			var img: Image = (load("res://assets/art/" + str(f["file"])) as Texture2D).get_image()
			img.decompress()
			var waterline := img.get_height() - ParallaxLayers.FRONT_DEPTH
			var name := "%s: %s" % [p["id"], f["file"]]
			check(waterline > 0, name + " has its waterline inside its picture")
			if waterline <= 0:
				continue
			var solid := true
			for y in range(waterline, img.get_height()):
				var runs := _runs(img, y)
				if runs.size() != 1 or runs[0][1] - runs[0][0] < 24:
					solid = false
			check(solid, name + " is one bank of land from its bottom up to its waterline, with nothing loose in the water beside it")
			var above: Array = _runs(img, waterline - 2).map(func(r): return r[1] - r[0])
			check(not above.is_empty() and above.max() >= 24, name + " has its land rising on above the water")
			var stands := false
			for y in range(0, waterline - 2):
				var runs := _runs(img, y)
				if not runs.is_empty() and (runs.size() > 1 or runs[0][1] - runs[0][0] < img.get_width() - 4):
					stands = true
			check(stands, name + " has its plant growing up above the land")


func test_a_plant_standing_up_from_below_keeps_its_land_on_the_waterline() -> void:
	var l := _built([PIECE])
	var s: Sprite2D = l.fronts()[0]
	var waterline := s.texture.get_height() - ParallaxLayers.FRONT_DEPTH
	for cam_y in [CoastCamera.HOME_Y, CoastCamera.ROW_SEA - Nav.view().y, CoastCamera.HOME_Y - 40.0]:
		_run(l, 600.0, 0.1, false, cam_y)
		check(absf(s.position.y + waterline + cam_y) < 0.01, "the bank's waterline lies on the sea's with the camera at %d" % cam_y)
		check(s.position.y + s.texture.get_height() >= Nav.view().y, "and the bank runs on below the view with the camera at %d" % cam_y)
	_run(l, 600.0, 0.1, false, CoastCamera.HOME_Y + 20.0)
	check(s.position.y + s.texture.get_height() >= Nav.view().y, "the bank still runs below the view as the view starts to dip")
	l.free()


func _coast(place: String) -> Node:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": place})
	return s


func _done(s: Node) -> void:
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func test_a_plant_on_the_coast_breaks_away_as_the_boat_rows_up_to_it() -> void:
	var s := _coast("harbour")
	var layers: ParallaxLayers = s._layers
	var piece: Dictionary = Data.places["harbour"]["layers"].filter(func(l): return l.has("front"))[0]
	var sprite: Sprite2D = layers.fronts()[0]
	s.boat_x = float(piece["x"]) - 52.0 + (-400.0 if float(piece["x"]) > 600.0 else 400.0)
	s.camera.jump(Vector2(s.boat_x + 52.0 - 240.0, CoastCamera.HOME_Y))
	for i in 30:
		s._process(1.0 / 30.0)
	check(_progress(sprite) == 0.0, "the plant stands whole while the boat is away")
	s.boat_x = float(piece["x"]) - 52.0
	s.camera.jump(Vector2(s.boat_x + 52.0 - 240.0, CoastCamera.HOME_Y))
	for i in 30:
		s._process(1.0 / 30.0)
	check(_progress(sprite) == 1.0, "and is gone with the boat at it")
	_done(s)


func test_a_plant_never_rests_over_the_buttons_along_the_bottom() -> void:
	var s := _coast("harbour")
	var layers: ParallaxLayers = s._layers
	var map_button: Rect2 = s._sail.get_global_rect()
	for k in layers.fronts().size():
		var piece: Dictionary = Data.places["harbour"]["layers"].filter(func(l): return l.has("front"))[k]
		if piece["front"] != "bottom":
			continue
		# The camera is set so the plant stands over the Bay map button, with the boat well away from it.
		var cam_x: float = float(piece["x"]) - 240.0 - (map_button.get_center().x - 240.0) / float(piece["factor"][0])
		if cam_x < 0.0 or cam_x > float(Data.places["harbour"]["width"]) - 480.0:
			continue
		s.boat_x = cam_x + 240.0 - 52.0
		s.camera.jump(Vector2(cam_x, CoastCamera.HOME_Y))
		for i in 30:
			s._process(1.0 / 30.0)
		check(_progress(layers.fronts()[k]) == 1.0, "a plant over the bottom buttons breaks away rather than rest behind them")
	_done(s)
