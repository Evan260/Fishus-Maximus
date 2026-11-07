class_name CoastMethods
extends Node
## The other ways to fish from the boat: setting and pulling pots, throwing the cast net over a shoal, spearing by
## lamplight with the trident, and leaving the fisherman to fish on his own.

const METHODS := ["line", "trap", "net", "trident"]
## A pot is pulled when the middle of the boat passes this close over it.
const PULL_REACH := 26.0
const NET_REACH := 170.0
const SPEAR_REACH := 150.0

var screen: Node
var method := "line"
var idle := false
var traps_view: TrapView
var net_view: NetView
var trident_view: TridentView
var _idle_minutes := 0.0
var _rng: RandomNumberGenerator


func setup(s: Node, rng: RandomNumberGenerator) -> void:
	screen = s
	_rng = rng
	method = str(Game.state.get("method", "line"))
	if not method in METHODS:
		method = "line"


func set_method(m: String) -> void:
	if m == method or not m in METHODS:
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
	idle = on
	_idle_minutes = 0.0
	if on:
		Game.state["idle"] = {"place": screen.place_id, "bait": screen.bait(), "depth": maxf(10.0, screen.hook.y)}
	else:
		Game.state.erase("idle")
	Toast.say("Fishing on his own." if on else "Back at the rod.")


func _net() -> String:
	return str(Game.state["gear"].get("net", ""))


func traps_here() -> Array:
	return Game.state["traps"].filter(func(t): return t["place"] == screen.place_id)


## Each frame on the boat: the fisherman fishes on his own if idle, pots under the boat come up, and the aims follow the mouse.
func tick(delta: float) -> void:
	var minutes := delta / 60.0
	if idle:
		_idle_minutes += minutes
		if _idle_minutes >= 0.25:
			_idle_step(_idle_minutes)
			_idle_minutes = 0.0
	trident_view.lit = Trident.can_use(screen.hour, str(Game.state["gear"].get("lamp", "")))
	if method == "trident" and not trident_view.lit:
		method = "line"
	for t in Game.state["traps"]:
		t["_told"] = maxf(0.0, float(t.get("_told", 0.0)) - delta / 20.0)
	_pull_traps_under_boat()
	var mouse: Vector2 = screen.get_global_mouse_position() + screen.camera.cam
	net_view.aim = mouse
	trident_view.aim = mouse
	net_view.thrown_left = maxf(0.0, net_view.thrown_left - delta)
	trident_view.thrown_left = maxf(0.0, trident_view.thrown_left - delta)
	traps_view.queue_redraw()
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
		Clock.season(day), screen.weather)
	for c in got:
		Game.state["bait"][bait] = maxi(0, int(Game.state["bait"].get(bait, 0)) - 1)
		Catches.record(Game.state, c["fish"], float(c["pounds"]), false)
		Toast.say("+ " + Data.fish[c["fish"]]["name"])
	if Hold.room(Game.state) <= 0:
		set_idle(false)
		Toast.say("The hold is full.")


func _pull_traps_under_boat() -> void:
	var mid: float = screen.boat_x + 52.0
	for t in traps_here():
		if absf(float(t["x"]) - mid) < PULL_REACH and not t["catch"].is_empty() and t.get("_told", 0.0) <= 0.0:
			var got := Traps.empty_into(Game.state, t)
			if not got.is_empty():
				Toast.say("You rowed over your pot and hauled it up: " + ", ".join(got.map(func(c): return Data.fish[c["fish"]]["name"].to_lower())) + ".")
			if not t["catch"].is_empty():
				Toast.say("The hold is full; the rest stay in the pot.")
				t["_told"] = 1.0


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
			Traps.empty_into(Game.state, t)
			if not t["catch"].is_empty():
				Toast.say("Make room in the hold before lifting this pot.")
				return
			Game.state["traps"].erase(t)
			Toast.say("Lifted the pot.")
			return
	var allowed := int(Game.state["gear"].get("traps", 2))
	if Game.state["traps"].size() >= allowed:
		Toast.say("All %d pots are set." % allowed)
		return
	var bait: String = screen.bait()
	if bait != "":
		Game.state["bait"][bait] = int(Game.state["bait"][bait]) - 1
	Game.state["traps"].append({"place": screen.place_id, "x": roundf(mid), "depth": screen.seabed.depth_at(mid),
		"set_time": float(Game.state["time"]), "catch": [], "size": 3, "hours": 0.0, "bait": bait})
	Game.state["stats"]["pots_set"] = int(Game.state["stats"].get("pots_set", 0)) + 1
	if int(Game.state["stats"].get("pots_set", 0)) <= 1:
		Toast.say("Your pot sinks to the seabed and fills with crabs, lobsters and octopus. Row over it later to haul it up.")
	else:
		Toast.say("Pot set on the seabed%s." % ((", baited with " + str(Data.bait[bait]["name"]).to_lower()) if bait != "" else ""))


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
