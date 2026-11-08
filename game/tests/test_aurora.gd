extends "res://tests/test_case.gd"
## The northern lights, rare this far south, as in Farmus Maximus.


func test_the_lights_come_on_about_one_clear_night_in_fourteen() -> void:
	var nights := 0
	for evening in 1400:
		if SkyView.aurora_night(7, evening, true):
			nights += 1
	check(nights > 60 and nights < 140, "about one night in fourteen has the lights, %d of 1400" % nights)


func test_nobody_misses_the_lights_by_bad_luck() -> void:
	var sure := int(Data.num("sky.aurora_sure_after_days", 30))
	check(SkyView.aurora_night(7, sure + 3, false), "after a month without them, every night has the lights")
	var later := 0
	for evening in range(sure, sure + 200):
		if SkyView.aurora_night(7, evening, true):
			later += 1
	check(later < 40, "and once seen they are rare again")


func test_the_lights_show_on_a_clear_night_only() -> void:
	var sky := SkyView.new()
	Nav.sky.add_child(sky)
	sky.force_aurora = true
	sky.follow(Vector2(300, CoastCamera.HOME_Y), 23.0, "clear")
	for i in 200:
		sky._process(0.1)
	check(sky.aurora_amount() > 0.9, "on a clear night they ripple over the hills")
	sky.follow(Vector2(300, CoastCamera.HOME_Y), 13.0, "clear")
	for i in 400:
		sky._process(0.1)
	check(sky.aurora_amount() < 0.01, "and fade away by day")
	sky.force_aurora = false
	sky.follow(Vector2(300, CoastCamera.HOME_Y), 23.0, "cloudy")
	for i in 400:
		sky._process(0.1)
	check(sky.aurora_amount() < 0.01, "the clouds hide them")
	sky.free()
