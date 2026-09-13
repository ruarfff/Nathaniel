@tool
class_name SpawnMarker
extends Marker2D
## Move this marker in the 2D editor. Its position is projected presentation space.
## Gameplay reads the inverse projection, preserving original Swift coordinates.

@export_enum("nathaniel", "hermes", "grunt", "soldier", "boss", "spawner", "gunTower", "laserTower", "healTower", "objective") var kind: String = "soldier":
	set(value):
		kind = value
		queue_redraw()
@export var label: String = "":
	set(value):
		label = value
		queue_redraw()
@export var enabled: bool = true:
	set(value):
		enabled = value
		queue_redraw()

## Leave empty to preserve shared gameplay balance.
@export var parameters: EncounterParameters


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
