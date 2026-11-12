extends "res://tests/test_case.gd"
## The notes from watching the second trailer: the oars splash as they go in, with no creak.


func _coast(boat: String, place := "harbour", x := 400.0) -> Node:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "hound")
	Game.state["boat"] = boat
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": place, "boat_x": x})
	return s


func _done(s: Node) -> void:
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func test_the_oars_splash_as_each_blade_goes_in() -> void:
	check(Audio._sounds.has("stroke"), "the oars have a splash for each stroke")
	check(not Audio._sounds.has("oars"), "the old rowing clip with its creaking oarlocks is gone")
	for id in Data.boats:
		var s := _coast(id)
		var b: BoatView = s._boat
		var entries := 0
		var was_in := false
		for k in 135:
			s.row(1.0, 1.0 / 30.0)
			b._process(1.0 / 30.0)
			var before: int = b.strokes
			b.place(s.boat_x, s.camera.cam, k / 30.0)
			var blade_in: bool = b.pose()[0] == "row" and b._oar()[0].y > 0.0
			if b.strokes > before:
				check(blade_in and not was_in, "%s: the splash comes on the frame the blade goes into the water" % id)
			if blade_in and not was_in:
				entries += 1
			was_in = blade_in
		if b.oars:
			check(b.strokes >= 4 and b.strokes == entries, "%s: one splash for each of its %d strokes in 4.5 seconds, not %d" % [id, entries, b.strokes])
		else:
			check(b.strokes == 0, "%s: a boat under sail makes no oar sounds (%d)" % [id, b.strokes])
		_done(s)


## Every fish's picture on screen, by the fish, as a rectangle in view pixels.
func _seen(sw: Swimmers) -> Dictionary:
	var out := {}
	var view := Rect2(Vector2.ZERO, Nav.view())
	for f in sw.fish:
		if f["state"] == "gone":
			continue
		var s: Sprite2D = f["sprite"]
		var r := Rect2(s.position - s.texture.get_size() / 2.0, s.texture.get_size())
		if r.intersects(view):
			out[s.get_instance_id()] = f["pos"]
	return out


func test_no_fish_appears_or_jumps_inside_the_view() -> void:
	var old_size: Vector2i = Nav.port.size_2d_override
	var old_zoom: int = Nav.zoom
	for size in [Vector2i(480, 270), Vector2i(640, 270), Vector2i(480, 360)]:
		Nav.fit(size, 1)
		for place in ["harbour", "rocky_shore", "open_bay", "misenum"]:
			var s := _coast("big_boat", place, 600.0)
			var sw: Swimmers = s.swimmers
			s._pinned = true
			var known := {}
			for f in sw.fish:
				known[(f["sprite"] as Sprite2D).get_instance_id()] = true
			var last := _seen(sw)
			var start: Vector2 = s.camera.cam
			var appeared := 0
			var jumped := 0
			for k in 900:
				var t := k / 30.0
				# The camera sweeps along the coast both ways and down into the deep and back, as rowing and the line take it.
				s.camera.cam = Vector2(maxf(0.0, start.x + sin(t * 0.35) * 500.0 + t * 20.0), CoastCamera.HOME_Y + (1.0 - cos(t * 0.5)) * 0.5 * minf(300.0, float(sw.place["depth"]) - 200.0))
				s._update_swimmer_world()
				sw.step(1.0 / 30.0, null, "")
				var now := _seen(sw)
				for id in now:
					if not known.has(id) and not last.has(id):
						appeared += 1
					elif last.has(id) and (now[id] as Vector2).distance_to(last[id]) > 6.0:
						jumped += 1
				for f in sw.fish:
					known[(f["sprite"] as Sprite2D).get_instance_id()] = true
				last = now
			check(appeared == 0, "%s at %s: no new fish shows up inside the view (%d did)" % [place, size, appeared])
			check(jumped == 0, "%s at %s: no fish jumps inside the view (%d did)" % [place, size, jumped])
			_done(s)
	Nav.fit(old_size, old_zoom)


func test_a_fish_let_go_of_the_bait_sinks_back_gently() -> void:
	var s := _coast("skiff", "rocky_shore", 600.0)
	var sw: Swimmers = s.swimmers
	var f := sw.bring_in("dentex", 8.0, 30.0, 1.0)
	check(not Rect2(Vector2.ZERO, Nav.view()).intersects(Rect2(f["sprite"].position - f["sprite"].texture.get_size() / 2.0, f["sprite"].texture.get_size())), "a fish brought in starts out of sight")
	f["pos"] = Vector2(s.camera.cam.x + 200.0, 20.0)
	var y: float = f["pos"].y
	sw.step(1.0 / 30.0, null, "")
	check(f["pos"].y - y < 1.0, "a deep fish above its depth sinks back a little at a time, not at once (%.1f)" % (f["pos"].y - y))
	_done(s)
