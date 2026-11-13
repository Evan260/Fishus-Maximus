class_name Controls
## The game's keys, added to the input map in code so every screen can use them by name. The settings change each
## action's own key; the arrow keys and the controller's buttons beside it always work too.

## Each action in the order the settings list them: its name there, its key, and keys that always work beside it.
const ACTIONS := {
	"row_left": {"name": "Row left", "key": KEY_A, "also": [KEY_LEFT]},
	"row_right": {"name": "Row right", "key": KEY_D, "also": [KEY_RIGHT]},
	"reel_up": {"name": "Reel in", "key": KEY_W, "also": [KEY_UP]},
	"let_out": {"name": "Let out line", "key": KEY_S, "also": [KEY_DOWN]},
	"cast": {"name": "Cast, strike and reel", "key": KEY_SPACE, "also": []},
	"method_line": {"name": "Line", "key": KEY_1, "also": []},
	"method_trap": {"name": "Pots", "key": KEY_2, "also": []},
	"method_net": {"name": "Cast net", "key": KEY_3, "also": []},
	"method_trident": {"name": "Trident", "key": KEY_4, "also": []},
	"idle": {"name": "Fish on his own", "key": KEY_I, "also": []},
	"close_panel": {"name": "Close a window or go back", "key": KEY_ESCAPE, "also": []},
	"toggle_strip": {"name": "Desktop strip", "key": KEY_F10, "also": []},
	"reset_strip": {"name": "Re-centre the strip", "key": KEY_F9, "also": []},
}
const PAD := [["row_left", JOY_BUTTON_DPAD_LEFT], ["row_right", JOY_BUTTON_DPAD_RIGHT], ["reel_up", JOY_BUTTON_DPAD_UP],
	["let_out", JOY_BUTTON_DPAD_DOWN], ["cast", JOY_BUTTON_A], ["idle", JOY_BUTTON_Y], ["method_line", JOY_BUTTON_LEFT_SHOULDER],
	["method_net", JOY_BUTTON_RIGHT_SHOULDER], ["close_panel", JOY_BUTTON_B]]
## Each controller button's picture in assets/art/ui/pad/, drawn by tools/art/make_pad_glyphs.py.
const GLYPHS := {JOY_BUTTON_A: "a", JOY_BUTTON_B: "b", JOY_BUTTON_X: "x", JOY_BUTTON_Y: "y", JOY_BUTTON_LEFT_SHOULDER: "lb",
	JOY_BUTTON_RIGHT_SHOULDER: "rb", JOY_BUTTON_DPAD_LEFT: "dpad_left", JOY_BUTTON_DPAD_RIGHT: "dpad_right",
	JOY_BUTTON_DPAD_UP: "dpad_up", JOY_BUTTON_DPAD_DOWN: "dpad_down"}
const GLYPH_DIR := "res://assets/art/ui/pad/"


static func ensure() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		bind(action)
	for pad in PAD:
		if not InputMap.action_get_events(pad[0]).any(func(e): return e is InputEventJoypadButton):
			var b := InputEventJoypadButton.new()
			b.button_index = pad[1]
			InputMap.action_add_event(pad[0], b)
	for stick in [["row_left", -1.0], ["row_right", 1.0]]:
		if not InputMap.action_get_events(stick[0]).any(func(e): return e is InputEventJoypadMotion):
			var m := InputEventJoypadMotion.new()
			m.axis = JOY_AXIS_LEFT_X
			m.axis_value = stick[1]
			InputMap.action_add_event(stick[0], m)
	# A click casts only when it lands on the water, so the coast takes it from the clicks no button used.
	for e in InputMap.action_get_events("cast"):
		if e is InputEventMouseButton:
			InputMap.action_erase_event("cast", e)


## The key the player has chosen for an action, or its own.
static func key_for(action: String) -> int:
	return int(Settings.keys.get(action, ACTIONS[action]["key"]))


static func key_name(action: String) -> String:
	return OS.get_keycode_string(key_for(action))


## Text with each {action} in it, such as {cast}, written as that action's key now, so advice names the keys chosen.
static func fill(text: String) -> String:
	var keys := {}
	for action in ACTIONS:
		keys[action] = key_name(action)
	return text.format(keys)


## The controller button that does an action, or -1 when none does.
static func pad_button(action: String) -> int:
	for p in PAD:
		if p[0] == action:
			return p[1]
	return -1


static func glyph_path(action: String) -> String:
	var b := pad_button(action)
	return GLYPH_DIR + GLYPHS[b] + ".png" if GLYPHS.has(b) else ""


## The picture of the controller button that does an action, or null when none does.
static func glyph(action: String) -> Texture2D:
	var path := glyph_path(action)
	return load(path) if path != "" and ResourceLoader.exists(path) else null


## Text with each {action} in it as a picture of its controller button, for a RichTextLabel; an action with no button
## keeps its key.
static func fill_pad(text: String) -> String:
	var keys := {}
	for action in ACTIONS:
		var path := glyph_path(action)
		keys[action] = "[img=center]%s[/img]" % path if path != "" else key_name(action)
	return text.format(keys)


## Gives an action a new key and keeps it; the keys that always work beside it stay.
static func rebind(action: String, keycode: int) -> void:
	if keycode == int(ACTIONS[action]["key"]):
		Settings.keys.erase(action)
	else:
		Settings.keys[action] = keycode
	Settings.save()
	bind(action)


static func bind(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			InputMap.action_erase_event(action, e)
	for key in [key_for(action)] + Array(ACTIONS[action]["also"]):
		var e := InputEventKey.new()
		e.physical_keycode = key
		InputMap.action_add_event(action, e)
