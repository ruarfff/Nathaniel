class_name GameSaveStore
extends RefCounted
## Godot-only saves. No live Swift UserDefaults domain is accessed.

const AtomicJSON = preload("res://scripts/services/atomic_json.gd")
const LegacyImport = preload("res://scripts/services/swift_save_import.gd")
const SLOT_COUNT: int = 3
const FORMAT: String = "nathaniel-godot"
const VERSION: int = 1

var directory: String


func _init(save_directory: String = "user://saves") -> void:
	directory = save_directory


func save_slot(slot: int, state: Dictionary, display_name: String = "Saved game") -> Dictionary:
	if not _valid_slot(slot):
		return AtomicJSON.failure("Invalid slot; use 1, 2, or 3")
	var issue := validate_state(state)
	if not issue.is_empty():
		return AtomicJSON.failure(issue)
	return AtomicJSON.write_file(slot_path(slot), {
		"format": FORMAT,
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"display_name": display_name.left(100),
		"state": state,
	})


func load_slot(slot: int) -> Dictionary:
	if not _valid_slot(slot):
		return AtomicJSON.failure("Invalid slot; use 1, 2, or 3")
	var result := AtomicJSON.read_file(slot_path(slot))
	if not result.success:
		return result
	var saved: Dictionary = result.data
	if saved.get("format") != FORMAT or saved.get("version") != VERSION:
		return AtomicJSON.failure("Unsupported save format or version")
	if not saved.get("state") is Dictionary:
		return AtomicJSON.failure("Save is missing gameplay state")
	var issue := validate_state(saved.state)
	if not issue.is_empty():
		return AtomicJSON.failure(issue)
	return {"success": true, "state": saved.state, "metadata": _metadata(slot, saved)}


func list_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for slot: int in range(1, SLOT_COUNT + 1):
		var result := load_slot(slot)
		if result.success:
			slots.append(result.metadata)
		else:
			slots.append({"id": slot, "has_save": false, "error": result.error if FileAccess.file_exists(slot_path(slot)) else ""})
	return slots


func delete_slot(slot: int) -> Dictionary:
	if not _valid_slot(slot):
		return AtomicJSON.failure("Invalid slot; use 1, 2, or 3")
	if not FileAccess.file_exists(slot_path(slot)):
		return {"success": true}
	if DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(slot))) != OK:
		return AtomicJSON.failure("Cannot delete save slot")
	return {"success": true}


func import_swift_file(path: String, slot: int, level_config: Dictionary = {}) -> Dictionary:
	# An import never replaces an existing Godot slot, including an unreadable one.
	if not _valid_slot(slot):
		return AtomicJSON.failure("Invalid slot; use 1, 2, or 3")
	if FileAccess.file_exists(slot_path(slot)):
		return AtomicJSON.failure("Import requires an empty Godot save slot")
	var source := AtomicJSON.read_file(path)
	if not source.success:
		return source
	var config := level_config
	if config.is_empty() and AtomicJSON.is_integer(source.data.get("levelNumber")) and int(source.data.levelNumber) in [0, 1, 2, 3, 4, 5]:
		var level_path := "res://levels/level_%d.tscn" % int(source.data.levelNumber)
		if ResourceLoader.exists(level_path):
			var scene := load(level_path) as PackedScene
			var level := scene.instantiate()
			config = level.data()
			level.free()
	var converted := LegacyImport.convert(source.data, config)
	if not converted.success:
		return converted
	var written := save_slot(slot, converted.state, str(source.data.get("displayName", "Imported Swift save")))
	if not written.success:
		return written
	var result := load_slot(slot)
	result["warnings"] = converted.get("warnings", [])
	return result


func slot_path(slot: int) -> String:
	return directory.path_join("slot_%d.json" % slot)


static func validate_state(state: Dictionary) -> String:
	if not AtomicJSON.is_serializable(state):
		return "State contains an unsupported or non-finite value"
	if state.get("schema") != 1 or not state.get("level") is Dictionary:
		return "Unsupported gameplay state schema"
	var level: Dictionary = state.level
	if not AtomicJSON.is_integer(level.get("number")) or int(level.number) not in [0, 1, 2, 3, 4, 5]:
		return "Invalid level number"
	for key: String in ["width", "height", "tile_size"]:
		if not AtomicJSON.is_number(level.get(key)) or float(level[key]) <= 0:
			return "Invalid level dimensions"
	if not AtomicJSON.is_integer(level.width) or not AtomicJSON.is_integer(level.height) or float(level.width) * float(level.height) > 1048576:
		return "Invalid or oversized level grid"
	for key: String in ["player_start", "hermes_start"]:
		if level.has(key) and not AtomicJSON.is_point(level[key]):
			return "Invalid level start position"
	if not level.get("blocked", []) is Array:
		return "Invalid blocked grid cells"
	for cell: Variant in level.get("blocked", []):
		if not AtomicJSON.is_point(cell):
			return "Invalid blocked grid cell"
	for key: String in ["enemies", "towers"]:
		if not level.get(key, []) is Array:
			return "Invalid level entity list"
		for spawn: Variant in level.get(key, []):
			if not spawn is Dictionary or not spawn.get("kind") is String or not AtomicJSON.is_point(spawn.get("position")):
				return "Invalid level entity placement"
	for key: String in ["resources", "score", "lives", "elapsed_time"]:
		if not AtomicJSON.is_number(state.get(key)) or float(state[key]) < 0:
			return "Invalid gameplay counter: " + key
	for key: String in ["resources", "score", "lives"]:
		if not AtomicJSON.is_integer(state[key]):
			return "Gameplay counter must be an integer: " + key
	if state.get("result", "playing") not in ["playing", "victory", "gameOver"] or state.get("hermes_mode", "building") not in ["following", "building", "independent", "locked", "stopped"]:
		return "Invalid gameplay mode"
	for key: String in ["wave_elapsed", "wave_since_last_spawn"]:
		if state.has(key) and (not AtomicJSON.is_number(state[key]) or float(state[key]) < 0):
			return "Invalid wave timer"
	if state.has("rng_state") and (not state.rng_state is String or not state.rng_state.is_valid_int()):
		return "Invalid random generator state"
	if not state.get("entities") is Array:
		return "Missing entities"
	var ids: Dictionary = {}
	var players: Dictionary = {}
	for entity: Variant in state.entities:
		if not entity is Dictionary or not AtomicJSON.is_integer(entity.get("id")) or int(entity.id) < 1 or not AtomicJSON.is_point(entity.get("position")):
			return "Invalid entity"
		if ids.has(entity.id):
			return "Duplicate entity ID"
		ids[entity.id] = true
		if entity.get("kind") not in ["nathaniel", "hermes", "grunt", "soldier", "boss", "spawner", "gunTower", "laserTower", "healTower"]:
			return "Unknown entity kind"
		for key: String in ["hp", "max_hp"]:
			if not AtomicJSON.is_number(entity.get(key)):
				return "Invalid entity health"
		if float(entity.max_hp) <= 0 or float(entity.hp) > float(entity.max_hp):
			return "Invalid entity health range"
		if entity.get("destination") != null and not AtomicJSON.is_point(entity.destination):
			return "Invalid requested destination"
		for key: String in ["facing", "size", "follow_destination"]:
			if entity.get(key) != null and not AtomicJSON.is_point(entity[key]):
				return "Invalid entity vector: " + key
		for key: String in ["cooldown", "burst", "pending_damage", "spawn_countdown", "initial_spawns_remaining", "construction_cost", "target_id", "manual_target_id", "speed", "range", "vision", "damage", "radius", "delay", "shot_speed"]:
			if entity.has(key) and not AtomicJSON.is_number(entity[key]):
				return "Invalid entity value: " + key
		for key: String in ["owned", "active", "firing", "moving", "enemy", "tower"]:
			if entity.has(key) and not entity[key] is bool:
				return "Invalid entity flag: " + key
		if entity.kind in ["nathaniel", "hermes"]:
			if players.has(entity.kind):
				return "Duplicate player"
			players[entity.kind] = true
	if not players.has("nathaniel") or not players.has("hermes"):
		return "Save must contain Nathaniel and Hermes"
	if not state.get("corpses", []) is Array or not state.get("projectiles", []) is Array or not state.get("fog", []) is Array:
		return "Invalid battlefield state"
	for corpse: Variant in state.get("corpses", []):
		if not corpse is Dictionary or not AtomicJSON.is_point(corpse.get("position")) or not AtomicJSON.is_number(corpse.get("amount")) or not AtomicJSON.is_number(corpse.get("expiration")) or not corpse.get("carried") is bool:
			return "Invalid corpse state"
	for shot: Variant in state.get("projectiles", []):
		if not shot is Dictionary or not AtomicJSON.is_point(shot.get("position")) or not AtomicJSON.is_point(shot.get("direction")) or not shot.get("enemy") is bool:
			return "Invalid projectile state"
		for key: String in ["owner_id", "speed", "remaining", "radius", "damage"]:
			if not AtomicJSON.is_number(shot.get(key)):
				return "Invalid projectile value: " + key
	for visibility: Variant in state.get("fog", []):
		if not AtomicJSON.is_integer(visibility) or int(visibility) not in [0, 1, 2]:
			return "Invalid fog state"
	return ""


static func _valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT


static func _metadata(slot: int, saved: Dictionary) -> Dictionary:
	return {"id": slot, "has_save": true, "display_name": saved.get("display_name", "Saved game"), "saved_at": saved.get("saved_at", ""), "level_number": saved.state.level.number, "elapsed_time": saved.state.elapsed_time, "score": saved.state.score}
