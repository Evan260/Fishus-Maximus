extends "res://tests/test_case.gd"
## What the game tells Steam: the rich presence friends see, sent only when it changes and only while Steam runs.

const PRESENCE_FILE := "res://../tools/steam/rich_presence.vdf"
const LANGUAGES := ["english", "french", "german", "spanish", "italian", "brazilian", "polish", "turkish", "russian",
	"ukrainian", "japanese", "koreana", "schinese", "tchinese"]


## Stands in for GodotSteam, counting what it is handed.
class FakeSteam:
	extends RefCounted
	var calls := []

	func setRichPresence(key: String, value: String) -> bool:
		calls.append([key, value])
		return true

	func run_callbacks() -> void:
		pass


## Each language's tokens in the rich presence file.
func _tokens() -> Dictionary:
	var text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(PRESENCE_FILE))
	var out := {}
	var lang := ""
	for line in text.split("\n"):
		var parts := line.strip_edges().split("\"", false)
		if parts.size() == 1 and parts[0] in LANGUAGES:
			lang = parts[0]
			out[lang] = {}
		elif lang != "" and parts.size() >= 3 and parts[0].begins_with("#"):
			out[lang][parts[0]] = parts[2]
	return out


func test_every_presence_has_its_tokens_in_every_language() -> void:
	var tokens := _tokens()
	check(tokens.keys().size() == LANGUAGES.size(), "the file has all 14 languages: %s" % [tokens.keys()])
	var state := {"place": "harbour", "time": 0.0}
	var shown := []
	for screen in ["title", "town", "shore", "map"]:
		shown.append(Awards.presence_for(screen, state))
	for place in Data.places:
		for t in [0.5, 8.0, 18.5, 22.0]:
			state = {"place": place, "time": t}
			shown.append(Awards.presence_for("coast", state))
	for lang in tokens:
		for p in shown:
			check(tokens[lang].has(p["steam_display"]), "%s has %s" % [lang, p["steam_display"]])
			if p.has("when"):
				check(tokens[lang].has("#When_" + p["when"]), "%s has #When_%s" % [lang, p["when"]])
		for key in tokens[lang]:
			check(tokens[lang][key].strip_edges() != "", "%s %s is written" % [lang, key])
	check(Awards.presence_for("coast", {}) == {"steam_display": "#Title"}, "before a game is loaded it shows the title")


func test_the_parts_of_the_day() -> void:
	var seen := {}
	for k in 100:
		seen[Clock.part_of_day(Clock.minutes_per_day() * k / 100.0)] = true
	check(seen.keys().size() == 4 and seen.has("dawn") and seen.has("day") and seen.has("dusk") and seen.has("night"),
		"a day has a dawn, a day, a dusk and a night: %s" % [seen.keys()])
	check(Clock.part_of_day(Clock.at_hour(0.0, 12.0)) == "day" and Clock.part_of_day(Clock.at_hour(0.0, 23.0)) == "night",
		"noon is day and eleven at night is night")


func test_presence_is_sent_only_on_a_change_and_only_with_steam() -> void:
	var before: Object = Awards._steam
	var kept: Dictionary = Awards._presence
	Awards._steam = null
	Awards.show_presence({"steam_display": "#Town"})
	check(Awards._presence == kept, "without Steam nothing is sent or remembered")
	var fake := FakeSteam.new()
	Awards._steam = fake
	Awards._presence = {}
	var p := {"steam_display": "#Fishing_capri", "when": "dusk"}
	Awards.show_presence(p)
	check(fake.calls == [["when", "dusk"], ["steam_display", "#Fishing_capri"]], "the value goes before the token: %s" % [fake.calls])
	Awards.show_presence(p.duplicate())
	check(fake.calls.size() == 2, "the same presence again sends nothing")
	Awards.show_presence({"steam_display": "#Town"})
	check(fake.calls.size() == 3 and fake.calls[2] == ["steam_display", "#Town"], "a change is sent")
	Awards._steam = before
	Awards._presence = kept
