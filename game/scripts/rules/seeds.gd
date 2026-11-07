class_name Seeds
## Every random choice in the rules comes from here, one stream per use, so a day can be replayed and tested.


static func rng(seed: int, tag: String, n: int = 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d:%s:%d" % [seed, tag, n])
	return r
