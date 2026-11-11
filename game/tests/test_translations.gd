extends "res://tests/test_case.gd"
## The translations: every string the game shows is in the strings sheet, every language has every string with the
## English placeholders, every language is offered and drawn in a font that has its letters, and words built from the
## save read in whatever language is chosen.

const SHEET := "res://translations/strings.csv"


## The strings sheet as {english: {locale: text}}, or empty in an exported game, which keeps only the translations.
func _sheet() -> Dictionary:
	if not FileAccess.file_exists(SHEET):
		return {}
	var f := FileAccess.open(SHEET, FileAccess.READ)
	var header := f.get_csv_line()
	var rows := {}
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() < header.size():
			continue
		var row := {}
		for i in range(1, header.size()):
			row[header[i]] = line[i]
		rows[line[0]] = row
	return rows


## The format codes in a string, sorted: %s, %d, %.1f and %% as Godot reads them, and {name} parts.
func _placeholders(s: String) -> Array:
	var out := []
	var i := 0
	while i < s.length():
		var c := s[i]
		if c == "%":
			var j := i + 1
			while j < s.length() and s[j] in "-0123456789.":
				j += 1
			if j < s.length() and s[j] in "sdifxXcv%":
				out.append(s.substr(i, j - i + 1))
				i = j + 1
				continue
		elif c == "{":
			var close := s.find("}", i)
			if close > i and s.substr(i + 1, close - i - 1).is_valid_ascii_identifier():
				out.append(s.substr(i, close - i + 1))
				i = close + 1
				continue
		i += 1
	out.sort()
	return out


## Every string literal passed to tr(), TranslationServer.translate() or say() in the game's scripts, by where it is.
func _keys_in_scripts() -> Dictionary:
	var found := {}
	var dirs := ["res://scripts"]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			dirs.append(dir.path_join(sub))
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd") or file == "dev.gd":
				continue
			var text := FileAccess.get_file_as_string(dir.path_join(file))
			for call in ["tr(\"", "translate(\"", "say(\""]:
				var at := text.find(call)
				while at >= 0:
					if call != "tr(\"" or at == 0 or not text[at - 1].is_valid_identifier():
						var key := _literal(text, at + call.length())
						# A piece of punctuation put together in code, such as "+ ", needs no row.
						if key.strip_edges() != "" and (key.to_lower() != key.to_upper() or key.contains("%") or key.contains("{")):
							found[key] = "%s/%s" % [dir, file]
					at = text.find(call, at + 1)
	return found


## The string literal that starts at `from`, just after its opening quote, with its escapes undone.
func _literal(text: String, from: int) -> String:
	var out := ""
	var i := from
	while i < text.length() and text[i] != "\"":
		if text[i] == "\\" and i + 1 < text.length():
			i += 1
			out += {"n": "\n", "t": "\t"}.get(text[i], text[i])
		else:
			out += text[i]
		i += 1
	return out


## Everything the game shows from its data and its own tables, as the English rows it looks them up by.
func _built() -> Array:
	var built := []
	for table in [Data.fish, Data.bait, Data.places, Data.boats]:
		for id in table:
			built += [str(table[id]["name"]), Data.lower_key(table[id])]
	for id in Data.fish:
		var f: Dictionary = Data.fish[id]
		if f.has("short"):
			built.append(str(f["short"]))
		if f.has("clue"):
			built.append(str(f["clue"]))
	for id in Data.places:
		built.append(str(Data.places[id]["where"]))
	for id in Data.boats:
		built.append(str(Data.boats[id]["text"]))
	for id in Data.bait:
		built.append(str(Data.bait[id]["text"]))
	for id in Data.gear:
		built.append(str(Data.gear[id]["name"]))
		if Data.gear[id]["kind"] == "finery":
			built.append(Data.lower_key(Data.gear[id]))
	for g in Data.garum["grades"]:
		built += [str(g["name"]), Data.lower_key(g)]
	for f in Data.ponds["features"]:
		built += [str(f["name"]), str(f["text"])]
	for c in Data.chapters:
		built += [str(c["name"]), str(c["text"])]
	for a in Data.achievements:
		built += [str(a["name"]), str(a["text"])]
	for id in Data.clients:
		var c: Dictionary = Data.clients[id]
		built += [str(c["name"]), str(c["title"])]
		for s in c["steps"]:
			built += [str(s["text"]), str(s["thanks"])]
	for id in Data.townsfolk:
		built += Array(Data.townsfolk[id]["lines"]).map(func(l): return str(l))
	for s in Data.guide["steps"]:
		built.append(str(s["text"]))
		if s.has("praise"):
			built.append(str(s["praise"]))
	built.append(str(Data.guide["farewell"]))
	for id in Helpers.HELP:
		built += [str(Helpers.HELP[id]["name"]), str(Helpers.HELP[id]["text"])]
	for b in Dogs.NAMES:
		built.append(str(Dogs.NAMES[b]))
		built += Dogs.coats(b).values()
	for a in Controls.ACTIONS:
		built.append(str(Controls.ACTIONS[a]["name"]))
	for g in Catalog.GRADES:
		built.append(str(g[1]))
	built += Array(Clock.SEASONS)
	for season in Data.weather:
		built += Data.weather[season].keys()
	built += Hud.METHOD_TIPS.values() + SettingsPanel.TABS + SettingsPanel.UI_SIZES.values() + LogbookPanel.SHORT.values()
	built += load("res://scripts/town/town_screen.gd").BUILDINGS.values()
	return built


func test_every_string_in_the_code_is_in_the_sheet() -> void:
	var sheet := _sheet()
	if sheet.is_empty():
		return
	var missing := []
	var keys := _keys_in_scripts()
	for key in keys:
		if not sheet.has(key):
			missing.append("%s (%s)" % [key, keys[key]])
	for key in _built():
		if not sheet.has(key):
			missing.append(key)
	check(missing.is_empty(), "every string the game shows is in the strings sheet (missing %s)" % ", ".join(missing.slice(0, 8)))


func test_every_language_has_every_string() -> void:
	var sheet := _sheet()
	if sheet.is_empty():
		return
	var gaps := {}
	for key in sheet:
		for loc in sheet[key]:
			if str(sheet[key][loc]).strip_edges() == "":
				gaps[loc] = int(gaps.get(loc, 0)) + 1
	check(gaps.is_empty(), "every language has every string (missing %s)" % str(gaps))
	check((sheet.values()[0] as Dictionary).size() == 14, "the sheet has all 14 languages")


func test_translations_keep_their_placeholders() -> void:
	var sheet := _sheet()
	var wrong := []
	for key in sheet:
		var want := _placeholders(key)
		for loc in sheet[key]:
			if _placeholders(str(sheet[key][loc])) != want:
				wrong.append("%s in %s" % [key, loc])
	check(wrong.is_empty(), "every translation keeps the English placeholders (%d wrong: %s)" % [wrong.size(), ", ".join(wrong.slice(0, 6))])


func test_every_language_is_offered() -> void:
	var have := TranslationServer.get_loaded_locales()
	check(SettingsPanel.NATIVE_NAMES.size() == 14, "the settings name all 14 languages")
	for loc in SettingsPanel.NATIVE_NAMES:
		check(loc in have, "%s is loaded and offered in the settings" % loc)


func test_fonts_have_every_letter() -> void:
	var sheet := _sheet()
	var missing := {}
	for key in sheet:
		for loc in sheet[key]:
			var font := UiTheme.body_font(loc)
			for c in str(sheet[key][loc]):
				if c != "\n" and c != " " and not font.has_char(c.unicode_at(0)):
					missing[loc] = str(missing.get(loc, "")) + c
	for loc in SettingsPanel.NATIVE_NAMES:
		for c in str(SettingsPanel.NATIVE_NAMES[loc]):
			if c != " " and not UiTheme.body_font(loc).has_char(c.unicode_at(0)):
				missing[loc] = str(missing.get(loc, "")) + c
	check(missing.is_empty(), "every language's font draws all its letters (missing %s)" % str(missing))
	for loc in UiTheme.SILKSCREEN:
		var heading := UiTheme.title_font(loc)
		var letters := ""
		for key in sheet:
			if sheet[key].has(loc):
				letters += str(sheet[key][loc]).to_upper()
		var lacking := ""
		for c in letters:
			var u := c.unicode_at(0)
			if c != " " and c != "\n" and not heading.has_char(u) and not UiTheme.body_font(loc).has_char(u) and not lacking.contains(c):
				lacking += c
		check(lacking == "", "%s headings draw every capital, in Silkscreen or the text font (missing %s)" % [loc, lacking])


func test_the_game_name_is_silkscreen_in_every_language() -> void:
	for loc in SettingsPanel.NATIVE_NAMES:
		TranslationServer.set_locale(loc)
		UiTheme.use_language()
		check(UiTheme.name_font().has_char("F".unicode_at(0)) and UiTheme.name_font() != UiTheme.body_font(), "the game's name keeps Silkscreen in %s" % loc)
	TranslationServer.set_locale("en")
	UiTheme.use_language()


func test_shown_words_follow_the_language() -> void:
	Game.new_game("Words", "hound")
	var kept := Ui.say("%s, %s, salted", [Data.fish["mullet"]["name"], "1 kg"])
	var english := Ui.text(kept)
	var coins := Ui.coins_text(2)
	var catch := Ui.fish_text({"fish": "bream", "pounds": 2.0, "fresh": 0.8})
	var guide := Controls.fill(TranslationServer.translate(str(Data.guide["steps"][1]["text"])))
	check(english == "Red mullet, 1 kg, salted" and coins == "2 denarii", "kept words read in English (%s, %s)" % [english, coins])
	TranslationServer.set_locale("de")
	var german := Ui.text(kept)
	check(german != english and german.begins_with(Data.fish_name("mullet")) and not german.contains("%"), "the same words read in German once German is chosen (%s)" % german)
	check(Ui.coins_text(2) != coins and Ui.coins_text(2).begins_with("2"), "money is counted in German too (%s)" % Ui.coins_text(2))
	check(Ui.fish_text({"fish": "bream", "pounds": 2.0, "fresh": 0.8}) != catch, "a fish in the hold reads in German (%s)" % Ui.fish_text({"fish": "bream", "pounds": 2.0, "fresh": 0.8}))
	var german_guide := Controls.fill(TranslationServer.translate(str(Data.guide["steps"][1]["text"])))
	check(german_guide != guide and german_guide.contains(Controls.key_name("cast")) and not german_guide.contains("{"), "old Rufus's lesson reads in German and names the casting key (%s)" % german_guide)
	TranslationServer.set_locale("ja")
	check(Ui.text(kept).begins_with(Data.fish_name("mullet")) and Data.fish_name("mullet") != "Red mullet", "and in Japanese (%s)" % Ui.text(kept))
	TranslationServer.set_locale("en")
	check(Ui.text(kept) == english and guide.contains(Controls.key_name("cast")) and not guide.contains("{"), "and in English again, the lesson naming the casting key (%s)" % guide)


func test_a_language_change_is_kept_and_rebuilds_the_screen() -> void:
	var was: String = Settings.language
	Settings.language = "fr"
	var cfg := ConfigFile.new()
	Settings.write_to(cfg)
	check(cfg.get_value("play", "language", "") == "fr", "the chosen language is kept in settings.cfg")
	var back := ConfigFile.new()
	back.set_value("play", "language", "ru")
	Settings.read_from(back)
	check(Settings.language == "ru", "and read back from it")
	Settings.language = was
	check(Settings.system_language() in TranslationServer.get_loaded_locales(), "the computer's language, or English, is always one the game has")
	check(Nav.has_method("reopen"), "a change of language builds the screen again")
