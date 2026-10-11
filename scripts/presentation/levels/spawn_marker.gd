@tool
class_name SpawnMarker
extends Marker2D
## Move this marker in the 2D editor. Its position is projected presentation space.
## Gameplay reads the inverse projection, preserving original Swift coordinates.

@export_enum("nathaniel", "hermes", "grunt", "soldier", "gunSoldier", "boss", "spawner", "gunTower", "laserTower", "healTower", "objective", "weaponPickup", "enemyEntry") var kind: String = "soldier":
	set(value):
		kind = value
		queue_redraw()
		notify_property_list_changed()
		update_configuration_warnings()
@export var label: String = "":
	set(value):
		label = value
		queue_redraw()
@export var enabled: bool = true:
	set(value):
		enabled = value
		queue_redraw()

## Enemy and tower overrides only. Leave empty to use GameBalance.
@export var parameters: EncounterParameters:
	set(value):
		parameters = value
		update_configuration_warnings()
@export_enum("rifle", "heavy_rifle") var weapon_id: String = "heavy_rifle"


func _validate_property(property: Dictionary) -> void:
	if property.name == "parameters" and kind not in GameBalance.ENEMIES and kind not in GameBalance.TOWERS:
		property.usage = int(property.usage) & ~PROPERTY_USAGE_EDITOR


func _get_configuration_warnings() -> PackedStringArray:
	if parameters != null and kind not in GameBalance.ENEMIES and kind not in GameBalance.TOWERS:
		return PackedStringArray(["Parameters apply only to enemies and towers. This marker's overrides are unused."])
	return PackedStringArray()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var tint: Color = Color("f17c72")
	if kind == "nathaniel":
		tint = Color("f2cd70")
	elif kind == "hermes":
		tint = Color("70d5ed")
	elif kind.ends_with("Tower"):
		tint = Color("92d589")
	elif kind == "objective":
		tint = Color("bd9df5")
	elif kind == "weaponPickup":
		tint = Color("f2cd70")
	if not enabled:
		tint.a = 0.3
	var outline: PackedVector2Array = PackedVector2Array([
		Vector2(-24, 0), Vector2(0, -12), Vector2(24, 0), Vector2(0, 12), Vector2(-24, 0)
	])
	draw_polyline(outline, tint, 2.0)
	draw_line(Vector2(0, -8), Vector2(0, 8), tint, 2.0)
	draw_line(Vector2(-8, 0), Vector2(8, 0), tint, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(28, 5), label if not label.is_empty() else kind,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, tint)
