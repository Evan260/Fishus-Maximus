class_name ItemArt
## The picture of a thing: a bait, a piece of gear, help for hire, a way of fishing, a boat or a fish, for the picture
## tiles of the shops, the tackle and the boat's bar.

const ITEMS := "res://assets/art/items/"
const PROPS := "res://assets/art/props/"
## The pictures that stand for the ways of fishing whose own picture is another thing's.
const METHODS := {"net": "cast_net"}


static func of(id: String) -> Texture2D:
	var path := ITEMS + id + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	if METHODS.has(id):
		return of(METHODS[id])
	if id.begins_with("trap_"):
		return load(PROPS + "trap.png")
	if Data.boats.has(id) and ResourceLoader.exists(PROPS + id + ".png"):
		return load(PROPS + id + ".png")
	if Data.fish.has(id):
		return _fish(id)
	return null


static func _fish(id: String) -> Texture2D:
	var path := "res://assets/art/fish/%s.png" % id
	return load(path) if ResourceLoader.exists(path) else null


## A picture shrunk at its own pixels to fit `room` (a size, or a number for a square), or as it is when it fits.
static func fitted(tex: Texture2D, room) -> Texture2D:
	var box: Vector2 = room if room is Vector2 else Vector2(room, room)
	var share := minf(box.x / tex.get_width(), box.y / tex.get_height())
	return tex if share >= 1.0 else Pixels.shrunk(tex, share)
