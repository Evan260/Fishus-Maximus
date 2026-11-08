extends "res://tests/test_case.gd"
## The sixth round of feedback: the rowing view, the long cast, the boat's keel, big fish in deep water and the map.

const BOATS := ["skiff", "fishing_boat", "sailing_boat", "big_boat"]


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


## The lowest painted row of each column of a picture, or -1 where the column is empty.
func _bottoms(img: Image) -> Array:
	var out := []
	for x in img.get_width():
		var b := -1
		for y in img.get_height():
			if img.get_pixel(x, y).a > 0.5:
				b = y
		out.append(b)
	return out


func test_every_hull_is_rounded_underneath() -> void:
	for id in BOATS:
		var img: Image = load("res://assets/art/props/%s.png" % id).get_image()
		var bottoms := _bottoms(img)
		var lowest: int = bottoms.max()
		var deep: Array = range(bottoms.size()).filter(func(x): return bottoms[x] >= lowest - 1)
		check(deep.size() < img.get_width() * 0.45, "%s: the keel is deepest only near the middle, not flat along %d of %d columns" % [id, deep.size(), img.get_width()])
		var left: int = bottoms.find(bottoms.filter(func(b): return b >= 0)[0])
		var w: int = bottoms.size() - left
		var near_end: int = bottoms[left + int(w * 0.12)]
		check(lowest - near_end >= 3, "%s: towards its end the hull curves up, by %d rows" % [id, lowest - near_end])
