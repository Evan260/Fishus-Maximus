extends "res://tests/test_case.gd"
## The eleventh round of feedback: fish drawn at their own pixels, a biting fish's mouth on the bait, fish that swim in
## rather than appear, the hook hanging straight under its drifting float, no casting while rowing, and a splash that
## shows when a fish leaps.


func _sea(seed_name: String) -> Swimmers:
	Game.new_game("Test", "hound")
	var sw := Swimmers.new()
	sw.setup("harbour", Seabed.new(Data.places["harbour"]["seabed"]), Seeds.rng(3, seed_name))
	Nav.port.add_child(sw)
	sw.cam = Vector2(200, -160)
	sw.hour = 9.0
	return sw


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


func test_fish_are_drawn_at_their_own_pixels() -> void:
	var sw := _sea("pixels")
	sw.populate()
	for i in 50:
		sw.step(0.1, null, "")
	check(not sw.fish.is_empty(), "there are fish to look at")
	for f in sw.fish:
		var s: Sprite2D = f["sprite"]
		check(is_equal_approx(s.scale.y, 1.0), "%s is drawn one texel to a pixel, not stretched by %.2f into doubled rows" % [f["id"], s.scale.y])
	sw.free()


func test_the_mouth_is_the_front_of_the_fish() -> void:
	var sw := _sea("mouth")
	for id in ["mullet", "bream", "sardine", "sea_bass"]:
		if not Data.fish.has(id):
			continue
		var tex := sw.texture_for(id)
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		var m := Swimmers.mouth_of(tex)
		var px := Vector2i(floori(m.x - 0.5 + tex.get_width() / 2.0), floori(m.y + tex.get_height() / 2.0))
		check(img.get_pixelv(px).a > 0.5, "%s's mouth is on the fish, at texel %s" % [id, px])
		var ahead := false
		for x in range(px.x + 1, tex.get_width()):
			for y in tex.get_height():
				ahead = ahead or img.get_pixel(x, y).a > 0.5
		check(not ahead, "%s's mouth is at its very front" % id)
	sw.free()


func test_a_biting_fish_has_its_mouth_on_the_bait() -> void:
	var sw := _sea("bite")
	var hook := Vector2(300, 58)
	var got := {"fish": {}}
	sw.bit.connect(func(f):
		if got["fish"].is_empty():
			got["fish"] = f)
	sw.populate()
	for i in 6000:
		sw.step(0.1, hook, "worm")
		if not got["fish"].is_empty():
			break
	var f: Dictionary = got["fish"]
	check(not f.is_empty(), "a fish comes to the worm")
	if f.is_empty():
		sw.free()
		return
	var bait := hook + Swimmers.BAIT_MIDDLE
	check(Swimmers.mouth_at(f).distance_to(bait) <= 2.0, "its mouth is on the bait: %s against %s" % [Swimmers.mouth_at(f), bait])
	var moved := hook + Vector2(3, 0)
	for i in 10:
		sw.step(0.1, moved, "worm")
	check(Swimmers.mouth_at(f).distance_to(moved + Swimmers.BAIT_MIDDLE) <= 2.0, "and stays on it as the float drifts the hook along")
	sw.free()


func test_new_fish_swim_in_from_outside_the_view() -> void:
	var sw := _sea("arrive")
	sw.populate()
	var known := {}
	for f in sw.fish:
		known[f["sprite"]] = true
	var view := Nav.view()
	var sprung := 0
	var arrived := 0
	for i in 3000:
		sw.cam.x = 200.0 + 600.0 * sin(i * 0.002)
		sw.step(0.1, null, "")
		for f in sw.fish:
			if known.has(f["sprite"]):
				continue
			known[f["sprite"]] = true
			arrived += 1
			var s: Sprite2D = f["sprite"]
			var half := s.texture.get_width() / 2.0
			if s.position.x + half > 0.0 and s.position.x - half < view.x:
				sprung += 1
	check(arrived > 5, "fish keep coming as the boat moves along, %d of them" % arrived)
	check(sprung == 0, "and every one comes from outside the view; %d appeared in it" % sprung)
	sw.free()


func test_the_hook_hangs_straight_under_the_drifting_float() -> void:
	var s := _coast()
	s.cast(0.5)
	var xs := []
	for i in 1200:
		s._process(0.05)
		if s.line_state() in ["waiting", "sinking"] and s.flight <= 0.0:
			xs.append(s.hook.x)
		if s.line_state() == "nibble":
			s._let_go()
	var lo: float = xs.min()
	var hi: float = xs.max()
	check(hi - lo >= 2.0, "the hook drifts along with the float, %.0f pixels" % (hi - lo))
	check(hi - lo <= LineView.DRIFT * 2.0 + 1.0, "but no farther than the float does")
	check(xs.all(func(x): return is_equal_approx(x - roundf(x), xs[0] - roundf(xs[0]))), "a whole pixel at a time, so the line under the float stays straight")
	_done(s)


func test_no_cast_while_rowing() -> void:
	var s := _coast()
	s._process(0.1)
	check(s.line_state() == "reeled", "the line starts wound in")
	s._boat.rowing = 1.0
	check(s.rowing(), "he is rowing")
	for i in 20:
		s._click = true
		s._handle_input(0.05)
		s._boat.rowing = 1.0
	s._click = false
	s._handle_input(0.05)
	check(s.line_state() == "reeled" and s.charge < 0.0, "a click while he rows neither charges nor casts the line")
	_done(s)


func test_a_leap_throws_up_a_splash_that_shows() -> void:
	var small := LineView.splash_size(16)
	var big := LineView.splash_size(60)
	check(big > small and small >= 6.0, "a bigger fish throws up a bigger splash, %.0f against %.0f" % [big, small])
	var drops := LineView.splash_drops(big, 1.0, 0.25)
	var highest := 0.0
	for d in drops:
		highest = maxf(highest, -d.y)
	check(drops.size() >= 12, "it throws up a spray of drops, %d of them" % drops.size())
	check(highest >= big, "flung well clear of the water, %.0f pixels up" % highest)
	check(LineView.splash_drops(big, 1.0, LineView.SPLASH_SECONDS).all(func(d): return d.y >= 0.0), "and all of them fallen back in by its end")
	check(LineView.SPLASH_SECONDS >= 0.9, "lasting long enough to see")


func test_messages_start_below_the_info_panel() -> void:
	var s := _coast()
	Toast.say("Your pot sinks to the seabed.")
	var panel: Control = Nav.ui.find_child("InfoPanel", true, false)
	check(panel != null, "the coast has its info panel at the top left")
	if panel:
		var bottom := panel.position.y + panel.get_combined_minimum_size().y
		check(Toast._box.offset_top >= bottom, "the message starts at %.0f, below the panel's bottom at %.0f, so it is never written over it" % [Toast._box.offset_top, bottom])
	_done(s)
