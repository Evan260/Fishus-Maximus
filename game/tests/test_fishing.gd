extends "res://tests/test_case.gd"

const STEP := 1.0 / 30.0
const START := {"pull": 1, "strength": 0.6, "hold": 1}
const BEST := {"pull": 4, "strength": 0.95, "hold": 3}


func _line_fish() -> Array:
	return Data.fish.keys().filter(func(id): return "line" in Data.fish[id]["methods"])


func _fight(id: String, lb: float, gear: Dictionary, seed := 1, gentle := false) -> LineFight:
	var f := LineFight.new()
	f.setup(id, lb, gear, gentle, Seeds.rng(seed, "f"))
	return f


## Seconds of reeling into the run a fish makes when struck until the line is past what it can bear.
func _seconds_to_break(id: String, lb: float, gear: Dictionary) -> float:
	var f := _fight(id, lb, gear)
	var t := 0.0
	while f.running() and f.tension <= 1.0:
		f.step(true, STEP)
		t += STEP
	return t if f.tension > 1.0 else INF


## Reels only while the fish rests: the outcome, the seconds taken and the highest tension.
func _patient(f: LineFight) -> Array:
	var t := 0.0
	var top := 0.0
	while f.state == "fighting" and t < 300.0:
		f.step(f.resting(), STEP)
		top = maxf(top, f.tension)
		t += STEP
	return [f.state, t, top]


## The average run and rest of a fish played patiently, in seconds.
func _phases(id: String, lb: float) -> Array:
	var runs := []
	var rests := []
	for seed in 10:
		var f := _fight(id, lb, START, seed)
		f.distance = 9999.0
		var was := true
		var length := 0.0
		while f.state == "fighting" and f.tired() < 1.0:
			f.step(f.resting(), STEP)
			length += STEP
			if f.running() != was:
				(runs if was else rests).append(length)
				length = 0.0
				was = f.running()
	return [runs.reduce(func(a, b): return a + b, 0.0) / runs.size(), rests.reduce(func(a, b): return a + b, 0.0) / rests.size()]


func test_fish_only_take_bait_they_like() -> void:
	check(Bite.chance("mullet", "worm", 10.0) > 0.0 and Bite.chance("mullet", "bread", 10.0) == 0.0, "mullet take worms, not bread")
	check(Bite.chance("mullet", "worm", 50.0) == 0.0, "nor from too far away")
	check(Bite.chance("mullet", "worm", 5.0) > Bite.chance("mullet", "worm", 30.0), "a bait right by the fish is likelier taken")
	check(is_equal_approx(Bite.window(), 1.0), "a second to strike")


func test_running_is_the_opposite_of_resting() -> void:
	var f := _fight("bream", 2.0, START)
	check(f.running() and not f.resting(), "a hooked fish runs first")
	while f.running():
		f.step(false, STEP)
	check(f.resting() and not f.running(), "then rests")


func test_reeling_against_a_running_fish_snaps_the_line() -> void:
	var f := _fight("grouper", 30.0, START)
	for i in 600:
		f.step(true, STEP)
		if f.state != "fighting":
			break
	check(f.state == "snapped", "a big grouper on light line, reeled hard, breaks it")


func test_reeling_through_a_run_snaps_flax_line_even_for_a_small_fish() -> void:
	for id in ["goby", "wrasse", "mullet", "salema"]:
		var f := _fight(id, float(Data.fish[id]["pounds"][0]), START)
		var t := 0.0
		while f.state == "fighting" and t < 30.0:
			f.step(true, STEP)
			t += STEP
		check(f.state == "snapped", "holding on through its runs breaks the flax line on the smallest %s" % id)


func test_every_fish_breaks_the_starting_line_within_half_a_second_of_reeling_into_a_run() -> void:
	for id in _line_fish():
		for lb in Data.fish[id]["pounds"]:
			var t := _seconds_to_break(id, float(lb), START)
			check(t <= 0.55, "%s of %.2f lb strains the flax line past breaking in %.2f s" % [id, float(lb), t])


func test_giving_line_to_a_run_keeps_it_safe_and_lands_any_fish() -> void:
	for id in _line_fish():
		var r := _patient(_fight(id, float(Data.fish[id]["pounds"][1]), START))
		check(r[0] == "landed", "the biggest %s is landed on starting gear by reeling only while it rests" % id)
		check(r[2] < 0.75, "and the line never comes near breaking (%.2f)" % r[2])


func test_patience_lands_the_fish() -> void:
	var r := _patient(_fight("bream", 2.0, {"pull": 2, "strength": 0.8, "hold": 2}))
	check(r[0] == "landed", "reeling only while the fish rests lands it")


func test_a_slack_line_lets_the_hook_slip() -> void:
	var f := _fight("bream", 2.0, {"pull": 2, "strength": 0.8, "hold": 1}, 2)
	for i in 900:
		f.step(false, STEP)
		if f.state != "fighting":
			break
	check(f.state == "slipped", "never reeling, the fish shakes the hook")


func test_big_strong_fish_run_more_often_and_for_longer() -> void:
	var small := _phases("mullet", 0.5)
	var big := _phases("grouper", 50.0)
	check(big[0] > small[0] * 1.5, "a big grouper's runs (%.1f s) are longer than a small mullet's (%.1f s)" % [big[0], small[0]])
	check(big[1] < small[1], "and its rests between them shorter (%.1f s against %.1f s)" % [big[1], small[1]])


func test_better_gear_is_more_forgiving() -> void:
	check(_seconds_to_break("sea_bass", 8.0, BEST) > _seconds_to_break("sea_bass", 8.0, START) * 1.4, "a stronger line and rod take longer to break")
	var quick := _patient(_fight("sea_bass", 8.0, BEST))
	var slow := _patient(_fight("sea_bass", 8.0, START))
	check(quick[0] == "landed" and quick[1] < slow[1], "a better rod brings the fish in sooner")
	var bronze := _fight("bream", 2.0, START)
	var iron := _fight("bream", 2.0, {"pull": 1, "strength": 0.6, "hold": 3})
	var t := [0.0, 0.0]
	for i in 2:
		var f: LineFight = [bronze, iron][i]
		while f.state == "fighting" and t[i] < 60.0:
			f.step(false, STEP)
			t[i] += STEP
	check(bronze.state == "slipped" and t[1] > t[0], "a better hook holds a slack line longer")


func test_gentle_fishing_never_loses_a_fish() -> void:
	for seed in 20:
		var f := _fight("grouper", 30.0, {"pull": 1, "strength": 0.3, "hold": 1}, seed, true)
		var ticks := 0
		while f.state == "fighting" and ticks < 9000:
			f.step(ticks % 2 == 0, STEP)
			ticks += 1
		check(f.state == "landed", "gentle fishing lands the fish in the end (seed %d)" % seed)


func test_gentle_fishing_never_snaps_or_slips_however_it_is_played() -> void:
	for id in ["swordfish", "great_tuna", "goby"]:
		for reel in [true, false]:
			var f := _fight(id, float(Data.fish[id]["pounds"][1]), START, 3, true)
			var t := 0.0
			while f.state == "fighting" and t < 120.0:
				f.step(reel, STEP)
				t += STEP
			check(f.state in ["fighting", "landed"], "gentle: %s %s, never lost" % [id, "always reeled" if reel else "never reeled"])
