extends Node
## Three save slots. Each save first moves the previous file aside as a backup, so a bad write never loses a boat.

const SLOTS := 3

var dir := "user://"
var slot := 0
## Off for scripted runs and the game with everything open, so neither ever overwrites a real game.
var enabled := true
var _autosave := 60.0


func _ready() -> void:
	if Dev.has("no-save") or Dev.has("demo") or Dev.has("max-state"):
		enabled = false


## Saves the game in play every minute, and as the window closes.
func _process(delta: float) -> void:
	_autosave -= delta
	if _autosave <= 0.0:
		_autosave = 60.0
		if slot > 0 and not Game.state.is_empty():
			save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and slot > 0 and not Game.state.is_empty():
		save()


func path_for(n: int) -> String:
	return dir.path_join("save_%d.json" % n)


func save(n: int = -1) -> bool:
	if n < 0:
		n = slot
	if n < 1 or n > SLOTS or not enabled:
		return false
	var path := path_for(n)
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak"))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	Game.state["last_real_time"] = Time.get_unix_time_from_system()
	f.store_string(JSON.stringify(Game.to_dict(), "\t"))
	f.close()
	slot = n
	return true


## Loads a slot, falling back to its backup when the main file is missing or unreadable. False if neither works.
func load_slot(n: int) -> bool:
	for path in [path_for(n), path_for(n) + ".bak"]:
		var d := _read(path)
		if not d.is_empty():
			Game.from_dict(d)
			slot = n
			return true
	return false


## The first empty slot, or 0 when all three are taken.
func free_slot() -> int:
	for n in range(1, SLOTS + 1):
		if slot_info(n).is_empty():
			return n
	return 0


func delete(n: int) -> void:
	for path in [path_for(n), path_for(n) + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## What the title shows for a slot: its name, day, chapter and dog, or an empty dictionary for a free slot.
func slot_info(n: int) -> Dictionary:
	var d := _read(path_for(n))
	if d.is_empty():
		d = _read(path_for(n) + ".bak")
	if d.is_empty():
		return {}
	return {"name": d.get("name", ""), "day": int(Clock.day_of(float(d.get("time", 0.0)))) + 1, "chapter": d.get("chapter", 1), "dog": d.get("dog", "")}


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return json.data if json.data is Dictionary and json.data.has("version") else {}
