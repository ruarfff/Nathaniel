class_name BlenderAssetPreview
extends Node2D
## An isolated art fixture. It creates no game state or saved data.

const VIEW_SCALE: float = 2.0
const PROP_POINTS: Array[Vector2] = [Vector2(110, 205), Vector2(320, 205), Vector2(530, 205)]
const BACK_OFFSET: Vector2 = Vector2(0, -8)
const FRONT_OFFSET: Vector2 = Vector2(0, 22)

var swapped: bool = false
@onready var scenery: Node2D = $World/Actors/Scenery
@onready var behind: ActorView = $World/Actors/Behind
@onready var in_front: ActorView = $World/Actors/InFront


func _ready() -> void:
	_update_actors()
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		swapped = not swapped
		_update_actors()
		queue_redraw()


func _update_actors() -> void:
	_set_actor(behind, PROP_POINTS[1] + (FRONT_OFFSET if swapped else BACK_OFFSET))
	_set_actor(in_front, PROP_POINTS[2] + (BACK_OFFSET if swapped else FRONT_OFFSET))


func _set_actor(actor: ActorView, projected: Vector2) -> void:
	actor.apply_state({"position": IsoProjection.unproject(projected), "hp": 1, "max_hp": 1, "moving": false}, false, false)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color("17232d"))
	_text(Vector2(48, 62), "Blender asset / Godot projection check", 28)
	_text(Vector2(48, 96), "Common 2x view zoom. Native grid: 64 x 32 px. One Blender unit: 32 logical units.", 18)
	for index: int in PROP_POINTS.size():
		var point: Vector2 = PROP_POINTS[index] * VIEW_SCALE
		var panel := Rect2(point.x - 180, 142, 360, 420)
		for row: int in 21:
			for column: int in 18:
				var shade := Color("24323e") if (row + column) % 2 == 0 else Color("2c3b48")
				draw_rect(Rect2(panel.position + Vector2(column, row) * 20.0, Vector2(20, 20)), shade)
		for axis: int in range(-2, 3):
			var coordinate: float = (float(axis) + 0.5) * 32.0
			_line(point, Vector2(coordinate, -80), Vector2(coordinate, 80), Color("5b7284"))
			_line(point, Vector2(-80, coordinate), Vector2(80, coordinate), Color("5b7284"))
		var diamond := PackedVector2Array()
		for corner: Vector2 in [Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16), Vector2(-16, -16)]:
			diamond.append(point + IsoProjection.project(corner) * VIEW_SCALE)
		draw_polyline(diamond, Color("e9bc64"), 2.0, true)
		draw_line(point + Vector2(-84, 0), point + Vector2(-70, 0), Color("e9bc64"), 2.0)
		draw_line(point + Vector2(70, 0), point + Vector2(84, 0), Color("e9bc64"), 2.0)
		var heading: String = ["Prop only", "Actor in front" if swapped else "Actor behind", "Actor behind" if swapped else "Actor in front"][index]
		_text(Vector2(panel.position.x + 16, 176), heading, 22)
		_text(Vector2(panel.position.x + 16, 538), "Base center = ground anchor", 17)
	_text(Vector2(48, 624), "Gold diamond: one ground cell. Gold side ticks: the prop origin. Checkerboard: PNG transparency.", 18)
	_text(Vector2(48, 658), "Scenery and Nathaniel share the game's nested Y sort. Press Space to swap front and behind.", 18)
	_text(Vector2(48, 710), "Artwork has no collision. Paint movement-blocking cells separately on a level's Collision layer.", 18)


func _line(point: Vector2, start: Vector2, end: Vector2, color: Color) -> void:
	draw_line(point + IsoProjection.project(start) * VIEW_SCALE, point + IsoProjection.project(end) * VIEW_SCALE, color, 1.0, true)


func _text(at: Vector2, value: String, size: int) -> void:
	draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, Color("e4edf4"))
