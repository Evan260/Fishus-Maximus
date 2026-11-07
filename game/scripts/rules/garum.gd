class_name Garum
## The garum works: stone tanks of fish and salt that ferment day by day into allec, muria, garum and, from mackerel
## only, garum sociorum, then go into amphorae for the market or the export ship.


static func new_tanks() -> Array:
	var out := []
	for i in int(Data.garum.get("tanks", 8)):
		out.append({"restored": i == 0, "fish": {}, "pounds": 0.0, "days": 0, "quality": 0.5, "stirred": false})
	return out


static func restore(state: Dictionary, tank: int) -> bool:
	var t: Dictionary = state["tanks"][tank]
	var open := int(Story.unlocks(int(state["chapter"]))["tanks"])
	var working: int = state["tanks"].filter(func(x): return x["restored"]).size()
	var price := int(Data.garum["restore"]["price"])
	if t["restored"] or working >= open or int(state["denarii"]) < price:
		return false
	state["denarii"] = int(state["denarii"]) - price
	t["restored"] = true
	return true


static func salt_needed(pounds: float) -> int:
	return int(ceilf(pounds * float(Data.garum.get("salt_per_pound", 0.25))))


## Fills an empty working tank with fish by weight and salt by measure.
static func fill(state: Dictionary, tank: int, fish: Array, salt: int) -> bool:
	var t: Dictionary = state["tanks"][tank]
	var pounds := 0.0
	for f in fish:
		pounds += float(f["pounds"])
	if not t["restored"] or float(t["pounds"]) > 0.0 or pounds <= 0.0 or salt < salt_needed(pounds) or int(state.get("salt", 0)) < salt:
		return false
	state["salt"] = int(state.get("salt", 0)) - salt
	var kinds := {}
	for f in fish:
		kinds[f["fish"]] = float(kinds.get(f["fish"], 0.0)) + float(f["pounds"])
	t["fish"] = kinds
	t["pounds"] = pounds
	t["days"] = 0
	t["quality"] = 0.5
	t["stirred"] = false
	return true


static func stir(state: Dictionary, tank: int) -> void:
	if float(state["tanks"][tank]["pounds"]) > 0.0:
		state["tanks"][tank]["stirred"] = true


## A day at the works: every full tank ferments a day longer, and a stirred one gets better.
static func day(state: Dictionary) -> void:
	for t in state["tanks"]:
		if float(t["pounds"]) <= 0.0:
			continue
		t["days"] = int(t["days"]) + 1
		if t["stirred"]:
			t["quality"] = minf(1.0, float(t["quality"]) + float(Data.garum.get("stir_quality", 0.05)))
		t["stirred"] = false


## What the tank would give now, or nothing when it is empty or not yet three days in.
static func grade(t: Dictionary) -> String:
	if float(t["pounds"]) <= 0.0:
		return ""
	var out := ""
	for g in Data.garum["grades"]:
		if int(t["days"]) >= int(g["days"]) and (not g.has("only") or t["fish"].keys() == [g["only"]]):
			out = g["id"]
	return out


static func grade_info(id: String) -> Dictionary:
	for g in Data.garum["grades"]:
		if g["id"] == id:
			return g
	return {}


## Empties a ready tank into amphorae of its grade, kept in the store until sold.
static func take(state: Dictionary, tank: int) -> Dictionary:
	var t: Dictionary = state["tanks"][tank]
	var g := grade(t)
	if g == "":
		return {}
	var n := maxi(1, int(float(t["pounds"]) / float(Data.garum.get("pounds_per_amphora", 5))))
	var had := int(state["garum"].get(g, 0))
	var qualities: Dictionary = state["garum_quality"] if state.get("garum_quality") is Dictionary else {}
	qualities[g] = (quality(state, g) * had + float(t["quality"]) * n) / float(had + n)
	state["garum_quality"] = qualities
	state["garum"][g] = had + n
	state["stats"]["garum_" + g] = int(state["stats"].get("garum_" + g, 0)) + n
	t["fish"] = {}
	t["pounds"] = 0.0
	t["days"] = 0
	return {"grade": g, "amphorae": n}


## An amphora's price at the market, by grade and how well the tank was kept; the export ship pays more.
static func price(grade_id: String, quality: float, export: bool) -> int:
	var base := float(grade_info(grade_id).get("price", 0))
	return int(roundf(base * (0.6 + 0.8 * quality) * (float(Data.garum.get("export_bonus", 1.5)) if export else 1.0)))


static func sell(state: Dictionary, grade_id: String, export: bool) -> int:
	if int(state["garum"].get(grade_id, 0)) <= 0:
		return 0
	var paid := price(grade_id, quality(state, grade_id), export)
	state["garum"][grade_id] = int(state["garum"][grade_id]) - 1
	state["denarii"] = int(state["denarii"]) + paid
	return paid


static func export_day(day: int) -> bool:
	return day > 0 and day % 7 == 0


## How well the amphorae of a grade in store were made, on average.
static func quality(state: Dictionary, grade_id: String) -> float:
	var q = state.get("garum_quality", {})
	return float(q.get(grade_id, 0.5)) if q is Dictionary else float(q)
