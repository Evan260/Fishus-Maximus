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


func test_a_catch_is_hung_out_on_a_banner() -> void:
	_clear()
	CatchCard.show_catch("mullet", 1.2, true)
	var card: Control = CatchCard._open
	var words := _texts(card)
	check("MULLET" in words, "the banner names the fish: %s" % words)
	check("1.2 lb" in words and Catalog.grade("mullet", 1.2) in words.to_lower(), "with its weight and grade: %s" % words)
	check("NEW" in words.to_upper(), "and says it is new to the logbook")
	check(card.get_meta("wreath", false), "a golden wreath crowns the staff for a new fish")
	var pic: TextureRect = card.find_child("Fish", true, false)
	check(pic != null and pic.texture == load("res://assets/art/fish/mullet.png"), "the fish's own picture is on it")
	if pic:
		var k := pic.size / pic.texture.get_size()
		check(k.x == k.y and k.x >= 2.0 and k.x == roundf(k.x), "drawn large, at a whole number of pixels each: %s" % k)
	_clear()
	CatchCard.show_catch("mullet", 1.2, false)
	card = CatchCard._open
	check(not card.get_meta("wreath", true) and not "NEW" in _texts(card).to_upper(), "a fish caught before has no wreath and no note")
	_clear()


func test_every_catch_banner_fits_the_smallest_interface() -> void:
	_clear()
	for id in Data.fish:
		CatchCard.show_catch(id, float(Data.fish[id]["pounds"][1]), true)
		var card: Control = CatchCard._open
		var size := Vector2(card.offset_right - card.offset_left, card.offset_bottom - card.offset_top)
		check(size.x <= Nav.UI_LEAST.x - 8.0 and size.y <= Nav.UI_LEAST.y - 8.0, "%s: the banner fits the smallest interface, %s" % [id, size])
		var pic: TextureRect = card.find_child("Fish", true, false)
		var box: Control = card.find_child("Tablet", true, false)
		if pic and box:
			check(Rect2(Vector2.ZERO, box.size).grow(1.0).encloses(Rect2(pic.position, pic.size)), "%s: the fish sits inside its tablet" % id)
		for l in card.find_children("*", "Label", true, false):
			check(l.get_combined_minimum_size().x <= card.find_child("Cloth", true, false).size.x, "%s: '%s' fits across the cloth" % [id, l.text])
		card.free()


func test_the_banner_unfurls() -> void:
	_clear()
	CatchCard.show_catch("bream", 2.0, false)
	var card: Control = CatchCard._open
	var cloth: Control = card.find_child("Hang", true, false)
	var full: float = cloth.get_meta("full")
	check(cloth.size.y < full * 0.2, "the cloth starts rolled up under the crossbar")
	var tw: Tween = card.get_meta("tween")
	tw.custom_step(0.9)
	check(is_equal_approx(cloth.size.y, full), "and has unfurled within a second, %s of %s" % [cloth.size.y, full])
	_clear()
