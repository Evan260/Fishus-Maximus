extends Node2D
## The title: the harbour at sunset, alive, with Continue, New game, Load, Settings and Quit. Clouds drift behind the
## land, the palms and the weed sway, the sun glitters on the sea, fish swim and bubbles rise.

const ART := "res://assets/art/title/"
const SWAY := """
shader_type canvas_item;
uniform sampler2D sway : filter_nearest;
void fragment() {
	float w = texture(sway, UV).r;
	float off = round(sin(TIME * 1.4 + UV.y * 38.0 + UV.x * 6.0) * 1.4 * w);
	COLOR = texture(TEXTURE, UV - vec2(off * TEXTURE_PIXEL_SIZE.x, 0.0));
}
"""
const FISH := ["mullet", "bream", "white_bream", "salema", "parrotfish", "wrasse", "golden_mullet", "red_porgy"]

var _stage: Node2D
var _menu: VBoxContainer
var _info := {"waterline": 164, "pad": 40, "horizon": 126}
var _clouds: Array = []
var _fish: Array = []
var _bubbles: Array = []
var _time := 0.0
var _painter: Node2D


func enter(_args: Dictionary) -> void:
	if FileAccess.file_exists(ART + "title.json"):
		_info = JSON.parse_string(FileAccess.get_file_as_string(ART + "title.json"))
	_stage = Node2D.new()
	add_child(_stage)
	var pad := float(_info["pad"])
	var around := Backdrop.new(load(ART + "base.png"))
	around.position = Vector2(0, -pad)
	_stage.add_child(around)
	var sky := Sprite2D.new()
	sky.texture = load(ART + "sky.png")
	sky.centered = false
	sky.position = Vector2(0, -pad)
	_stage.add_child(sky)
	var cloud_tex: Texture2D = load("res://assets/art/places/common/clouds.png")
	for i in 2:
		var c := Sprite2D.new()
		c.texture = cloud_tex
		c.centered = false
		c.modulate = Color(1.0, 0.82, 0.78, 0.55 - i * 0.15)
		c.scale = Vector2.ONE * (1.0 - i * 0.3)
		_stage.add_child(c)
		_clouds.append({"node": c, "x": -i * 300.0, "y": -pad + 6.0 + i * 26.0, "speed": 3.0 - i * 1.2})
	var land := Sprite2D.new()
	land.texture = load(ART + "land.png")
	land.centered = false
	land.position = Vector2(0, -pad)
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SWAY
	mat.shader = shader
	mat.set_shader_parameter("sway", load(ART + "sway.png"))
	land.material = mat
	_stage.add_child(land)
	_painter = Node2D.new()
	_painter.draw.connect(_draw_life)
	_stage.add_child(_painter)
	for i in 7:
		_add_fish(randf_range(0.0, 480.0))
	Windowing.view_changed.connect(_place)
	_place()
	Audio.set_ambience({"sea": 0.4, "gulls": 0.15})
	_show_menu()


func _place() -> void:
	if is_instance_valid(_stage):
		_stage.position = Nav.offset()


func _add_fish(x: float) -> void:
	var id: String = FISH[randi() % FISH.size()]
	var path := "res://assets/art/fish/%s.png" % id
	if not ResourceLoader.exists(path):
		return
	var s := Sprite2D.new()
	s.texture = load(path)
	var dir := 1.0 if randf() < 0.5 else -1.0
	s.flip_h = dir < 0.0
	var water := float(_info["waterline"]) - float(_info["pad"])
	var y := randf_range(water + 22.0, water + 104.0)
	s.modulate = Color(0.95, 1.0, 1.0).lerp(Color(0.55, 0.72, 0.8), (y - water) / 130.0)
	s.scale = Vector2.ONE * randf_range(0.6, 0.85)
	_stage.add_child(s)
	_painter.move_to_front()
	_fish.append({"node": s, "x": x, "y": y, "dir": dir, "speed": randf_range(6.0, 14.0), "phase": randf() * TAU})


func _process(delta: float) -> void:
	_time += delta
	for c in _clouds:
		var node: Sprite2D = c["node"]
		var w: float = node.texture.get_width() * node.scale.x
		c["x"] = fposmod(c["x"] + c["speed"] * delta + w, 480.0 + w) - w
		node.position = Vector2(roundf(c["x"]), c["y"])
	for f in _fish:
		f["x"] += f["dir"] * f["speed"] * delta
		var node: Sprite2D = f["node"]
		node.position = Vector2(roundf(f["x"]), roundf(f["y"] + sin(_time * 1.3 + f["phase"]) * 1.5))
		if f["x"] < -40.0 or f["x"] > 520.0:
			f["dir"] = -f["dir"]
			node.flip_h = f["dir"] < 0.0
	var water := float(_info["waterline"]) - float(_info["pad"])
	if randf() < delta * 2.2:
		var sources := [26.0, 58.0, 118.0, 392.0, 436.0]
		_bubbles.append({"pos": Vector2(sources[randi() % sources.size()] + randf_range(-4, 4), water + 110.0), "r": randf_range(0.6, 2.2)})
	for b in _bubbles:
		b["pos"] += Vector2(sin(_time * 3.0 + b["r"] * 5.0) * 4.0 * delta, -(14.0 + b["r"] * 5.0) * delta)
	_bubbles = _bubbles.filter(func(b): return b["pos"].y > water + 2.0)
	_painter.queue_redraw()


func _draw_life() -> void:
	var water := float(_info["waterline"]) - float(_info["pad"])
	var horizon := float(_info["horizon"]) - float(_info["pad"])
	# The sun's glitter on the sea below it, and the light catching the waterline.
	for i in 22:
		if sin(_time * 2.4 + i * 1.7) > 0.25:
			var y := horizon + 4.0 + (i * 5) % int(water - horizon - 6.0)
			var spread := 8.0 + (y - horizon) * 0.7
			_painter.draw_rect(Rect2(roundf(272.0 + sin(i * 2.3) * spread), roundf(y), 3, 1), Color(1.0, 0.92, 0.7, 0.85))
	for i in 34:
		var x := fposmod(i * 37.0 + _time * (5.0 + i % 3 * 2.0), 480.0)
		_painter.draw_rect(Rect2(roundf(x), water + (i % 2), 3 + i % 3, 1), Color(1.0, 0.93, 0.85, 0.45))
	for b in _bubbles:
		var p: Vector2 = b["pos"].round()
		if b["r"] < 1.2:
			_painter.draw_rect(Rect2(p, Vector2.ONE), Color(0.9, 1.0, 1.0, 0.75))
		else:
			_painter.draw_arc(p, b["r"], 0.0, TAU, 8, Color(0.9, 1.0, 1.0, 0.7), 1.0)


func _show_menu() -> void:
	for c in Nav.ui.get_children():
		c.queue_free()
	var title := Ui.label(Nav.ui, "FISHUS MAXIMUS", "Title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", UiTheme.INK)
	title.add_theme_constant_override("outline_size", 4)
	Ui.hang(title, "top", Vector2(0, 26 + Nav.offset().y), Vector2(480, 20))
	var sub := Ui.label(Nav.ui, "A fishing life on the Bay of Naples, AD 72", "LightLabel")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_outline_color", UiTheme.INK)
	sub.add_theme_constant_override("outline_size", 2)
	Ui.hang(sub, "top", Vector2(0, 46 + Nav.offset().y), Vector2(480, 14))
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
	Ui.hang(_menu, "top", Vector2(0, 120 + Nav.offset().y), Vector2(100, 0))


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
		var away := Game.catch_up()
		Nav.go("coast", {"place": str(Game.state.get("place", "harbour")), "away": away})


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
		var confirm := LineEdit.new()
		confirm.placeholder_text = "type delete"
		confirm.custom_minimum_size = Vector2(70, 0)
		confirm.text_changed.connect(func(t):
			if t.strip_edges().to_lower() == "delete":
				Saves.delete(slot)
				if Saves.slot == slot:
					Saves.slot = 0
				_load())
		r.add_child(confirm)
