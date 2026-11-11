extends "res://tests/test_case.gd"
## The boat round of feedback: the dog sitting inside the hull, between its far and near sides.


func _coast(boat: String) -> Node:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "hound")
	Game.state["boat"] = boat
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour", "boat_x": 400.0})
	return s


func _done(s: Node) -> void:
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func test_the_dog_sits_in_front_of_the_far_side_and_behind_the_near_side() -> void:
	for id in Data.boats:
		for facing in [1.0, -1.0]:
			var s := _coast(id)
			var b: BoatView = s._boat
			b.facing = facing
			s._process(0.05)
			s.dog._process(0.05)
			var img: Image = b.boat.texture.get_image()
			if img.is_compressed():
				img.decompress()
			var near: Image = b.front.texture.get_image()
			check(b.front.visible and b.front.flip_h == b.boat.flip_h, "%s facing %d: the near side is drawn, turned with the boat" % [id, facing])
			# The dog's middle column in the boat's own picture, wherever the boat is facing.
			var on_boat := roundi(s.dog.position.x - b.boat.position.x)
			var col := on_boat if facing > 0.0 else img.get_width() - 1 - on_boat
			var far_rows := 0
			var far_drawn := 0
			var near_missing := 0
			for x in range(maxi(0, col - 12), mini(img.get_width(), col + 13)):
				var rail := int(b.near_rail[x])
				for y in img.get_height():
					var solid := img.get_pixel(x, y).a > 0.5
					var over := near.get_pixel(x, y).a > 0.5
					if y < rail and solid:
						far_rows += 1
						far_drawn += 1 if over else 0
					elif y >= rail and solid and not over:
						near_missing += 1
			check(far_drawn == 0, "%s facing %d: nothing above the near rail, the far side, is drawn over the dog (%d pixels are)" % [id, facing, far_drawn])
			check(near_missing == 0, "%s facing %d: the near side from its rail down is drawn over the dog (%d pixels missing)" % [id, facing, near_missing])
			check(absf(b.dog_rail - b.near_rail[col]) <= 1.0, "%s facing %d: the dog's rail is the near rail where it sits" % [id, facing])
			var shown_to: float = roundf(s.dog_seat().y) + minf(s.dog.cut, s.dog._hidden_from())
			check(shown_to >= b.dog_rail, "%s facing %d: the dog is drawn down to the near rail, row %d, not cut off above it at %d" % [id, facing, b.dog_rail, shown_to])
			if id in ["skiff", "big_boat"]:
				check(far_rows >= 20, "%s facing %d: the far side shows above the near rail where the dog sits, %d pixels, and stays behind it" % [id, facing, far_rows])
			_done(s)


func test_every_boat_names_its_near_rail() -> void:
	for id in Data.boats:
		var b := BoatView.new()
		b.set_boat(id)
		var rail: Array = Data.boats[id].get("rail", [])
		check(rail.size() >= 2, "%s: names the row its near side starts in along the boat" % id)
		check(b.dog_spot.y - b.dog_rail >= 8.0, "%s: the dog sits down inside the hull, its feet %d rows under the near rail" % [id, b.dog_spot.y - b.dog_rail])
		b.free()
