extends "res://tests/test_case.gd"


func test_fish_only_take_bait_they_like() -> void:
	check(Bite.chance("mullet", "worm", 10.0) > 0.0 and Bite.chance("mullet", "bread", 10.0) == 0.0, "mullet take worms, not bread")
	check(Bite.chance("mullet", "worm", 50.0) == 0.0, "nor from too far away")
	check(Bite.chance("mullet", "worm", 5.0) > Bite.chance("mullet", "worm", 30.0), "a bait right by the fish is likelier taken")
	check(is_equal_approx(Bite.window(), 1.0), "a second to strike")


func test_reeling_against_a_running_fish_snaps_the_line() -> void:
	var f := LineFight.new()
	f.setup("grouper", 30.0, {"pull": 1, "strength": 0.6, "hold": 1}, false, Seeds.rng(1, "f"))
	for i in 600:
		f.step(true, 1.0 / 30.0)
		if f.state != "fighting":
			break
	check(f.state == "snapped", "a big grouper on light line, reeled hard, breaks it")


func test_patience_lands_the_fish() -> void:
	var f := LineFight.new()
	f.setup("bream", 2.0, {"pull": 2, "strength": 0.8, "hold": 2}, false, Seeds.rng(1, "f"))
	var ticks := 0
	while f.state == "fighting" and ticks < 3000:
		f.step(f.resting(), 1.0 / 30.0)
		ticks += 1
	check(f.state == "landed", "reeling only while the fish rests lands it")


func test_a_slack_line_lets_the_hook_slip() -> void:
	var f := LineFight.new()
	f.setup("bream", 2.0, {"pull": 2, "strength": 0.8, "hold": 1}, false, Seeds.rng(2, "f"))
	for i in 900:
		f.step(false, 1.0 / 30.0)
		if f.state != "fighting":
			break
	check(f.state == "slipped", "never reeling, the fish shakes the hook")


func test_gentle_fishing_never_loses_a_fish() -> void:
	for seed in 20:
		var f := LineFight.new()
		f.setup("grouper", 30.0, {"pull": 1, "strength": 0.3, "hold": 1}, true, Seeds.rng(seed, "f"))
		var ticks := 0
		while f.state == "fighting" and ticks < 9000:
			f.step(ticks % 2 == 0, 1.0 / 30.0)
			ticks += 1
		check(f.state == "landed", "gentle fishing lands the fish in the end (seed %d)" % seed)
