extends "res://tests/test_case.gd"


## How far a colour is from grey, whatever its brightness.
func _chroma(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))


func test_the_seabed_is_smooth_sand() -> void:
	for p in Data.places.values():
		var img := (load("res://assets/art/" + str(p["floor"]["file"])) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		var bright := 0
		var coloured := 0
		var rim := 0.0
		var body := 0.0
		for x in img.get_width():
			var top := 0
			while top < img.get_height() and img.get_pixel(x, top).a < 0.5:
				top += 1
			rim += img.get_pixel(x, top).get_luminance()
			body += img.get_pixel(x, top + 8).get_luminance()
			for y in range(top, img.get_height()):
				var c := img.get_pixel(x, y)
				# Only the band of sand above where it darkens into the ground is seen as sand.
				if y < top + 16 and _chroma(c) > 0.08:
					coloured += 1
				# A pebble or a shell is a pixel much brighter than the sand just above and below it.
				if y > top + 2 and y < img.get_height() - 2:
					var around := (img.get_pixel(x, y - 2).get_luminance() + img.get_pixel(x, y + 2).get_luminance()) / 2.0
					if c.get_luminance() > around + 0.09:
						bright += 1
		check(bright == 0, "%s: no pebbles or shells stand out of the sand (%d)" % [p["id"], bright])
		check(coloured == 0, "%s: the sand is a soft grey (%d coloured pixels)" % [p["id"], coloured])
		check(rim > body, "%s: its top edge is lighter than the sand below" % p["id"])
