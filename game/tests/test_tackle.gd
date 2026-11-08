extends "res://tests/test_case.gd"
## Choosing the bait and the rod before a cast, with a tip for each saying which fish it suits.


func test_choosing_a_lighter_rod_keeps_the_better_one_yours() -> void:
	Game.new_game("Test", "hound")
	Game.state["denarii"] = 200
	Shop.buy(Game.state, "ash_rod")
	TacklePanel.use_rod("cane_rod")
	check(Game.state["gear"]["rod"] == "cane_rod", "the cane rod is in his hands")
	check(Shop.owned(Game.state, "ash_rod"), "and the ash rod is still his, so the shop does not sell it again")
	TacklePanel.use_rod("yew_rod")
	check(Game.state["gear"]["rod"] == "cane_rod", "a rod he has not bought cannot be picked")


func test_choosing_a_bait_puts_it_on_the_hook() -> void:
	Game.new_game("Test", "hound")
	Game.state["bait"]["shrimp"] = 5
	TacklePanel.use_bait("shrimp")
	check(Game.state["current_bait"] == "shrimp", "the shrimp goes on the hook")
	TacklePanel.use_bait("squid")
	check(Game.state["current_bait"] == "shrimp", "a bait he has none of cannot be picked")


func test_a_heavy_rod_puts_small_fish_off() -> void:
	Game.new_game("Test", "hound")
	var light := Bite.chance("mullet", "worm", 0.0, "clear", "cane_rod")
	var heavy := Bite.chance("mullet", "worm", 0.0, "clear", "masters_rod")
	check(heavy < light, "a mullet is shy of a rod built for tuna")


func test_the_tips_name_the_fish_each_suits() -> void:
	check("mullet" in TacklePanel.bait_tip("worm", "harbour").to_lower(), "the worm's tip names the mullet that take it here")
	var tip := TacklePanel.rod_tip("cane_rod", "harbour")
	check("kg" in tip and "small" in tip.to_lower(), "the cane rod's tip says the size of fish it suits")


func test_a_long_tip_is_broken_into_short_lines() -> void:
	var tip := Ui.wrapped("Loved by gilt-head bream, white sea bream and squid. Also taken by red porgy and mullet.", 46)
	check(Array(tip.split("\n")).all(func(l): return l.length() <= 46), "no line of the tip runs past 46 letters")
