class_name Nets
## The cast net thrown over a shoal near the surface.


## How many of a shoal the net brings up: up to the net's size, and fewer the further the ring lands off the shoal's
## middle, where an aim error of 1 or more is a miss.
static func throw(shoal_size: int, net: Dictionary, aim_error: float, rng: RandomNumberGenerator) -> int:
	if aim_error >= 1.0 or shoal_size <= 0:
		return 0
	var most := mini(shoal_size, int(net.get("size", 4)))
	var k := (1.0 - aim_error) * rng.randf_range(0.75, 1.0)
	return clampi(int(roundf(most * k)), 1, most)
