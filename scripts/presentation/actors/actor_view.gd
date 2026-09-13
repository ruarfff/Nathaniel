@tool
class_name ActorView
extends Node2D
## A view of a logical entity. This scene never changes simulation state.

@export var kind: String = "nathaniel"
@export var visual: ActorVisual:
	set(value):
		visual = value
		if is_node_ready():
			_update_sprite(0, false, 0.0)
		queue_redraw()

var entity_id: int = -1
var _health: float = 1.0
var _selected: bool = false
var _last_position: Vector2 = Vector2.INF
var _facing: int = 0
var _animation_time: float = 0.0
var _moving: bool = false
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_update_sprite(0, false, 0.0)


func apply_state(entity: Dictionary, selected: bool = false) -> void:
	entity_id = int(entity.get("id", -1))
	var logical: Vector2 = entity.get("position", Vector2.ZERO)
	var projected: Vector2 = IsoProjection.project(logical)
	if _last_position.is_finite():
		var direction: Vector2 = projected - _last_position
		_moving = direction.length_squared() > 0.005
		if _moving:
			_facing = _screen_direction(direction)
	if entity.has("moving"):
		_moving = bool(entity.moving)
	if entity.get("facing") is Vector2 and not entity.facing.is_zero_approx():
		_facing = _screen_direction(IsoProjection.project(entity.facing))
	_last_position = projected
	position = projected
	var previous_health: float = _health
	_health = clampf(float(entity.get("hp", 1)) / maxf(1.0, float(entity.get("max_hp", 1))), 0.0, 1.0)
	_selected = selected
	_animation_time += get_process_delta_time()
	_update_sprite(_facing, _moving, _animation_time)
	if previous_health > _health and is_inside_tree():
		sprite.modulate = Color("ff8585")
		create_tween().tween_property(sprite, "modulate", visual.tint, 0.15)
	queue_redraw()


func _update_sprite(facing: int, moving: bool, elapsed: float) -> void:
	if visual == null or visual.texture == null or not is_node_ready():
		return
	var texture: Texture2D = visual.texture
	var columns: int = visual.columns
	var rows: int = visual.rows
	var row: int = visual.moving_row if moving else visual.idle_row
	var column: int = facing if columns > 1 else 0
	if kind == "hermes" and moving and visual.moving_texture != null:
		texture = visual.moving_texture
		columns = visual.moving_columns
		rows = 1
		column = [1, 0, 1, 4, 2, 3, 3, 4][facing]
		row = 0
	elif kind == "boss":
		if moving:
			row = int(elapsed * visual.animation_fps) % 4
		else:
			column = [0, 1, 4, 2, 7, 5, 6, 3][facing]
			row = 5
	elif kind == "grunt" and moving:
		row = 1 + int(elapsed * visual.animation_fps) % 3
	column = clampi(column, 0, columns - 1)
	row = clampi(row, 0, rows - 1)
	var frame_size: Vector2 = texture.get_size() / Vector2(columns, rows)
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2(column, row) * frame_size, frame_size)
	sprite.scale = visual.display_size / frame_size
	sprite.position = Vector2(0, -visual.display_size.y / 2.0) + visual.feet_offset
	if Engine.is_editor_hint():
		sprite.modulate = visual.tint


static func _screen_direction(direction: Vector2) -> int:
	# Original art's eight columns name screen directions. Choose after projection.
	var sector: int = posmod(roundi(direction.angle() / (PI / 4.0)), 8)
	return [6, 4, 0, 1, 3, 7, 2, 5][sector]


func _draw() -> void:
	if visual == null:
		return
	var radius: float = visual.shadow_radius
	var ellipse: PackedVector2Array = PackedVector2Array()
	for i: int in range(24):
		var angle: float = TAU * float(i) / 24.0
		ellipse.append(Vector2(cos(angle) * radius, sin(angle) * radius * 0.4))
	draw_colored_polygon(ellipse, Color(0.02, 0.03, 0.04, 0.4))
	if _selected:
		ellipse.append(ellipse[0])
		draw_polyline(ellipse, Color("f2cf72") if kind == "nathaniel" else Color("6bd7ed"), 2.5, true)
	if _health < 1.0 or _selected:
		var bar: Rect2 = Rect2(-22, -visual.display_size.y - 10, 44, 4)
		draw_rect(bar, Color("172125"))
		bar.size.x *= _health
		draw_rect(bar, visual.health_color)
