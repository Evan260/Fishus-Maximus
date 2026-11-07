extends "res://tests/test_case.gd"
## The game drawn at the window's resolution so things move by fractions of a game pixel, the fish swimming naturally,
## a hooked fish leaping, and a fish caught by him on his own brought in on the line.

const STEP := 1.0 / 30.0


func _clear_ui() -> void:
	for c in Nav.ui.get_children():
		c.free()


func _swimmers() -> Swimmers:
	var w := Swimmers.new()
	w.setup("harbour", Seabed.new(Data.places["harbour"]["seabed"]), Seeds.rng(1, "w"))
	return w


func _fish(w: Swimmers, at: Vector2, heading := 1.0) -> Dictionary:
	var s := Sprite2D.new()
	w.add_child(s)
	return {"id": "mullet", "lb": 1.0, "sprite": s, "pos": at, "heading": heading, "phase": 0.0, "speed": 10.0,
		"band": Data.fish["mullet"]["depth"], "goal_y": at.y, "turn": 100.0, "look": 1.0, "state": "swim", "leader": {}, "group": 1}


func _hooked() -> Node:
	_clear_ui()
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	s.cast(0.5)
	for i in 600:
		s.sink(STEP)
	s._on_bite({"id": "mullet", "lb": 1.0, "state": "bit", "heading": 1.0})
	while s.line_state() == "nibble":
		s.bite_step(0.05)
	s.strike()
	return s


func _done(s: Node) -> void:
	_clear_ui()
	s.free()


func _told(text: String) -> bool:
	return is_instance_valid(Toast._box) and Toast._box.get_children().any(func(l): return text in l.text)


func test_the_game_is_drawn_at_the_windows_resolution() -> void:
	var win := Windowing.get_window()
	var before := win.size
	win.size = Vector2i(1440, 810)
	Windowing._process(0.0)
	check(Nav.view() == Vector2(480, 270) and Nav.zoom == 3, "a 1440 by 810 window shows 480 by 270 game pixels, not %s" % Nav.view())
	check(Vector2(Nav.port.size) == Nav.view() * Nav.zoom, "and the port draws every window pixel of it, not %s" % Nav.port.size)
	win.size = before
	Windowing._process(0.0)


func test_a_fish_sits_between_game_pixels() -> void:
	var w := _swimmers()
	var f := _fish(w, Vector2(600.3, 60.7))
	w._move(f, STEP, null)
	var s: Sprite2D = f["sprite"]
	check(s.position.is_equal_approx(f["pos"] - w.cam) and not s.position.is_equal_approx(s.position.round()), "a fish is drawn where it is, not on the nearest game pixel")
	w.free()


func test_a_fish_eases_round_to_turn() -> void:
	var w := _swimmers()
	var f := _fish(w, Vector2(600, 60))
	w._move(f, STEP, null)
	f["vel"] = Vector2(10, 0)
	f["pace_left"] = 100.0
	f["heading"] = -1.0
	var slowed := false
	var narrowest := 1.0
	var flipped_at := INF
	for i in 150:
		var was: Vector2 = f["pos"]
		w._move(f, STEP, null)
		slowed = slowed or absf(f["vel"].x) < 5.0
		narrowest = minf(narrowest, f["width"])
		if f["face"] < 0.0 and flipped_at == INF:
			flipped_at = (f["pos"].x - was.x) / STEP
	check(f["vel"].x < -8.0 and slowed, "it slows, stops and speeds up the other way instead of reversing at once")
	check(flipped_at <= 0.5, "it faces the new way once it is swimming that way")
	check(narrowest < 0.6 and is_equal_approx(f["width"], 1.0), "it narrows as it comes round and is its full width after")
	w.free()


func test_a_fish_curves_and_changes_its_pace() -> void:
	var w := _swimmers()
	var f := _fish(w, Vector2(600, 80))
	var ys := []
	var speeds := []
	for i in 30 * 30:
		w._move(f, STEP, null)
		ys.append(f["pos"].y)
		speeds.append(absf(f["vel"].x))
	check(ys.max() - ys.min() > 3.0, "it rises and dips as it swims, not in a straight line")
	check(speeds.max() - speeds.min() > 4.0, "and speeds up and slows down")
	w.free()


func test_a_shoal_stays_together() -> void:
	var w := _swimmers()
	var leader := _fish(w, Vector2(600, 60))
	var rest := []
	for i in 4:
		var one := _fish(w, Vector2(600, 60) + Vector2(-12 * (i + 1), 4 * i))
		one["leader"] = leader
		one["offset"] = Vector2(-12 * (i + 1), 4 * i)
		rest.append(one)
	var apart := 0.0
	for i in 30 * 30:
		w._move(leader, STEP, null)
		for one in rest:
			w._move(one, STEP, null)
			if i > 90:
				apart = maxf(apart, one["pos"].distance_to(leader["pos"] + one["offset"]))
	check(apart < 20.0, "every fish of a shoal keeps near its place in it, at most %.1f pixels off" % apart)
	w.free()


func test_a_fish_that_likes_the_bait_comes_to_it_and_bites() -> void:
	Game.new_game("Test", "mutt")
	var w := _swimmers()
	var bait := Vector2(600, 100)
	w.cam = bait - Vector2(240, 135)
	var f := _fish(w, bait + Vector2(-60, -10))
	f["look"] = 0.0
	w.fish.append(f)
	var got := []
	w.bit.connect(func(fish): got.append(fish))
	for i in 60 * 30:
		w.step(STEP, bait, "worm")
		if not got.is_empty():
			break
	check(not got.is_empty(), "a fish that likes the worm notices it, swims over and takes it")
	for one in w.fish:
		one["sprite"].free()
	w.free()


func test_a_leaping_fish_clears_the_water_and_comes_back_to_the_hook() -> void:
	var s := _hooked()
	check(s.line_state() == "fighting", "a fish is on")
	s.hook = Vector2(s.hook.x, 20.0)
	var line: LineView = s._line
	var distance: float = s.fight.distance
	line._process(STEP)
	line._leap = 0.0
	line._leap_height = 20.0
	var highest := INF
	var splashes := 0
	for i in int((LineView.LEAP_SECONDS + 20.0 * LineView.LEAP_PER_DEPTH) / STEP) + 2:
		var before := line._splashes.size()
		line._process(STEP)
		splashes += maxi(0, line._splashes.size() - before)
		highest = minf(highest, line.fish_at().y)
	check(highest < -10.0, "it leaps clear of the water, to %.1f" % highest)
	check(splashes == 2, "with a splash where it leaves the water and where it goes back in, not %d" % splashes)
	check(not line.leaping(), "and it is over in under a second")
	check(s.fight.distance == distance, "the leap is only the picture: the fight is as it was")
	for i in 60:
		line._process(STEP)
	check(line.fish_at().distance_to(s.hook) < 6.0, "after it the fish is back on the hook")
	_done(s)


func test_a_fish_caught_on_his_own_comes_in_on_the_line() -> void:
	_clear_ui()
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	s.methods.set_idle(true)
	for i in 120:
		s._process(STEP)
	check(s.line_state() in ["sinking", "waiting"], "he casts by himself")
	for i in 600:
		s.sink(STEP)
	var held: int = Game.state["hold"].size()
	for i in 40:
		s.methods._idle_step(3.0)
		if s.line_state() == "taken":
			break
	check(s.line_state() == "taken" and s.landing != "", "when he catches one the float goes under")
	check(Game.state["hold"].size() > held, "the catch is kept at once")
	check(not _told("+ "), "but not told of until it is in the boat")
	var depth: float = s.hook.y
	var rose := false
	for i in 30 * 10:
		s._process(STEP)
		rose = rose or (s.line_state() == "landing" and s.hook.y < depth - 10.0)
		if s.line_state() == "reeled":
			break
	check(rose and s.line_state() == "reeled", "he brings it in on the line to the boat")
	s._process(STEP)
	check(_told("+ "), "and then it is told of")
	for i in int(CoastMethods.RECAST_AFTER / STEP) + 30:
		s._process(STEP)
	check(s.line_state() in ["sinking", "waiting"] or not s.methods.idle, "and he casts again")
	_done(s)


func test_leaving_while_a_fish_comes_in_still_tells_of_it() -> void:
	_clear_ui()
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	s.methods.set_idle(true)
	s.cast(0.5)
	s.flight = 0.0
	for i in 40:
		s.methods._idle_step(3.0)
		if s.line_state() == "taken":
			break
	s.prepare_to_leave()
	check(_told("+ ") and not Game.state.has("idle"), "the fish on the line is told of as the boat leaves")
	_done(s)
