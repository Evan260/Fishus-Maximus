extends Node
## Every balance number and every list of things in the game, read from game/data.

var balance := {}
var fish := {}
var places := {}
var bait := {}
var gear := {}
var boats := {}
var clients := {}
var townsfolk := {}
var chapters: Array = []
var ponds := {}
var garum := {}
var weather := {}
var achievements: Array = []
var guide := {}


func _ready() -> void:
	reload()


func reload() -> void:
	balance = _read("balance.json", {})
	fish = _by_id(_read("fish.json", []))
	places = _by_id(_read("places.json", []))
	bait = _by_id(_read("bait.json", []))
	gear = _by_id(_read("gear.json", []))
	boats = _by_id(_read("boats.json", []))
	clients = _by_id(_read("clients.json", []))
	townsfolk = _by_id(_read("townsfolk.json", []))
	chapters = _read("chapters.json", [])
	ponds = _read("ponds.json", {})
	garum = _read("garum.json", {})
	weather = _read("weather.json", {})
	achievements = _read("achievements.json", [])
	guide = _read("guide.json", {})


## A balance number by its dotted path, such as "time.day_minutes".
func num(path: String, fallback: float = 0.0) -> float:
	var v = value(path, fallback)
	return float(v) if (v is float or v is int) else fallback


func value(path: String, fallback = null):
	var node = balance
	for part in path.split("."):
		if node is Dictionary and node.has(part):
			node = node[part]
		else:
			return fallback
	return node


func _read(file: String, fallback):
	var path := "res://data/" + file
	if not FileAccess.file_exists(path):
		return fallback
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("could not read %s: %s at line %d" % [path, json.get_error_message(), json.get_error_line()])
		return fallback
	return json.data


func _by_id(list) -> Dictionary:
	var out := {}
	if list is Array:
		for item in list:
			out[str(item["id"])] = item
	return out


## A thing's name in the player's language: a fish, bait, gear, boat, place or anything else with a "name".
func name_of(entry: Dictionary) -> String:
	return tr(str(entry.get("name", "")))


## A thing's name as it reads inside a sentence, in the player's language: "red mullet", "the rocky shore", and
## "John Dory" as it is, from its "lower" field where lower-casing the first letter would be wrong.
func lower_of(entry: Dictionary) -> String:
	return tr(lower_key(entry))


## The English row for a name inside a sentence, as the strings sheet keeps it.
static func lower_key(entry: Dictionary) -> String:
	if entry.has("lower"):
		return str(entry["lower"])
	var n := str(entry.get("name", ""))
	return n.substr(0, 1).to_lower() + n.substr(1)


func fish_name(id: String) -> String:
	return name_of(fish.get(id, {"name": id}))


func fish_lower(id: String) -> String:
	return lower_of(fish.get(id, {"name": id}))
