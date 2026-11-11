extends Node2D
## A place on the coast, seen side on with the waterline across the screen: the painted layers sliding at their own
## speeds, the water, the fish, the boat and the line. The camera follows the boat along the coast and the hook down.

signal caught(fish: String, pounds: float)

const RAIN_LIGHT := Color(0.72, 0.75, 0.8)
## How far a stretch of rowing is, for the guide's rowing lesson.
const ROWED := 30.0
const REEL_SPEED := 70.0
const CAST_NEAR := 20.0
const CAST_FAR := 240.0
## How long the float takes to fly out, and how high it arcs on the way, for the gentlest and the hardest cast.
const FLIGHT_SECONDS := [0.5, 1.1]
const FLIGHT_ARC := [40.0, 130.0]
## Seconds the float dips for at each nibble.
const TWITCH := 0.25
## Seconds the float stays under when a fish takes his bait while he fishes on his own, before he brings it in.
const TAKEN_SECONDS := 1.2
## How far down the water he hangs his bait when he fishes on his own.
const IDLE_DEPTH := 0.4

var place := {}
var place_id := ""
var boat_x := 150.0
var hook := Vector2.ZERO
var seabed: Seabed
var camera: CoastCamera
var swimmers: Swimmers
var methods: CoastMethods
var events: CoastEvents
var dog: DogView
var hud: Hud
var _row_sound := 0.0
var _cheer_wait := 0.0
var fight: LineFight
var weather := "clear"
var hour := 12.0
var charge := -1.0
## Seconds left of the float's flight out after a cast, where it set off from, how long it flies and how high.
var flight := 0.0
## How far the float has drifted from where it landed.
var _drift := 0.0
var _flight_from := Vector2.ZERO
var _flight_time := 0.5
var _arc := 40.0
## A click on the water this frame, and whether the mouse is still held down after one; clicks on buttons never get here.
var _click := false
var _mouse_held := false
var _weather_check := 0.0
var _day := -1
## The fish at the hook, first nibbling and then with the bait taken, and how long is left to strike once it has it.
var biter := {}
var bite_left := 0.0
## How long the float's current twitch has left, while a fish nibbles.
var twitch := 0.0
var _nibbles_left := 0
var _nibble_in := 0.0
## The fish he has caught on his own and is bringing in on the line, and how long the float stays under first.
var landing := ""
var _taken_left := 0.0
var _state := "reeled"
var _time := 0.0
var _pinned := false
var _fight_dir := Vector2.RIGHT
var _demo := false
var _rng: RandomNumberGenerator
var _sky: SkyView
var _lit: Node2D
var _layers: ParallaxLayers
var _floor: FloorView
var _water: WaterView
var _murk: Murk
var _land: UnderLand
var _boat: BoatView
var _ground: Node2D
var _line: LineView
var _rain: Array = []
var _ashore: Button
var _sail: Button
## How far the boat has been rowed since that last counted as a stretch of rowing.
var _rowed := 0.0
## The quay is where the boat ties up to go into town, in the harbour only.
const QUAY_REACH := 200.0
## How far below the seabed the ground turns to solid shadow, which hides the bottom edges of pieces in front of it.
var _ground_below := 24.0


func enter(args: Dictionary) -> void:
	Controls.ensure()
	if Game.state.is_empty():
		Game.new_game("Marcus", "")
	place_id = str(args.get("place", Dev.get_arg("place", str(Game.state.get("place", "harbour")))))
	if not Data.places.has(place_id):
		place_id = "harbour"
	place = Data.places[place_id]
	Game.state["place"] = place_id
	_rng = Seeds.rng(int(Game.state.get("seed", 1)), "coast:" + place_id, Clock.day_of(float(Game.state.get("time", 0.0))))
	seabed = Seabed.new(place["seabed"])
	_ground_below = float(place.get("ground_below", 24))
	camera = CoastCamera.new(Vector2(float(place["width"]), float(place["depth"]) + 40.0))
	if not Game.state.has("weather"):
		Game.state["weather"] = Weather.for_day(int(Game.state["seed"]), Clock.day_of(float(Game.state["time"])))
	weather = str(Dev.get_arg("weather", str(Game.state["weather"])))
	if Dev.has("hour"):
		Game.state["time"] = _time_at_hour(Dev.num("hour", 12.0))
	hour = Clock.hour(float(Game.state.get("time", 0.0)))
	_demo = Dev.has("demo-cast")
	_build()
	boat_x = clampf(float(args.get("boat_x", Game.state.get("boat_x", 150.0))), 0.0, _end())
	if Dev.has("at"):
		var xy := Dev.get_arg("at").split(",")
		boat_x = clampf(float(xy[0]), 0.0, _end())
		camera.jump(Vector2(boat_x + 52.0 - 240.0, float(xy[1]) if xy.size() > 1 else CoastCamera.HOME_Y))
		_pinned = xy.size() > 1
	else:
		camera.jump(Vector2(boat_x + 52.0 - 240.0, CoastCamera.HOME_Y))
	hook = _boat.rod_tip(boat_x)
	_update_swimmer_world()
	swimmers.populate()
	events.setup(self)
	dog.setup(self)
	if Nav.ui and not Dev.has("no-hud"):
		hud = Hud.new()
		Nav.ui.add_child(hud)
		hud.setup(self)
	Windowing.view_changed.connect(_on_view_changed)
	_on_view_changed()
	if Nav.ui and not Dev.has("no-hud"):
		GuideNote.add(self, "coast")
	if args.get("first", false) and not Settings.guide:
		Toast.say(tr("Your uncle's skiff. Hold %s or the mouse to cast, %s and %s to row.") % [Controls.key_name("cast"), Controls.key_name("row_left"), Controls.key_name("row_right")])
	if Nav.ui and not Dev.has("no-hud"):
		_sail = Ui.tile(Nav.ui, ItemArt.of("bay_map"), "", "Bay map: sail to another fishing place.", func():
			if fight == null:
				prepare_to_leave()
				Nav.go("map"), true, false, Hud.TILE)
		_sail.name = "BayMap"
		Ui.hang(_sail, "bottom_left", Vector2(4, 4), Hud.TILE)
	if place_id == "harbour" and Nav.ui and not Dev.has("no-hud"):
		_ashore = Ui.button(Nav.ui, "Go ashore", go_ashore)
		Ui.hang(_ashore, "bottom_right", Vector2(4, 4), Vector2(76, Hud.TILE.y))
	relayout()
	if Dev.has("tackle"):
		TacklePanel.open(hud.method_buttons["line"] if hud else null)


## Where a lesson of the guide points, in interface pixels: the button to press, or nothing while it is hidden.
func guide_target(id: String) -> Rect2:
	var b: Control = {"ashore": _ashore, "map": _sail, "pots": hud.method_buttons.get("trap") if hud else null}.get(id)
	return b.get_global_rect() if is_instance_valid(b) and b.is_visible_in_tree() else Rect2()


func go_ashore() -> void:
	if fight == null:
		prepare_to_leave()
		Nav.go("town")


## Remembers where the boat lies, and stops him fishing on his own, since he is going with you.
func prepare_to_leave() -> void:
	Game.state["boat_x"] = boat_x
	methods.leave()


func _exit_tree() -> void:
	if is_instance_valid(_sky):
		_sky.queue_free()


func _build() -> void:
	_sky = SkyView.new()
	Nav.sky.add_child(_sky)
	_lit = Node2D.new()
	add_child(_lit)
	_layers = ParallaxLayers.new()
	_layers.sky = _sky
	_lit.add_child(_layers)
	_layers.build(place.get("layers", []))
	_floor = FloorView.new()
	_floor.z_index = -8
	_floor.bake(place, seabed)
	_lit.add_child(_floor)
	_water = WaterView.new()
	_water.depth = float(place["depth"])
	_water.z_index = -10
	_lit.add_child(_water)
	_ground = Painter.new()
	_ground.fn = _draw_ground
	_ground.z_index = -6
	_lit.add_child(_ground)
	swimmers = Swimmers.new()
	swimmers.z_index = -4
	swimmers.setup(place_id, seabed, _rng)
	swimmers.bit.connect(_on_bite)
	_lit.add_child(swimmers)
	_boat = BoatView.new()
	_boat.z_index = -1
	_boat.set_boat(str(Game.state.get("boat", "skiff")))
	_lit.add_child(_boat)
	dog = DogView.new()
	dog.z_index = -1
	_lit.add_child(dog)
	_line = LineView.new()
	_line.screen = self
	_line.z_index = 0
	_lit.add_child(_line)
	methods = CoastMethods.new()
	add_child(methods)
	methods.setup(self, _rng)
	methods.traps_view = TrapView.new()
	methods.traps_view.screen = self
	methods.traps_view.z_index = -5
	_lit.add_child(methods.traps_view)
	methods.trident_view = TridentView.new()
	methods.trident_view.screen = self
	methods.trident_view.z_index = -3
	_lit.add_child(methods.trident_view)
	events = CoastEvents.new()
	events.z_index = -2
	_lit.add_child(events)
	methods.net_view = NetView.new()
	methods.net_view.screen = self
	methods.net_view.z_index = 1
	_lit.add_child(methods.net_view)
	# These shade the lit picture under them, so inside the light they would tint it a second time.
	_land = UnderLand.new(place)
	_land.z_index = _water.z_index
	add_child(_land)
	_murk = Murk.new()
	_murk.z_index = swimmers.z_index
	_murk.set_depth(float(place["depth"]))
	add_child(_murk)
	var lantern := BoatLantern.new()
	lantern.screen = self
	lantern.z_index = 1
	add_child(lantern)


func _end() -> float:
	return float(place["width"]) - (_boat.width() if _boat else 105.0)


## The game time today when the clock shows the given hour, for screenshots at a set time of day.
func _time_at_hour(h: float) -> float:
	var t := float(Game.state.get("time", 0.0))
	var day := Clock.day_of(t) * Clock.minutes_per_day()
	for m in range(0, int(Clock.minutes_per_day() * 10)):
		if absf(Clock.hour(day + m / 10.0) - h) < 0.1:
			return day + m / 10.0
	return t


func line_state() -> String:
	return _state


func rod_tip() -> Vector2:
	return _boat.rod_tip(boat_x)


## The top of the boat's side in the world at a point along it, where pots go over it.
func gunwale(x: float) -> float:
	return _boat.rail_at(x, boat_x)


func time() -> float:
	return _time


func boat_view() -> BoatView:
	return _boat


## The light over the scene now, for the hour and the weather.
func light_now() -> Color:
	return _lit.modulate


func facing() -> float:
	return _boat.facing


func boat_screen_position() -> Vector2:
	return _boat.boat.position


func boat_width() -> float:
	return _boat.width()


func dog_seat() -> Vector2:
	return _boat.dog_seat()


## The row in the boat's picture where its near side starts at the dog's spot.
func dog_rail() -> float:
	return _boat.dog_rail


## The row of the boat's picture the dog is drawn down to, below which the hull's near side hides it.
func dog_cut() -> float:
	return _boat.seat.y + 3.0


## In the desktop strip the fisherman fishes on his own and the panels make way for the view.
func _on_view_changed() -> void:
	charge = -1.0
	if Windowing.strip and not methods.idle:
		methods.set_idle(true)
		if _state == "reeled":
			cast(0.6)
	if hud:
		hud.visible = not Windowing.strip
	if is_instance_valid(_sail):
		_sail.visible = not Windowing.strip
	if is_instance_valid(events._haul_button):
		events._haul_button.visible = not Windowing.strip
	# The see-through strip shows only the sea and what is on it, so the sky and the land behind the water are hidden.
	var see_through := Windowing.strip and Windowing.transparent
	_sky.visible = not see_through
	for n in _layers.get_children():
		n.visible = not see_through or n.z_index > _water.z_index
	StripControls.sync()


## Rows the boat along the coast for some seconds; the line comes in first, and the boat stops at the place's ends.
func row(dir: float, seconds: float) -> void:
	if dir == 0.0 or _state == "fighting":
		return
	_let_go()
	_state = "reeled"
	_boat.facing = signf(dir)
	_boat.rowing = 0.15
	var speed := float(Data.boats.get(str(Game.state.get("boat", "skiff")), {}).get("speed", 40))
	var was := boat_x
	boat_x = clampf(boat_x + dir * speed * seconds, 0.0, _end())
	_rowed += absf(boat_x - was)
	if _rowed >= ROWED:
		_rowed = 0.0
		Game.state["stats"]["rowed"] = int(Game.state["stats"].get("rowed", 0)) + 1
	_row_sound -= seconds
	if _row_sound <= 0.0:
		_row_sound = 1.1
		Audio.play("oars", -6.0)
	Game.state["boat_x"] = boat_x
	hook = _boat.rod_tip(boat_x)


## Casts the line out in front of the boat: power 0 lands it close, power 1 as far as the rod throws.
func cast(power: float) -> void:
	var tip := _boat.rest_tip(boat_x)
	_boat.throw()
	power = clampf(power, 0.0, 1.0)
	hook = seabed.clamp_hook(Vector2(tip.x + _boat.facing * lerpf(CAST_NEAR, CAST_FAR, power), 0.0))
	_state = "sinking"
	charge = -1.0
	_flight_time = lerpf(FLIGHT_SECONDS[0], FLIGHT_SECONDS[1], power)
	_arc = lerpf(FLIGHT_ARC[0], FLIGHT_ARC[1], power)
	flight = _flight_time
	_flight_from = _boat.rod_tip(boat_x)
	# Only a cast by the player's own hand counts as learning to cast.
	if not methods.idle and not _demo:
		Game.state["stats"]["casts"] = int(Game.state["stats"].get("casts", 0)) + 1


## Where the float is on its flight out, arcing from the rod's tip to where it lands.
func flying() -> Vector2:
	var u := 1.0 - clampf(flight / _flight_time, 0.0, 1.0)
	return _flight_from.lerp(Vector2(hook.x, 0.0), u) + Vector2(0, -_arc * 4.0 * u * (1.0 - u))


## Whether a click at a point pets the dog: never while a fish is at the bait, when a click strikes.
func _pets_dog(at: Vector2) -> bool:
	return not _state in ["nibble", "bite"] and dog.rect().has_point(at)


## Whether he is rowing, with the rod laid down in the boat.
func rowing() -> bool:
	return _boat.rowing > 0.0 and _boat.oars


## Whether the rod lies in the boat with its line wound in, while he rows or the boat sails.
func rod_down() -> bool:
	return _boat.rod_down()


## Lets the hook sink, until it rests on the seabed or the line runs out; fishing on his own, he sets his float so the
## bait hangs in mid water.
## Lets the float drift on the water, the hook hanging straight under it, by a whole pixel at a time.
func _drift_step(delta: float) -> void:
	if not _state in ["sinking", "waiting", "nibble", "bite", "taken"] or flight > 0.0:
		_drift = 0.0
		return
	var next := move_toward(_drift, LineView.float_drift(_time), delta * 2.0)
	hook.x += roundf(next) - roundf(_drift)
	_drift = next


func sink(delta: float) -> void:
	if _state != "sinking":
		return
	var floor_y := minf(seabed.depth_at(hook.x) - 2.0, _line_length())
	if methods.idle:
		floor_y = minf(floor_y, clampf(seabed.depth_at(hook.x) * IDLE_DEPTH, 18.0, 90.0))
	hook.y = minf(hook.y + Data.num("fishing.sink_speed", 30) * delta, floor_y)
	# The hook's position is kept in single precision, so it only ever reaches the floor to within a rounding.
	if hook.y >= floor_y - 0.01:
		_state = "waiting"


## A fish he has caught on his own takes the bait: the float goes under, then he brings it in on the line.
func idle_catch(fish: String) -> void:
	landing = fish
	_state = "taken"
	_taken_left = TAKEN_SECONDS
	dog.bark()
	Audio.play("cork", -4.0)


func reel_in() -> void:
	_let_go()
	if _state != "reeled" and _state != "fighting":
		_state = "reeling"


## The bait on the hook, or nothing once the box is empty.
func bait() -> String:
	var b := str(Game.state.get("current_bait", ""))
	return b if int(Game.state.get("bait", {}).get(b, 0)) > 0 else ""


func _gear() -> Dictionary:
	var g: Dictionary = Game.state["gear"]
	return {"pull": Data.gear.get(str(g.get("rod", "")), {}).get("pull", 1),
		"strength": Data.gear.get(str(g.get("line", "")), {}).get("strength", 0.6),
		"hold": Data.gear.get(str(g.get("hook", "")), {}).get("hold", 1)}


func _line_length() -> float:
	return float(Data.gear.get(str(Game.state["gear"].get("line", "flax_line")), {}).get("length", 260))


## A fish reaches the hook and nibbles at the bait, twitching the float, before it takes it.
func _on_bite(f: Dictionary) -> void:
	if not _state in ["waiting", "sinking"] or not biter.is_empty():
		swimmers.release(f, false)
		return
	biter = f
	var count: Array = Data.value("fishing.nibbles", [1, 3])
	_nibbles_left = _rng.randi_range(int(count[0]), int(count[1]))
	_nibble_in = 0.0
	_state = "nibble"


## The nibbles, then the fish taking the bait and the float going under, then the fish going if nobody strikes.
func bite_step(delta: float) -> void:
	twitch = maxf(0.0, twitch - delta)
	if _state == "nibble":
		_nibble_in -= delta
		if _nibble_in > 0.0:
			return
		if _nibbles_left > 0:
			_nibbles_left -= 1
			twitch = TWITCH
			var gap: Array = Data.value("fishing.nibble_gap", [0.5, 1.2])
			_nibble_in = _rng.randf_range(float(gap[0]), float(gap[1]))
			Audio.play("cork", -16.0, 1.5)
		else:
			_state = "bite"
			bite_left = Bite.window()
			dog.bark()
			Audio.play("cork", -4.0)
	elif _state == "bite":
		bite_left -= delta
		if bite_left <= 0.0:
			_let_go()
			_use_bait()
			_state = "waiting"
			Toast.say("Too slow! It took the bait." if bait() != "" else "Too slow! It took your last bait.")


## Strikes at the fish at the hook: hooked once it has taken the bait, but scared off while it only nibbles.
func strike() -> void:
	if _state == "nibble":
		_let_go()
		_state = "waiting"
		Audio.play("splash_small", -12.0, 1.4)
		Toast.say("Too soon! Wait for the float to go under.")
		return
	if _state != "bite" or biter.is_empty():
		return
	fight = LineFight.new()
	fight.setup(biter["id"], float(biter["lb"]), _gear(), Settings.gentle, _rng)
	var tip := _boat.rod_tip(boat_x)
	fight.distance = maxf(10.0, hook.distance_to(tip))
	_fight_dir = (hook - tip).normalized()
	_use_bait()
	swimmers.release(biter, true)
	_state = "fighting"
	Game.state["stats"]["hooked"] = int(Game.state["stats"].get("hooked", 0)) + 1
	Audio.play("reel")


func _let_go() -> void:
	if not biter.is_empty() and _state in ["nibble", "bite"]:
		swimmers.release(biter, false, true)
	biter = {}
	twitch = 0.0
	flight = 0.0


func _use_bait() -> void:
	var b := bait()
	if b != "":
		Game.state["bait"][b] = int(Game.state["bait"][b]) - 1


func _fight_step(delta: float, reeling: bool) -> void:
	fight.step(reeling, delta)
	var tip := _boat.rod_tip(boat_x)
	var sway := Vector2(sin(_time * 9.0) * 7.0, cos(_time * 6.0) * 3.0) if fight.running() else Vector2.ZERO
	hook = seabed.clamp_hook(tip + _fight_dir * fight.distance + sway)
	if fight.state == "fighting":
		return
	var f := fight.fish
	var lb := fight.pounds
	var how := fight.state
	fight = null
	biter = {}
	_state = "reeled"
	hook = tip
	if how == "landed":
		Audio.play("splash_big")
		dog.cheer()
		var record := Catches.record(Game.state, f, lb, bool(Data.fish[f].get("live", false)))
		caught.emit(f, lb)
		CatchCard.show_catch(f, lb, bool(record["new"]))
		if record["where"] == "full":
			HoldChoice.ask(record["fish"])
	else:
		Toast.say("The line snapped. Let go while it runs!" if how == "snapped" else "It slipped the hook. Reel in while it rests!")


## Puts everything back in place for the camera, after a move or a change to the window.
func relayout() -> void:
	_sky.follow(camera.cam, hour, weather)
	_layers.time = _time
	_layers.keep_clear(_kept_clear(), fight != null)
	_layers.place(camera.cam)
	_floor.place_at(camera.cam)
	_water.cam = camera.cam
	_water.time = _time
	_boat.charge = charge if methods.method == "line" else -1.0
	_boat.strain = fight.tension if fight != null else 0.0
	_boat.pull = hook
	_boat.place(boat_x, camera.cam, _time)
	var light := SkyView.light(hour)
	if weather in ["rain", "storm"]:
		light = light * RAIN_LIGHT
		_water.rays = 0.3
	else:
		_water.rays = 1.0
	_layers.rough = 1.8 if weather in ["rain", "storm"] else 1.0
	_lit.modulate = Color(light, 1.0)
	_land.place_at(camera.cam)
	_murk.place_at(camera.cam, _lit.modulate)
	_ground.queue_redraw()
	_line.queue_redraw()
	_water.queue_redraw()


## What the plants in front of the view must not hide, in view pixels: the boat, the float or the hook, and the buttons
## along the bottom of the screen.
func _kept_clear() -> Array:
	var cam := camera.cam
	var out: Array = [Rect2(boat_x - cam.x, 0.0, _boat.width(), Nav.view().y), Rect2((flying() if flight > 0.0 else hook) - cam, Vector2.ZERO)]
	if Nav.ui:
		for b in Nav.ui.find_children("*", "Button", true, false):
			var r := Nav.from_ui(b.get_global_rect())
			if b.is_visible_in_tree() and r.end.y > Nav.view().y - 40.0:
				out.append(r)
	return out


func _update_swimmer_world() -> void:
	swimmers.cam = camera.cam
	swimmers.hour = hour
	swimmers.season = Clock.season(Clock.day_of(float(Game.state.get("time", 0.0))))
	swimmers.weather = weather
	swimmers.events = Events.on(Clock.day_of(float(Game.state.get("time", 0.0))))
	if not place_id in CoastEvents.DOLPHIN_PLACES:
		swimmers.events.erase("dolphins")


func _process(delta: float) -> void:
	_time += delta
	if not Dev.has("hour"):
		World.advance(Game.state, delta / 60.0, _rng)
	hour = Clock.hour(float(Game.state.get("time", 0.0)))
	if _demo:
		_demo_step()
	else:
		_handle_input(delta)
	if flight > 0.0:
		flight -= delta
		if flight <= 0.0:
			Audio.play("splash_small", -4.0)
	else:
		sink(delta)
	_drift_step(delta)
	match _state:
		"reeling":
			var tip := _boat.rod_tip(boat_x)
			hook = hook.move_toward(tip, REEL_SPEED * 2.0 * delta)
			if hook.y <= 0.0:
				hook = tip
				_state = "reeled"
		"reeled":
			hook = _boat.rod_tip(boat_x)
		"nibble", "bite":
			if methods.idle:
				_let_go()
				_state = "waiting"
			# The fish waits while a window is open, since nothing can be struck through it.
			elif not Ui.window_open():
				bite_step(delta)
		"fighting":
			# The fish waits while a window is open, as a bite does, since nobody can reel through it.
			if not Ui.window_open():
				_fight_step(delta, _reeling_input())
		"taken":
			_taken_left -= delta
			if _taken_left <= 0.0:
				_state = "landing"
				Audio.play("reel")
		"landing":
			var tip := _boat.rod_tip(boat_x)
			hook = hook.move_toward(tip, REEL_SPEED * delta)
			if hook.distance_to(tip) < 1.0:
				hook = tip
				_state = "reeled"
				dog.cheer()
				Audio.play("splash_big", -6.0)
	camera.view = Nav.view()
	if not _pinned:
		var watched := Vector2(hook.x, flying().y) if flight > 0.0 else hook
		var hooked := _state != "reeled" and not Windowing.strip
		# With the line in, the view goes down with a pot to the seabed and back, unless he is rowing on.
		var pot: Vector2 = methods.traps_view.watched()
		if not hooked and pot.is_finite() and _boat.rowing <= 0.0 and not Windowing.strip:
			watched = pot
			hooked = true
		camera.follow(boat_x, watched, hooked, delta, rowing() and not Windowing.strip)
	methods.tick(delta)
	_update_swimmer_world()
	swimmers.light = methods.trident_view.light_at() if methods.trident_view.lit else null
	swimmers.light_reach = Trident.reach(str(Game.state["gear"].get("lamp", "")))
	var today := Clock.day_of(float(Game.state.get("time", 0.0)))
	if today != _day:
		_day = today
		events.refresh()
	swimmers.held_at = hook if _state in ["nibble", "bite"] else null
	swimmers.step(delta, hook if hook_baited() else null, bait())
	_weather_check -= delta
	if _weather_check <= 0.0 and not Dev.has("weather"):
		_weather_check = 2.0
		weather = str(Game.state.get("weather", weather))
	_rain_step(delta)
	_sounds(delta)
	if _ashore:
		_ashore.visible = boat_x < QUAY_REACH and _state == "reeled" and not Windowing.strip
	_click = false
	relayout()


## Whether a fish may take the hand line's bait: a line in the water with bait on it, while the player is at the rod.
func hook_baited() -> bool:
	return _state in ["waiting", "sinking"] and flight <= 0.0 and bait() != "" and methods.method == "line" and not methods.idle


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		_click = true
		_mouse_held = true


func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		_mouse_held = false


## The cast button just pressed: Space or the controller, or a click on the water.
func _pressed() -> bool:
	return Input.is_action_just_pressed("cast") or _click


func _held() -> bool:
	return Input.is_action_pressed("cast") or _mouse_held


func _reeling_input() -> bool:
	if _demo:
		return fight != null and fight.resting()
	return _held()


func _handle_input(delta: float) -> void:
	if CatchCard.is_open() or Ui.window_open() or methods.method != "line":
		charge = -1.0
	if CatchCard.is_open() or Ui.window_open():
		return
	if _click and _pets_dog(get_global_mouse_position()):
		dog.pet()
		return
	for m in CoastMethods.METHODS:
		if Input.is_action_just_pressed("method_" + m):
			methods.set_method(m)
	if Input.is_action_just_pressed("idle"):
		methods.set_idle(not methods.idle)
		if methods.idle and _state == "reeled":
			cast(0.6)
	if methods.idle:
		return
	var dir := Input.get_axis("row_left", "row_right")
	if Dev.has("row") and _time < Dev.num("row-for", 6.0):
		dir = Dev.num("row", 1.0)
	if dir != 0.0:
		_pinned = false
		row(dir, delta)
	if methods.method != "line":
		if _pressed():
			methods.use()
		return
	match _state:
		"reeled":
			if rowing() or dir != 0.0:
				charge = -1.0
			elif _pressed():
				charge = 0.0
			elif charge >= 0.0 and _held():
				charge = minf(1.0, charge + delta / Data.num("fishing.cast_seconds", 1.5))
			elif charge >= 0.0:
				if bait() == "":
					Toast.say("No bait on the hook.")
				cast(charge)
				charge = -1.0
		"nibble", "bite":
			if _pressed():
				strike()
		"waiting", "sinking":
			if _pressed():
				reel_in()
			else:
				var v := Input.get_axis("reel_up", "let_out")
				if v < 0.0:
					hook.y = maxf(0.0, hook.y - REEL_SPEED * delta)
					_state = "waiting"
				elif v > 0.0 and _state == "waiting":
					_state = "sinking"


## The demo for screenshots and checks: cast, wait for a bite (or with --hook=ID have that fish take the bait at once),
## strike at once and reel only while the fish rests.
func _demo_step() -> void:
	if _state == "reeled" and not CatchCard.is_open() and _time > 0.8:
		cast(0.7)
	elif _state == "waiting" and Dev.has("hook"):
		_on_bite({"id": Dev.get_arg("hook", "mullet"), "lb": 1.5, "state": "bit", "heading": 1.0})
	elif _state == "bite":
		strike()


func _rain_step(delta: float) -> void:
	if not weather in ["rain", "storm"]:
		_rain.clear()
		return
	var want := 140 if weather == "storm" else 80
	# The desktop strip shifts the canvas up to the waterline, so the rain falls over the rows that are on screen.
	var top := -get_viewport().canvas_transform.origin.y
	var bottom := top + Nav.view().y
	while _rain.size() < want:
		_rain.append(Vector2(randf_range(0, Nav.view().x + 40.0), randf_range(top - 20.0, bottom)))
	for i in _rain.size():
		_rain[i] += Vector2(-30.0, 220.0) * delta
		if _rain[i].y > bottom or _rain[i].x < -10.0:
			_rain[i] = Vector2(randf_range(0, Nav.view().x + 60.0), top - 10.0)


func rain() -> Array:
	return _rain


## Solid shadow below the seabed, fading in over sixteen pixels, so pieces in front of the floor never end in a cut.
func _draw_ground(node: Node2D) -> void:
	var cam := camera.cam
	var x0 := floorf(cam.x / 8.0) * 8.0 - 8.0
	var view := Nav.view()
	while x0 < cam.x + view.x:
		var x1 := x0 + 8.0
		var a := Vector2(x0, roundf(seabed.depth_at(x0) + _ground_below)) - cam
		var b := Vector2(x1, roundf(seabed.depth_at(x1) + _ground_below)) - cam
		var bottom := maxf(view.y + 10.0, maxf(a.y, b.y) + 1.0)
		node.draw_colored_polygon(PackedVector2Array([a, b, Vector2(b.x, bottom), Vector2(a.x, bottom)]), FloorView.SHADOW)
		for k in 8:
			var up := Vector2(0, 16.0 - k * 2.0)
			var down := Vector2(0, 14.0 - k * 2.0)
			node.draw_colored_polygon(PackedVector2Array([a - up, b - up, b - down, a - down]), Color(FloorView.SHADOW, (k + 1) / 9.0))
		x0 = x1


class Painter extends Node2D:
	var fn: Callable

	func _draw() -> void:
		fn.call(self)


## The sea's sounds for the hour and weather, and the dog's delight when a shoal passes under the boat.
func _sounds(delta: float) -> void:
	var day := hour >= 5.0 and hour < 20.0
	Audio.set_ambience({"gulls": 0.35 if day and hour < 17.5 else 0.0, "cicadas": 0.3 if hour >= 16.0 and hour < 20.5 else 0.0,
		"night": 0.4 if not day else 0.0, "rain": 0.6 if weather in ["rain", "storm"] else 0.0, "wind": 0.5 if weather in ["wind", "storm"] else 0.0})
	if randf() < delta / 25.0:
		Audio.play("creak", -10.0)
	_cheer_wait -= delta
	if _cheer_wait <= 0.0:
		var mid := boat_x + _boat.width() / 2.0
		if swimmers.fish.any(func(f): return f["leader"].is_empty() and Data.fish[f["id"]].get("shoal", false) and absf(f["pos"].x - mid) < 40.0 and f["pos"].y < 120.0):
			dog.cheer()
			_cheer_wait = 20.0
