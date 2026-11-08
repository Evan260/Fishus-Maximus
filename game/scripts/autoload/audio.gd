extends Node
## Every sound in the game: effects found by file name in assets/audio/sfx, where name_1, name_2 are takes of one
## sound picked at random; looping ambience for the scene and the hour; and calm music with long quiet gaps between.

const SFX := "res://assets/audio/sfx/"
const AMBIENCE := "res://assets/audio/ambience/"
const MUSIC := "res://assets/audio/music/"

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _loops := {}
var _music: AudioStreamPlayer
var _tracks: Array = []
var _gap := 8.0
var _next := 0
## The ambience each loop should be at, from 0 to 1, set by the scene showing.
var wanted := {}


func _ready() -> void:
	# Scripted runs for tests, screenshots and bots play nothing at all.
	if Dev.has("run-tests") or Dev.has("shot") or Dev.has("burst") or Dev.has("flow") or Dev.has("pacing") or Dev.has("quit"):
		AudioServer.set_bus_mute(0, true)
	if AudioServer.get_bus_index("Ambience") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Ambience")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
		Settings.apply()
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Effects"
		add_child(p)
		_players.append(p)
	for file in _list(SFX):
		var name := file.get_basename()
		var parts := name.rsplit("_", true, 1)
		var key := parts[0] if parts.size() == 2 and parts[1].is_valid_int() else name
		if not _sounds.has(key):
			_sounds[key] = []
		_sounds[key].append(load(SFX + file))
	for file in _list(AMBIENCE):
		var p := AudioStreamPlayer.new()
		p.bus = "Ambience"
		p.stream = load(AMBIENCE + file)
		if p.stream is AudioStreamOggVorbis:
			p.stream.loop = true
		p.volume_db = -60.0
		add_child(p)
		_loops[file.get_basename()] = p
	_tracks = _list(MUSIC).map(func(f): return load(MUSIC + f))
	_tracks.shuffle()
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.finished.connect(func(): _gap = randf_range(90.0, 240.0))
	add_child(_music)


func _list(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in ResourceLoader.list_directory(dir):
		if f.ends_with(".ogg") or f.ends_with(".wav") or f.ends_with(".mp3"):
			out.append(f)
	return out


func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if Dev.has("run-tests") or not _sounds.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sounds[name][randi() % _sounds[name].size()]
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.play()


## Sets the scene's ambience: each named loop fades towards its level, and loops not named fade out.
func set_ambience(levels: Dictionary) -> void:
	wanted = levels


func _process(delta: float) -> void:
	for name in _loops:
		var p: AudioStreamPlayer = _loops[name]
		var level: float = wanted.get(name, 0.0)
		var target := linear_to_db(maxf(level, 0.001))
		p.volume_db = move_toward(p.volume_db, target, delta * 20.0)
		if level > 0.0 and not p.playing:
			p.play()
		elif level <= 0.0 and p.playing and p.volume_db <= -59.0:
			p.stop()
	if not _music.playing and not _tracks.is_empty():
		_gap -= delta
		if _gap <= 0.0:
			_music.stream = _tracks[randi() % _tracks.size()]
			_music.play()
