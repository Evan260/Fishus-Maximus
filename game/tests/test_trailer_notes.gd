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


func test_the_dog_barks_softly() -> void:
	check(DogView.BARK_DB <= -12.0, "the bark is well down, at %.0f dB" % DogView.BARK_DB)
	check(DogView.PETTED_DB <= DogView.BARK_DB, "and a yip when petted is no louder")
	var shots := FileAccess.get_file_as_string("res://tools/trailer/shots.gd")
	check(shots.contains("Audio._sounds.erase(\"dog\")"), "the trailer's shots leave the dog's sounds out")


func test_nothing_creaks() -> void:
	check(not Audio._sounds.has("creak"), "the creaking rope is gone from the sounds")
	check(not FileAccess.get_file_as_string("res://scripts/coast/coast_screen.gd").contains("\"creak\""), "and the coast never plays it")


## The cast frames shown from a cast until the throw ends, stepping the coast as the game does.
func _cast_frames(s: Node, start: Callable) -> Array:
	var b: BoatView = s._boat
	start.call()
	var frames := []
	var tip_held := true
	for k in 40:
		var p: Array = b.pose()
		if p[0] == "cast" and (frames.is_empty() or frames[-1] != p[1]):
			frames.append(p[1])
		if p[0] == "cast" and p[1] < BoatView.WIND_FRAMES and s.flight > 0.0 and s.flying().distance_to(b.rod_tip(s.boat_x)) > 1.5:
			tip_held = false
		b._process(1.0 / 30.0)
		s._process(1.0 / 30.0)
	check(tip_held, "the float hangs from the rod's tip while he swings back")
	return frames


func test_every_cast_plays_the_throw() -> void:
	for id in Data.boats:
		for facing in [1.0, -1.0]:
			var s := _coast(id)
			s._demo = true
			s._time = -100.0
			s._boat.facing = facing
			s._process(1.0 / 30.0)
			var frames := _cast_frames(s, func(): s.cast(1.0))
			check(frames.size() >= 6 and frames[0] <= 1 and frames.has(BoatView.WIND_FRAMES - 1) and frames.has(7) and frames.has(8),
				"%s facing %d: a scripted cast swings the rod back and throws it forward (%s)" % [id, facing, frames])
			check(_rising(frames), "%s facing %d: the frames run in order" % [id, facing])
			_done(s)
	var s := _coast("skiff")
	s._demo = true
	s._time = -100.0
	s._process(1.0 / 30.0)
	var wound := _cast_frames(s, func():
		s._boat.charge = 1.0
		s.cast(1.0))
	check(wound.size() >= 3 and wound[0] == BoatView.WIND_FRAMES - 1 and wound.has(7) and wound.has(8), "a cast wound right back throws straight away (%s)" % [wound])
	_done(s)
	s = _coast("fishing_boat")
	s.methods.set_idle(true)
	var idle := _cast_frames(s, func(): s.methods._recast_in = 0.0)
	check(idle.has(BoatView.WIND_FRAMES - 1) and idle.has(8), "fishing on his own, as in the desktop strip, he throws too (%s)" % [idle])
	_done(s)


func _rising(frames: Array) -> bool:
	for i in range(1, frames.size()):
		if frames[i] < frames[i - 1]:
			return false
	return true


func test_the_rod_is_held_only_while_fishing() -> void:
	for id in Data.boats:
		for facing in [1.0, -1.0]:
			var s := _coast(id)
			var b: BoatView = s._boat
			var line: LineView = s._line
			b.facing = facing
			s._process(1.0 / 30.0)
			check(s.rod_down(), "%s facing %d: sitting still with the line in, the rod lies in the boat" % [id, facing])
			check(b.rod_tip(s.boat_x).y > b.rest_tip(s.boat_x).y + 10.0, "%s facing %d: its tip down in the hull" % [id, facing])
			var hooks := 0
			# Winding up, the hook hangs from the raised rod's tip and never on the dog.
			for k in BoatView.WIND_FRAMES:
				s.charge = (k + 0.5) / BoatView.WIND_FRAMES
				s.relayout()
				check(not s.rod_down(), "%s facing %d: he holds the rod as he winds up" % [id, facing])
				var hook: Vector2 = s.rod_tip() - s.camera.cam + Vector2(0, 10)
				if s.dog.rect().grow(-6.0).intersects(Rect2(hook - Vector2(2, 0), Vector2(5, 6))):
					hooks += 1
			check(hooks == 0, "%s facing %d: the hook and bait never rest on the dog (%d frames)" % [id, facing, hooks])
			s.charge = -1.0
			s.cast(0.6)
			for k in 60:
				b._process(1.0 / 30.0)
				s._process(1.0 / 30.0)
				check(not s.rod_down(), "%s facing %d: he holds it through the cast and while the line is out" % [id, facing])
			s.reel_in()
			for k in 300:
				b._process(1.0 / 30.0)
				s._process(1.0 / 30.0)
				if s.line_state() == "reeled":
					break
			s._process(1.0 / 30.0)
			check(s.line_state() == "reeled" and s.rod_down(), "%s facing %d: once the line is in he lays it down again" % [id, facing])
			check(not line.bait_shown() or s.rod_down(), "%s facing %d: and the hook and bait are put away with it" % [id, facing])
			_done(s)
