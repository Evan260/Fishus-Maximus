class_name Dogs
## The dogs from Farmus Maximus, one chosen at the start to ride in the bow: its breed, its coat and its name. Every
## breed comes in several coats, recoloured from its own fur as in Farmus, so collars, eyes and pale markings stay as
## drawn.

const NAMES := {"hound": "Farm hound", "molossian": "Mastiff", "sighthound": "Sighthound", "lapdog": "Lapdog", "sheepdog": "Sheepdog"}
const ART := "res://assets/art/dogs/"
const COATS := {"golden": "Golden", "black": "Black", "chocolate": "Chocolate", "cream": "Cream", "grey": "Grey", "red": "Red"}
## Every breed's coats; the first is the look its pictures are drawn in, and "natural" keeps that id for old saves.
const BREED_COATS := {
	"hound": COATS,
	"molossian": {"natural": "Brown", "fawn": "Fawn", "grey": "Grey", "black": "Black"},
	"sighthound": {"natural": "Fawn", "black": "Black and white", "grey": "Grey and white"},
	"lapdog": {"natural": "White", "apricot": "Apricot", "grey": "Grey", "black": "Black"},
	"sheepdog": {"natural": "Grey and white", "black": "Black and white", "brown": "Brown and white"},
}
const DEFAULT_NAME := "Fidus"

static var _recoloured := {}


static func breeds() -> Array:
	return NAMES.keys()


## The coats a breed comes in.
static func coats(breed: String) -> Dictionary:
	return BREED_COATS.get(breed, COATS)


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


## A picture of the dog in a coat, worked out once and kept: only the breed's own fur colours change.
static func recolour(tex: Texture2D, breed: String, coat: String) -> Texture2D:
	if not breed in BREED_COATS or not coats(breed).has(coat) or coat == coats(breed).keys()[0]:
		return tex
	var key := "%s|%s" % [tex.resource_path, coat]
	if not _recoloured.has(key):
		var img := tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.0:
					img.set_pixel(x, y, pixel(breed, coat, c))
		_recoloured[key] = ImageTexture.create_from_image(img)
	return _recoloured[key]


## One pixel of a breed in one of its coats.
static func pixel(breed: String, coat: String, c: Color) -> Color:
	match breed:
		"hound":
			if c.h >= 0.02 and c.h <= 0.16 and c.s >= 0.3:
				return _shift(c, coat)
		"molossian":
			if c.h < 0.04 or c.h > 0.12:
				return c
			# The low, dark pixels are the black mask and outline, which stay dark in every coat.
			var body := c.s >= 0.27 and c.v >= 0.32
			match coat:
				"fawn":
					if body: return Color.from_hsv(0.095, c.s * 0.95, minf(1.0, c.v * 1.4), c.a)
				"grey":
					return Color.from_hsv(0.6, 0.07 if body else 0.06, c.v * (0.92 if body else 1.0), c.a)
				"black":
					if body: return Color.from_hsv(0.07, 0.2, c.v * 0.42 + 0.05, c.a)
		"sighthound":
			# The olive tinge on its tail is part of the coat too.
			if coat == "natural" or c.h < 0.02 or c.h > 0.2:
				return c
			if c.s >= 0.4 or (c.s >= 0.3 and c.v < 0.45):
				return _shift(c, coat)
			if c.v >= 0.6:
				# Its pale muzzle, chest and feet turn white beside a dark coat.
				return Color.from_hsv(0.1, c.s * 0.4, minf(1.0, c.v * 1.03), c.a)
		"lapdog":
			var fur := (c.h >= 0.05 and c.h <= 0.13 and c.s < 0.4) or (c.s < 0.05 and c.v > 0.95)
			if not fur:
				return c
			match coat:
				"apricot": return Color.from_hsv(0.075, minf(1.0, c.s * 1.6 + 0.2), c.v * 0.96, c.a)
				"grey": return Color.from_hsv(0.6, 0.05, c.v * 0.75, c.a)
				"black": return Color.from_hsv(0.62, 0.1, 0.07 + c.v * 0.3, c.a)
		"sheepdog":
			# Only the grey fur changes; its white coat stays white.
			if c.h < 0.04 or c.h > 0.13 or c.s >= 0.2 or c.v > 0.66:
				return c
			match coat:
				"black": return Color.from_hsv(0.62, 0.1, 0.06 + c.v * 0.38, c.a)
				"brown": return Color.from_hsv(0.06, 0.5, c.v * 0.78, c.a)
	return c


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
