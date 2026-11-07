class_name BoatView
extends Node2D
## The boat bobbing on the water with the fisherman sitting in it and his rod drawn out over the bow, and the part of
## the hull below the waterline tinted as if seen through the water. Where people sit is measured from the hull picture.

const ART := "res://assets/art/props/"
const FALLBACK := "res://assets/art/style_test/boat.png"
const TINT := Color(0.5, 0.78, 0.84, 0.85)
## How deep the hull sits in the water.
const DRAFT := 10.0
const ROD := Vector2(18, -17)
const ROD_COLOUR := Color("#6b4a2b")

var boat: Sprite2D
var hull: Sprite2D
var person: Sprite2D
## The hull's near side, drawn again over the fisherman so he sits in the boat with the sail and mast behind him.
var front: Sprite2D
var facing := 1.0
var bob := 0.0
## How far the boat's top sits above the waterline.
var ride := 44.0
## The row of the hull's top edge, where the fisherman and the dog sit, in the hull picture.
var deck := 30.0
## Where the fisherman sits: how far along the boat, and the row of the hull's top edge in front of him.
var seat := Vector2(0.62, 30.0)
## Where the dog sits, the same way: how far along, and the row its feet rest on.
var dog_spot := Vector2(0.24, 32.0)
var _painted := false


func set_boat(id: String) -> void:
	var path := ART + id + ".png"
	_painted = ResourceLoader.exists(path)
	var tex: Texture2D = load(path if _painted else FALLBACK)
	if boat == null:
		boat = Sprite2D.new()
		boat.centered = false
		add_child(boat)
		person = Sprite2D.new()
		person.centered = false
		add_child(person)
		front = Sprite2D.new()
		front.centered = false
		front.region_enabled = true
		add_child(front)
		hull = Sprite2D.new()
		hull.centered = false
		hull.region_enabled = true
		hull.modulate = TINT
		add_child(hull)
	boat.texture = tex
	front.texture = tex
	hull.texture = tex
	var h := float(tex.get_height())
	ride = h - DRAFT if _painted else 44.0
	deck = _deck_row(tex.get_image()) if _painted else 30.0
	# A boat with a tall sail or high sides names its seat in boats.json, since the outline alone cannot find it.
	var at: Array = Data.boats.get(id, {}).get("seat", [])
	seat = Vector2(float(at[0]), float(at[1])) if at.size() == 2 else Vector2(0.62, deck)
	var dog_at: Array = Data.boats.get(id, {}).get("dog", [])
	dog_spot = Vector2(float(dog_at[0]), float(dog_at[1])) if dog_at.size() == 2 else Vector2(0.24, deck + 2.0)
	person.visible = _painted and ResourceLoader.exists(ART + "fisherman.png")
	if person.visible:
		person.texture = load(ART + "fisherman.png")


## The hull's top edge: going up from the hull's widest row, the first row much narrower, which skips masts and sails.
func _deck_row(img: Image) -> float:
	var widths := []
	for y in img.get_height():
		var n := 0
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				n += 1
		widths.append(n)
	var widest: int = widths.max()
	for y in range(widths.find(widest), -1, -1):
		if widths[y] < widest * 0.5:
			return float(y + 1)
	return 0.0


func width() -> float:
	return float(boat.texture.get_width()) if boat else 105.0


## Where along the boat, from 0 at the stern to 1 at the bow, a spot is, turned round when the boat faces west.
func _along(k: float) -> float:
	return width() * (k if facing > 0.0 else 1.0 - k)


## Where the fisherman's hands are in the world, for a boat whose left edge is at x.
func _hands(x: float) -> Vector2:
	if not person.visible:
		return Vector2(x + (102.0 if facing > 0.0 else width() - 102.0), -ride + 4.0 + bob)
	var size := person.texture.get_size()
	return Vector2(x + _along(seat.x) + size.x * 0.3 * facing, -ride + bob + seat.y - size.y * 0.45 + 5.0)


## Where the rod's tip is in the world, for a boat whose left edge is at x.
func rod_tip(x: float) -> Vector2:
	if not person.visible:
		return _hands(x)
	return _hands(x) + Vector2(ROD.x * facing, ROD.y)


## Where the dog sits, on the boat picture's own pixels.
func dog_seat() -> Vector2:
	return Vector2(_along(dog_spot.x), dog_spot.y)


func place(x: float, cam: Vector2, time: float) -> void:
	bob = roundf(sin(time * 1.6))
	boat.flip_h = facing < 0.0
	hull.flip_h = boat.flip_h
	front.flip_h = boat.flip_h
	boat.position = (Vector2(x, -ride + bob) - cam).round()
	var h := float(boat.texture.get_height())
	var cut := clampf(ride - bob + 1.0, 0.0, h - 1.0)
	hull.region_rect = Rect2(0, cut, boat.texture.get_width(), h - cut)
	hull.position = boat.position + Vector2(0, cut)
	front.visible = person.visible
	if person.visible:
		var size := person.texture.get_size()
		person.flip_h = facing < 0.0
		person.position = boat.position + Vector2(_along(seat.x) - size.x / 2.0, seat.y - size.y + 9.0)
		front.region_rect = Rect2(0, seat.y, boat.texture.get_width(), h - seat.y)
		front.position = boat.position + Vector2(0, seat.y)
	_cam = cam
	_x = x
	queue_redraw()


var _cam := Vector2.ZERO
var _x := 0.0


func _draw() -> void:
	if person.visible:
		draw_line((_hands(_x) - _cam).round(), (rod_tip(_x) - _cam).round(), ROD_COLOUR, 1.0)
