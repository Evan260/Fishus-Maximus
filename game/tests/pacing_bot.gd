class_name PacingBot
extends RefCounted
## A keen player run on the game's own rules, minute by minute of game time: it fishes where the day's orders and
## clients' fish live, sells when the hold is full, fills orders, buys bait, gear and the next boat, builds ponds and
## hunts the legends whose time has come. It notes when each chapter, boat and legend arrives, in hours of play.

## Catches a minute while fishing by hand.
const RATE := 1.0
## The chance a minute that a legend whose time and place have come is landed.
const LEGEND := 0.06

var state: Dictionary
var rng: RandomNumberGenerator
var log := {"chapters": {}, "boats": {}, "legends": {}, "denarii": 0}
var _minutes := 0.0
var _place := "harbour"


func run(hours: float, seed: int) -> Dictionary:
	Game.new_game("Bot", "hound")
	state = Game.state
	state["seed"] = seed
	rng = Seeds.rng(seed, "bot")
	state["orders"] = []
	Orders.new_day(state, rng)
	var last_chapter := 1
	while _minutes < hours * 60.0:
		if int(_minutes) % 30 == 0 or (int(_minutes) % 5 == 0 and _legend_somewhere()):
			_choose_place()
		_fish_a_minute()
		if Hold.room(state) <= 0 or int(_minutes) % 25 == 24:
			_go_to_town()
		_tick(1.0)
		if int(state["chapter"]) > last_chapter:
			last_chapter = int(state["chapter"])
			log["chapters"][last_chapter] = snappedf(_minutes / 60.0, 0.01)
	log["denarii"] = int(state["denarii"])
	log["reputation"] = int(state["reputation"])
	return log


func _tick(minutes: float) -> void:
	World.advance(state, minutes, rng)
	_minutes += minutes


func _hour() -> float:
	return Clock.hour(float(state["time"]))


func _season() -> String:
	return Clock.season(Clock.day_of(float(state["time"])))


## Goes where a legend can be had now, or where the most wanted fish live.
func _choose_place() -> void:
	var places := Story.reachable(state)
	var best := _place
	var score := -1.0
	for p in places:
		var s := 0.0
		for method in ["line", "trap", "net"]:
			s += 10.0 * Legends.here(p, _hour(), _season(), str(state.get("weather", "clear")), state, method).size()
		for want in _wants():
			if p in Data.fish[want["fish"]]["places"]:
				s += 1.0
		s += 0.5 * Story.boat_rank(str(Data.places[p]["boat"]))
		if s > score:
			score = s
			best = p
	if best != _place and BayMap.sail(state, best):
		_place = best
		_minutes += 1.0


func _legend_somewhere() -> bool:
	for p in Story.reachable(state):
		for method in ["line", "trap", "net"]:
			if _method_open(method) and not Legends.here(p, _hour(), _season(), str(state.get("weather", "clear")), state, method).is_empty():
				return p != _place
	return false


func _wants() -> Array:
	var out: Array = state["orders"].duplicate()
	for c in Data.clients:
		var step := Story.client_step(state, c)
		if not step.is_empty():
			out.append(step)
	return out


func _fish_a_minute() -> void:
	var hour := _hour()
	var weather := str(state.get("weather", "clear"))
	for method in ["line", "net", "trap"]:
		for legend in Legends.here(_place, hour, _season(), weather, state, method):
			if rng.randf() < LEGEND and _method_open(method):
				Catches.record(state, legend, Catalog.roll_pounds(legend, rng), Hold.well_room(state) > 0)
				log["legends"][legend] = snappedf(_minutes / 60.0, 0.01)
				return
	var catches := RATE * (1.0 + 0.15 * float(Data.gear[state["gear"]["rod"]]["pull"]))
	var n := int(catches) + (1 if rng.randf() < catches - floorf(catches) else 0)
	var depth_limit := minf(float(Data.places[_place]["depth"]), float(Data.gear[state["gear"]["line"]]["length"]))
	for i in n:
		var kinds := Catalog.available(_place, rng.randf_range(10.0, depth_limit), hour, _season(), weather, "line")
		if kinds.is_empty():
			continue
		var fish := Pick.by_rarity(kinds, rng)
		Catches.record(state, fish, Catalog.roll_pounds(fish, rng), Data.fish[fish].get("live", false))
		if Hold.room(state) <= 0:
			return


func _method_open(method: String) -> bool:
	return method in Story.unlocks(int(state["chapter"]))["methods"]


## Rows to the quay and spends a couple of minutes in town: orders and clients first, then the market and the shops.
func _go_to_town() -> void:
	if _place != "harbour":
		BayMap.sail(state, "harbour")
		_place = "harbour"
	for i in range(state["orders"].size() - 1, -1, -1):
		var at := _find(state["orders"][i])
		if at[0] >= 0:
			Orders.fill(state, i, at[0], at[1])
	for c in Data.clients:
		var step := Story.client_step(state, c)
		if not step.is_empty():
			var at := _find(step)
			if at[0] >= 0:
				Story.deliver(state, c, at[0], at[1])
	for i in state["live_well"].size():
		if state["ponds"].size() > 0:
			Ponds.stock(state, 0, 0)
	for p in state["ponds"].size():
		Ponds.feed(state, p)
	while not state["hold"].is_empty():
		Market.sell(state, 0)
	_shop()
	_tick(2.0)


func _find(want: Dictionary) -> Array:
	for from_well in [true, false]:
		var list: Array = state["live_well"] if from_well else state["hold"]
		for i in list.size():
			if Orders.suits(want, list[i], from_well):
				return [i, from_well]
	return [-1, false]


## Buys the next boat first, then gear that helps, then a pond and its features.
func _shop() -> void:
	for boat in ["fishing_boat", "sailing_boat", "big_boat"]:
		if Shop.buy(state, boat):
			log["boats"][boat] = snappedf(_minutes / 60.0, 0.01)
	# A boat on sale and not yet owned is saved for before anything else.
	for boat in ["fishing_boat", "sailing_boat", "big_boat"]:
		if Shop.on_sale(state, boat) and not Shop.owned(state, boat):
			return
	for id in ["ash_rod", "horsehair_line", "barbed_hook", "yew_rod", "twisted_line", "iron_hook", "masters_rod", "fine_line", "cast_net"]:
		if int(state["denarii"]) > Shop.price(id) + 150:
			Shop.buy(state, id)
	if state["ponds"].size() < Ponds.allowed(state) and int(state["denarii"]) > 400:
		Ponds.build(state, state["ponds"].size(), "large")
	for p in state["ponds"].size():
		for f in ["rocks", "sand", "weed", "caves"]:
			if int(state["denarii"]) > 300:
				Ponds.add_feature(state, p, f)
