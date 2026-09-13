class_name GameAudio
extends Node

var music: AudioStreamPlayer
var requested_track := "menuMusic"
var music_enabled := false
var sound_enabled := false
var streams: Dictionary = {}


func _ready() -> void:
	music = AudioStreamPlayer.new()
	music.volume_db = -5
	add_child(music)
	music.finished.connect(func() -> void: music.play())


func apply_settings(settings: GameSettingsStore) -> void:
	music_enabled = settings.music_enabled
	sound_enabled = settings.sound_effects_enabled
	if music_enabled:
		play_music(requested_track)
	else:
		music.stream_paused = true


func play_music(track: String) -> void:
	var changed := requested_track != track or music.stream == null
	requested_track = track
	if changed:
		music.stream = load("res://assets/Audio/Music/%s.mp3" % track)
	if music_enabled:
		music.stream_paused = false
		if changed or not music.playing:
			music.play()


func play_effect(name: String) -> void:
	if not sound_enabled:
		return
	var path := "res://assets/Audio/SFX/%s.wav" % name
	if not ResourceLoader.exists(path):
		return
	if not streams.has(path):
		streams[path] = load(path)
	var player := AudioStreamPlayer.new()
	player.stream = streams[path]
	player.volume_db = -12
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
