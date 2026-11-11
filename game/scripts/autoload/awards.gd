extends Node
## Achievements on Steam, as Mosaicus Maximus sends them: each one earned is handed to Steam when the game runs through
## Steam, and every one in the save is sent again on each change of screen, so ones earned without Steam still count.
## Only a real game sends them, never one made up by a test or a developer's option.

var _steam: Object = null


func _ready() -> void:
	# GodotSteam adds a "Steam" singleton; without it (the editor, or a build outside Steam) achievements stay in the save.
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")
		_steam.call("steamInit")
	Nav.screen_changed.connect(func(_s: String) -> void: sync())


func _process(_delta: float) -> void:
	if _steam:
		_steam.call("run_callbacks")


## Only a real, saved game sends achievements, never one made up for checks such as --max-state or --demo-state.
func may_send() -> bool:
	return Saves.enabled and not Dev.made_up() and not Dev.has("run-tests") and not Dev.has("achievement") and not Dev.has("panel") \
		and not Game.state.get("_unlocked", false)


func unlock(id: String) -> void:
	if _steam and may_send():
		_steam.call("setAchievement", id)
		_steam.call("storeStats")


## Sends every achievement in the save to Steam.
func sync() -> void:
	for id in Game.state.get("achievements", []):
		unlock(str(id))
