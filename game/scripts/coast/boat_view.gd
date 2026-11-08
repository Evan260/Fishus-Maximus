class_name BoatView
extends Node2D
## The boat bobbing on the water with the fisherman in it. He sits facing the bow with his rod, turns to face the
## stern and pulls on the near oar while the boat is rowed, as rowers do, and swings the rod back over his shoulder and
## forward to cast. The oar and the rod are drawn in his hands, and the hull below the waterline is tinted as if seen
## through the water. Where people sit is measured from the hull picture.

const ART := "res://assets/art/props/"
const MAN := "res://assets/art/fisherman/"
const FALLBACK := "res://assets/art/style_test/boat.png"
const TINT := Color(0.5, 0.78, 0.84, 0.85)
## How deep the hull sits in the water.
const DRAFT := 8.0
const ROD_LENGTH := 26.0
const ROD_COLOUR := Color("#6b4a2b")
const ROD_LIGHT := Color("#9a7048")
## The rod's angle in degrees, up from the bow, while he sits fishing, and in each frame of the cast.
const ROD_REST := -40.0
const ROD_CAST := [-45.0, -60.0, -95.0, -125.0, -135.0, -140.0, -140.0, -20.0, -30.0]
## The cast's frames he winds back through while the cast is held, and the two he throws with.
const WIND_FRAMES := 7
const ROW_FPS := 9.0
const THROW_FPS := 14.0
## Where the oarlock is on his canvas, ahead of him on the gunwale, and how far the oar reaches past it.
const OARLOCK := Vector2(50, 38)
const OAR_OUT := 30.0
const OAR_COLOUR := Color("#7a5532")
const OAR_LIGHT := Color("#a5774a")

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
var dog_spot := Vector2(0.24, 38.0)
## Whether this boat is rowed, so he takes up the oar when it moves.
var oars := false
## Seconds of rowing still to show; the coast tops it up while the player rows.
var rowing := 0.0
## How far the cast is wound up, from 0 to 1, or below zero when it is not being held.
var charge := -1.0
## How hard a hooked fish pulls, as the line's tension, and the point in the world it pulls towards.
var strain := 0.0
var pull := Vector2.ZERO
var _throw := -1.0
var _row_t := 0.0
var _frames := {}
var _hands := {}
var _hip := 40.0
var _middle := 28.0
var _painted := false
var _overlay: Node2D
var _cam := Vector2.ZERO
var _x := 0.0


func _init() -> void:
	var info_path := MAN + "fisherman.json"
	if FileAccess.file_exists(info_path):
		var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(info_path))
		_hands = info["hands"]
		_hip = float(info["hip"])
		_middle = float(info["middle"])
		for move in _hands:
			var list: Array[Texture2D] = []
			for i in (_hands[move] as Array).size():
				var path := MAN + ("sit.png" if move == "sit" else "%s_%02d.png" % [move, i])
				if ResourceLoader.exists(path):
					list.append(load(path))
			_frames[move] = list


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
		person.region_enabled = true
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
		_overlay = Node2D.new()
		_overlay.draw.connect(_draw_in_hands)
		add_child(_overlay)
	boat.texture = tex
	front.texture = tex
	hull.texture = tex
	var h := float(tex.get_height())
	ride = h - DRAFT if _painted else 44.0
	deck = _deck_row(tex.get_image()) if _painted else 30.0
	var spec: Dictionary = Data.boats.get(id, {})
	# A boat with a tall sail or high sides names its seat in boats.json, since the outline alone cannot find it.
	var at: Array = spec.get("seat", [])
	seat = Vector2(float(at[0]), float(at[1])) if at.size() == 2 else Vector2(0.62, deck)
	# The dog sits down inside the boat, so the hull hides its legs.
	var dog_at: Array = spec.get("dog", [])
	dog_spot = Vector2(float(dog_at[0]), float(dog_at[1])) if dog_at.size() == 2 else Vector2(0.24, deck + 8.0)
	oars = bool(spec.get("oars", false))
	person.visible = _painted and _frames.has("sit") and not (_frames["sit"] as Array).is_empty()


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


## Starts the throw that sends the line out, once the cast is let go.
func throw() -> void:
	_throw = 0.0
	charge = -1.0


## What he is doing now, as the move and the frame of it.
func pose() -> Array:
	if not person.visible:
		return ["sit", 0]
	if _throw >= 0.0:
		return ["cast", mini(8, WIND_FRAMES + int(_throw * THROW_FPS))]
	if charge >= 0.0:
		return ["cast", mini(WIND_FRAMES - 1, int(clampf(charge, 0.0, 1.0) * WIND_FRAMES))]
	if rowing > 0.0 and oars:
		return ["row", int(_row_t * ROW_FPS) % (_frames["row"] as Array).size()]
	return ["sit", 0]


## The rower faces the stern, so he is turned round from the way the boat goes.
func _turned() -> bool:
	return (pose()[0] == "row") == (facing > 0.0)


## The top left of his picture in the world, for a boat whose left edge is at x.
func _person_at(x: float, turned: bool) -> Vector2:
	var middle := 64.0 - _middle if turned else _middle
	return Vector2(x, -ride + bob) + Vector2(_along(seat.x) - middle, seat.y + 3.0 - _hip).round()


## A point on his picture, in the world, for a boat whose left edge is at x.
func _on_person(x: float, p: Vector2, turned := _turned()) -> Vector2:
	return _person_at(x, turned) + Vector2(63.0 - p.x if turned else p.x, p.y)


## Where his hands are in the world, for a boat whose left edge is at x.
func _hands_at(x: float) -> Vector2:
	if not person.visible:
		return Vector2(x + (102.0 if facing > 0.0 else width() - 102.0), -ride + 4.0 + bob)
	var p: Array = pose()
	var at: Array = _hands[p[0]][p[1]]
	return _on_person(x, Vector2(at[0], at[1]))


## Where the rod's tip is in the world, for a boat whose left edge is at x: in his hands, or lying in the boat while
## he rows.
func rod_tip(x: float) -> Vector2:
	if not person.visible:
		return _hands_at(x)
	var p: Array = pose()
	if p[0] == "row":
		return Vector2(x + _along(0.86), -ride + bob + deck + 3.0)
	var angle := deg_to_rad(ROD_CAST[p[1]] if p[0] == "cast" else ROD_REST)
	var hands := _hands_at(x)
	var straight := Vector2(cos(angle) * facing, sin(angle))
	if strain <= 0.0 or p[0] != "sit":
		return hands + straight * ROD_LENGTH
	# A pulling fish bends the tip round towards the line, more the harder it pulls.
	var bend := straight.slerp((pull - hands).normalized(), clampf(strain, 0.0, 1.0) * 0.55)
	return hands + bend * ROD_LENGTH * (1.0 - 0.12 * clampf(strain, 0.0, 1.0))


## Where the rod's tip is while he sits fishing, which a cast is measured from wherever the rod is in the swing.
func rest_tip(x: float) -> Vector2:
	if not person.visible:
		return _hands_at(x)
	var hand: Array = _hands["sit"][0]
	var angle := deg_to_rad(ROD_REST)
	return _on_person(x, Vector2(hand[0], hand[1]), facing < 0.0) + Vector2(cos(angle) * facing, sin(angle)) * ROD_LENGTH


## Where the dog sits, on the boat picture's own pixels.
func dog_seat() -> Vector2:
	return Vector2(_along(dog_spot.x), dog_spot.y)


func _process(delta: float) -> void:
	rowing = maxf(0.0, rowing - delta)
	if rowing > 0.0:
		_row_t += delta
	if _throw >= 0.0:
		_throw += delta
		if WIND_FRAMES + int(_throw * THROW_FPS) > 8 and _throw > 0.3:
			_throw = -1.0


func place(x: float, cam: Vector2, time: float) -> void:
	bob = sin(time * 1.6)
	boat.flip_h = facing < 0.0
	hull.flip_h = boat.flip_h
	front.flip_h = boat.flip_h
	boat.position = Vector2(x, -ride + bob) - cam
	var h := float(boat.texture.get_height())
	# The tint starts on a whole row of the hull, so its pixels lie exactly over the boat's.
	var cut := clampf(roundf(ride - bob + 1.0), 0.0, h - 1.0)
	hull.region_rect = Rect2(0, cut, boat.texture.get_width(), h - cut)
	hull.position = boat.position + Vector2(0, cut)
	front.visible = person.visible
	if person.visible:
		var p: Array = pose()
		person.texture = _frames[p[0]][p[1]]
		# He is cut off just under the gunwale, so his feet never show below a hull shallower than his legs.
		person.region_rect = Rect2(0, 0, 64, _hip - 1.0)
		person.flip_h = _turned()
		person.position = _person_at(x, _turned()) - cam
		front.region_rect = Rect2(0, seat.y, boat.texture.get_width(), h - seat.y)
		front.position = boat.position + Vector2(0, seat.y)
	_cam = cam
	_x = x
	if _overlay:
		_overlay.queue_redraw()


## The near oar while he rows and the rod while he holds it, over the hull, since both cross its near side.
func _draw_in_hands() -> void:
	if not person.visible:
		return
	var hands := _hands_at(_x) - _cam
	if pose()[0] != "row":
		_rod(_overlay, hands, rod_tip(_x) - _cam)
		return
	var lock := _on_person(_x, OARLOCK) - _cam
	var along := (lock - hands).normalized()
	var blade := lock + along * OAR_OUT
	var water := -_cam.y
	Pixels.line(_overlay, hands, blade, OAR_COLOUR, 2)
	Pixels.line(_overlay, hands, lock, OAR_LIGHT)
	# The blade is the last third of the oar, broader, and tinted where it is under the water.
	var root := lock + along * OAR_OUT * 0.62
	var side := Vector2(-along.y, along.x)
	var shape := PackedVector2Array([root - side, blade - side * 2.0, blade + side * 2.0, root + side])
	Pixels.polygon(_overlay, shape, OAR_COLOUR if blade.y < water else OAR_COLOUR.lerp(TINT, 0.55), hands)


## The rod from its butt to its tip, curved when a fish bends it: the butt stays pointing where he holds it.
func _rod(on: CanvasItem, from: Vector2, to: Vector2) -> void:
	var angle := deg_to_rad(ROD_REST)
	var held := from + Vector2(cos(angle) * facing, sin(angle)) * ROD_LENGTH * 0.5
	var bent: bool = strain > 0.0 and pose()[0] == "sit"
	var last := from
	for k in range(1, 9):
		var u := k / 8.0
		var point := from.lerp(held, u).lerp(held.lerp(to, u), u) if bent else from.lerp(to, u)
		point = from + (point - from).round()
		Pixels.line(on, last, point, ROD_LIGHT if k <= 3 else ROD_COLOUR)
		last = point
