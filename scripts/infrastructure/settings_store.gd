class_name GameSettingsStore
extends RefCounted

const AtomicJSON = preload("res://scripts/infrastructure/atomic_json.gd")
var path: String
var sound_effects_enabled: bool = false
var music_enabled: bool = false
var fog_enabled: bool = true


func _init(file_path: String = "user://settings.json") -> void:
	path = file_path
	var result := AtomicJSON.read_file(path)
	if result.success:
		var data: Dictionary = result.data
		if data.get("sound_effects_enabled") is bool:
			sound_effects_enabled = data.sound_effects_enabled
		if data.get("music_enabled") is bool:
			music_enabled = data.music_enabled
		if data.get("fog_enabled") is bool:
			fog_enabled = data.fog_enabled


func save() -> Dictionary:
	return AtomicJSON.write_file(path, {"version": 1, "sound_effects_enabled": sound_effects_enabled, "music_enabled": music_enabled, "fog_enabled": fog_enabled})
