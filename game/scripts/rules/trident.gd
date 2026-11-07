class_name Trident
## Spearing fish by the lamp's light at night.


static func can_use(hour: float, lamp: String) -> bool:
	return lamp != "" and (hour >= Data.num("time.dusk_hour", 20) or hour < Data.num("time.dawn_hour", 5))


## How far a lamp's light draws the night fish to the boat.
static func reach(lamp: String) -> float:
	return float(Data.gear.get(lamp, {}).get("radius", 0)) * 2.5 if lamp != "" else 0.0


static func hits(at: Vector2, fish_at: Vector2) -> bool:
	return at.distance_to(fish_at) <= Data.num("trident.reach", 6)
