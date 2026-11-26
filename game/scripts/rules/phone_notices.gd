class_name PhoneNotices
## What a phone tells the player while the game is put away: once when every pot set is full, and once when the boat
## left fishing on its own stops, its hold full or its bait gone. The time away is played ahead on a copy of the game
## as saved, with the dice the return uses (`Away`), so a notice tells what the player then finds, never past the cap.


## Each notice as {id, seconds, title, text}, soonest first; the phone replaces a waiting notice that has the same id.
static func plan(saved: Dictionary, pots := true, boat := true) -> Array:
	var state: Dictionary = saved.duplicate(true)
	var watch_pots := pots and can_fill(state)
	# Pots or a boat already stopped when the game was put away were left that way, so only stopping later is news.
	var watch_boat := boat and Away.fishing(state)
	var were_full := pots_full(state)
	var rng := Away.rng(state)
	var most := Clock.away(INF)
	var notices := []
	var t := 0.0
	while t < most and (watch_pots or watch_boat):
		t += Away.step(state, most - t, rng)
		if watch_pots:
			var full := pots_full(state)
			if full and not were_full:
				notices.append(_notice("pots", t, "Your pots are full", "Row over them to haul them up."))
				watch_pots = false
			were_full = full
		if watch_boat and not Away.fishing(state):
			notices.append(_notice("boat", t, "Your boat has stopped fishing", "The hold is full." if Hold.room(state) <= 0 else "Out of bait."))
			watch_boat = false
	return notices


## Whether every pot set holds all it can.
static func pots_full(state: Dictionary) -> bool:
	var traps: Array = state["traps"]
	return not traps.is_empty() and traps.all(func(t): return t["catch"].size() >= int(t.get("size", 3)))


## Whether the pots set can all fill: a pot where nothing lives at its depth stays empty.
static func can_fill(state: Dictionary) -> bool:
	var traps: Array = state["traps"]
	return not traps.is_empty() and traps.all(func(t): return not Traps.kinds(str(t["place"]), float(t["depth"])).is_empty())


static func _notice(id: String, minutes: float, title: String, text: String) -> Dictionary:
	# A minute of game time away is a minute of real time.
	return {"id": id, "seconds": minutes * 60.0, "title": String(TranslationServer.translate(title)), "text": String(TranslationServer.translate(text))}
