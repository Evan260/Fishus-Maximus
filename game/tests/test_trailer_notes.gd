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
