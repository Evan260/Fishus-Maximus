extends "res://tests/test_case.gd"
## The settings for the player's own music and for the tips.


func _clear() -> void:
	for c in Nav.ui.get_children():
		c.free()


## A folder of its own under the system's temporary files, so no test touches the player's own music.
func _temp_folder() -> String:
	var folder := OS.get_temp_dir().path_join("fishus_music_test_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	return folder


func test_music_put_in_the_folder_is_found_and_played() -> void:
	var folder := _temp_folder()
	check(Audio.player_tracks(folder).is_empty(), "an empty folder has no music")
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 8000
	wav.data = PackedByteArray()
	wav.data.resize(1600)
	wav.save_to_wav(folder.path_join("song.wav"))
	var notes := FileAccess.open(folder.path_join("notes.txt"), FileAccess.WRITE)
	notes.store_string("not music")
	notes.close()
	var found := Audio.player_tracks(folder)
	check(found.size() == 1 and str(found[0]).ends_with("song.wav"), "a song in it is found and other files are not, %s" % [found])
	check(Audio.load_external(str(found[0])) is AudioStreamWAV, "and it can be played")
	check(Audio.load_external(folder.path_join("notes.txt")) == null, "a file that is not music is skipped")
	check(Audio.player_tracks(folder.path_join("missing")).is_empty(), "and a folder not yet made has none")
	for f in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(f))
	DirAccess.remove_absolute(folder)


func test_the_settings_open_the_music_folder() -> void:
	_clear()
	SettingsPanel.open()
	var row: Node = Nav.ui.find_child("OwnMusic", true, false)
	check(row != null, "the settings have a row for your own music")
	var b: Button = row.find_children("*", "Button", true, false)[0] if row else null
	check(b != null and b.text == "Open folder", "with a button to open its folder")
	check(Audio.PLAYER_MUSIC.begins_with("user://"), "which is kept beside the saves")
	_clear()


func test_the_tips_can_be_turned_off_and_on() -> void:
	var was: bool = Settings.tooltips
	var fresh: Node = load("res://scripts/autoload/settings.gd").new()
	check(fresh.tooltips, "tips are on for a new player")
	var cfg := ConfigFile.new()
	fresh.tooltips = false
	fresh.write_to(cfg)
	var again: Node = load("res://scripts/autoload/settings.gd").new()
	again.read_from(cfg)
	check(not again.tooltips, "turning them off is kept")
	fresh.free()
	again.free()
	_clear()
	SettingsPanel.open()
	var box: CheckBox = Nav.ui.find_children("*", "CheckBox", true, false).filter(func(c): return c.text.begins_with("Tips"))[0]
	check(box.button_pressed == Settings.tooltips, "the settings show whether tips are on")
	box.button_pressed = false
	check(not Settings.tooltips, "and turn them off")
	_clear()
	for on in [false, true]:
		Settings.tooltips = on
		var owner := Ui.button(Nav.ui, "Tip", func(): pass)
		var tip := PopupPanel.new()
		tip.theme_type_variation = "TooltipPanel"
		owner.add_child(tip)
		tip.size = Vector2i(40, 20)
		tip.show()
		Nav.fit_tip(tip)
		check(tip.visible == on, "a tip shows only while tips are on (%s)" % on)
		owner.free()
	Settings.tooltips = was
