class_name Dogs
## The dogs from Farmus Maximus, one chosen at the start to ride in the bow: its breed, its coat and its name. Only the
## farm hound comes in several coats, recoloured from its own golden fur as in Farmus, so collars, eyes and the pale
## chest stay as drawn.

const NAMES := {"hound": "Farm hound", "molossian": "Mastiff", "sighthound": "Sighthound", "lapdog": "Lapdog", "sheepdog": "Sheepdog"}
const ART := "res://assets/art/dogs/"
const COATS := {"golden": "Golden", "black": "Black", "chocolate": "Chocolate", "cream": "Cream", "grey": "Grey", "red": "Red"}
const DEFAULT_NAME := "Fidus"

static var _recoloured := {}


static func breeds() -> Array:
	return NAMES.keys()


## The coats a breed comes in: the farm hound in several, the others only in their own.
static func coats(breed: String) -> Dictionary:
	return COATS if breed == "hound" else {"natural": "Natural coat"}


## The frames of one of a dog's moves: "sit_east", "sleep_east" or "happy_east", in the coat given.
static func frames(breed: String, move: String, coat := "") -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if not breed in NAMES:
		breed = "hound"
	for i in 12:
		var path := "%s%s/%s/frame_%02d.png" % [ART, breed, move, i]
		if not ResourceLoader.exists(path):
			break
		out.append(recolour(load(path), breed, coat))
	return out


## A picture of the dog in a coat, worked out once and kept: only its warm golden fur changes.
static func recolour(tex: Texture2D, breed: String, coat: String) -> Texture2D:
	if breed != "hound" or not COATS.has(coat) or coat == "golden":
		return tex
	var key := "%s|%s" % [tex.resource_path, coat]
	if not _recoloured.has(key):
		var img := tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.0 and c.h >= 0.02 and c.h <= 0.16 and c.s >= 0.3:
					img.set_pixel(x, y, _shift(c, coat))
		_recoloured[key] = ImageTexture.create_from_image(img)
	return _recoloured[key]


static func _shift(c: Color, coat: String) -> Color:
	match coat:
		"black":
			return Color.from_hsv(c.h, c.s * 0.25, c.v * 0.32 + 0.05, c.a)
		"chocolate":
			return Color.from_hsv(0.055, c.s * 0.8, c.v * 0.62, c.a)
		"cream":
			return Color.from_hsv(0.1, c.s * 0.22, 0.74 + c.v * 0.24, c.a)
		"grey":
			return Color.from_hsv(0.6, c.s * 0.08, c.v * 0.82, c.a)
		"red":
			return Color.from_hsv(0.032, c.s * 0.92, c.v * 0.7, c.a)
	return c
