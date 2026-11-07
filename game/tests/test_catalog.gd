extends "res://tests/test_case.gd"


func test_every_place_has_its_fish() -> void:
	for p in Data.places:
		var any := Data.fish.values().filter(func(f): return p in f["places"] and not f["legend"])
		check(any.size() >= 8, "%s has at least eight kinds of fish" % p)
	check(Data.fish.size() >= 58 and Data.fish.values().filter(func(f): return f["legend"]).size() == 12, "about sixty kinds, twelve legends")


func test_every_fish_is_complete() -> void:
	for f in Data.fish.values():
		for key in ["name", "places", "depth", "hours", "baits", "pounds", "strength", "stamina", "rarity", "price", "methods"]:
			check(f.has(key), "%s has %s" % [f["id"], key])
		check(f["pounds"][0] < f["pounds"][1] and f["depth"][0] < f["depth"][1], f["id"] + " has a weight and depth range")
		for p in f["places"]:
			check(Data.places.has(p), f["id"] + " lives in a real place")
		for b in f["baits"]:
			check(Data.bait.has(b), "%s's bait %s exists" % [f["id"], b])
		if f.get("live", false):
			check(f.has("pond"), f["id"] + " can live in a pond, so it has pond needs")
		if f["legend"]:
			check(str(f.get("clue", "")) != "", f["id"] + " has a clue")


func test_fish_only_bite_in_their_hours_and_depths() -> void:
	var day := Catalog.available("harbour", 40.0, 9.0, "spring", "clear", "line")
	var night := Catalog.available("harbour", 40.0, 23.0, "spring", "clear", "trident")
	check("mullet" in day and not "mullet" in night, "mullet bite by day")
	check(not night.is_empty() and night.all(func(f): return Data.fish[f]["hours"] != [5, 20]), "night fish at night")
	check(not Catalog.available("harbour", 40.0, 9.0, "spring", "clear", "line").has("tiberius_mullet"), "a legend needs its own time")
	check(not Catalog.available("harbour", 5.0, 9.0, "spring", "clear", "line").has("sole"), "a sole lives on the sand, not at the surface")


func test_weights_grades_and_value() -> void:
	var rng := Seeds.rng(1, "w")
	for i in 50:
		var lb := Catalog.roll_pounds("bream", rng)
		check(lb >= Data.fish["bream"]["pounds"][0] and lb <= Data.fish["bream"]["pounds"][1], "a weight within the range")
	var top: float = Data.fish["bream"]["pounds"][1]
	check(Catalog.grade("bream", top) == "prize" and Catalog.grade("bream", Data.fish["bream"]["pounds"][0]) == "small", "the grades")
	check(Catalog.value("bream", top, 1.0) > Catalog.value("bream", top * 0.3, 1.0) * 3, "prize fish sell for many times a small one")
	check(Catalog.value("bream", top, 0.5) < Catalog.value("bream", top, 1.0), "stale fish sell for less")


func test_boats_gear_and_bait() -> void:
	check(Data.boats["skiff"]["hold"] == 10 and Data.boats["big_boat"]["well"] == 6, "the boats' holds and wells")
	for id in ["cane_rod", "flax_line", "bronze_hook"]:
		check(Data.gear.has(id) and int(Data.gear[id]["price"]) == 0, id + " is the free starting gear")
	for p in Data.places.values():
		check(Data.boats.has(p["boat"]) and int(p["width"]) >= 1440, p["id"] + " needs a real boat and is wide enough to row")
