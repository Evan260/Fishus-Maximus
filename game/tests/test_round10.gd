extends "res://tests/test_case.gd"
## The tenth round of feedback: the boat's sounds, its oar and its height, and never being left without a way to fish.


func test_the_lapping_hull_is_gone() -> void:
	check(not ResourceLoader.exists("res://assets/audio/ambience/sea.ogg"), "the noisy recording of waves on a hull is gone")
	for path in ["res://scripts/coast/coast_screen.gd", "res://scripts/screens/title.gd", "res://scripts/shore/shore_screen.gd"]:
		check(not "\"sea\":" in FileAccess.get_file_as_string(path), "%s no longer plays it" % path.get_file())


func test_the_oar_comes_out_of_the_water_between_strokes() -> void:
	var b := BoatView.new()
	b.set_boat("skiff")
	var above := 0
	var below := 0
	for i in 90:
		b.rowing = 1.0
		b._process(1.0 / 30.0)
		b.place(100.0, Vector2(0, -160), i / 30.0)
		var blade: Vector2 = b._oar()[0]
		if blade.y < -1.0:
			above += 1
		elif blade.y > 4.0:
			below += 1
		check((blade - b._oar()[2]).length() <= BoatView.OAR_OUT + 0.5, "the oar never grows longer as it swings")
	check(above >= 20 and below >= 30, "the blade pulls through the water and lifts clear of it to swing back: %d up, %d down" % [above, below])
	b.free()
