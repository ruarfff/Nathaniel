@tool
class_name EncounterParameters
extends Resource
## Optional encounter-specific balance. -1 uses the shared gameplay default.

@export_range(-1, 99999) var max_hp: int = -1
@export_range(-1, 99999) var hp: int = -1
@export_range(-1, 2000) var speed: float = -1.0
@export_range(-1, 5000) var attack_range: float = -1.0
@export_range(-1, 5000) var vision: float = -1.0
@export_range(-1, 99999) var damage: int = -1
@export_range(-1, 120) var attack_delay: float = -1.0
@export_range(-1, 5000) var shot_speed: float = -1.0


func data() -> Dictionary:
	var result: Dictionary = {}
	var values: Dictionary = {
		"max_hp": max_hp,
		"hp": hp,
		"speed": speed,
		"range": attack_range,
		"vision": vision,
		"damage": damage,
		"delay": attack_delay,
		"shot_speed": shot_speed,
	}
	for key: String in values:
		if float(values[key]) >= 0.0:
			result[key] = values[key]
	return result
