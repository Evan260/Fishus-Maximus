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

