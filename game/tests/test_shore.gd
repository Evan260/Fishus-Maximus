extends "res://tests/test_case.gd"


func test_a_happy_pond_grows_and_breeds() -> void:
	Game.new_game("Test", "mutt")
	var pond := {"stage": 2, "features": ["rocks", "caves", "weed"], "fish": [
		{"fish": "bream", "pounds": 2.0, "name": "", "finery": "", "age_days": 10, "fed": true},
		{"fish": "bream", "pounds": 2.1, "name": "", "finery": "", "age_days": 10, "fed": true}]}
	Game.state["pond"] = pond
	for d in 6:
		for f in pond["fish"]:
			f["fed"] = true
		Ponds.day(Game.state, Seeds.rng(d, "p"))
	check(pond["fish"][0]["pounds"] > 2.0, "fed fish grow")
	check(pond["fish"].size() == 3, "a happy pair has young")


func test_a_hungry_pond_does_not_grow() -> void:
	Game.new_game("Test", "mutt")
	var pond := {"stage": 1, "features": [], "fish": [{"fish": "moray", "pounds": 4.0, "name": "Hortensia", "finery": "earrings", "age_days": 40, "fed": false}]}
	Game.state["pond"] = pond
	Ponds.day(Game.state, Seeds.rng(1, "p"))
	check(pond["fish"][0]["pounds"] == 4.0 and Ponds.happiness(pond, pond["fish"][0]) < 0.5, "a hungry moray without a cave does not grow")


func test_pond_fish_grow_past_any_caught_wild() -> void:
	Game.new_game("Test", "mutt")
	var pond := {"stage": 2, "features": ["rocks", "sand"], "fish": [{"fish": "bream", "pounds": 6.9, "name": "", "finery": "", "age_days": 10, "fed": true}]}
	Game.state["pond"] = pond
	for d in 200:
		pond["fish"][0]["fed"] = true
		Ponds.day(Game.state, Seeds.rng(d, "p"))
	check(pond["fish"][0]["pounds"] > 7.0 and pond["fish"][0]["pounds"] <= 7.0 * 1.3 + 0.001, "up to 1.3 times the wild maximum")


func test_the_pond_is_dug_stocked_named_and_dressed() -> void:
	Game.new_game("Test", "mutt")
	Game.state["denarii"] = 1000
	check(not Ponds.dug(Game.state) and Ponds.stage(Game.state) == 0, "a new game has no pond yet")
	check(Ponds.widen(Game.state) and Ponds.stage(Game.state) == 1, "the pond is dug into the rock")
	check(Game.state["denarii"] == 1000 - int(Data.ponds["stages"][0]["price"]), "for the first stage's price")
	check(not Ponds.widen(Game.state), "and the first chapter allows it no wider")
	check(Ponds.add_feature(Game.state, "rocks") and "rocks" in Ponds.of(Game.state)["features"], "rocks put in")
	Game.state["boat"] = "fishing_boat"
	Hold.add(Game.state, {"fish": "bream", "pounds": 2.0, "fresh": 1.0, "live": true})
	check(Ponds.stock(Game.state, 0) and Game.state["live_well"].is_empty() and Ponds.of(Game.state)["fish"].size() == 1, "a live bream goes from the well to the pond")
	Ponds.name_fish(Game.state, 0, "Aurata")
	Game.state["finery"] = ["earrings"]
	check(Ponds.dress(Game.state, 0, "earrings") and Ponds.of(Game.state)["fish"][0]["finery"] == "earrings" and Game.state["finery"].is_empty(), "named and dressed")
	Ponds.feed(Game.state)
	check(Ponds.of(Game.state)["fish"][0]["fed"], "fed by hand")


func test_a_fish_sells_from_the_pond_for_more_only_once_settled() -> void:
	Game.new_game("Test", "mutt")
	Game.state["denarii"] = 1000
	Ponds.widen(Game.state)
	Game.state["boat"] = "fishing_boat"
	Hold.add(Game.state, {"fish": "bream", "pounds": 2.0, "fresh": 1.0, "live": true})
	Ponds.stock(Game.state, 0)
	var worth := Catalog.value("bream", 2.0, 1.0)
	var f: Dictionary = Ponds.of(Game.state)["fish"][0]
	check(Ponds.live_price(f) == worth, "a fish just put in sells for its worth at market, not half again")
	for d in int(Data.num("ponds.settled_days", 3)):
		Ponds.day(Game.state, Seeds.rng(d, "p"))
	check(Ponds.settled(f) and Ponds.live_price(f) == int(Catalog.value("bream", float(f["pounds"]), 1.0) * 1.5), "once it has lived there some days it fetches half again")
	var before := int(Game.state["denarii"])
	check(Ponds.sell_live(Game.state, 0) == int(Game.state["denarii"]) - before, "and that is what selling it pays")
	check(Ponds.settled({"fish": "bream", "pounds": 2.0}), "a fish from an older save, its days not counted, is taken as settled")


func test_there_is_one_pond_widened_as_the_chapters_open() -> void:
	Game.new_game("Test", "mutt")
	Game.state["denarii"] = 100000
	var rooms := []
	for chapter in range(1, Data.chapters.size() + 1):
		Game.state["chapter"] = chapter
		while Ponds.widen(Game.state):
			pass
		check(Ponds.stage(Game.state) == Ponds.allowed(Game.state), "chapter %d: widened as far as it allows, stage %d" % [chapter, Ponds.stage(Game.state)])
		rooms.append(Ponds.room(Ponds.of(Game.state)))
	check(Ponds.stage(Game.state) == Ponds.stages() and Ponds.next_price(Game.state) == -1, "the last chapter allows it its full width, and no wider")
	var sorted := rooms.duplicate()
	sorted.sort()
	check(rooms == sorted and rooms[-1] > rooms[0], "each widening gives more room: %s" % [rooms])
	check(Game.state.get("pond") is Dictionary and not Game.state.has("ponds"), "and the game keeps one pond, not a list of them")
	check(Achievements.met("first_pond", Game.state) and Achievements.met("all_ponds", Game.state), "digging it and widening it fully are each an achievement")


func test_brackish_fish_need_the_spring() -> void:
	Game.new_game("Test", "mutt")
	var eel := {"fish": "eel", "pounds": 2.0, "name": "", "finery": "", "age_days": 10, "fed": true}
	var pond := {"stage": 2, "features": ["caves", "weed"], "fish": [eel]}
	var without := Ponds.happiness(pond, eel)
	pond["features"].append("spring")
	check(Ponds.happiness(pond, eel) > without and Ponds.happiness(pond, eel) == 1.0, "an eel is happy once the spring brings brackish water")
	var bream := {"fish": "bream", "pounds": 2.0, "name": "", "finery": "", "age_days": 10, "fed": true}
	pond["features"].append_array(["rocks", "sand"])
	check(Ponds.happiness(pond, bream) == 1.0, "and the sea fish stay happy beside it")


func test_an_old_save_with_six_ponds_keeps_every_fish_in_the_one_pond() -> void:
	var old := Game.defaults()
	old.erase("pond")
	old["version"] = 1
	old["chapter"] = 5
	old["ponds"] = [
		{"site": 0, "size": "large", "water": "sea", "features": ["rocks", "sand"], "breeding": {"bream": 3}, "fish": [
			{"fish": "bream", "pounds": 4.2, "name": "Aurata", "finery": "gold_ring", "age_days": 30, "fed": true},
			{"fish": "bream", "pounds": 3.1, "name": "", "finery": "", "age_days": 30, "fed": true}]},
		{"site": 1, "size": "small", "water": "sea", "features": ["caves", "rocks"], "fish": [
			{"fish": "moray", "pounds": 12.5, "name": "Hortensia", "finery": "earrings", "age_days": 60, "fed": false}]},
		{"site": 5, "size": "large", "water": "brackish", "features": ["weed"], "fish": [
			{"fish": "eel", "pounds": 2.0, "name": "", "finery": "", "age_days": 9, "fed": false}]}]
	# A save goes through JSON on its way to disk and back, so the old one is read the same way.
	Game.from_dict(JSON.parse_string(JSON.stringify(old)))
	var pond := Ponds.of(Game.state)
	check(not Game.state.has("ponds"), "the six sites are gone from the game")
	check(pond["fish"].size() == 4, "every fish is in the one pond, %d" % pond["fish"].size())
	var names: Array = pond["fish"].map(func(f): return str(f["name"]))
	check("Aurata" in names and "Hortensia" in names, "named fish keep their names")
	check(pond["fish"].any(func(f): return f["name"] == "Hortensia" and f["finery"] == "earrings" and is_equal_approx(float(f["pounds"]), 12.5)),
		"and their finery and weight")
	for feature in ["rocks", "sand", "caves", "weed", "spring"]:
		check(feature in pond["features"], "the pond has the %s one of the old ponds had" % feature)
	check(Ponds.room(pond) >= 14 + 6 + 14, "it is dug wide enough for all the old ponds' room, stage %d, room %d" % [Ponds.stage(Game.state), Ponds.room(pond)])
	check(int(pond["breeding"].get("bream", 0)) == 3, "and the bream's breeding carries on")
	var eel: Dictionary = pond["fish"].filter(func(f): return f["fish"] == "eel")[0]
	check(Ponds.happiness(pond, eel) > 0.5, "the eel from the brackish pond has brackish water still")
	var saved := Game.to_dict()
	check(int(saved["version"]) == Game.VERSION and saved.has("pond") and not saved.has("ponds"), "and it saves as one pond")
	Game.from_dict(JSON.parse_string(JSON.stringify(saved)))
	check(Ponds.of(Game.state)["fish"].size() == 4, "which loads again unchanged")


func test_an_old_save_with_no_ponds_has_no_pond_yet() -> void:
	var old := Game.defaults()
	old.erase("pond")
	old["ponds"] = []
	Game.from_dict(old)
	check(not Ponds.dug(Game.state) and not Game.state.has("ponds"), "a save that never dug a pond has none yet")


func test_the_wave_washes_up_the_beach_and_draws_back() -> void:
	check(is_equal_approx(ShoreWash.run_up(0.0), 0.0), "a wave starts at the still line")
	check(is_equal_approx(ShoreWash.run_up(ShoreWash.SURGE), 1.0), "it reaches its highest at the end of its surge")
	var steps := 400
	var last := ShoreWash.run_up(0.0)
	var low := last
	var biggest_step := 0.0
	var turns := 0
	var rising := true
	for i in range(1, steps):
		var now := ShoreWash.run_up(float(i) / steps)
		biggest_step = maxf(biggest_step, absf(now - last))
		if rising and now < last:
			rising = false
			turns += 1
		elif not rising and now > last + 0.0001:
			turns += 1
		low = minf(low, now)
		last = now
	check(biggest_step < 0.02, "it moves smoothly, never more than %.3f of its reach in a step" % biggest_step)
	check(turns == 1, "it runs up once and draws back once each wave")
	check(low < 0.0 and low >= -ShoreWash.BACKWASH - 0.001, "the backwash sinks a little past the still line, to %.2f" % low)
	var surge_speed := ShoreWash.run_up(0.05) - ShoreWash.run_up(0.0)
	var back_speed := ShoreWash.run_up(0.5) - ShoreWash.run_up(0.55)
	check(surge_speed > back_speed * 2.0, "it surges up faster than it draws back")
	check(ShoreWash.run_up(0.999) < 0.0 and is_equal_approx(ShoreWash.run_up(1.0), 0.0), "and the next wave comes in as the backwash ends")
	check(ShoreWash.PERIOD >= 6.0 and ShoreWash.PERIOD <= 12.0, "a wave every %s seconds, a slow sea" % ShoreWash.PERIOD)


func test_the_beach_is_drawn_with_the_waves_rhythm() -> void:
	Game.new_game("Test", "mutt")
	var s := _open()
	var m: ShaderMaterial = s._beach.material
	check(m.get_shader_parameter("period") == ShoreWash.PERIOD and m.get_shader_parameter("reach") == ShoreWash.REACH, "the beach's shader keeps the waves' rhythm")
	var t: float = m.get_shader_parameter("wash_time")
	s._process(0.5)
	check(float(m.get_shader_parameter("wash_time")) > t, "and its waves move on with time")
	check(m.get_shader_parameter("zenith") == s._layers.bands()[1].material.get_shader_parameter("zenith"), "its water mirrors the same sky as the sea behind it")
	_close(s)


func test_garum_grades_by_days_and_fish() -> void:
	Game.new_game("Test", "mutt")
	Game.state["salt"] = 20
	check(Garum.fill(Game.state, 0, [{"fish": "mackerel", "pounds": 10.0}], 5), "the working tank takes fish and salt")
	for d in 20:
		Garum.day(Game.state)
	check(Garum.grade(Game.state["tanks"][0]) == "sociorum", "twenty days of mackerel make the finest")
	check(not Garum.fill(Game.state, 1, [{"fish": "sardine", "pounds": 10.0}], 5), "a ruined tank takes nothing")
	Game.state["tanks"][1]["restored"] = true
	Garum.fill(Game.state, 1, [{"fish": "sardine", "pounds": 10.0}], 5)
	for d in 25:
		Garum.day(Game.state)
	check(Garum.grade(Game.state["tanks"][1]) == "garum", "other fish make plain garum however long")
	check(Garum.export_day(7) and not Garum.export_day(8), "the ship comes every seventh day")
	var got := Garum.take(Game.state, 0)
	check(got["grade"] == "sociorum" and int(got["amphorae"]) >= 1 and Game.state["garum"].get("sociorum", 0) >= 1, "bottled in amphorae")
	check(Garum.grade(Game.state["tanks"][0]) == "", "and the tank is empty again")


func test_stirring_makes_better_garum() -> void:
	Game.new_game("Test", "mutt")
	Game.state["salt"] = 20
	Game.state["tanks"][1]["restored"] = true
	Garum.fill(Game.state, 0, [{"fish": "sardine", "pounds": 10.0}], 5)
	Garum.fill(Game.state, 1, [{"fish": "sardine", "pounds": 10.0}], 5)
	for d in 10:
		Garum.stir(Game.state, 0)
		Garum.day(Game.state)
	check(float(Game.state["tanks"][0]["quality"]) > float(Game.state["tanks"][1]["quality"]), "a stirred tank is better")
	check(Garum.price("garum", 1.0, false) < Garum.price("garum", 1.0, true), "the export ship pays more")


func test_the_shore_opens_on_one_large_pond() -> void:
	Game.new_game("Test", "mutt")
	Game.state["denarii"] = 500
	Ponds.widen(Game.state)
	Game.state["pond"]["fish"].append({"fish": "bream", "pounds": 2.0, "name": "Aurata", "finery": "", "age_days": 9, "fed": true})
	Game.state["pond"]["fish"].append({"fish": "mullet", "pounds": 1.0, "name": "", "finery": "", "age_days": 9, "fed": true})
	var s := _open()
	check(s.views.size() == 1 and s.views[0] == s.pond, "one pond")
	check(s.pond.right - s.pond.left >= Nav.view().x, "as wide as the view, %s" % (s.pond.right - s.pond.left))
	check(s.pond.fish().size() == 2, "with its fish swimming in it")
	check(s.pond.fish().all(func(f): return f["sprite"].scale.y == 1.0), "each one texel to a pixel")
	check(s._thing_at(Vector2(Nav.view().x / 2.0, s.WATER + Nav.offset().y + 20.0)) == "pond", "the water is the pond to click")
	var g: Rect2i = s._garum.get_used_rect()
	check(s._thing_at(s._bank_at() + Vector2(g.get_center())) == "garum", "and the garum works stand on its bank")
	s.pond.ring()
	for i in 40:
		s._process(0.1)
	check(s.pond.shown_names().size() == 1, "ringing the bell shows the named fish")
	_close(s)


func test_the_estate_carries_on_past_the_widest_view() -> void:
	Game.new_game("Test", "mutt")
	var s := _open()
	# A short window as wide as an 8K screen is the widest view the game can have, at one window pixel per game pixel.
	var half := (7680.0 - Nav.SIZE.x) / 2.0
	var shown := Vector2(-half, Nav.SIZE.x + half)
	var beach := Vector2(s.BEACH_AT.x - s.REACH, s.BEACH_AT.x - s.REACH + s._beach.region_rect.size.x)
	check(beach.x <= shown.x and beach.y >= shown.y, "the beach reaches both edges, %s" % beach)
	var walls: Array = s._walls()
	var tile := float(load(s.ESTATE + "wall.png").get_width())
	var left := float(walls[0]["at"][0])
	var right := float(walls[1]["at"][0]) + tile * int(walls[1]["repeat"])
	check(left <= shown.x and right >= shown.y, "and so does the wall, %s to %s" % [left, right])
	check(is_equal_approx(left + tile * int(walls[0]["repeat"]), s.BANK_AT.x), "the wall on the left runs up to the bank")
	var sides: Array = s._floor_sides
	check(sides[0].position.x - s.LEFT <= shown.x and sides[1].position.x + sides[1].region_rect.size.x - s.LEFT >= shown.y, "and the pond's floor")
	check(is_equal_approx(sides[0].position.x + sides[0].region_rect.size.x, 0.0) and sides[1].position.x == s.WIDTH, "running on from the pond's own floor")
	_close(s)


func test_the_wall_runs_on_unbroken_from_the_bank() -> void:
	var bank: Image = load("res://assets/art/estate/bank.png").get_image()
	var wall: Image = load("res://assets/art/estate/wall.png").get_image()
	var w := wall.get_width()
	var same_left := true
	var same_right := true
	# The wall's stones, below the grass and the bank's own slope, are the same pixels at either join.
	for y in range(133, wall.get_height()):
		for x in w:
			same_left = same_left and bank.get_pixel(x, y) == wall.get_pixel(x, y)
		# The bank's last stretch of stones began partway through the wall's picture, at its eleventh column.
		for x in range(10, w):
			same_right = same_right and bank.get_pixel(bank.get_width() - w + x, y) == wall.get_pixel(x, y)
	check(same_left, "the wall's stones on the left run on from the bank's first stones")
	check(same_right, "and on the right from its last")
	var top := func(img: Image, x: int) -> int:
		for y in img.get_height():
			if img.get_pixel(x, y).a > 0.5:
				return y
		return -1
	check(absi(top.call(bank, bank.get_width() - 1) - top.call(wall, 0)) <= 4, "the bank's right end comes down to the wall's grass")


func test_every_feature_rests_on_the_pond_bed() -> void:
	Game.new_game("Test", "mutt")
	Game.state["denarii"] = 500
	Ponds.widen(Game.state)
	Game.state["pond"]["features"] = Data.ponds["features"].map(func(f): return str(f["id"]))
	var s := _open()
	var pieces: Array = s._bed.get_children()
	var want := 0
	for feature in s.PIECES:
		want += (s.PIECES[feature] as Array).size()
	check(pieces.size() == want, "every piece of every feature is laid on the floor, %d of %d" % [pieces.size(), want])
	check(s._bed.z_index > s._floor.z_index, "the pieces stand in front of the floor, so it never cuts their feet off straight")
	for p in pieces:
		var img: Image = p.texture.get_image()
		var used := img.get_used_rect()
		var middle: float = p.position.x + used.get_center().x
		var sand: float = s.sand_top(middle)
		var floating := 0
		var columns := 0
		for x in range(used.position.x + used.size.x / 6, used.end.x - used.size.x / 6):
			for y in range(used.end.y - 1, used.position.y - 1, -1):
				if img.get_pixel(x, y).a > 0.5:
					columns += 1
					if p.position.y + y < sand - 1.0:
						floating += 1
					break
		check(floating <= columns / 5, "%s at %d rests on the sand, %d of %d columns above it" % [p.texture.resource_path, middle, floating, columns])
		check(p.position.y + used.end.y <= sand + 8.0, "and is not sunk into it, its foot at row %d with the sand at %d" % [p.position.y + used.end.y, sand])
		var open_sides := true
		for y in range(img.get_height() - 8, img.get_height()):
			open_sides = open_sides and img.get_pixel(0, y).a < 0.5 and img.get_pixel(img.get_width() - 1, y).a < 0.5
		check(open_sides, "%s has no plant cut off by its picture's sides near the sand" % p.texture.resource_path)
	check(s._channel.visible and s._channel.texture != null, "the sea channel is a painted culvert in the wall")
	Game.state["pond"]["features"] = []
	s._dress_pond()
	check(not s._channel.visible, "and is gone from a pond without it")
	_close(s)


func _open() -> Node:
	for c in Nav.ui.get_children():
		c.free()
	var s: Node = load("res://scripts/shore/shore_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({})
	s._process(0.1)
	return s


func _close(s: Node) -> void:
	for c in Nav.ui.get_children():
		c.free()
	s.free()
