extends "res://tests/test_case.gd"
## The tenth round of feedback: the boat's sounds, its oar and its height, and never being left without a way to fish.


func test_the_lapping_hull_is_gone() -> void:
	check(not ResourceLoader.exists("res://assets/audio/ambience/sea.ogg"), "the noisy recording of waves on a hull is gone")
	for path in ["res://scripts/coast/coast_screen.gd", "res://scripts/screens/title.gd", "res://scripts/shore/shore_screen.gd"]:
		check(not "\"sea\":" in FileAccess.get_file_as_string(path), "%s no longer plays it" % path.get_file())
