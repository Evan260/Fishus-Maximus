extends "res://tests/test_case.gd"
## The sixth round of feedback: the rowing view, the long cast, the boat's keel, big fish in deep water and the map.


func test_picking_the_place_you_are_at_keeps_the_boat_where_it_lies() -> void:
	Game.new_game("Test", "hound")
	Game.state["boat_x"] = 640.0
	check(BayMap.sail(Game.state, "harbour"), "you may pick the place you are at")
	check(float(Game.state["boat_x"]) == 640.0, "and the boat stays where it lay, not back at the jetty")


func test_the_stowed_rod_lies_below_the_gunwale() -> void:
	var b := BoatView.new()
	b.set_boat("skiff")
	b.rowing = 1.0
	b.place(100.0, Vector2.ZERO, 0.0)
	check(b.pose()[0] == "row", "he is rowing")
	check(b.rod_tip(100.0).y > -b.ride + b.bob + b.deck + 1.0, "the rod lies down inside the hull, out of sight, not across its top")
	b.free()
