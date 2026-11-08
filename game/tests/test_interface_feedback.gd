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
	AchievementCard._free_at = 0.0
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
	check(cards[1].get_meta("wait") >= 3.0, "the second waits for the first to go, so they take turns")
	_clear()
	s.free()
