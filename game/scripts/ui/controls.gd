class_name Controls
## The game's keys, added to the input map in code so every screen can use them by name.

const KEYS := {
	"row_left": [KEY_A, KEY_LEFT],
	"row_right": [KEY_D, KEY_RIGHT],
	"reel_up": [KEY_W, KEY_UP],
	"let_out": [KEY_S, KEY_DOWN],
	"cast": [KEY_SPACE],
	"method_line": [KEY_1],
	"method_trap": [KEY_2],
	"method_net": [KEY_3],
	"method_trident": [KEY_4],
	"idle": [KEY_I],
}


static func ensure() -> void:
	for action in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in KEYS[action]:
			var e := InputEventKey.new()
			e.physical_keycode = key
			InputMap.action_add_event(action, e)
	for pad in [["row_left", JOY_BUTTON_DPAD_LEFT], ["row_right", JOY_BUTTON_DPAD_RIGHT], ["reel_up", JOY_BUTTON_DPAD_UP],
			["let_out", JOY_BUTTON_DPAD_DOWN], ["cast", JOY_BUTTON_A], ["idle", JOY_BUTTON_Y], ["method_line", JOY_BUTTON_LEFT_SHOULDER],
			["method_net", JOY_BUTTON_RIGHT_SHOULDER]]:
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
