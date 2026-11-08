extends "res://tests/test_case.gd"
## The little fish of the shoals take a small bait on the line now and then, without crowding out the rest.

const LITTLE := ["sardine", "anchovy", "sand_smelt", "picarel"]


func test_a_little_fish_takes_a_worm_but_seldom() -> void:
	Game.new_game("Test", "hound")
	for id in LITTLE:
		var little := Bite.chance(id, "worm", 0.0)
		check(little > 0.0, "%s takes a worm on the line" % id)
		check(little < Bite.chance("mullet", "worm", 0.0) * 0.2, "but a fish of a shoal is far slower to take it than a mullet")


func test_little_fish_bite_by_the_shore() -> void:
	Game.new_game("Test", "hound")
	var bed := Seabed.new(Data.places["harbour"]["seabed"])
	var sw := Swimmers.new()
	sw.setup("harbour", bed, Seeds.rng(3, "little"))
	Nav.port.add_child(sw)
	sw.cam = Vector2(60, -160)
	sw.hour = 9.0
	var count := {"little": 0, "all": 0}
	sw.bit.connect(func(f):
		count["all"] += 1
		if f["id"] in LITTLE:
			count["little"] += 1
		sw.release(f, true))
	sw.populate()
	for i in 6000:
		sw.step(0.1, Vector2(300, 58), "worm")
	check(count["little"] >= 2, "in ten minutes by the shore the little fish take the worm %d times" % count["little"])
	check(count["all"] <= 60, "and the bites still come some seconds apart, not all at once: %d" % count["all"])
	sw.free()


func test_fishing_on_his_own_is_not_all_little_fish() -> void:
	var got := Idle.catches(6000.0, "harbour", 60.0, "worm", 1000, Seeds.rng(1, "idle little"), 9.0, "spring", "clear", 120.0)
	var little := got.filter(func(c): return c["fish"] in LITTLE).size()
	check(little > 0 and little < got.size() * 0.35, "a few of his catches are little fish, %d of %d" % [little, got.size()])
