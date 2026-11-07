class_name Pick
## Choosing one fish from a list, the commoner kinds more often.


static func by_rarity(kinds: Array, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in kinds:
		total += float(Data.fish[k]["rarity"])
	var left := rng.randf() * total
	for k in kinds:
		left -= float(Data.fish[k]["rarity"])
		if left <= 0.0:
			return k
	return kinds[-1]


## A caught fish as the hold keeps it.
static func catch_of(fish: String, rng: RandomNumberGenerator, live: bool) -> Dictionary:
	return {"fish": fish, "pounds": Catalog.roll_pounds(fish, rng), "fresh": 1.0, "live": live}
