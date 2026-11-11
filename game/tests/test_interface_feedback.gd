extends "res://tests/test_case.gd"
## Feedback on the interface: whole slider tracks, achievements in the bottom right corner and the catch banner.


func _clear() -> void:
	for c in Nav.ui.get_children():
		c.free()


func test_a_slider_track_is_whole_along_its_bottom() -> void:
	var t := UiTheme.build()
	for style in ["slider", "grabber_area", "grabber_area_highlight"]:
		var box: StyleBoxTexture = t.get_stylebox(style, "HSlider")
		var img := box.texture.get_image()
		var mid := img.get_width() / 2
		var top := img.get_pixel(mid, 0)
		var bottom := img.get_pixel(mid, img.get_height() - 1)
		check(top.a > 0.9 and bottom.is_equal_approx(top), "%s: the track's bottom edge is as dark as its top, not %s against %s" % [style, bottom, top])
		check(box.get_minimum_size().y == img.get_height(), "%s: it is drawn at its full height" % style)
		check(img.get_height() % 2 == 1, "%s: an odd number of rows, so it sits centred on the knob" % style)
	var slider := HSlider.new()
	slider.theme = t
	Nav.ui.add_child(slider)
	var knob: Texture2D = t.get_icon("grabber", "HSlider")
	check(slider.get_combined_minimum_size().y >= knob.get_height(), "the slider is as tall as its knob")
	slider.free()


func _cards() -> Array:
	return Nav.ui.get_children().filter(func(c): return c.has_meta("achievement"))


func test_an_achievement_slides_in_at_the_bottom_right() -> void:
	_clear()
	Game.new_game("Test", "mutt")
	var s: Node = load("res://scripts/coast/coast_screen.gd").new()
	Nav.port.add_child(s)
	s.enter({"place": "harbour"})
	AchievementCard.show_earned("first_fish")
	AchievementCard.show_earned("first_fish")
	var cards := _cards()
	check(cards.size() == 2, "each achievement has its card")
	var view := Nav.ui_view()
	for card in cards:
		card.reset_size()
		check(card.position.x >= view.x, "a card starts past the right edge, at %s" % card.position)
		var rest: Vector2 = card.get_meta("rest")
		var shown := Rect2(rest, card.size)
		check(absf(view.x - 4.0 - shown.end.x) < 0.01, "and comes to rest in the bottom right corner, %s" % shown)
		for b in Nav.ui.find_children("*", "Button", true, false):
			if b.is_visible_in_tree():
				check(not shown.intersects(b.get_global_rect()), "above the buttons along the bottom, clear of %s" % b.get_global_rect())
	check(cards[0].get_meta("shown", false) and not cards[1].get_meta("shown", false), "the second waits while the first is shown")
	cards[0].free()
	check(cards[1].get_meta("shown", false), "and slides in when the first has gone, so they take turns")
	_clear()
	s.free()


func test_an_achievement_waits_for_the_catch_banner() -> void:
	_clear()
	Game.new_game("Test", "mutt")
	CatchCard.show_catch("bream", 2.0, true)
	AchievementCard.show_earned("first_fish")
	var card: Control = _cards()[0]
	check(not card.get_meta("shown", false), "a card earned with a catch waits while the banner is hung out")
	CatchCard._open.free()
	await Nav.get_tree().create_timer(0.3).timeout
	check(card.get_meta("shown", false), "and slides in once the banner has gone")
	_clear()


func _texts(n: Node) -> String:
	return " ".join(n.find_children("*", "Label", true, false).map(func(l): return l.text))


func _pictures(card: Control) -> Array:
	return card.find_children("*", "TextureRect", true, false).map(func(r): return r.texture)


func test_a_catch_is_hung_out_on_a_banner() -> void:
	_clear()
	CatchCard.show_catch("mullet", 1.2, true)
	var card: Control = CatchCard._open
	var words := _texts(card)
	check("MULLET" in words, "the banner names the fish: %s" % words)
	check("0.54 kg" in words and Catalog.grade("mullet", 1.2) in words.to_lower(), "with its weight and grade: %s" % words)
	check("NEW" in words.to_upper(), "and says it is new to the logbook")
	var shown := _pictures(card)
	for part in [CatchCard.TOP, CatchCard.CLOTH]:
		check(part in shown, "the linen banner is hung out whole: %s" % part.resource_path)
	check(card.get_meta("mark", false) and CatchCard.STAR in shown, "a little painted star marks a new fish")
	var pic: TextureRect = card.find_child("Fish", true, false)
	check(pic != null and pic.texture == load("res://assets/art/fish_banner/mullet.png"), "the fish's own picture, drawn larger, is on it")
	_clear()
	CatchCard.show_catch("mullet", 1.2, false)
	card = CatchCard._open
	check(not card.get_meta("mark", true) and not CatchCard.STAR in _pictures(card), "a fish caught before has no star")
	check(not "NEW" in _texts(card).to_upper(), "and no note")
	_clear()
	CatchCard.show_catch("great_tuna", 300.0, false)
	card = CatchCard._open
	check("LEGEND" in _texts(card).to_upper() and CatchCard.STAR in _pictures(card), "a legend is hailed as one and marked with the star")
	_clear()


func test_the_banner_is_a_humble_size() -> void:
	check(CatchCard.SIZE.x <= 232.0 * 0.8 and CatchCard.SIZE.y <= 188.0 * 0.8, "about a quarter smaller than 232 by 188, %s" % CatchCard.SIZE)
	check(CatchCard.SIZE.x >= 232.0 * 0.7 and CatchCard.SIZE.y >= 188.0 * 0.7, "and not much smaller than that, %s" % CatchCard.SIZE)
	check(CatchCard.TOP.get_width() == CatchCard.SIZE.x, "the pole spans the banner")
	check(CatchCard.HANG.x * 2.0 + CatchCard.CLOTH.get_width() == CatchCard.SIZE.x, "the cloth hangs in the middle of it")
	check(CatchCard.HANG.y + CatchCard.CLOTH.get_height() == CatchCard.SIZE.y, "and reaches its foot")


func test_every_picture_on_the_banner_is_one_texel_to_a_pixel() -> void:
	_clear()
	for id in ["sardine", "anchovy", "tuna", "swordfish", "neptune_lobster", "sleeping_sunfish", "misenum_swordfish"]:
		CatchCard.show_catch(id, float(Data.fish[id]["pounds"][1]), true)
		var card: Control = CatchCard._open
		var pic: TextureRect = card.find_child("Fish", true, false)
		check(pic != null and pic.size == pic.texture.get_size(), "%s: the fish is drawn at its own size, %s" % [id, pic.size if pic else null])
		for r: TextureRect in card.find_children("*", "TextureRect", true, false):
			check(r.size == r.texture.get_size() and r.scale == Vector2.ONE, "%s: %s is never stretched" % [id, r.texture.resource_path])
		card.free()


func test_the_banner_is_drawn_in_the_game_s_own_pixels() -> void:
	_clear()
	var before := Windowing.get_window().size
	for size in [Vector2i(1440, 810), Vector2i(1920, 1080), Vector2i(2560, 1377)]:
		Windowing.get_window().size = size
		Windowing._process(0.0)
		for step in [-1, 0, 1]:
			Settings.interface_size = step
			Windowing._fit()
			CatchCard.show_catch("bream", 2.0, true)
			var card: Control = CatchCard._open
			var px := card.get_global_transform().get_scale() * Nav.ui_layer.transform.get_scale()
			check(px.is_equal_approx(Vector2.ONE), "%s at %d: a banner pixel is one game pixel, not %s" % [size, step, px])
			card.free()
	Settings.interface_size = -1
	Windowing._fit()
	Windowing.get_window().size = before
	Windowing._process(0.0)
	_clear()


## The rows of each kind of line's capitals, below the top of its label.
func _caps(l: Label) -> Vector2:
	return {"Title": CatchCard.NAME_CAPS, "LightLabel": CatchCard.LINE_CAPS, "LightHeading": CatchCard.NOTE_CAPS}[l.theme_type_variation]


func test_every_catch_banner_fits_the_smallest_interface() -> void:
	_clear()
	for id in Data.fish:
		CatchCard.show_catch(id, float(Data.fish[id]["pounds"][1]), true)
		var card: Control = CatchCard._open
		var size := CatchCard.SIZE * card.scale
		check(size.x <= Nav.UI_LEAST.x - 8.0 and size.y <= Nav.UI_LEAST.y - 8.0, "%s: the banner fits the smallest interface, %s" % [id, size])
		var pic: TextureRect = card.find_child("Fish", true, false)
		check(pic != null, "%s: the fish is shown on the cloth" % id)
		var below := 0.0
		if pic:
			check(CatchCard.INSIDE.encloses(Rect2(pic.position, pic.size)), "%s: the fish lies inside the cloth's painted border, %s" % [id, Rect2(pic.position, pic.size)])
		var lines := card.find_children("*", "Label", true, false)
		check(lines.size() == 3, "%s: the name, the weight and grade, and the note" % id)
		for l: Label in lines:
			check(l.get_combined_minimum_size().x <= CatchCard.INSIDE.size.x, "%s: '%s' fits across the cloth" % [id, l.text])
			var caps := _caps(l)
			var rows := l.get_line_count()
			var tall := caps.y * rows + CatchCard.NAME_GAP * (rows - 1)
			var top := l.position.y + caps.x
			check(top >= CatchCard.INSIDE.position.y and top + tall <= CatchCard.INSIDE.end.y, "%s: '%s' lies inside the cloth's painted border" % [id, l.text])
			if l.theme_type_variation == "Title" and pic:
				check(top + tall < pic.position.y, "%s: the name is above the fish" % id)
			elif pic:
				check(top > pic.position.y + pic.size.y, "%s: '%s' is below the fish" % [id, l.text])
		card.free()


func test_the_banner_fits_every_interface_size() -> void:
	_clear()
	var before := Windowing.get_window().size
	for size in [Vector2i(1440, 810), Vector2i(1280, 800), Vector2i(1920, 1080), Vector2i(2560, 1377)]:
		Windowing.get_window().size = size
		Windowing._process(0.0)
		for step in [-1, 0, 1]:
			Settings.interface_size = step
			Windowing._fit()
			for id in ["misenum_swordfish", "sleeping_sunfish", "anchovy"]:
				CatchCard.show_catch(id, float(Data.fish[id]["pounds"][1]), true)
				var card: Control = CatchCard._open
				var tw: Tween = card.get_meta("tween")
				tw.custom_step(0.9)
				check(Rect2(Vector2.ZERO, Nav.ui_view()).encloses(card.get_global_rect()), "%s at %d, %s: the banner is all on screen, %s in %s" % [size, step, id, card.get_global_rect(), Nav.ui_view()])
				card.free()
	Settings.interface_size = -1
	Windowing._fit()
	Windowing.get_window().size = before
	Windowing._process(0.0)
	_clear()


func test_the_desktop_strip_tells_a_catch_in_one_line() -> void:
	_clear()
	Windowing.strip = true
	CatchCard.show_catch("mullet", 1.2, true)
	Windowing.strip = false
	check(not CatchCard.is_open(), "no banner, which the strip is too short for")
	var box: Control = Toast._box
	var said := " ".join(box.get_children().map(func(l): return l.text)) if is_instance_valid(box) else ""
	check("Red mullet, 0.54 kg" in said and "New in your logbook" in said, "a line names the fish, its weight and that it is new: %s" % said)
	_clear()


func test_the_frayed_edge_sways() -> void:
	_clear()
	CatchCard.show_catch("bream", 2.0, false)
	var swaying := CatchCard._open.find_children("*", "TextureRect", true, false).filter(func(r):
		return r.material is ShaderMaterial and r.material.shader == CatchCard.SWAY)
	check(swaying.map(func(r): return r.texture) == [CatchCard.CLOTH], "the cloth's frayed foot sways")
	if swaying.size() == 1:
		var from: float = swaying[0].material.get_shader_parameter("from_row")
		check(from >= CatchCard.INSIDE.end.y, "below the words and the fish, which stay still, from row %s" % from)
	_clear()


func test_the_banner_unfurls() -> void:
	_clear()
	CatchCard.show_catch("bream", 2.0, false)
	var card: Control = CatchCard._open
	var cloth: Control = card.find_child("Hang", true, false)
	var full: float = cloth.get_meta("full")
	check(cloth.size.y < full * 0.2, "the cloth starts rolled up under the pole")
	var tw: Tween = card.get_meta("tween")
	tw.custom_step(0.9)
	check(is_equal_approx(cloth.size.y, full), "and has unfurled within a second, %s of %s" % [cloth.size.y, full])
	_clear()


func test_the_banner_stays_up_a_second_longer() -> void:
	_clear()
	CatchCard.show_catch("bream", 2.0, false)
	var card: Control = CatchCard._open
	var cloth: Control = card.find_child("Hang", true, false)
	var tw: Tween = card.get_meta("tween")
	tw.custom_step(4.9)
	check(is_equal_approx(cloth.size.y, cloth.get_meta("full")) and not card.is_queued_for_deletion(),
		"still hung out 4.9 seconds on, a second past when it used to have rolled up and gone")
	tw.custom_step(0.6)
	check(card.is_queued_for_deletion(), "and rolled up and gone by 5.5 seconds")
	_clear()
