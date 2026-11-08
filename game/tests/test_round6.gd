extends "res://tests/test_case.gd"
## The sixth round of feedback: the rowing view, the long cast, the boat's keel, big fish in deep water and the map.

const BOATS := ["skiff", "fishing_boat", "sailing_boat", "big_boat"]


func _coast() -> Node:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "hound")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour", "boat_x": 400.0})
	return s


func _done(s: Node) -> void:
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func test_picking_the_place_you_are_at_keeps_the_boat_where_it_lies() -> void:
	Game.new_game("Test", "hound")
	Game.state["boat_x"] = 640.0
	check(BayMap.sail(Game.state, "harbour"), "you may pick the place you are at")
	check(float(Game.state["boat_x"]) == 640.0, "and the boat stays where it lay, not back at the jetty")


func test_the_stowed_rod_lies_below_the_gunwale() -> void:
	var b := BoatView.new()
	b.set_boat("skiff")
	b.rowing = 1.0
	b.place(100.0, Vector2.ZERO, 0.0)
	check(b.pose()[0] == "row", "he is rowing")
	check(b.rod_tip(100.0).y > -b.ride + b.bob + b.deck + 1.0, "the rod lies down inside the hull, out of sight, not across its top")
	b.free()


## The lowest painted row of each column of a picture, or -1 where the column is empty.
func _bottoms(img: Image) -> Array:
	var out := []
	for x in img.get_width():
		var b := -1
		for y in img.get_height():
			if img.get_pixel(x, y).a > 0.5:
				b = y
		out.append(b)
	return out


func test_every_hull_is_rounded_underneath() -> void:
	for id in BOATS:
		var img: Image = load("res://assets/art/props/%s.png" % id).get_image()
		var bottoms := _bottoms(img)
		var lowest: int = bottoms.max()
		var deep: Array = range(bottoms.size()).filter(func(x): return bottoms[x] >= lowest - 1)
		check(deep.size() < img.get_width() * 0.45, "%s: the keel is deepest only near the middle, not flat along %d of %d columns" % [id, deep.size(), img.get_width()])
		var left: int = bottoms.find(bottoms.filter(func(b): return b >= 0)[0])
		var w: int = bottoms.size() - left
		var near_end: int = bottoms[left + int(w * 0.12)]
		check(lowest - near_end >= 3, "%s: towards its end the hull curves up, by %d rows" % [id, lowest - near_end])


func test_the_view_rises_while_he_rows() -> void:
	var c := CoastCamera.new(Vector2(1440, 340))
	for i in 200:
		c.follow(500.0, Vector2(560, -30), false, 0.05, true)
	check(-c.cam.y >= c.view.y - CoastCamera.ROW_SEA - 1.0, "rowing, the waterline sits near the bottom, so little under the water shows: %s" % c.cam)
	for i in 400:
		c.follow(500.0, Vector2(560, -30), false, 0.05, false)
	check(c.cam.y == CoastCamera.HOME_Y, "stopped, the view comes back down to look under the water")


func test_the_rowing_view_waits_out_a_short_pause() -> void:
	var c := CoastCamera.new(Vector2(1440, 340))
	for i in 200:
		c.follow(500.0, Vector2(560, -30), false, 0.05, true)
	var up := c.cam.y
	for i in 6:
		c.follow(500.0, Vector2(560, -30), false, 0.05, false)
	check(absf(c.cam.y - up) < 1.0, "letting go of the key for a moment does not bob the view")


func test_a_full_cast_flies_far_and_high() -> void:
	var s := _coast()
	var tip: Vector2 = s._boat.rest_tip(s.boat_x)
	s.cast(1.0)
	check(absf(s.hook.x - tip.x) >= 220.0, "a full cast lands far out, %d pixels off" % absf(s.hook.x - tip.x))
	var highest := 0.0
	while s.flight > 0.0:
		highest = minf(highest, s.flying().y)
		s.flight -= 0.02
	check(highest <= tip.y - 90.0, "and the float arcs well up into the air on its way, to %d" % highest)
	_done(s)


func test_the_view_follows_the_float_up_and_out() -> void:
	var s := _coast()
	s.cast(1.0)
	var top := 0.0
	var seen := true
	while s.flight > 0.0:
		s._process(1.0 / 30.0)
		top = minf(top, s.camera.cam.y)
		var at: Vector2 = s.flying() if s.flight > 0.0 else Vector2(s.hook.x, 0.0)
		seen = seen and at.x > s.camera.cam.x and at.x < s.camera.cam.x + s.camera.view.x and at.y > s.camera.cam.y
	check(top < CoastCamera.HOME_Y - 25.0, "the view rises with the float, to %d" % top)
	for i in 30:
		s._process(1.0 / 30.0)
	check(s.hook.x > s.camera.cam.x + 20.0 and s.hook.x < s.camera.cam.x + s.camera.view.x - 20.0, "and the float stays on screen where it lands")
	check(seen, "the float never leaves the screen on its way out")
	_done(s)


func test_big_fish_need_deep_water() -> void:
	check(Catalog.water_needed("tuna") > Catalog.water_needed("sea_bass"), "a tuna needs deeper water than a sea bass")
	check(Catalog.water_needed("sea_bass") > Catalog.water_needed("mullet"), "and a sea bass deeper than a mullet")
	var shallow := Catalog.available("harbour", 30.0, 6.0, "spring", "clear", "line", 64.0)
	var deep := Catalog.available("harbour", 30.0, 6.0, "spring", "clear", "line", 200.0)
	check("mullet" in shallow and not "sea_bass" in shallow, "near the shore a mullet swims, but no sea bass")
	check("sea_bass" in deep, "out over deeper water the sea bass is found")


func test_every_fish_has_water_deep_enough_at_each_of_its_places() -> void:
	for id in Data.fish:
		for p in Data.fish[id]["places"]:
			var deepest := 0.0
			for point in Data.places[p]["seabed"]:
				deepest = maxf(deepest, float(point[1]))
			check(Catalog.water_needed(id) <= deepest - 20.0, "%s finds water deep enough in %s" % [id, p])


func test_a_big_fish_turns_back_from_the_shallows() -> void:
	var bed := Seabed.new(Data.places["harbour"]["seabed"])
	var sw := Swimmers.new()
	sw.setup("harbour", bed, Seeds.rng(1, "shallows"))
	Nav.port.add_child(sw)
	var s := Swimmers.sprite_for("sea_bass", sw.texture_for("sea_bass"))
	sw.add_child(s)
	var f := {"id": "sea_bass", "lb": 8.0, "sprite": s, "pos": Vector2(760, 100), "heading": -1.0, "phase": 0.0, "speed": 12.0,
		"band": Data.fish["sea_bass"]["depth"], "goal_y": 100.0, "turn": 1000.0, "look": 1.0, "state": "swim", "leader": {},
		"group": 1, "offset": Vector2.ZERO}
	sw.fish = [f]
	var shallowest := INF
	for i in 1800:
		sw._move(f, 1.0 / 30.0, null)
		shallowest = minf(shallowest, bed.depth_at(f["pos"].x))
	check(shallowest >= Catalog.water_needed("sea_bass") - 6.0, "a sea bass keeps to water at least %d deep, and went to %d" % [Catalog.water_needed("sea_bass"), shallowest])
	sw.free()


func test_a_big_fish_ignores_a_bait_in_the_shallows() -> void:
	var bed := Seabed.new(Data.places["harbour"]["seabed"])
	var sw := Swimmers.new()
	sw.setup("harbour", bed, Seeds.rng(1, "bait"))
	check(not sw.deep_enough("sea_bass", 60.0), "a bait by the shore is too shallow for a sea bass to come to")
	check(sw.deep_enough("mullet", 60.0), "but not for a mullet")
	sw.free()


func test_fishing_on_his_own_by_the_shore_brings_no_big_fish() -> void:
	var got := Idle.catches(6000.0, "harbour", 30.0, "worm", 1000, Seeds.rng(1, "shore"), 6.0, "spring", "clear", 64.0)
	check(not got.is_empty() and got.all(func(c): return Catalog.water_needed(c["fish"]) <= 64.0), "only fish of the shallows take his bait by the shore")


func test_the_sky_reaches_the_top_of_a_raised_view() -> void:
	var sky := SkyView.new()
	Nav.sky.add_child(sky)
	sky.follow(Vector2(300, CoastCamera.HOME_Y - 110.0), 12.0, "clear")
	check(sky.position.y + sky._gradient.position.y <= Nav.port.canvas_transform.origin.y + 0.5, "no black band shows above the sky while the view is up")
	sky.free()


func test_the_dog_sits_down_once_and_stays_sitting() -> void:
	var s := _coast()
	s.dog._process(0.1)
	var settled := []
	for i in 40:
		s.dog._process(0.1)
		if i >= 20:
			settled.append(s.dog.frame())
	check(settled.all(func(f): return f == settled[0]), "once it has sat down it stays sitting, not standing up again: %s" % [settled])
	check(settled[0] == s.dog.frames_of("sit_east").size() - 1, "and it rests on the last frame of sitting down")
	_done(s)


func test_the_dog_sits_down_inside_each_boat() -> void:
	for id in BOATS:
		var b := BoatView.new()
		b.set_boat(id)
		var seat := b.dog_seat()
		check(seat.y - b.seat.y >= 12.0, "%s: the dog sits down in the hull, whose near side hides its legs (%d rows)" % [id, seat.y - b.seat.y])
		var w := b.width()
		check(seat.x > w * 0.15 and seat.x < w * 0.88, "%s: and off the very tips of the bow and stern" % id)
		b.free()


func test_the_dog_is_drawn_inside_the_boat_not_behind_it() -> void:
	var s := _coast()
	var boat: Node = s._boat
	check(s.dog.z_index == boat.z_index and s.dog.get_index() > boat.get_index(), "the dog is drawn over the boat behind it")
	check(boat.front.z_index > 0 and boat.front.z_as_relative, "and under the hull's near side, which is drawn over it")
	_done(s)


func test_the_land_under_the_water_follows_the_land_not_the_plants_in_front() -> void:
	for p in Data.places.values():
		var land: Array = p["layers"].filter(func(l): return l.has("at") and l.has("file") and l.has("factor"))
		var nearest := 0.0
		for l in land:
			nearest = maxf(nearest, float(l["factor"][0]))
		var u := UnderLand.new(p)
		check(u._factor[UnderLand.FAR] == nearest, "%s: the far slope under the water slides with the nearest land, at %s, not %s" % [p["id"], nearest, u._factor[UnderLand.FAR]])
		u.free()
