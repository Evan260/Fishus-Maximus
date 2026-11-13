extends Node
## Achievements on Steam, as Mosaicus Maximus sends them: each one earned is handed to Steam when the game runs through
## Steam, and every one in the save is sent again on each change of screen, so ones earned without Steam still count.
## Only a real game sends them, never one made up by a test or a developer's option. It also tells Steam friends what
## the player is doing (rich presence), with the tokens in `tools/steam/rich_presence.vdf`.

## How often, in seconds, the rich presence is checked for a change of place or time of day.
const PRESENCE_EVERY := 5.0

var _steam: Object = null
var _presence := {}
var _presence_left := 0.0


func _ready() -> void:
	# GodotSteam adds a "Steam" singleton; without it, or with no Steam client running, achievements stay in the save.
	if Engine.has_singleton("Steam"):
		var steam: Object = Engine.get_singleton("Steam")
		var result: Dictionary = steam.call("steamInitEx")
		if int(result.get("status", -1)) == 0:
			_steam = steam
		else:
			print("Steam is not available, so achievements stay in the save: ", result.get("verbal", ""))
	Nav.screen_changed.connect(func(_s: String) -> void:
		sync()
		_presence_left = 0.0)


func _process(delta: float) -> void:
	if not _steam:
		return
	_steam.call("run_callbacks")
	_presence_left -= delta
	if _presence_left <= 0.0:
		_presence_left = PRESENCE_EVERY
		show_presence(presence_for(Nav.current_name, Game.state))


## What Steam shows friends for a screen: a `steam_display` token from the rich presence file and what it fills in.
static func presence_for(screen: String, state: Dictionary) -> Dictionary:
	if state.is_empty():
		return {"steam_display": "#Title"}
	match screen:
		"coast":
			return {"steam_display": "#Fishing_" + str(state["place"]), "when": Clock.part_of_day(float(state["time"]))}
		"town":
			return {"steam_display": "#Town"}
		"shore":
			return {"steam_display": "#Pond"}
		"map":
			return {"steam_display": "#Map"}
	return {"steam_display": "#Title"}


## Hands Steam the rich presence only when it has changed, the token last so it never shows with an old value.
func show_presence(p: Dictionary) -> void:
	if not _steam or p == _presence:
		return
	_presence = p
	for key in p:
		if key != "steam_display":
			_steam.call("setRichPresence", key, p[key])
	_steam.call("setRichPresence", "steam_display", p["steam_display"])


## Only a real, saved game sends achievements, never one made up for checks such as --max-state or --demo-state.
func may_send() -> bool:
	return Saves.enabled and not Dev.made_up() and not Dev.has("run-tests") and not Dev.has("achievement") and not Dev.has("panel") \
		and not Game.state.get("_unlocked", false)


## The full game's Steam App ID, kept only in `steam.app_id` in balance.json; 0 until Steamworks gives one.
static func store_app_id() -> int:
	return int(Data.num("steam.app_id", 0))


## The demo sends achievements only when Steam runs it as the full game, so they reach the full game's page; otherwise
## they stay in the save and the full game sends them when it first loads it.
func sends_from_demo() -> bool:
	return store_app_id() != 0 and _steam != null and int(_steam.call("getAppID")) == store_app_id()


## Opens the full game's store page to wishlist it: in the Steam client when it runs, else in the browser.
func wishlist() -> void:
	var id := store_app_id()
	if id == 0:
		return
	OS.shell_open(("steam://store/%d" % id) if _steam else ("https://store.steampowered.com/app/%d/" % id))


func unlock(id: String) -> void:
	if Game.is_demo() and not sends_from_demo():
		return
	if _steam and may_send():
		_steam.call("setAchievement", id)
		_steam.call("storeStats")


## Sends every achievement in the save to Steam.
func sync() -> void:
	for id in Game.state.get("achievements", []):
		unlock(str(id))
