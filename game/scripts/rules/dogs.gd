class_name Dogs
## The dogs from Farmus Maximus, one chosen at the start to ride in the bow.

const NAMES := {"hound": "Farm hound", "molossian": "Mastiff", "sighthound": "Sighthound", "lapdog": "Lapdog", "sheepdog": "Sheepdog"}
const ART := "res://assets/art/dogs/"


static func breeds() -> Array:
	return NAMES.keys()


## The frames of one of a dog's moves: "sit_east", "sleep_east" or "happy_east".
static func frames(breed: String, move: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if not breed in NAMES:
		breed = "hound"
	for i in 12:
		var path := "%s%s/%s/frame_%02d.png" % [ART, breed, move, i]
		if not ResourceLoader.exists(path):
			break
		out.append(load(path))
	return out
