extends Node
## The game being played: everything a save holds, in one dictionary. Keys starting with an underscore, and a fight in
## progress, belong to the moment and are never saved.

signal changed

const VERSION := 2

var state := {}
## Plays by the demo's limits without a demo build, for the tests.
var acts_as_demo := false
## The wall clock, which keeps running while the game is put away; the tests swap in their own.
var wall_clock: Callable = Time.get_unix_time_from_system
var _check_left := 2.0
## The wall clock at the last frame, or 0 when the next frame is the first since a game was loaded, caught up or shown.
var _last_wall := 0.0


func _ready() -> void:
	FullGame.changed.connect(_on_full_game_changed)
	FullGame.finished.connect(func(result: String) -> void: DemoEnd.store_result(result))
	# The seconds spent building a new screen are not time away.
	Nav.screen_changed.connect(func(_screen: String) -> void: _last_wall = 0.0)


## Whether this is the free demo, exported with the `demo` feature, or a phone that has not bought the full game.
func is_demo() -> bool:
	return OS.has_feature("demo") or acts_as_demo or FullGame.locked()


func demo_last_chapter() -> int:
	return int(Data.num("demo.last_chapter", 2))


## Whether something opening in this chapter belongs to the full game, so the demo never opens it.
func in_full_game(chapter: int) -> bool:
	return is_demo() and chapter > demo_last_chapter()


func new_game(name: String, dog: String, coat := "golden", dog_name := Dogs.DEFAULT_NAME) -> void:
	state = defaults()
	state["name"] = name
	state["dog"] = dog
	state["dog_coat"] = coat
	state["dog_name"] = dog_name
	state["seed"] = int(Time.get_unix_time_from_system()) % 1000000007
	state["tanks"] = Garum.new_tanks()
	Orders.new_day(state, Seeds.rng(int(state["seed"]), "orders", 0))
	changed.emit()


func defaults() -> Dictionary:
	return {"name": "", "seed": 1, "time": 0.0, "denarii": int(Data.num("start.denarii", 20)), "reputation": 0, "chapter": 1,
		"place": "harbour", "boat": "skiff", "boat_x": 150.0,
		"gear": {"rod": "cane_rod", "line": "flax_line", "hook": "bronze_hook", "net": "", "traps": 2, "lamp": "", "bait_box": 1},
		"bait": {"worm": 20}, "current_bait": "worm", "method": "line",
		"hold": [], "live_well": [], "traps": [], "pond": {}, "tanks": [], "orders": [], "clients": {}, "logbook": {},
		"legends": {}, "legends_paid": [], "market": {}, "achievements": [], "dog": "", "dog_coat": "golden", "dog_name": Dogs.DEFAULT_NAME, "helpers": [], "stats": {}, "finery": [], "salt": 6, "garum": {}, "guide": {"done": [], "finished": false},
		"last_real_time": Time.get_unix_time_from_system()}


func to_dict() -> Dictionary:
	var out := {"version": VERSION}
	for k in state:
		if not str(k).begins_with("_") and k != "fight":
			out[k] = state[k]
	return out.duplicate(true)


func from_dict(d: Dictionary) -> void:
	state = defaults()
	for k in d:
		if k != "version":
			state[k] = d[k]
	# A save from before the one pond kept six pond sites, which become the one pond with all their fish.
	if d.has("ponds"):
		if not d.has("pond"):
			state["pond"] = Ponds.from_sites(d["ponds"])
		state.erase("ponds")
	# A save from before the guide that has fish in its logbook belongs to someone who already knows how to fish.
	if not d.has("guide"):
		state["guide"]["finished"] = not state["logbook"].is_empty()
	_open_earned_chapters()
	changed.emit()


## A game carried over from the demo opens at once the chapters its name earned while the demo held them back.
func _open_earned_chapters() -> void:
	if not is_demo():
		state.erase("demo_done")
	var was := int(state["chapter"])
	if Story.add_reputation(state, 0) > 0:
		state["_chapter_seen"] = was


## Buying the full game on a phone carries the game being played straight over, there and then.
func _on_full_game_changed() -> void:
	DemoEnd.refresh()
	SettingsPanel.refresh()
	if is_demo() or not state.has("demo_done"):
		return
	_open_earned_chapters()
	changed.emit()


## A game some way in, for screenshots and checks: the third chapter, the pond dug to its third stage with fish, a
## tank of garum and a hold of fish.
func demo_state() -> void:
	new_game("Marcus", "mutt")
	# A game made up for checks and pictures never sends its achievements to Steam.
	state["_unlocked"] = true
	state["guide"]["finished"] = true
	state["chapter"] = 3
	state["reputation"] = 90
	state["denarii"] = 640
	state["boat"] = "fishing_boat"
	state["gear"]["net"] = "cast_net"
	state["bait"] = {"worm": 30, "shrimp": 15, "bread": 20}
	state["finery"] = ["earrings"]
	state["pond"] = {"stage": 3, "features": ["rocks", "sand", "weed", "caves"], "breeding": {}, "fish": [
		{"fish": "bream", "pounds": 4.2, "name": "Aurata", "finery": "gold_ring", "age_days": 30, "fed": true},
		{"fish": "bream", "pounds": 3.1, "name": "", "finery": "", "age_days": 30, "fed": true},
		{"fish": "mullet", "pounds": 1.8, "name": "", "finery": "", "age_days": 12, "fed": false},
		{"fish": "white_bream", "pounds": 1.4, "name": "", "finery": "", "age_days": 20, "fed": true},
		{"fish": "moray", "pounds": 12.5, "name": "Hortensia", "finery": "earrings", "age_days": 60, "fed": true}]}
	state["tanks"][0] = {"restored": true, "fish": {"sardine": 12.0}, "pounds": 12.0, "days": 6, "quality": 0.6, "stirred": false}
	for f in [["mullet", 1.2], ["bream", 2.4], ["sardine", 0.15], ["octopus", 3.5]]:
		Catches.record(state, f[0], f[1])
	for f in state["hold"]:
		f["fresh"] = 0.9
	for f in [["mullet", 6, 1.9], ["bream", 5, 4.2], ["sardine", 14, 0.2], ["salema", 3, 0.9], ["sole", 1, 1.1], ["moray", 1, 12.5], ["crab", 4, 0.6]]:
		state["logbook"][f[0]] = {"count": f[1], "best": f[2]}
	changed.emit()


## A game with every chapter open and the best of everything: the biggest boat, the best gear of every kind, a full
## bait box, all the help, the pond dug as wide as it goes and every garum tank restored, money to spare, and the
## achievements all that has met already earned.
func max_state() -> void:
	new_game("Marcus", "mutt")
	state["guide"]["finished"] = true
	var last: Dictionary = Data.chapters[Data.chapters.size() - 1]
	state["chapter"] = int(last["chapter"])
	state["_chapter_seen"] = state["chapter"]
	state["reputation"] = int(last["reputation"]) + 100
	state["denarii"] = 50000
	state["boat"] = Data.boats.keys()[Data.boats.size() - 1]
	var best := {}
	for id in Data.gear:
		var g: Dictionary = Data.gear[id]
		if g["kind"] != "finery" and (not best.has(g["kind"]) or int(g["price"]) > int(Data.gear[best[g["kind"]]]["price"])):
			best[g["kind"]] = id
	for kind in best:
		if kind == "trap":
			state["gear"]["traps"] = int(Data.gear[best[kind]]["count"])
		else:
			state["gear"][kind] = best[kind]
	state["gear"]["rod_best"] = state["gear"]["rod"]
	state["bait"] = {}
	for id in Data.bait:
		state["bait"][id] = Shop.bait_capacity(state) / Data.bait.size()
	state["helpers"] = Helpers.HELP.keys()
	state["finery"] = Data.gear.keys().filter(func(id): return Data.gear[id]["kind"] == "finery")
	state["pond"] = {"stage": Ponds.allowed(state), "features": [], "fish": [], "breeding": {}}
	for t in state["tanks"]:
		t["restored"] = true
	# What this game has already met is earned quietly, so no card slides in for each and nothing goes to Steam.
	state["achievements"] = Data.achievements.map(func(a): return a["id"]).filter(func(id): return Achievements.met(id, state))
	state["_unlocked"] = true
	changed.emit()


## Opens the demo's end card once, when chapter 3 would have opened; says whether it did.
func show_demo_end() -> bool:
	if not is_demo() or not state.get("demo_done", false) or state.get("demo_card_seen", false):
		return false
	state["demo_card_seen"] = true
	DemoEnd.open()
	return true


## Lets the time away pass, up to the cap: the time since the game was last saved, or `seconds` when given; says how
## many minutes of game time that was.
func catch_up(seconds := -1.0) -> float:
	var now := Time.get_unix_time_from_system()
	var minutes := Clock.away(now - float(state.get("last_real_time", now)) if seconds < 0.0 else seconds)
	var rng := Away.rng(state)
	state["last_real_time"] = now
	_last_wall = 0.0
	if minutes > 0.0:
		# No one is ashore while the game is away, just as in a game closed and opened again.
		var ashore = state.get("_ashore")
		state.erase("_ashore")
		var left := minutes
		while left > 0.0:
			left -= Away.step(state, left, rng)
		if ashore != null:
			state["_ashore"] = ashore
	return minutes


## Godot shortens a long frame's delta, so the time a game spends put away on a phone, or open on a computer that
## sleeps, shows only on the wall clock, and is then lived as time away.
func _watch_clock() -> void:
	var now: float = wall_clock.call()
	var gap := now - _last_wall
	var first := _last_wall <= 0.0
	_last_wall = now
	if not first and gap > Data.num("time.long_frame_seconds", 10) and away_counts():
		catch_up(gap)
		changed.emit()


## Whether time away counts for the game in memory: one being played from its slot, not one on the title, which loads
## it afresh, nor one made up for checks.
func away_counts() -> bool:
	return not state.is_empty() and Saves.enabled and Saves.slot > 0 and Nav.current_name != "title"


## Earns every achievement newly met: sent to Steam, its card slid in, and the logbook's pages ticked if they are open.
func earn_achievements() -> void:
	var got := Achievements.check(state)
	for id in got:
		Awards.unlock(id)
		AchievementCard.show_earned(id)
	if not got.is_empty():
		LogbookPanel.refresh_achievements()


func _process(delta: float) -> void:
	if state.is_empty() or Dev.has("run-tests"):
		return
	_watch_clock()
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = 2.0
	earn_achievements()
	if int(state.get("_chapter_seen", state["chapter"])) < int(state["chapter"]):
		var c: Dictionary = Data.chapters[int(state["chapter"]) - 1]
		Toast.say(tr("Chapter %d: %s. %s") % [int(c["chapter"]), tr(c["name"]), tr(c["text"])])
		Audio.play("market_bell")
	state["_chapter_seen"] = int(state["chapter"])
	show_demo_end()
	if state.has("_contest"):
		var c: Dictionary = state["_contest"]
		if c["won"]:
			Toast.say(tr("You won the Neptunalia with %s of %s! +%s") % [Units.weight(float(c["pounds"])), Data.fish_lower(c["fish"]), Ui.coins_text(int(c["prize"]))])
		else:
			Toast.say(tr("The Neptunalia went to old Rufus with a fish of %s.") % Units.weight(float(c["pounds"])))
		state.erase("_contest")
	if state.has("_rescued"):
		Toast.say(tr("Old Rufus: \"Out of bait and coin? Here are %d worms from my garden. And your pots need no bait at all.\"") % int(state["_rescued"]))
		Audio.play("coins")
		state.erase("_rescued")
	if state.has("_lost"):
		Toast.say(tr("%d fish in the live well died overnight; the hold had no room for them.") % int(state["_lost"]))
		state.erase("_lost")
