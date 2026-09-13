class_name GameProgressStore
extends RefCounted
## Campaign progress is independent of the three resumable gameplay slots.

const AtomicJSON = preload("res://scripts/infrastructure/atomic_json.gd")
var path: String
var data: Dictionary = {"highest_level_completed": 0, "highest_score": 0, "best_completion_time": null, "level_high_scores": {}, "level_best_times": {}}


func _init(file_path: String = "user://progress.json") -> void:
	path = file_path
	var result := AtomicJSON.read_file(path)
	if result.success and _valid(result.data):
		data = result.data


func record_completion(level: int, score: int, elapsed: float) -> Dictionary:
	if level < 0 or level > 5 or score < 0 or not is_finite(elapsed) or elapsed < 0:
		return AtomicJSON.failure("Invalid level completion")
	var updated := data.duplicate(true)
	updated.highest_level_completed = maxi(int(updated.highest_level_completed), level)
	var key := str(level)
	updated.level_high_scores[key] = maxi(int(updated.level_high_scores.get(key, score)), score)
	updated.level_best_times[key] = minf(float(updated.level_best_times.get(key, elapsed)), elapsed)
	var total_score: int = 0
	var total_time: float = 0.0
	for value: Variant in updated.level_high_scores.values():
		total_score += int(value)
	for value: Variant in updated.level_best_times.values():
		total_time += float(value)
	updated.highest_score = maxi(int(updated.highest_score), total_score)
	if int(updated.highest_level_completed) >= 5:
		updated.best_completion_time = minf(float(updated.best_completion_time), total_time) if updated.best_completion_time != null else total_time
	var result := AtomicJSON.write_file(path, updated)
	if result.success:
		data = updated
	return result


func continue_level() -> int:
	return mini(int(data.highest_level_completed) + 1, 5)


func is_level_completed(level: int) -> bool:
	return int(data.highest_level_completed) >= level


static func _valid(value: Dictionary) -> bool:
	if not AtomicJSON.is_number(value.get("highest_level_completed")) or value.highest_level_completed < 0 or value.highest_level_completed > 5 or not AtomicJSON.is_number(value.get("highest_score")):
		return false
	if not value.get("level_high_scores") is Dictionary or not value.get("level_best_times") is Dictionary:
		return false
	for field: String in ["level_high_scores", "level_best_times"]:
		for key: String in value[field]:
			if not key.is_valid_int() or int(key) < 0 or int(key) > 5 or not AtomicJSON.is_number(value[field][key]) or value[field][key] < 0:
				return false
	return value.get("best_completion_time") == null or (AtomicJSON.is_number(value.best_completion_time) and value.best_completion_time >= 0)
