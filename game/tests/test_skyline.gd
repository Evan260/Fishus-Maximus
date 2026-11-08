extends "res://tests/test_case.gd"
## Every row of land ends against the sky on crisp, whole pixels: never cut by the picture's top edge, never faded.


func _land(p: Dictionary) -> Array:
	var factors: Array = p["layers"].filter(func(l): return l.has("band")).map(func(l): return l["factor"])
	return p["layers"].filter(func(l): return l.has("file") and l.has("at") and factors.has(l.get("factor")))


## The most columns side by side whose topmost pixel is see-through, as along a skyline faded into the sky.
func _softest_run(img: Image) -> int:
	var best := 0
	var run := 0
	for x in img.get_width():
		var soft := false
		for y in img.get_height():
			var a := img.get_pixel(x, y).a
			if a > 0.01:
				soft = a < 0.98
				break
		run = run + 1 if soft else 0
		best = maxi(best, run)
	return best


func test_no_skyline_fades_into_the_sky() -> void:
	for p in Data.places.values():
		for l in _land(p):
			var img: Image = (load("res://assets/art/" + str(l["file"])) as Texture2D).get_image()
			img.decompress()
			check(_softest_run(img) <= 6, "%s: %s ends against the sky on solid pixels, not a faded band (%d columns)" % [p["id"], l["file"], _softest_run(img)])


func test_no_land_runs_up_to_its_picture_top() -> void:
	for p in Data.places.values():
		for l in _land(p):
			var img: Image = (load("res://assets/art/" + str(l["file"])) as Texture2D).get_image()
			img.decompress()
			var touching := 0
			for x in img.get_width():
				if img.get_pixel(x, 0).a > 0.01:
					touching += 1
			check(touching == 0, "%s: %s has sky above all of its land, so no top is cut off (%d columns touch)" % [p["id"], l["file"], touching])
