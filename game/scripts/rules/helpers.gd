class_name Helpers
## Hired help: Tertius the boy pulls the pots and stirs the tanks each morning, and later a second fisherman fishes
## the harbour on his own all day, filling the hold.

const HELP := {
	"boy": {"name": "Tertius, the errand boy", "price": 60, "chapter": 1, "text": "Pulls your pots into the hold and stirs the garum tanks each morning."},
	"fisherman": {"name": "A second fisherman", "price": 400, "chapter": 4, "text": "Fishes the harbour on his own all day while you are busy elsewhere."},
}


static func hire(state: Dictionary, id: String) -> bool:
	var h: Dictionary = HELP.get(id, {})
	if h.is_empty() or id in state["helpers"] or int(state["chapter"]) < int(h["chapter"]) or int(state["denarii"]) < int(h["price"]):
		return false
	state["denarii"] = int(state["denarii"]) - int(h["price"])
	state["helpers"].append(id)
	return true


## The morning's work: the boy empties every pot with something in it and stirs every tank.
static func morning(state: Dictionary) -> void:
	if not "boy" in state["helpers"]:
		return
	for t in state["traps"]:
		Traps.empty_into(state, t)
	for i in state["tanks"].size():
		Garum.stir(state, i)


## The second fisherman's catch over some minutes of the day, at the rate of fishing on one's own, into the hold.
static func fish(state: Dictionary, minutes: float, rng: RandomNumberGenerator) -> void:
	if not "fisherman" in state["helpers"] or Hold.room(state) <= 0:
		return
	var t := float(state["time"])
	for c in Idle.catches(minutes, "harbour", 60.0, "worm", Hold.room(state), rng, Clock.hour(t), Clock.season(Clock.day_of(t)), str(state.get("weather", "clear"))):
		Catches.record(state, c["fish"], float(c["pounds"]), false)
