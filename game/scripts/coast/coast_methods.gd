class_name CoastMethods
extends Node
## The other ways to fish from the boat: setting and pulling pots, throwing the cast net over a shoal, spearing by
## lamplight with the trident, and leaving the fisherman to fish on his own.

const METHODS := ["line", "trap", "net", "trident"]
## A pot is pulled when the middle of the boat passes this close over it.
const PULL_REACH := 26.0
const NET_REACH := 170.0
const SPEAR_REACH := 150.0
## Seconds he waits with the fish landed, fishing on his own, before he casts again.
const RECAST_AFTER := 1.5

var screen: Node
var method := "line"
var idle := false
var traps_view: TrapView
var net_view: NetView
var trident_view: TridentView
var _idle_minutes := 0.0
## The fish he has caught on his own that are still coming in on the line, each told of once it is in the boat.
var _landing: Array[String] = []
var _recast_in := RECAST_AFTER
var _rng: RandomNumberGenerator


func setup(s: Node, rng: RandomNumberGenerator) -> void:
	screen = s
	_rng = rng
	method = str(Game.state.get("method", "line"))
	if not method in METHODS:
		method = "line"
	# A game saved while he fished on his own here carries on so; one saved elsewhere ended when the boat left.
	if Game.state.has("idle"):
		if str(Game.state["idle"].get("place", "")) == screen.place_id:
			idle = true
		else:
			Game.state.erase("idle")
	# --idle starts him fishing on his own, and --idle-speed=N runs his fishing N times faster, for checks.
	if Dev.has("idle"):
		set_idle.call_deferred(true)
	# --pot drops a pot from the boat at the start, and --pot=haul hauls up a full one from under it, for checks.
	if Dev.has("pot"):
		_dev_pot.call_deferred(Dev.get_arg("pot"))


func set_method(m: String) -> void:
	if m == method or not m in METHODS:
		return
	if screen.fight != null:
		Toast.say("Land the fish first.")
		return
	if m == "net" and _net() == "":
		Toast.say("You have no cast net yet.")
		return
	if m == "trident" and not Trident.can_use(screen.hour, str(Game.state["gear"].get("lamp", ""))):
		Toast.say("The trident needs the night and a lamp.")
		return
	screen.reel_in()
	method = m
	Game.state["method"] = m


func set_idle(on: bool) -> void:
	if on and screen.bait() == "":
		Toast.say("No bait on the hook.")
		return
	idle = on
	_idle_minutes = 0.0
	if on:
		Game.state["idle"] = {"place": screen.place_id, "bait": screen.bait(), "depth": maxf(10.0, screen.hook.y),
			"water": screen.seabed.depth_at(screen.hook.x)}
	else:
		Game.state.erase("idle")
		if screen.line_state() in ["taken", "landing"]:
			screen.reel_in()
	Toast.say("Fishing on his own." if on else "Back at the rod.")


## Stops him fishing on his own as the boat leaves, with word of any fish still coming in on the line.
func leave() -> void:
	_announce()
	if traps_view:
		traps_view.tell_now()
	idle = false
	Game.state.erase("idle")


func _net() -> String:
	return str(Game.state["gear"].get("net", ""))


func traps_here() -> Array:
	return Game.state["traps"].filter(func(t): return t["place"] == screen.place_id)


## Each frame on the boat: the fisherman fishes on his own if idle, pots under the boat come up, and the aims follow the mouse.
func tick(delta: float) -> void:
	var minutes := delta / 60.0
	if idle:
		_idle_minutes += minutes * Dev.num("idle-speed", 1.0)
		# While a fish is coming in the minutes add up, so the line in the water catches at the same rate.
		if _idle_minutes >= 0.25 and screen.line_state() in ["waiting", "sinking"] and screen.flight <= 0.0:
			_idle_step(_idle_minutes)
			_idle_minutes = 0.0
	if not _landing.is_empty() and not screen.line_state() in ["taken", "landing"]:
		_announce()
	if idle and screen.line_state() == "reeled":
		_recast_in -= delta
		if _recast_in <= 0.0:
			screen.cast(0.6)
	else:
		_recast_in = RECAST_AFTER
	trident_view.lit = Trident.can_use(screen.hour, str(Game.state["gear"].get("lamp", "")))
	if method == "trident" and not trident_view.lit:
		method = "line"
	for t in Game.state["traps"]:
		t["_told"] = maxf(0.0, float(t.get("_told", 0.0)) - delta / 20.0)
	traps_view.step(delta)
	_pull_traps_under_boat()
	var mouse: Vector2 = screen.get_global_mouse_position() + screen.camera.cam
	net_view.aim = mouse
	trident_view.aim = mouse
	net_view.thrown_left = maxf(0.0, net_view.thrown_left - delta)
	trident_view.thrown_left = maxf(0.0, trident_view.thrown_left - delta)
	net_view.queue_redraw()
	trident_view.queue_redraw()


func _idle_step(minutes: float) -> void:
	var bait: String = screen.bait()
	if bait == "":
		set_idle(false)
		Toast.say("Out of bait.")
		return
	var depth: float = maxf(10.0, screen.hook.y)
	var day := Clock.day_of(float(Game.state["time"]))
	var got := Idle.catches(minutes, screen.place_id, depth, bait, Hold.room(Game.state), _rng, screen.hour,
		Clock.season(day), screen.weather, screen.seabed.depth_at(screen.hook.x))
	for c in got:
		Game.state["bait"][bait] = maxi(0, int(Game.state["bait"].get(bait, 0)) - 1)
		Catches.record(Game.state, c["fish"], float(c["pounds"]), false)
		_landing.append(str(c["fish"]))
	# The catch is kept at once, and shown coming in on the line before it is told of.
	if not got.is_empty():
		screen.idle_catch(str(got[0]["fish"]))
	elif Hold.room(Game.state) <= 0:
		set_idle(false)
		Toast.say("The hold is full.")


## Tells of the fish he has brought in on his own, and stops him once the hold is full.
func _announce() -> void:
	for id in _landing:
		Toast.say("+ " + Data.fish[id]["name"])
	_landing.clear()
	if idle and Hold.room(Game.state) <= 0:
		set_idle(false)
		Toast.say("The hold is full.")


func _pull_traps_under_boat() -> void:
	var mid: float = screen.boat_x + 52.0
	for t in traps_here():
		if absf(float(t["x"]) - mid) < PULL_REACH and not t["catch"].is_empty() and t.get("_told", 0.0) <= 0.0 \
				and not traps_view.moving(t):
			var got := Traps.empty_into(Game.state, t)
			var say := []
			if not got.is_empty():
				say.append("You rowed over your pot and hauled it up: " + _names(got) + ".")
			if not t["catch"].is_empty():
				say.append("The hold is full; the rest stay in the pot.")
				t["_told"] = 1.0
			_haul(t, got, say, true)


func _names(got: Array) -> String:
	return ", ".join(got.map(func(c): return Data.fish[c["fish"]]["name"].to_lower()))


## Hauls a pot up to tell what came out of it once it is in the boat; a pot nothing came out of stays down.
func _haul(t: Dictionary, got: Array, say: Array, keep: bool) -> void:
	if traps_view and (not got.is_empty() or not keep):
		traps_view.haul(t, say, keep)
	else:
		for line in say:
			Toast.say(line)


## Space or a click with a method other than the line: set or lift a pot, throw the net, or throw the trident.
func use() -> void:
	match method:
		"trap":
			_set_or_lift_trap()
		"net":
			_throw_net()
		"trident":
			_throw_trident()


func _set_or_lift_trap() -> void:
	var mid: float = screen.boat_x + 52.0
	for t in traps_here():
		if absf(float(t["x"]) - mid) < PULL_REACH:
			var got := Traps.empty_into(Game.state, t)
			var said := ": " + _names(got) + "." if not got.is_empty() else "."
			if not t["catch"].is_empty():
				var say := ["Hauled the pot up" + said] if not got.is_empty() else []
				_haul(t, got, say + ["Make room in the hold before lifting this pot."], true)
				return
			Game.state["traps"].erase(t)
			_haul(t, got, ["Lifted the pot" + said], false)
			return
	var allowed := int(Game.state["gear"].get("traps", 2))
	if Game.state["traps"].size() >= allowed:
		Toast.say("All %d pots are set." % allowed)
		return
	var bait: String = screen.bait()
	if bait != "":
		Game.state["bait"][bait] = int(Game.state["bait"][bait]) - 1
	var trap := {"place": screen.place_id, "x": roundf(mid), "depth": screen.seabed.depth_at(mid),
		"set_time": float(Game.state["time"]), "catch": [], "size": 3, "hours": 0.0, "bait": bait}
	Game.state["traps"].append(trap)
	if traps_view:
		traps_view.drop(trap)
	Game.state["stats"]["pots_set"] = int(Game.state["stats"].get("pots_set", 0)) + 1
	if int(Game.state["stats"].get("pots_set", 0)) <= 1:
		Toast.say("Your pot sinks to the seabed and fills with crabs, lobsters and octopus. Row over it later to haul it up.")
	else:
		Toast.say("Pot set on the seabed%s." % ((", baited with " + str(Data.bait[bait]["name"]).to_lower()) if bait != "" else ""))


func _dev_pot(how: String) -> void:
	method = "trap"
	var mid: float = screen.boat_x + 52.0
	if how == "haul":
		var kinds := Traps.kinds(screen.place_id, screen.seabed.depth_at(mid))
		Game.state["traps"].append({"place": screen.place_id, "x": roundf(mid), "depth": screen.seabed.depth_at(mid),
			"set_time": float(Game.state["time"]), "catch": [Pick.catch_of(kinds[0] if not kinds.is_empty() else "crab", _rng, true)],
			"size": 3, "hours": 2.0, "bait": ""})
	_set_or_lift_trap()


func _throw_net() -> void:
	var aim := net_view.aim
	var tip: Vector2 = screen.rod_tip()
	if absf(aim.x - tip.x) > NET_REACH or aim.y < 0.0 or aim.y > 80.0:
		Toast.say("Throw the net over a shoal near the boat.")
		return
	net_view.thrown_at = aim
	net_view.thrown_left = 0.8
	var shoal := _nearest_shoal(aim)
	if shoal.is_empty():
		return
	var centre := Vector2.ZERO
	for f in shoal:
		centre += f["pos"]
	centre /= shoal.size()
	var size := int(Data.gear.get(_net(), {}).get("size", 4))
	var error := aim.distance_to(centre) / (NetView.RADIUS * 1.6) * (0.6 if "dolphins" in screen.swimmers.events else 1.0)
	var n := Nets.throw(shoal.size(), {"size": size}, error, _rng, screen.weather)
	for i in n:
		var f: Dictionary = shoal[i]
		screen.swimmers.release(f, true)
		var r := Catches.record(Game.state, f["id"], float(f["lb"]), false)
		if r["where"] == "full":
			HoldChoice.ask(r["fish"])
			break
	if n > 0:
		Toast.say("%d %s in the net." % [n, Data.fish[shoal[0]["id"]]["name"].to_lower()])


## The fish of the netable shoal closest to a point, near enough for the ring to reach.
func _nearest_shoal(at: Vector2) -> Array:
	var best := []
	var best_d := NetView.RADIUS * 1.6
	var groups := {}
	for f in screen.swimmers.fish:
		if f["state"] != "swim" or not "net" in Data.fish[f["id"]]["methods"]:
			continue
		if not groups.has(f["group"]):
			groups[f["group"]] = []
		groups[f["group"]].append(f)
	for g in groups.values():
		var c := Vector2.ZERO
		for f in g:
			c += f["pos"]
		c /= g.size()
		if c.distance_to(at) < best_d:
			best_d = c.distance_to(at)
			best = g
	return best


func _throw_trident() -> void:
	var aim := trident_view.aim
	if aim.distance_to(screen.rod_tip()) > SPEAR_REACH or aim.y < 0.0:
		Toast.say("Too far to throw.")
		return
	trident_view.thrown_at = aim
	trident_view.thrown_left = 0.35
	for f in screen.swimmers.fish:
		if f["state"] in ["swim", "curious"] and "trident" in Data.fish[f["id"]]["methods"] and Trident.hits(aim, f["pos"]):
			screen.swimmers.release(f, true)
			var r := Catches.record(Game.state, f["id"], float(f["lb"]), false)
			if r["where"] == "full":
				HoldChoice.ask(r["fish"])
			else:
				CatchCard.show_catch(f["id"], float(f["lb"]), r["new"])
			return
	Toast.say("Missed.")
