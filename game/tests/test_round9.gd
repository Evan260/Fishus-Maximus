extends "res://tests/test_case.gd"
## The ninth round of feedback: the bait on the hook, the sea filled with fish from the start, the depth he fishes at
## on his own, birds over the bay, and fish spread out from the shore.


func test_each_bait_shows_on_the_hook_as_itself() -> void:
	var looks := {}
	for id in Data.bait:
		var px: Array = LineView.bait_pixels(id)
		check(px.size() >= 6, "%s shows on the hook as a small picture, not a single pixel" % id)
		looks[str(px)] = id
	check(looks.size() == Data.bait.size(), "and each bait looks different from the others")
	check(LineView.bait_pixels("").is_empty(), "a bare hook shows no bait")
