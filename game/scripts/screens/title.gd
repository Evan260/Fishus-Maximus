extends Node2D
## The title: the harbour at sunset with Continue, New game, Load, Settings and Quit. It is built from the coast's own
## pieces with the camera held still, so it always looks as the game does: the sky with its drifting clouds, the town,
## the lighthouse and the headland, the land carried on down under the water, the sand, the murk and the fish. It runs
## before any game is loaded, so it reads nothing from a game and changes nothing in one.

const PLACE := "harbour"
const HOUR := 19.3
const SEASON := "summer"
## Where the camera rests in a 480 by 270 view; a view of another shape is centred on the same spot.
const AT := Vector2(60, CoastCamera.HOME_Y)

var place := {}
var seabed: Seabed
var cam := AT
var swimmers: Swimmers
var _time := 0.0
var _sky: SkyView
var _lit: Node2D
var _layers: ParallaxLayers
var _floor: FloorView
var _water: WaterView
var _ground: Node2D
var _surface: Node2D
var _land: UnderLand
var _murk: Murk
var _menu: VBoxContainer
var _heading: Label
var _sub: Label


func enter(_args: Dictionary) -> void:
	place = Data.places[PLACE]
	seabed = Seabed.new(place["seabed"])
	_build()
	Windowing.view_changed.connect(_place)
	_place()
	swimmers.populate()
	Audio.set_ambience({"gulls": 0.15, "cicadas": 0.2})
	_show_menu()


func _exit_tree() -> void:
	if is_instance_valid(_sky):
		_sky.queue_free()


## The coast's pieces in the coast's own order, so each is drawn over what it is drawn over in the game.
func _build() -> void:
	_sky = SkyView.new()
	Nav.sky.add_child(_sky)
	_lit = Node2D.new()
	add_child(_lit)
	_layers = ParallaxLayers.new()
	_layers.sky = _sky
	_lit.add_child(_layers)
	_layers.build(place["layers"])
	_floor = FloorView.new()
	_floor.z_index = -8
	_floor.bake(place, seabed)
	_lit.add_child(_floor)
	_water = WaterView.new()
	_water.depth = float(place["depth"])
	_water.z_index = -10
	_lit.add_child(_water)
	_ground = Node2D.new()
	_ground.z_index = -6
	_ground.draw.connect(_draw_ground)
	_lit.add_child(_ground)
	swimmers = Swimmers.new()
	swimmers.z_index = -4
	swimmers.with_legends = false
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	swimmers.setup(PLACE, seabed, rng)
	swimmers.hour = HOUR
	swimmers.season = SEASON
	_lit.add_child(swimmers)
	_surface = Node2D.new()
	_surface.draw.connect(func(): WaterView.draw_surface(_surface, cam, _time))
	_lit.add_child(_surface)
	# These shade the lit picture under them, so inside the light they would tint it a second time.
	_land = UnderLand.new(place)
	_land.z_index = _water.z_index
	add_child(_land)
	_murk = Murk.new()
	_murk.z_index = swimmers.z_index
	_murk.set_depth(float(place["depth"]))
	add_child(_murk)


## Centres the camera's resting spot in the view, as far as the harbour reaches, and lays the menu over it.
func _place() -> void:
	var view := Nav.view()
	cam = Vector2(clampf(AT.x + (Nav.SIZE.x - view.x) / 2.0, 0.0, float(place["width"]) - view.x), AT.y - Nav.offset().y)
	_relayout()
	if is_instance_valid(_menu):
		# Each line keeps its place on the scene, but a larger interface pushes the next one down rather than overlap it.
		var heading := roundf(_row(26))
		var sub := maxf(roundf(_row(46)), heading + 20)
		var menu := maxf(roundf(_row(120)), sub + 24)
		menu = maxf(sub + 16, minf(menu, Nav.ui_view().y - _menu.get_combined_minimum_size().y - 6))
		Ui.hang(_heading, "top", Vector2(0, heading), Vector2(0, 20))
		Ui.hang(_sub, "top", Vector2(0, sub), Vector2(0, 14))
		Ui.hang(_menu, "top", Vector2(0, menu), Vector2(100, 0))


## A row of the 480 by 270 scene in interface pixels.
func _row(y: float) -> float:
	return Nav.to_ui(Vector2(0, y + Nav.offset().y)).y


func _process(delta: float) -> void:
	_time += delta
	swimmers.step(delta, null, "")
	_relayout()


func _relayout() -> void:
	_sky.follow(cam, HOUR, "clear")
	_layers.time = _time
	_layers.place(cam)
	_floor.place_at(cam)
	_water.cam = cam
	_water.time = _time
	_lit.modulate = Color(SkyView.light(HOUR), 1.0)
	_land.place_at(cam)
	_murk.place_at(cam, _lit.modulate)
	swimmers.cam = cam
	_water.queue_redraw()
	_ground.queue_redraw()
	_surface.queue_redraw()


## Solid shadow below the seabed, fading in over sixteen pixels, as the coast draws it.
func _draw_ground() -> void:
	var below := float(place.get("ground_below", 24))
	var view := Nav.view()
	var x0 := floorf(cam.x / 8.0) * 8.0 - 8.0
	while x0 < cam.x + view.x:
		var x1 := x0 + 8.0
		var a := Vector2(x0, roundf(seabed.depth_at(x0) + below)) - cam
		var b := Vector2(x1, roundf(seabed.depth_at(x1) + below)) - cam
		var bottom := maxf(view.y + 10.0, maxf(a.y, b.y) + 1.0)
		_ground.draw_colored_polygon(PackedVector2Array([a, b, Vector2(b.x, bottom), Vector2(a.x, bottom)]), FloorView.SHADOW)
		for k in 8:
			var up := Vector2(0, 16.0 - k * 2.0)
			var down := Vector2(0, 14.0 - k * 2.0)
			_ground.draw_colored_polygon(PackedVector2Array([a - up, b - up, b - down, a - down]), Color(FloorView.SHADOW, (k + 1) / 9.0))
		x0 = x1


func _show_menu() -> void:
	for c in Nav.ui.get_children():
		c.queue_free()
	_heading = Ui.label(Nav.ui, "FISHUS MAXIMUS", "Title")
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.add_theme_color_override("font_outline_color", UiTheme.INK)
	_heading.add_theme_constant_override("outline_size", 4)
	_sub = Ui.label(Nav.ui, "A fishing life on the Bay of Naples, AD 72", "LightLabel")
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_color_override("font_outline_color", UiTheme.INK)
	_sub.add_theme_constant_override("outline_size", 2)
	_menu = VBoxContainer.new()
	_menu.custom_minimum_size = Vector2(100, 0)
	_menu.add_theme_constant_override("separation", 4)
	Nav.ui.add_child(_menu)
	var last := _latest_slot()
	if last > 0:
		Ui.button(_menu, "Continue", func(): _play(last))
	Ui.button(_menu, "New game", _new_game)
	if last > 0:
		Ui.button(_menu, "Load", _load)
	Ui.button(_menu, "Settings", func(): SettingsPanel.open())
	Ui.button(_menu, "Quit", func(): get_tree().quit())
	_place()


## The slot played most recently, or 0 when there are no saves.
func _latest_slot() -> int:
	var best := 0
	var when := -1.0
	for n in range(1, Saves.SLOTS + 1):
		var path := Saves.path_for(n)
		if FileAccess.file_exists(path) and FileAccess.get_modified_time(path) > when:
			when = FileAccess.get_modified_time(path)
			best = n
	return best


func _play(n: int) -> void:
	if Saves.load_slot(n):
		Game.catch_up()
		Nav.go("coast", {"place": str(Game.state.get("place", "harbour"))})


func _new_game() -> void:
	var list := Ui.window("A new game", 300, 200)
	Ui.label(list, "Your name", "MutedLabel")
	var name := LineEdit.new()
	name.text = "Marcus"
	name.max_length = 16
	list.add_child(name)
	Ui.label(list, "Your dog, who rides in the bow", "MutedLabel")
	var row := HBoxContainer.new()
	list.add_child(row)
	var chosen := ["hound"]
	var buttons := []
	for breed in Dogs.breeds():
		var b := Button.new()
		var frames := Dogs.frames(breed, "sit_east")
		if not frames.is_empty():
			b.icon = frames[0]
		b.tooltip_text = Dogs.NAMES[breed]
		b.toggle_mode = true
		b.button_pressed = breed == "hound"
		b.expand_icon = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(48, 48)
		var id: String = breed
		b.pressed.connect(func():
			chosen[0] = id
			for other in buttons:
				other.button_pressed = other == b)
		row.add_child(b)
		buttons.append(b)
	var slot := Saves.free_slot()
	if slot == 0:
		Ui.label(list, "All three slots are used; this will replace slot 1.", "MutedLabel")
		slot = 1
	Ui.button(list, "Set out", func():
		Game.new_game(name.text.strip_edges() if name.text.strip_edges() != "" else "Marcus", chosen[0])
		Saves.slot = slot
		Saves.save(slot)
		Ui.close_window()
		Nav.go("coast", {"place": "harbour", "first": true}))


func _load() -> void:
	var list := Ui.window("Load a game", 300, 170)
	for n in range(1, Saves.SLOTS + 1):
		var info := Saves.slot_info(n)
		var slot: int = n
		if info.is_empty():
			Ui.row(list, "Slot %d: empty" % n)
			continue
		var r := Ui.row(list, "Slot %d: %s, day %d, chapter %d" % [n, info["name"], int(info["day"]), int(info["chapter"])], "Play", func(): _play(slot))
		Ui.button(r, "Delete", func(): _confirm_delete(slot, info))


## A game cannot be brought back, so deleting one asks for the word typed out, which no stray click can do.
func _confirm_delete(slot: int, info: Dictionary) -> void:
	var list := Ui.window("Delete a game", 260, 120)
	var ask := Ui.label(list, "Type \"delete\" to delete %s's game, day %d, for good." % [info["name"], int(info["day"])])
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var field := LineEdit.new()
	field.placeholder_text = "delete"
	field.max_length = 20
	list.add_child(field)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	list.add_child(row)
	var gone := func():
		if field.text.strip_edges().to_lower() != "delete":
			return
		Saves.delete(slot)
		if Saves.slot == slot:
			Saves.slot = 0
		# The menu is laid out again, so Continue goes to a save that is still there, or goes with the last.
		_show_menu()
		if _latest_slot() > 0:
			_load()
	var delete := Ui.button(row, "Delete", gone)
	delete.disabled = true
	field.text_changed.connect(func(t: String): delete.disabled = t.strip_edges().to_lower() != "delete")
	field.text_submitted.connect(func(_t): gone.call())
	Ui.button(row, "Cancel", _load)
	field.grab_focus.call_deferred()
