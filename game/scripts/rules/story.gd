class_name Story
## Your name in town and the five chapters it opens, and each client's story, one request after another.


static func chapter_for(reputation: int) -> int:
	var out := 1
	for c in Data.chapters:
		if reputation >= int(c["reputation"]):
			out = maxi(out, int(c["chapter"]))
	return out


## Everything open by this chapter: its places, clients, shop stock, boats and methods, with every earlier chapter's.
static func unlocks(chapter: int) -> Dictionary:
	var out := {"places": [], "clients": [], "bait": [], "gear": [], "boats": ["skiff"], "methods": [], "pond": 1, "tanks": 1}
	for c in Data.chapters:
		if int(c["chapter"]) > chapter:
			continue
		for key in ["places", "clients", "bait", "gear", "boats", "methods"]:
			for v in c[key]:
				if not v in out[key]:
					out[key].append(v)
		out["pond"] = int(c["pond"])
		out["tanks"] = int(c["tanks"])
	return out


## Raises your name and opens the next chapter when it is high enough; says the new chapter, or 0. The demo stops at
## its last chapter and marks the game `demo_done` when the next one would have opened.
static func add_reputation(state: Dictionary, amount: int) -> int:
	state["reputation"] = int(state["reputation"]) + amount
	var c := chapter_for(int(state["reputation"]))
	if Game.in_full_game(c):
		state["demo_done"] = true
		c = Game.demo_last_chapter()
	if c > int(state["chapter"]):
		state["chapter"] = c
		return c
	return 0


## The boats' order from the skiff up, so a place's boat can be compared with yours.
static func boat_rank(boat: String) -> int:
	return Data.boats.keys().find(boat)


## The places you can fish now: open by your chapter and reachable in your boat.
static func reachable(state: Dictionary) -> Array:
	var open: Array = unlocks(int(state["chapter"]))["places"]
	var rank := boat_rank(str(state["boat"]))
	return open.filter(func(p): return boat_rank(str(Data.places[p]["boat"])) <= rank)


## The client's current request, or nothing when they have not come to town yet or their story is done.
static func client_step(state: Dictionary, client: String) -> Dictionary:
	var c: Dictionary = Data.clients.get(client, {})
	if c.is_empty() or int(c["chapter"]) > int(state["chapter"]):
		return {}
	var at := int(state["clients"].get(client, 0))
	return c["steps"][at] if at < c["steps"].size() else {}


## The clients in town on a day: at most two of those with something to ask, taking turns day by day so every one
## of them comes.
static func visiting(state: Dictionary, day: int) -> Array:
	var waiting: Array = Data.clients.keys().filter(func(c): return not client_step(state, c).is_empty())
	if waiting.size() <= 2:
		return waiting
	var first := posmod(day, waiting.size())
	return [waiting[first], waiting[(first + 1) % waiting.size()]]


static func advance_client(state: Dictionary, client: String) -> void:
	state["clients"][client] = int(state["clients"].get(client, 0)) + 1


## Hands a client the fish found for them by Supply.find; pays and moves their story on when it is right.
static func deliver_from(state: Dictionary, client: String, at: Dictionary) -> bool:
	var step := client_step(state, client)
	if step.is_empty() or at.is_empty() or Supply.find(state, step) != at:
		return false
	Legends.pay(state, Supply.take(state, at).get("fish", ""))
	state["denarii"] = int(state["denarii"]) + int(step["reward"])
	add_reputation(state, int(step["reputation"]))
	advance_client(state, client)
	return true


## Hands a client the fish they asked for, from the hold or the well; pays and moves their story on when it is right.
static func deliver(state: Dictionary, client: String, index: int, from_well: bool) -> bool:
	var step := client_step(state, client)
	var list: Array = state["live_well"] if from_well else state["hold"]
	if step.is_empty() or index < 0 or index >= list.size() or not Orders.suits(step, list[index], from_well):
		return false
	Legends.pay(state, list[index]["fish"])
	list.remove_at(index)
	state["denarii"] = int(state["denarii"]) + int(step["reward"])
	add_reputation(state, int(step["reputation"]))
	advance_client(state, client)
	return true
