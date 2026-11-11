extends Node
## Three save slots, saved every minute and as the window closes, as Farmus Maximus saves: each save is written to a
## temporary file and read back before it replaces anything, and the last few saves are kept as rolling backups.

const SLOTS := 3
const BACKUPS := 3
## Seconds the newest backup must have aged before the backups move along, so each really is an older copy.
const BACKUP_EVERY := 300.0

var dir := "user://"
var slot := 0
## Off for scripted runs and the game with everything open, so neither ever overwrites a real game.
var enabled := true
var _autosave := 60.0


func _ready() -> void:
	if Dev.has("no-save") or Dev.has("demo") or Dev.has("max-state"):
		enabled = false


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
	Game.state["last_real_time"] = Time.get_unix_time_from_system()
	var data := Game.to_dict()
	data["saved_at"] = Time.get_unix_time_from_system()
	# Writing to a temporary file first means a crash mid-write never leaves a half-written save.
	var tmp := path + ".tmp"
	if not _write(tmp, JSON.stringify(data, "\t")) or not _set_aside_unreadable(n):
		return false
	_rotate_backups(path)
	if not _move(tmp, path):
		return false
	slot = n
	return true


## Loads a slot from its save, or the newest backup that can be read when it cannot. False if none can.
func load_slot(n: int) -> bool:
	for path in _load_order(n):
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
	for path in _candidates(n) + [path_for(n) + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## What the title shows for a slot: its name, day, chapter, dog and kinds of fish caught, or an empty dictionary for a free slot.
func slot_info(n: int) -> Dictionary:
	for path in _load_order(n):
		var d := _read(path)
		if not d.is_empty():
			return {"name": d.get("name", ""), "day": int(Clock.day_of(float(d.get("time", 0.0)))) + 1, "chapter": d.get("chapter", 1),
				"dog": d.get("dog", ""), "fish": (d["logbook"] as Dictionary).size() if d.get("logbook") is Dictionary else 0}
	return {}


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return json.data if json.data is Dictionary and json.data.has("version") else {}


## Writes a file and reads it back, so a full disk or a failed write is caught before it can replace anything.
func _write(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Could not write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	var stored := f.store_string(text)
	f.close()
	if not stored or FileAccess.get_file_as_string(path) != text:
		push_error("Could not write %s" % path)
		return false
	return true


func _move(from: String, to: String) -> bool:
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to))
	if err != OK:
		push_error("Could not move %s to %s: %s" % [from, to, error_string(err)])
	return err == OK


## The save and its backups, newest first; the single `.bak` older games kept is read last.
func _candidates(n: int) -> Array:
	var list := [path_for(n)]
	for i in range(1, BACKUPS + 1):
		list.append("%s.bak%d" % [path_for(n), i])
	list.append(path_for(n) + ".bak")
	return list


## The files a game is read from, best first: a save cut off before its .tmp replaced the save leaves the newest there.
func _load_order(n: int) -> Array:
	var list := _candidates(n)
	var tmp := path_for(n) + ".tmp"
	if _saved_at(tmp) > _saved_at(path_for(n)):
		list.push_front(tmp)
	return list


## When a save was made, or -1 for a file that is missing or not whole, so a half-written .tmp never wins.
func _saved_at(path: String) -> float:
	var d := _read(path)
	return float(d.get("saved_at", 0.0)) if not d.is_empty() else -1.0


## A game none of whose files can be read is moved aside under a plain name rather than saved over, so it can be rescued.
func _set_aside_unreadable(n: int) -> bool:
	var found := _candidates(n).filter(func(path): return FileAccess.file_exists(path))
	if found.is_empty() or found.any(func(path): return not _read(path).is_empty()):
		return true
	var stamp := int(Time.get_unix_time_from_system())
	for path in found:
		if not _move(path, "%s.unreadable-%d" % [path, stamp]):
			return false
	push_error("Save %d could not be read, so its files were kept beside it as .unreadable copies" % n)
	return true


## Moves each backup one along, the save itself becoming the newest, once the newest backup has aged.
func _rotate_backups(path: String) -> void:
	var newest := path + ".bak1"
	if FileAccess.file_exists(newest) and Time.get_unix_time_from_system() - FileAccess.get_modified_time(newest) < BACKUP_EVERY:
		return
	if _read(path).is_empty():
		return
	# Renaming rather than copying leaves each older copy's contents untouched on the disk.
	for i in range(BACKUPS - 1, 0, -1):
		var older := "%s.bak%d" % [path, i]
		if FileAccess.file_exists(older) and not _move(older, "%s.bak%d" % [path, i + 1]):
			return
	_move(path, newest)
