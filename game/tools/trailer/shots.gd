extends Node
## The trailer's scripted shots: each makes up a game that is never saved, opens its screen and plays it, so
## tools/trailer/make_trailer.py records it the same way every time. Started by main.gd with --trailer-shot=NAME.

const INK := Color(0.29, 0.18, 0.14)
const CREAM := Color(0.99, 0.95, 0.86)
## The fish the first cast brings in, and its weight in pounds.
const FIRST_FISH := "dentex"
const FIRST_POUNDS := 8.2
## Window pixels to the game pixel in the shorts' tall frame, closer than the game would choose for a phone's shape.
const TALL_ZOOM := 6
## How deep the line is held for the legend, and the Senator's weight.
const LEGEND_DEPTH := 230.0
const LEGEND_POUNDS := 172.0

var shot := ""
var _pointer: Sprite2D
var _ring: Sprite2D
## The fish sent to the bait, and every other fish kept from taking it first.
var _biter := {}
## Which way the boat is rowed or sailed each frame, as a player holding the key would.
var _row := 0.0
## How fast the view is carried along, in game pixels a second, for a shot that pans over the seabed.
var _pan := Vector2.ZERO
## How deep a downward pan stops.
var _pan_to := INF


func _ready() -> void:
	shot = Dev.get_arg("trailer-shot")
	Saves.enabled = false
	Tips.process_mode = Node.PROCESS_MODE_DISABLED
	# A made-up game meets achievements at once, and their cards would slide in on screen.
	Awards.process_mode = Node.PROCESS_MODE_DISABLED
	# The edit lays the trailer's own music over the shots, so the game's is left out of the recording.
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	# The dog barks at a bite and yips when petted, which the trailer leaves out.
	Audio._sounds.erase("dog")
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_pointer = Sprite2D.new()
	_pointer.texture = _arrow()
	_pointer.centered = false
	_pointer.visible = false
	layer.add_child(_pointer)
	_ring = Sprite2D.new()
	_ring.texture = _ring_texture()
	_ring.modulate.a = 0.0
	layer.add_child(_ring)
	# The real mouse plays no part: wherever it rests would light up what it is over.
	get_tree().root.set_disable_input(true)
	_fit_tall()
	call("_shot_" + shot)


func _process(delta: float) -> void:
	_fit_tall()
	# The shorts carry their own captions, so the game's passing messages would cover them.
	if _tall() and is_instance_valid(Toast._box):
		Toast._box.visible = false
	if _row != 0.0 and Nav.current and Nav.current.has_method("row"):
		Nav.current.row(_row, delta)
	if _pan != Vector2.ZERO and Nav.current and "camera" in Nav.current:
		Nav.current.camera.cam += _pan * delta
		if Nav.current.camera.cam.y >= _pan_to:
			Nav.current.camera.cam.y = _pan_to
			_pan = Vector2.ZERO
	if _biter.is_empty() or not Nav.current or not "swimmers" in Nav.current:
		return
	for f in Nav.current.swimmers.fish:
		if f != _biter and f["state"] in ["curious", "approach"]:
			f["state"] = "swim"


## A game some way in, in the first boat with old Rufus's lessons done, at a fixed seed.
func _early_game() -> void:
	Game.demo_state()
	Game.state["boat"] = "skiff"
	Game.state["seed"] = 7


## The best of everything, with a logbook full of fish and a pond full of named ones.
func _late_game() -> void:
	Game.max_state()
	Game.state["seed"] = 7
	Game.state["denarii"] = 3180
	var rng := RandomNumberGenerator.new()
	rng.seed = 72
	for id in Data.fish:
		if not Data.fish[id]["legend"] or id in ["tiberius_mullet", "orata_bream", "claudius_parrotfish"]:
			var lb: Array = Data.fish[id]["pounds"]
			Game.state["logbook"][id] = {"count": rng.randi_range(1, 30), "best": snappedf(lerpf(float(lb[0]), float(lb[1]), rng.randf_range(0.5, 0.9)), 0.1)}
	var pond: Dictionary = Game.state["pond"]
	pond["features"] = ["rocks", "caves", "weed", "sand", "spring", "shade"]
	pond["fish"] = []
	for f in [["bream", 6.1, "Aurata", "gold_ring"], ["bream", 4.4, "", ""], ["bream", 3.2, "", ""], ["moray", 18.0, "Hortensia", "earrings"],
			["mullet", 2.1, "Rufa", ""], ["mullet", 1.6, "", ""], ["white_bream", 2.2, "", ""], ["parrotfish", 2.6, "Claudia", ""],
			["grey_mullet", 4.0, "", ""], ["sea_bass", 9.5, "Lupus", ""], ["sea_bass", 6.0, "", ""], ["scorpionfish", 2.0, "", ""],
			["dentex", 12.0, "", ""], ["golden_mullet", 1.4, "", ""]]:
		if Data.fish[f[0]].has("pond"):
			pond["fish"].append({"fish": f[0], "pounds": f[1], "name": f[2], "finery": f[3], "age_days": 40, "fed": true})
	# What this made-up game has met is earned quietly, so no achievement is told of on screen.
	Game.state["achievements"] = Data.achievements.map(func(a): return a["id"]).filter(func(id): return Achievements.met(id, Game.state))


func _open(screen: String, flags: Dictionary) -> void:
	Dev.args.merge(flags, true)
	# The window takes its size in the first frames, and the screen lays itself out for the view it opens in.
	for i in 3:
		await get_tree().process_frame
		_fit_tall()
	Nav.go(screen, Dev.args)
	while Nav.current_name != screen or Nav.current == null:
		await get_tree().process_frame
	if _tall() and "camera" in Nav.current:
		var coast: Node = Nav.current
		coast.camera.view = Nav.view()
		coast.camera.jump(Vector2(coast.boat_x + 52.0 - Nav.view().x / 2.0, coast.camera.cam.y))


# Shots -------------------------------------------------------------------

## The harbour at first light: the skiff waits by the jetty with the dog in the bow, then rows out into the bay.
func _shot_dawn() -> void:
	_early_game()
	await _open("coast", {"place": "harbour", "hour": "6.1", "weather": "clear", "no-hud": "", "at": "120"})
	await _wait(3.5)
	_row = 1.0


## The first cast of the morning off the rocky shore: the float flies out, a dentex comes to look, nibbles and takes
## it, the dog barks, the fight runs and leaps, and the fish comes up onto the catch banner.
func _shot_cast() -> void:
	_early_game()
	await _open("coast", {"place": "rocky_shore", "hour": "8.2", "weather": "clear", "no-hud": "", "at": "260", "demo-cast": "", "leap": ""})
	var coast: Node = Nav.current
	coast._time = -0.2
	# The dentex swims in from past the right of the view before the part of the shot that is used.
	_biter = coast.swimmers.bring_in(FIRST_FISH, FIRST_POUNDS, 70.0, 1.0)
	while coast.line_state() != "sinking" or coast.flight > 0.0:
		await get_tree().process_frame
	# The line is held near the surface, as a player holding reel-up does, so the fight runs where the fish can leap.
	while coast.hook.y < 48.0:
		await get_tree().process_frame
	coast._state = "waiting"
	await _wait(0.8)
	_biter["state"] = "approach"
	while coast.fight == null:
		await get_tree().process_frame
	# The trailer has a few seconds for the fight, so this dentex runs and leaps once and then tires.
	coast.fight._energy = coast.fight._full_energy * 0.3
	coast.fight.distance = minf(coast.fight.distance, 45.0)


## Capri's cliffs and caves at noon, sailing past in the sailing boat.
func _shot_capri() -> void:
	_late_game()
	Game.state["boat"] = "sailing_boat"
	await _open("coast", {"place": "capri", "hour": "11.5", "weather": "clear", "no-hud": "", "at": "300"})
	_row = 1.0


## The rocky shore in the morning, rowing along under the cliffs in the fishing boat.
func _shot_rocky() -> void:
	_early_game()
	Game.state["boat"] = "fishing_boat"
	await _open("coast", {"place": "rocky_shore", "hour": "9.5", "weather": "clear", "no-hud": "", "at": "500"})
	_row = -1.0


## Misenum's headland at dusk, the big boat's lantern lit.
func _shot_misenum() -> void:
	_late_game()
	await _open("coast", {"place": "misenum", "hour": "18.6", "weather": "clear", "no-hud": "", "at": "400"})
	_row = 1.0


## The open bay's seabed in the early afternoon: the view passes slowly over the sunken fishing boat as fish swim by.
func _shot_wreck() -> void:
	_late_game()
	await _open("coast", {"place": "open_bay", "hour": "13.5", "weather": "clear", "no-hud": "", "at": "150,70"})
	var coast: Node = Nav.current
	coast.camera.cam = Vector2(90.0, 30.0)
	coast._update_swimmer_world()
	var sw: Swimmers = coast.swimmers
	var kinds: Array = sw.kinds_at(170.0, 240.0).filter(func(k): return not Data.fish[k].get("shoal", false) and not Data.fish[k]["legend"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in mini(2, kinds.size()):
		sw.bring_in(kinds[k], Catalog.roll_pounds(kinds[k], rng), 165.0 + 30.0 * k, 1.0)
	_pan = Vector2(22.0, 0.0)


## Deep water off Misenum at night under the northern lights: the line goes down into the dark after the big fish.
func _shot_night() -> void:
	_late_game()
	await _open("coast", {"place": "misenum", "hour": "23.2", "weather": "clear", "no-hud": "", "at": "980", "aurora": ""})
	await _wait(3.5)
	Nav.current.cast(1.0)


## The logbook, its pages turning from place to place, every fish drawn with its best weight.
func _shot_logbook() -> void:
	_late_game()
	await _open("coast", {"place": "harbour", "hour": "10", "weather": "clear", "no-hud": "", "at": "300"})
	await _wait(0.6)
	LogbookPanel.open(0)
	for k in 6:
		await _wait(1.5)
		LogbookPanel._bookmark_turn(LogbookPanel.section + 1)


## The harbour town's covered street in the morning, the townsfolk walking and talking.
func _shot_town() -> void:
	_early_game()
	await _open("town", {"hour": "9.5", "weather": "clear", "no-hud": "", "talk": ""})


## The boatwright's yard: the big boat is bought.
func _shot_boatwright() -> void:
	_late_game()
	Game.state["boat"] = "sailing_boat"
	await _open("town", {"hour": "11", "weather": "clear", "no-hud": ""})
	await _wait(0.5)
	ShopPanel.boatwright()
	await get_tree().process_frame
	var tile := _tile_for("big_boat")
	_pointer.scale = Vector2.ONE * Nav.ui_zoom
	_pointer.position = Nav.ui_to_window(Nav.ui_view() * Vector2(0.75, 0.85))
	_pointer.visible = true
	await _wait(0.6)
	if tile:
		await _press(tile)
	await _wait(0.5)
	_pointer.visible = false


## The big boat under sail across the open bay in the golden hour, its sail full and its flag flying.
func _shot_sail() -> void:
	_late_game()
	await _open("coast", {"place": "open_bay", "hour": "17.8", "weather": "clear", "no-hud": "", "at": "200"})
	_row = 1.0


## The dog in the bow is petted, wags and sends up hearts.
func _shot_dog() -> void:
	_early_game()
	Game.state["boat"] = "fishing_boat"
	await _open("coast", {"place": "harbour", "hour": "16.5", "weather": "clear", "no-hud": "", "at": "420"})
	await _wait(1.2)
	Nav.current.dog.pet()
	await _wait(1.6)
	Nav.current.dog.pet()


## The estate's pond in the late afternoon, its fish fed, and the sea washing up the beach beyond.
func _shot_pond() -> void:
	_late_game()
	await _open("shore", {"hour": "16.8", "weather": "clear", "no-hud": ""})
	if _tall():
		_hide_shore_hud()
	await _wait(2.0)
	Nav.current.pond.feed()


## The boat fishing on its own in a strip along the bottom of the desktop.
func _shot_strip() -> void:
	_late_game()
	Game.state["boat"] = "fishing_boat"
	await _open("coast", {"place": "harbour", "hour": "10", "weather": "clear", "at": "520", "idle": ""})
	Windowing.set_strip(true)


## The harbour at sunset behind the logo at the end.
func _shot_endcard() -> void:
	_late_game()
	Game.state["boat"] = "fishing_boat"
	await _open("coast", {"place": "harbour", "hour": "19.0", "weather": "clear", "no-hud": "", "no-front": "", "at": "330"})


# The shorts' shots, recorded in the tall frame -----------------------------

## Night off Misenum under the northern lights: the Senator comes out of the dark to the bait and is fought up.
func _shot_legend() -> void:
	_late_game()
	Game.state["logbook"].erase("senator_grouper")
	await _open("coast", {"place": "misenum", "hour": "22.6", "weather": "clear", "no-hud": "", "at": "980", "aurora": "", "demo-cast": ""})
	var coast: Node = Nav.current
	coast._time = 0.2
	while coast.line_state() != "sinking" or coast.flight > 0.0:
		await get_tree().process_frame
	while coast.hook.y < LEGEND_DEPTH:
		await get_tree().process_frame
	coast._state = "waiting"
	_biter = coast.swimmers.bring_in("senator_grouper", LEGEND_POUNDS, coast.hook.y + 6.0, 1.0)
	await _wait(1.6)
	_biter["state"] = "approach"
	while coast.fight == null:
		await get_tree().process_frame
	coast.fight._energy = coast.fight._full_energy * 0.45


## The skiff in the harbour; the rowing boats wait at rest, since rowing lifts the view off the waterline all four share.
func _shot_boat_skiff() -> void:
	_early_game()
	await _open("coast", {"place": "harbour", "hour": "7.4", "weather": "clear", "no-hud": "", "at": "300"})


## The fishing boat along the rocky shore.
func _shot_boat_fishing() -> void:
	_early_game()
	Game.state["boat"] = "fishing_boat"
	await _open("coast", {"place": "rocky_shore", "hour": "10", "weather": "clear", "no-hud": "", "at": "600"})


## The sailing boat past the cliffs of Capri.
func _shot_boat_sailing() -> void:
	_late_game()
	Game.state["boat"] = "sailing_boat"
	await _open("coast", {"place": "capri", "hour": "13", "weather": "clear", "no-hud": "", "at": "500"})
	_row = 1.0


## The big boat under full sail in the golden hour.
func _shot_boat_big() -> void:
	_late_game()
	await _open("coast", {"place": "open_bay", "hour": "17.8", "weather": "clear", "no-hud": "", "at": "400"})
	_row = 1.0


## Each dog in the bow, petted twice.
func _shot_pet_hound() -> void:
	await _pet("hound")


func _shot_pet_molossian() -> void:
	await _pet("molossian")


func _shot_pet_sighthound() -> void:
	await _pet("sighthound")


func _shot_pet_sheepdog() -> void:
	await _pet("sheepdog")


func _pet(breed: String) -> void:
	_early_game()
	Game.state["boat"] = "fishing_boat"
	Game.state["dog"] = breed
	await _open("coast", {"place": "harbour", "hour": "16.5", "weather": "clear", "no-hud": "", "at": "420"})
	await _wait(1.6)
	Nav.current.dog.pet()
	await _wait(1.4)
	Nav.current.dog.pet()


## The boat fishing on its own in the strip, at the shorts' width.
func _shot_desk() -> void:
	_late_game()
	Game.state["boat"] = "fishing_boat"
	await _open("coast", {"place": "harbour", "hour": "10", "weather": "clear", "at": "520", "idle": "", "idle-speed": "12"})
	Windowing.set_strip(true)


## Close up on the boat fishing on its own and bringing in a bream, with the dog asleep in the bow.
func _shot_idle() -> void:
	_late_game()
	Game.state["boat"] = "fishing_boat"
	await _open("coast", {"place": "harbour", "hour": "10.5", "weather": "clear", "no-hud": "", "no-front": "", "at": "520", "idle": ""})
	_hold_on_boat()
	# A bream takes his bait at a set moment, as one he catches on his own would.
	await _wait(1.6)
	Nav.current.idle_catch("bream")


## The dog asleep while the boat fishes on its own, petted anyway.
func _shot_idle_dog() -> void:
	_late_game()
	Game.state["boat"] = "fishing_boat"
	await _open("coast", {"place": "harbour", "hour": "14", "weather": "clear", "no-hud": "", "no-front": "", "at": "520", "idle": ""})
	_hold_on_boat()
	await _wait(1.8)
	Nav.current.dog.pet()
	await _wait(1.6)
	Nav.current.dog.pet()


## From the boat on the surface the view goes slowly down to the old wreck off the rocky shore, where a conger lives.
func _shot_wreck_dive() -> void:
	_late_game()
	Game.state["boat"] = "fishing_boat"
	await _open("coast", {"place": "rocky_shore", "hour": "12.5", "weather": "clear", "no-hud": "", "no-front": "", "at": "1348,-160"})
	var coast: Node = Nav.current
	await _wait(1.5)
	_pan = Vector2(0.0, 34.0)
	_pan_to = 175.0
	await _wait(6.8)
	coast.swimmers.bring_in("conger", 22.0, 335.0, 1.0)


## The estate's pond: the bell is rung and the named fish come to the front, their names over them.
func _shot_pond_bell() -> void:
	_late_game()
	Game.state["pond"]["fish"] = Game.state["pond"]["fish"].filter(func(f): return f["name"] in ["", "Hortensia", "Aurata", "Lupus"])
	await _open("shore", {"hour": "9.5", "weather": "clear", "no-hud": ""})
	_hide_shore_hud()
	await _wait(1.0)
	Nav.current.pond.feed()
	await _wait(3.0)
	Nav.current.pond.ring()


## Rain on the rocky shore, rowing slowly under the cliffs.
func _shot_rain() -> void:
	_early_game()
	Game.state["boat"] = "fishing_boat"
	await _open("coast", {"place": "rocky_shore", "hour": "15", "weather": "rain", "no-hud": "", "at": "700"})
	await _wait(2.5)
	_row = 0.6


## The harbour at night, the lamps of the town lit and the crickets out.
func _shot_night_harbour() -> void:
	_late_game()
	Game.state["boat"] = "fishing_boat"
	await _open("coast", {"place": "harbour", "hour": "21.5", "weather": "clear", "no-hud": "", "at": "330", "aurora": ""})


# Helpers -----------------------------------------------------------------

## A tall window for the shorts is drawn closer than the game draws it, so the boat fills a phone's width.
## Hides the shore's top bar and its button back to town, which the narrow frame cuts off, but keeps the fish's names.
func _hide_shore_hud() -> void:
	for c in Nav.ui.get_children():
		if c != Nav.current._names:
			c.visible = false


## Keeps the view on the boat, where it would follow the line out of the narrow frame.
func _hold_on_boat() -> void:
	var coast: Node = Nav.current
	coast._pinned = true
	coast.camera.jump(Vector2(coast.boat_x + 52.0 - coast.camera.view.x / 2.0, CoastCamera.HOME_Y))


func _tall() -> bool:
	return get_window().size.y > get_window().size.x


func _fit_tall() -> void:
	var size := get_window().size
	if not _tall():
		return
	var view := Vector2i(ceili(size.x / float(TALL_ZOOM)), ceili(size.y / float(TALL_ZOOM)))
	if Nav.zoom == TALL_ZOOM and Vector2i(Nav.view()) == view:
		return
	Windowing._fitted = size
	Nav.fit(view, TALL_ZOOM)
	Windowing.view_changed.emit()


## The shop tile selling this item, found by the price written under it.
func _tile_for(id: String) -> Control:
	for b in Nav.ui.find_children("*", "Button", true, false):
		var caption := b.get_node_or_null("Caption")
		if caption is Label and (caption as Label).text == str(Shop.price(id)) and b.is_visible_in_tree():
			return b
	return null


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## The middle of a control, in window pixels.
func _centre(c: Control) -> Vector2:
	return Nav.ui_to_window(c.get_global_rect().get_center()).round()


func _glide(to: Vector2, seconds := 0.7) -> void:
	var from := _pointer.position
	var tw := create_tween()
	tw.tween_method(func(u: float) -> void: _pointer.position = from.lerp(to, u * u * (3.0 - 2.0 * u)).round(), 0.0, 1.0, seconds)
	await tw.finished


## Moves the pointer onto a button and presses it, as a player would.
func _press(button: BaseButton) -> void:
	await _glide(_centre(button))
	await _wait(0.3)
	_tap()
	button.pressed.emit()


## A small ring spreads from the pointer's tip, so a click reads on screen.
func _tap() -> void:
	_ring.position = _pointer.position
	_ring.scale = _pointer.scale * 0.5
	_ring.modulate.a = 1.0
	var t := create_tween().set_parallel()
	t.tween_property(_ring, "scale", _pointer.scale * 1.2, 0.3)
	t.tween_property(_ring, "modulate:a", 0.0, 0.3)


## The familiar arrow pointer, drawn in the interface's ink and parchment.
static func _arrow() -> Texture2D:
	var rows := [
		"X.........",
		"XX........",
		"XoX.......",
		"XooX......",
		"XoooX.....",
		"XooooX....",
		"XoooooX...",
		"XooooooX..",
		"XoooooooX.",
		"XooooooooX",
		"XoooooXXXX",
		"XooXooX...",
		"XoX.XooX..",
		"XX..XooX..",
		"X....XooX.",
		".....XooX.",
		"......XX..",
	]
	var img := Image.create(10, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in 10:
			var c: String = rows[y][x]
			if c == "X":
				img.set_pixel(x, y, INK)
			elif c == "o":
				img.set_pixel(x, y, CREAM)
	return ImageTexture.create_from_image(img)


static func _ring_texture() -> Texture2D:
	var img := Image.create(11, 11, false, Image.FORMAT_RGBA8)
	for y in 11:
		for x in 11:
			var d := Vector2(x - 5, y - 5).length()
			if d > 3.6 and d < 4.8:
				img.set_pixel(x, y, Color(CREAM, 0.9))
	return ImageTexture.create_from_image(img)
