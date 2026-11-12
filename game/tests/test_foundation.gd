extends "res://tests/test_case.gd"


func test_the_day_and_the_year() -> void:
	check(Clock.minutes_per_day() == 25.0, "a day is 20 minutes of daylight and 5 of night")
	check(Clock.hour(0.0) == 5.0 and Clock.is_night(24.0) and not Clock.is_night(10.0), "dawn at five, night at the end")
	check(Clock.hour(20.0) == 20.0 and Clock.hour(10.0) == 12.5, "dusk at eight, half past noon at the middle of the day")
	check(Clock.season(0) == "spring" and Clock.season(7) == "summer" and Clock.season(28) == "spring", "seven-day seasons in a 28-day year")
	check(Clock.day_of(26.0) == 1 and Clock.year_day(30) == 2, "days and the day of the year")


func test_time_away_is_capped() -> void:
	check(Clock.away(3600.0 * 24.0 * 14.0) == 8.0 * 60.0, "two weeks away counts as eight hours")
	check(Clock.away(-500.0) == 0.0, "a clock set backwards counts as no time")
	check(Clock.away(600.0) == 10.0, "ten minutes away counts as ten")


func test_a_save_round_trips_and_survives_corruption() -> void:
	Saves.delete(1)
	Game.new_game("Test", "mutt")
	Game.state["denarii"] = 321
	Game.state["hold"] = [{"fish": "mullet", "pounds": 1.5, "fresh": 1.0}]
	check(Saves.save(1), "saves")
	Game.state["denarii"] = 5
	Saves.save(1)
	var f := FileAccess.open(Saves.path_for(1), FileAccess.WRITE)
	f.store_string("{")
	f.close()
	check(Saves.load_slot(1) and Game.state["denarii"] == 321, "a broken save falls back to the backup")
	check(Game.state["hold"][0]["fish"] == "mullet", "the hold survives")
	check(Saves.slot_info(1).get("name", "") == "Test", "the slot shows its name")
	Saves.delete(1)
	check(Saves.slot_info(1).is_empty(), "a deleted slot is empty")


func test_a_fish_on_the_line_is_not_saved() -> void:
	Game.new_game("Test", "mutt")
	Game.state["fight"] = {"fish": "bream"}
	Game.state["_scratch"] = 1
	check(not Game.to_dict().has("fight") and not Game.to_dict().has("_scratch"), "a fight in progress is never written to the save")


func test_a_new_game_starts_poor_in_the_harbour() -> void:
	Game.new_game("Test", "mutt")
	check(Game.state["place"] == "harbour" and Game.state["boat"] == "skiff" and Game.state["chapter"] == 1, "in the skiff at the harbour")
	check(Game.state["denarii"] == int(Data.num("start.denarii")), "with the starting purse")
	check(Ui.coins_text(1) == "1 denarius" and Ui.coins_text(12) == "12 denarii", "money is written out")


func test_a_save_is_written_safely_and_keeps_backups() -> void:
	Saves.delete(1)
	Game.new_game("Safe", "mutt")
	Game.state["denarii"] = 1
	check(Saves.save(1), "the first save is written")
	check(not FileAccess.file_exists(Saves.path_for(1) + ".tmp"), "through a temporary file that is moved into place")
	Game.state["denarii"] = 2
	Saves.save(1)
	check(FileAccess.file_exists(Saves.path_for(1) + ".bak1"), "the save before it becomes the newest backup")
	Game.state["denarii"] = 3
	Saves.save(1)
	check(not FileAccess.file_exists(Saves.path_for(1) + ".bak2"), "and the backups move along only once the newest has aged")
	check(Saves.load_slot(1) and Game.state["denarii"] == 3, "the newest save is the one loaded")
	var tmp := Saves.path_for(1) + ".tmp"
	var later := Game.to_dict()
	later["denarii"] = 4
	later["saved_at"] = Time.get_unix_time_from_system() + 60.0
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string(JSON.stringify(later))
	f.close()
	check(Saves.load_slot(1) and Game.state["denarii"] == 4, "a save cut off before its temporary file was moved is still found")
	f = FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string("{\"version\"")
	f.close()
	check(Saves.load_slot(1) and Game.state["denarii"] == 3, "but a half-written temporary file never wins")
	var old := FileAccess.open(Saves.path_for(1) + ".bak", FileAccess.WRITE)
	old.store_string(JSON.stringify(later))
	old.close()
	Saves.delete(1)
	check(Saves.slot_info(1).is_empty() and not FileAccess.file_exists(Saves.path_for(1) + ".bak"), "deleting takes every file, the old single backup too")
	var older := FileAccess.open(Saves.path_for(1) + ".bak", FileAccess.WRITE)
	older.store_string(JSON.stringify(later))
	older.close()
	check(Saves.load_slot(1) and Game.state["denarii"] == 4, "an older game's single backup is still read")
	Saves.delete(1)


func test_the_credits_name_every_part_of_the_game() -> void:
	var credits: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/credits.json"))
	check(credits is Dictionary, "the credits read")
	for part in ["made_by", "music", "sounds", "font", "libraries"]:
		check(credits is Dictionary and not (credits.get(part, []) as Array).is_empty(), "with their %s" % part)
	check(FileAccess.file_exists("res://tools/write_credits.gd"), "and a tool writes them out with Godot's licence")
