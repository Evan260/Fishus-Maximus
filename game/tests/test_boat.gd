extends "res://tests/test_case.gd"
## The boat round of feedback: the dog sitting inside the hull, between its far and near sides, and the rod laid down
## while the boat sails, the bait hidden in the mouth of a fish that has taken it, and the sail filling and the flag
## waving, every hull sitting in the water along its length, and each fish drawn larger on the catch banner.


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


func test_the_rod_is_laid_down_while_the_boat_sails() -> void:
	for id in ["sailing_boat", "big_boat"]:
		var s := _coast(id)
		var b: BoatView = s._boat
		b.line_out = true
		check(not b.rod_down(), "%s: with his line out he holds the rod" % id)
		var held: Vector2 = b.rod_tip(s.boat_x)
		s.row(1.0, 0.05)
		s.relayout()
		check(b.rod_down() and s.rod_down(), "%s: while the boat sails along the rod is laid down in the boat" % id)
		check(b.pose()[0] == "rest", "%s: and he sits with his hands at rest, with no oars to pull" % id)
		var tip: Vector2 = b.rod_tip(s.boat_x)
		check(tip.y > held.y + 10.0, "%s: so its tip lies down in the hull, row %.0f, not up in the air at %.0f" % [id, tip.y, held.y])
		b._process(0.5)
		s.relayout()
		check(b.rod_down(), "%s: and once the boat stops with no line out it stays in the boat" % id)
		_done(s)


func test_the_bait_is_hidden_once_a_fish_takes_it() -> void:
	var s := _coast("skiff")
	var line: LineView = s._line
	s.cast(0.5)
	s._state = "waiting"
	check(line.bait_shown(), "the bait shows on the hook while he waits")
	s._on_bite({"id": "mullet", "lb": 1.5, "state": "bit", "heading": 1.0})
	check(s.line_state() == "nibble" and line.bait_shown(), "and while a fish only nibbles at it")
	s._nibbles_left = 0
	s._nibble_in = 0.0
	s.bite_step(0.01)
	check(s.line_state() == "bite" and not line.bait_shown(), "once the fish takes it the bait is in its mouth and shows no more")
	s.strike()
	check(s.line_state() == "fighting" and not line.bait_shown(), "nor while it fights on the line")
	_done(s)


func test_the_sail_fills_and_the_flag_waves() -> void:
	for id in ["sailing_boat", "big_boat"]:
		var s := _coast(id)
		var b: BoatView = s._boat
		var sail := b.boat.material as ShaderMaterial
		check(sail != null and sail.shader.resource_path.ends_with("sail.gdshader"), "%s: its sail and flag are moved by the sail shader" % id)
		var flag: Vector4 = sail.get_shader_parameter("flag")
		check(flag.w > flag.z, "%s: and it names where its flag is" % id)
		b._process(0.1)
		check(float(sail.get_shader_parameter("belly")) == 0.0, "%s: at rest the sail hangs as painted" % id)
		var clock: float = sail.get_shader_parameter("clock")
		b._process(0.1)
		check(float(sail.get_shader_parameter("clock")) > clock and float(sail.get_shader_parameter("flutter")) > 0.0, "%s: but the flag still waves a little" % id)
		var still: float = sail.get_shader_parameter("flutter")
		for i in 20:
			s.row(1.0, 0.05)
			b._process(0.05)
		check(b.wind > 0.9 and float(sail.get_shader_parameter("belly")) >= 1.0, "%s: under way the wind fills the sail, bellying it out %.1f texels" % [id, float(sail.get_shader_parameter("belly"))])
		check(float(sail.get_shader_parameter("flutter")) > still, "%s: and the flag waves harder" % id)
		for i in 30:
			b._process(0.05)
		check(b.wind == 0.0 and float(sail.get_shader_parameter("belly")) == 0.0, "%s: and once the boat stops the sail falls slack again" % id)
		_done(s)
	for id in ["skiff", "fishing_boat"]:
		var b := BoatView.new()
		b.set_boat(id)
		check(b.boat.material == null, "%s: a rowing boat has no sail to fill" % id)
		b.free()


func test_every_boat_sits_in_the_water_along_its_length() -> void:
	for id in Data.boats:
		var b := BoatView.new()
		b.set_boat(id)
		var img: Image = b.boat.texture.get_image()
		if img.is_compressed():
			img.decompress()
		# The waterline's row in the picture when the boat bobs highest, the least of it in the water.
		var water := b.ride + 1.0
		var first := -1
		var last := -1
		var wet := []
		for x in img.get_width():
			var bottom := -1
			for y in img.get_height():
				if img.get_pixel(x, y).a > 0.5:
					bottom = y
			if bottom < 0:
				continue
			if first < 0:
				first = x
			last = x
			if bottom > water:
				wet.append(x)
		var length := last - first + 1
		check(not wet.is_empty() and float(wet.size()) / length >= 0.8, "%s: %d of its %d columns reach into the water" % [id, wet.size(), length])
		var ends := length * 0.11
		check(wet[0] - first <= ends and last - wet[wet.size() - 1] <= ends, "%s: only the stern's last %d columns and the bow's last %d ride clear of it" % [id, wet[0] - first, last - wet[wet.size() - 1]])
		b.free()


func test_the_banner_shows_each_fish_larger_and_the_logbook_keeps_the_small_one() -> void:
	for id in Data.fish:
		var small: Texture2D = load("res://assets/art/fish/%s.png" % id)
		var big := CatchCard.picture_of(id)
		check(big != null and big.resource_path.contains("fish_banner"), "%s: the banner has its own larger picture" % id)
		if big == null:
			continue
		var k := minf(big.get_width() / float(small.get_width()), big.get_height() / float(small.get_height()))
		check(k >= 1.3, "%s: drawn %.2f times as large as in the logbook, %s against %s" % [id, k, big.get_size(), small.get_size()])
		check(ItemArt._fish(id) == small, "%s: the logbook and the shops keep the small picture the sea shows" % id)


func test_his_hands_rest_on_his_knee_while_the_rod_is_down() -> void:
	for id in ["skiff", "fishing_boat", "sailing_boat", "big_boat"]:
		var s := _coast(id)
		var b: BoatView = s._boat
		b.line_out = false
		s.relayout()
		check(b.rod_down() and b.pose() == ["rest", 0], "%s: with the rod laid down he sits at rest, %s" % [id, b.pose()])
		check(b.person.texture.resource_path.ends_with("rest.png"), "%s: in his resting picture" % id)
		var hands: Array = b._hands["rest"][0]
		var held: Array = b._hands["sit"][0]
		check(hands[1] > held[1] + 5, "%s: his hands lie low in his lap, not raised as if holding a rod" % id)
		b.line_out = true
		check(b.pose() == ["sit", 0], "%s: and with his line out he holds the rod up again" % id)
		_done(s)


func test_he_sits_down_to_the_near_rail_in_every_boat() -> void:
	for id in Data.boats:
		var s := _coast(id)
		var b: BoatView = s._boat
		var near: Image = b.front.texture.get_image()
		var lowest := int(b.seat.y) + 1
		var gaps := 0
		var middle := int(b.seat.x * b.width())
		for x in range(middle - 4, middle + 5):
			var y := lowest + 1
			while y < near.get_height() and near.get_pixel(x, y).a < 0.5:
				y += 1
			if y > lowest + 1:
				gaps += 1
		check(gaps <= 2, "%s: the near side starts right under him, with no open rows between his picture and the rail, %d columns open" % [id, gaps])
		_done(s)
