extends Node
## The game being played: everything a save holds, in one dictionary. Keys starting with an underscore, and a fight in
## progress, belong to the moment and are never saved.

signal changed

const VERSION := 1

var state := {}
var _check_left := 2.0


func new_game(name: String, dog: String) -> void:
	state = defaults()
	state["name"] = name
	state["dog"] = dog
	state["seed"] = int(Time.get_unix_time_from_system()) % 1000000007
	state["tanks"] = Garum.new_tanks()
	Orders.new_day(state, Seeds.rng(int(state["seed"]), "orders", 0))
	changed.emit()


func defaults() -> Dictionary:
	return {"name": "", "seed": 1, "time": 0.0, "denarii": int(Data.num("start.denarii", 20)), "reputation": 0, "chapter": 1,
		"place": "harbour", "boat": "skiff", "boat_x": 150.0,
		"gear": {"rod": "cane_rod", "line": "flax_line", "hook": "bronze_hook", "net": "", "traps": 2, "lamp": "", "bait_box": 1},
		"bait": {"worm": 20}, "current_bait": "worm", "method": "line",
		"hold": [], "live_well": [], "traps": [], "ponds": [], "tanks": [], "orders": [], "clients": {}, "logbook": {},
		"legends": {}, "market": {}, "achievements": [], "dog": "", "helpers": [], "stats": {}, "finery": [], "salt": 6, "garum": {}, "guide": {"done": [], "finished": false},
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
	# A save from before the guide that has fish in its logbook belongs to someone who already knows how to fish.
	if not d.has("guide"):
		state["guide"]["finished"] = not state["logbook"].is_empty()
	changed.emit()


## A game some way in, for screenshots and checks: the third chapter, two ponds with fish, a tank of garum and a
## hold of fish.
func demo_state() -> void:
	new_game("Marcus", "mutt")
	state["guide"]["finished"] = true
	state["chapter"] = 3
	state["reputation"] = 90
	state["denarii"] = 640
	state["boat"] = "fishing_boat"
	state["gear"]["net"] = "cast_net"
	state["bait"] = {"worm": 30, "shrimp": 15, "bread": 20}
	state["finery"] = ["earrings"]
	state["ponds"] = [
		{"site": 0, "size": "large", "water": "sea", "features": ["rocks", "sand", "weed"], "fish": [
			{"fish": "bream", "pounds": 4.2, "name": "Aurata", "finery": "gold_ring", "age_days": 30, "fed": true},
			{"fish": "bream", "pounds": 3.1, "name": "", "finery": "", "age_days": 30, "fed": true},
			{"fish": "mullet", "pounds": 1.8, "name": "", "finery": "", "age_days": 12, "fed": false}]},
		{"site": 1, "size": "small", "water": "sea", "features": ["caves", "rocks"], "fish": [
			{"fish": "moray", "pounds": 12.5, "name": "Hortensia", "finery": "earrings", "age_days": 60, "fed": true}]}]
	state["tanks"][0] = {"restored": true, "fish": {"sardine": 12.0}, "pounds": 12.0, "days": 6, "quality": 0.6, "stirred": false}
	for f in [["mullet", 1.2], ["bream", 2.4], ["sardine", 0.15], ["octopus", 3.5]]:
		Catches.record(state, f[0], f[1])
	for f in state["hold"]:
		f["fresh"] = 0.9
	for f in [["mullet", 6, 1.9], ["bream", 5, 4.2], ["sardine", 14, 0.2], ["salema", 3, 0.9], ["sole", 1, 1.1], ["moray", 1, 12.5], ["crab", 4, 0.6]]:
		state["logbook"][f[0]] = {"count": f[1], "best": f[2]}
	changed.emit()


## A game with every chapter open and the best of everything: the biggest boat, the best gear of every kind, a full
## bait box, all the help, every pond dug large and every garum tank restored, and money to spare.
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
	state["ponds"] = []
	for site in Ponds.allowed(state):
		state["ponds"].append({"site": site, "size": "large", "water": Data.ponds["sites"][site]["water"], "features": [], "fish": []})
	for t in state["tanks"]:
		t["restored"] = true
	changed.emit()


## Lets the time since the game was last saved pass, up to the cap; says how many minutes of game time that was.
func catch_up() -> float:
	var now := Time.get_unix_time_from_system()
	var minutes := Clock.away(now - float(state.get("last_real_time", now)))
	state["last_real_time"] = now
	if minutes > 0.0:
		var rng := Seeds.rng(int(state["seed"]), "away", int(now))
		World.advance(state, minutes, rng)
		if state.has("idle"):
			var idle: Dictionary = state["idle"]
			var t := float(state["time"])
			var bait := str(idle["bait"])
			var left := int(state["bait"].get(bait, 0)) if bait != "" else 0
			for c in Idle.catches(minutes, str(idle["place"]), float(idle["depth"]), bait, mini(Hold.room(state), left), rng,
					Clock.hour(t), Clock.season(Clock.day_of(t)), str(state.get("weather", "clear")), float(idle.get("water", INF))):
				Catches.record(state, c["fish"], float(c["pounds"]), false)
				state["bait"][bait] = int(state["bait"][bait]) - 1
	return minutes


func _process(delta: float) -> void:
	if state.is_empty() or Dev.has("run-tests"):
		return
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = 2.0
	for id in Achievements.check(state):
		AchievementCard.show_earned(id)
	if int(state.get("_chapter_seen", state["chapter"])) < int(state["chapter"]):
		var c: Dictionary = Data.chapters[int(state["chapter"]) - 1]
		Toast.say("Chapter %d: %s. %s" % [int(c["chapter"]), c["name"], c["text"]])
		Audio.play("market_bell")
	state["_chapter_seen"] = int(state["chapter"])
	if state.has("_rescued"):
		Toast.say("Old Rufus: \"Out of bait and coin? Here are %d worms from my garden. And your pots need no bait at all.\"" % int(state["_rescued"]))
		Audio.play("coins")
		state.erase("_rescued")
	if state.has("_lost"):
		Toast.say("%d fish in the live well died overnight; the hold had no room for them." % int(state["_lost"]))
		state.erase("_lost")
