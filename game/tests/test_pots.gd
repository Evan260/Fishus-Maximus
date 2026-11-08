extends "res://tests/test_case.gd"
## Pots are seen going down to the seabed and coming back up, while the game itself changes at once.

const FRAME := 1.0 / 30.0


func _coast() -> Node:
	for c in Nav.ui.get_children():
		c.free()
	Game.new_game("Test", "hound")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	s.methods.set_method("trap")
	return s


func _done(s: Node) -> void:
	for c in Nav.ui.get_children():
		c.free()
	s.free()


func _said(text: String) -> bool:
	var box: Control = Toast._box
	return is_instance_valid(box) and box.get_children().any(func(l): return text in l.text)


func _bed(s: Node, x: float) -> float:
	return roundf(s.seabed.depth_at(x))


## A pot resting on the seabed under the boat, with a crab in it.
func _full_pot(s: Node) -> Dictionary:
	var x := roundf(s.boat_x + 52.0)
	var t := {"place": "harbour", "x": x, "depth": s.seabed.depth_at(x), "set_time": 0.0,
		"catch": [{"fish": "crab", "pounds": 0.5, "live": true}], "size": 3, "hours": 2.0, "bait": ""}
	Game.state["traps"].append(t)
	return t


func test_a_pot_just_set_sinks_to_the_seabed() -> void:
	var s := _coast()
	s.methods.use()
	check(Game.state["traps"].size() == 1, "the pot is set at once")
	var trap: Dictionary = Game.state["traps"][0]
	var view: TrapView = s.methods.traps_view
	var bed := _bed(s, float(trap["x"]))
	check(float(view.pot_at(trap)["at"].y) <= s.gunwale(float(trap["x"])) + 30.0 and view.moving(trap), "it starts in the boat")
	var last := -INF
	var aired := false
	var rose := false
	var through := false
	var arrived := -1.0
	var tilted := false
	for i in 30 * 20:
		view.step(FRAME)
		var at: Vector2 = view.pot_at(trap)["at"]
		if aired and at.y > 1.0 and at.y < last - 0.01:
			rose = true
		aired = aired or at.y < 0.0
		if at.y > bed + 0.01:
			through = true
		if absf(float(view.pot_at(trap)["angle"])) > 0.02:
			tilted = true
		last = at.y
		if arrived < 0.0 and not view.moving(trap) and absf(at.y - bed) < 0.01:
			arrived = i * FRAME
	check(not through, "it never sinks into the seabed")
	check(not rose, "it only ever goes down once it is in the water")
	check(tilted, "it sways a little as it sinks")
	check(arrived >= 2.0 and arrived <= 12.0, "it reaches the bed after a few seconds: %.1f" % arrived)
	var rest: Dictionary = view.pot_at(trap)
	check(rest["at"] == Vector2(float(trap["x"]), bed) and float(rest["angle"]) == view._lie(float(trap["x"])),
		"and rests on whole pixels, lying along the slope of the sand: %s" % rest)
	_done(s)


func test_a_sinking_pot_sinks_faster_at_first() -> void:
	var s := _coast()
	s.methods.use()
	var trap: Dictionary = Game.state["traps"][0]
	var view: TrapView = s.methods.traps_view
	var ys: Array[float] = []
	for i in 30 * 4:
		view.step(FRAME)
		ys.append(float(view.pot_at(trap)["at"].y))
	var entered := ys.find(ys.filter(func(y): return y < 0.0)[0])
	while ys[entered] < 0.0:
		entered += 1
	var first := ys[entered + 6] - ys[entered]
	var later := ys[entered + 36] - ys[entered + 30]
	check(first > later * 1.3, "the splash carries it down fast, then the water slows it: %.1f then %.1f" % [first, later])
	_done(s)


func test_lifting_a_pot_hauls_it_up_and_into_the_boat() -> void:
	var s := _coast()
	var trap := _full_pot(s)
	var view: TrapView = s.methods.traps_view
	s.methods.use()
	check(Game.state["traps"].is_empty(), "the pot is lifted at once")
	check(Game.state["hold"].any(func(c): return c["fish"] == "crab") or Game.state["live_well"].any(func(c): return c["fish"] == "crab"), "and its catch kept at once")
	check(not _said("crab") and not _said("Lifted"), "but nothing is told until it is up")
	var bed := _bed(s, float(trap["x"]))
	check(absf(float(view.pot_at(trap)["at"].y) - bed) < 0.5, "it starts on the bed")
	var surfaced := -1.0
	var gone := -1.0
	var sank := 0.0
	var last := bed
	for i in 30 * 20:
		view.step(FRAME)
		var p: Dictionary = view.pot_at(trap)
		if p.is_empty():
			gone = i * FRAME
			break
		var y := float(p["at"].y)
		if surfaced < 0.0:
			sank = maxf(sank, y - last)
		last = y
		if surfaced < 0.0 and y <= 0.0:
			surfaced = i * FRAME
			check(not _said("Lifted"), "still nothing told as it breaks the surface")
	check(surfaced > 1.0, "it is hauled up through the water: %.1f" % surfaced)
	check(sank < 2.0, "each pull lifts it, and it never drops back more than a little between pulls: %.1f" % sank)
	check(gone > surfaced, "then it is taken into the boat and is gone")
	check(_said("Lifted") and _said("crab"), "and the catch is told once it is in the boat")
	_done(s)


func test_rowing_over_a_pot_hauls_it_and_sets_it_again() -> void:
	var s := _coast()
	var trap := _full_pot(s)
	var view: TrapView = s.methods.traps_view
	s.methods._pull_traps_under_boat()
	check(trap["catch"].is_empty() and Game.state["traps"].has(trap), "the catch comes out at once and the pot stays set")
	check(not _said("rowed over"), "nothing is told while it comes up")
	var topped := false
	for i in 30 * 30:
		view.step(FRAME)
		topped = topped or float(view.pot_at(trap)["at"].y) < 0.0
	check(topped and _said("rowed over"), "it comes up to the boat and the catch is told")
	check(not view.moving(trap) and view.pot_at(trap)["at"] == Vector2(float(trap["x"]), _bed(s, float(trap["x"]))), "then it goes back down to the bed")
	_done(s)


func test_a_pot_is_safe_to_save_on_its_way() -> void:
	var s := _coast()
	s.methods.use()
	var view: TrapView = s.methods.traps_view
	for i in 30:
		view.step(FRAME)
	var saved: Dictionary = Game.to_dict()
	check(saved["traps"].size() == 1 and JSON.parse_string(JSON.stringify(saved))["traps"].size() == 1, "a pot on its way down is saved as set")
	check(saved["traps"][0].keys().all(func(k): return not str(k).begins_with("_")), "with nothing of the picture in it")
	Game.state["traps"].clear()
	var full := _full_pot(s)
	s.methods.use()
	for i in 30:
		view.step(FRAME)
	saved = Game.to_dict()
	check(saved["traps"].is_empty() and saved["hold"].size() + saved["live_well"].size() >= 1, "a pot on its way up is saved lifted, its catch kept")
	check(not view.pot_at(full).is_empty(), "while the picture of it is still coming up")
	_done(s)


func test_the_pot_stays_whole_pixels() -> void:
	var s := _coast()
	s.methods.use()
	var trap: Dictionary = Game.state["traps"][0]
	var view: TrapView = s.methods.traps_view
	for i in 30 * 3:
		view.step(FRAME)
	var sprite: Sprite2D = view.sprite_of(trap)
	check(sprite != null and sprite.material is ShaderMaterial and (sprite.material as ShaderMaterial).shader == Pixels.SHADER, "the turning pot keeps its texels whole")
	check(view.bits().size() > 0, "bubbles rise from it")
	check(view.bits().all(func(b): return b == b.round()), "and every bubble, drop and grain of sand sits on a whole pixel")
	_done(s)


func test_settling_stirs_up_the_sand() -> void:
	var s := _coast()
	s.methods.use()
	var trap: Dictionary = Game.state["traps"][0]
	var view: TrapView = s.methods.traps_view
	var bed := _bed(s, float(trap["x"]))
	var puffed := false
	for i in 30 * 15:
		view.step(FRAME)
		if absf(float(view.pot_at(trap)["at"].y) - bed) < 0.01:
			puffed = puffed or view.bits().any(func(b): return b.y > bed - 8.0 and b.y < bed + 2.0)
	check(puffed, "a little puff of silt rises where it lands")
	_done(s)


func test_the_camera_follows_a_pot_down() -> void:
	var s := _coast()
	s.boat_x = 900.0
	s.methods.use()
	var trap: Dictionary = Game.state["traps"][0]
	var deepest := -INF
	for i in 30 * 12:
		s._process(FRAME)
		deepest = maxf(deepest, s.camera.cam.y)
	check(_bed(s, float(trap["x"])) - deepest <= Nav.view().y, "the view goes down with it until the bed is on screen")
	_done(s)


func test_a_pot_lifted_on_its_way_down_comes_back_up() -> void:
	var s := _coast()
	s.methods.use()
	var trap: Dictionary = Game.state["traps"][0]
	var view: TrapView = s.methods.traps_view
	for i in 45:
		view.step(FRAME)
	var was := float(view.pot_at(trap)["at"].y)
	s.methods.use()
	check(Game.state["traps"].is_empty(), "the pot is lifted at once")
	view.step(FRAME)
	check(absf(float(view.pot_at(trap)["at"].y) - was) < 3.0, "it is hauled up from where it had sunk to")
	for i in 30 * 15:
		view.step(FRAME)
	check(view.pot_at(trap).is_empty() and _said("Lifted the pot"), "and taken into the boat")
	_done(s)


func test_leaving_tells_of_a_pot_still_coming_up() -> void:
	var s := _coast()
	_full_pot(s)
	s.methods.use()
	s.prepare_to_leave()
	check(_said("Lifted the pot"), "the catch is told as the boat sails off")
	_done(s)
