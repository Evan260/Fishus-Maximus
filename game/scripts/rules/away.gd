class_name Away
## Time away from the game, lived an hour of the clock at a time, so what the boat catches on its own keeps to each
## hour's time of day, season and weather. The catch-up on return and a phone's reminders both play it this way with
## the same dice, so a reminder tells what the player then finds.


## The dice for the time away since the game was last saved, the same each time that stretch is played out.
static func rng(state: Dictionary) -> RandomNumberGenerator:
	return Seeds.rng(int(state["seed"]), "away", int(float(state.get("last_real_time", 0.0))))


## Lives up to an hour of the clock, and no more than `left` minutes; says how many minutes it took.
static func step(state: Dictionary, left: float, rng: RandomNumberGenerator) -> float:
	var t := float(state["time"])
	var minutes := minf(left, Clock.minutes_for_hours(t, 1.0))
	World.advance(state, minutes, rng)
	fish(state, minutes, t + minutes / 2.0, rng)
	return minutes


## What the boat left fishing on its own catches in `minutes` of time away around the time `t`.
static func fish(state: Dictionary, minutes: float, t: float, rng: RandomNumberGenerator) -> void:
	if not state.has("idle"):
		return
	var idle: Dictionary = state["idle"]
	var bait := str(idle["bait"])
	var day := Clock.day_of(t)
	var weather := str(state.get("weather", "clear")) if day == Clock.day_of(float(state["time"])) else Weather.for_day(int(state["seed"]), day)
	for c in Idle.catches(minutes, str(idle["place"]), float(idle["depth"]), bait, mini(Hold.room(state), bait_left(state)), rng,
			Clock.hour(t), Clock.season(day), weather, float(idle.get("water", INF))):
		Catches.record(state, c["fish"], float(c["pounds"]), false)
		state["bait"][bait] = int(state["bait"][bait]) - 1


## How many of the bait the boat fishes with are left; none when it fishes with no bait.
static func bait_left(state: Dictionary) -> int:
	var bait := str(state.get("idle", {}).get("bait", ""))
	return int(state["bait"].get(bait, 0)) if bait != "" else 0


## Whether the boat left fishing on its own can go on: it has room in the hold and bait on the hook.
static func fishing(state: Dictionary) -> bool:
	return state.has("idle") and Hold.room(state) > 0 and bait_left(state) > 0
