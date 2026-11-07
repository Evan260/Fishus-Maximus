class_name FloorView
extends Sprite2D
## The sea floor, painted once when a place opens: a strip of sand that joins seamlessly onto itself is laid along the
## seabed's line, column by column, and below it the ground is solid shadow down past the bottom of the world.

const SHADOW := Color("#14222a")


func bake(place: Dictionary, bed: Seabed) -> void:
	var width := int(place["width"])
	var height := int(place["depth"]) + 80
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var spec: Dictionary = place.get("floor", {})
	var strip: Image = null
	var path := "res://assets/art/" + str(spec.get("file", ""))
	if spec.has("file") and ResourceLoader.exists(path):
		strip = (load(path) as Texture2D).get_image()
		strip.convert(Image.FORMAT_RGBA8)
	var surface := int(spec.get("surface", 0))
	for x in width:
		var top := int(roundf(bed.depth_at(x))) - surface
		var below := top
		if strip:
			var sx := x % strip.get_width()
			img.blit_rect(strip, Rect2i(sx, 0, 1, strip.get_height()), Vector2i(x, top))
			below = top + strip.get_height()
		else:
			below = top + surface
		if below < height:
			img.fill_rect(Rect2i(x, maxi(0, below), 1, height - maxi(0, below)), SHADOW)
	texture = ImageTexture.create_from_image(img)
	centered = false


func place_at(cam: Vector2) -> void:
	position = -cam
