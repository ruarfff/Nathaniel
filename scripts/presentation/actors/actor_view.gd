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

var _health: float = 1.0
var _selected: bool = false
var _last_position: Vector2 = Vector2.INF
var _facing: int = 0
var _logical_facing: int = 0
var _aim_direction: Vector2 = Vector2.RIGHT
var _movement_direction: Vector2 = Vector2.RIGHT
var _movement_speed: float = 0.0
var _equipped_weapon_id: String = ""
var _animation_time: float = 0.0
var _moving: bool = false
var _firing: bool = false
var _attack_active: bool = false
var _playback_enabled: bool = true
var animation_sprite: AnimatedSprite2D
var model_view: ActorModelView
@onready var sprite: Sprite2D = $Sprite2D
@onready var healing_pulse: HealingTowerPulse = get_node_or_null("HealingPulse")


func _ready() -> void:
	_update_sprite(0, false, 0.0)


func apply_state(entity: Dictionary, selected: bool = false, playback_enabled: bool = true) -> void:
	_playback_enabled = playback_enabled
	if healing_pulse != null:
		healing_pulse.playback_enabled = playback_enabled
	var logical: Vector2 = entity.get("position", Vector2.ZERO)
	var projected: Vector2 = IsoProjection.project(logical)
	if not _last_position.is_finite() and entity.get("facing") is Vector2 and not entity.facing.is_zero_approx():
		_movement_direction = entity.facing.normalized()
	if _last_position.is_finite():
		var direction: Vector2 = projected - _last_position
		_moving = direction.length_squared() > 0.005
		if _moving:
			_facing = _screen_direction(direction)
			_logical_facing = _world_direction(IsoProjection.unproject(direction))
			_aim_direction = IsoProjection.unproject(direction).normalized()
			_movement_direction = _aim_direction
			_movement_speed = IsoProjection.unproject(direction).length() / maxf(0.001, get_physics_process_delta_time())
	if entity.has("moving"):
		_moving = bool(entity.moving)
	if not _moving:
		_movement_speed = 0.0
	elif _movement_speed <= 0.0:
		_movement_speed = float(entity.get("speed", 70.0))
	if entity.get("facing") is Vector2 and not entity.facing.is_zero_approx():
		_facing = _screen_direction(IsoProjection.project(entity.facing))
		_logical_facing = _world_direction(entity.facing)
		_aim_direction = entity.facing.normalized()
	if entity.get("aim_direction") is Vector2 and not entity.aim_direction.is_zero_approx():
		_aim_direction = entity.aim_direction.normalized()
		_facing = _screen_direction(IsoProjection.project(_aim_direction))
		_logical_facing = _world_direction(_aim_direction)
	if entity.has("equipped_weapon_id"):
		_equipped_weapon_id = str(entity.equipped_weapon_id)
	_firing = bool(entity.get("firing", false))
	_last_position = projected
	position = projected
	var previous_health: float = _health
	_health = clampf(float(entity.get("hp", 1)) / maxf(1.0, float(entity.get("max_hp", 1))), 0.0, 1.0)
	_selected = selected
	if _playback_enabled:
		_animation_time += get_process_delta_time()
	_update_sprite(_facing, _moving, _animation_time)
	if previous_health > _health and is_inside_tree() and visual != null:
		var display: CanvasItem = animation_sprite if animation_sprite != null and animation_sprite.visible else sprite
		if model_view != null and model_view.visible:
			display = model_view.display
		display.modulate = Color("ff8585")
		create_tween().tween_property(display, "modulate", visual.tint, 0.15)
	queue_redraw()


func notify_attack(direction: Vector2 = Vector2.ZERO, weapon_id: String = "") -> void:
	if model_view != null and model_view.visible and not weapon_id.is_empty() and not model_view.weapon_id.is_empty() and weapon_id != model_view.weapon_id:
		return
	if direction.is_finite() and not direction.is_zero_approx():
		_aim_direction = direction.normalized()
		_facing = _screen_direction(IsoProjection.project(direction))
		_logical_facing = _world_direction(direction)
	if model_view != null and model_view.visible:
		model_view.fire(_aim_direction, weapon_id)
		return
	if visual == null or visual.animations == null or not visual.animations.has_animation("fire_%d" % _logical_facing):
		return
	if visual.animations.get_frame_count("fire_%d" % _logical_facing) == 0:
		return
	_attack_active = true
	if animation_sprite != null:
		animation_sprite.stop()
	_update_sprite(_facing, _moving, _animation_time)


func notify_heal() -> void:
	if healing_pulse != null:
		healing_pulse.pulse()


func sprite_contains_screen_point(screen: Vector2) -> bool:
	if not is_visible_in_tree() or not sprite.visible:
		return false
	return sprite.is_pixel_opaque(sprite.get_global_transform_with_canvas().affine_inverse() * screen)


func weapon_muzzle(direction: Vector2, weapon_id: String = "") -> Vector2:
	if model_view == null or not model_view.visible:
		return Vector2.INF
	return model_view.weapon_muzzle(direction, weapon_id) + visual.feet_offset


func notify_respawn() -> void:
	_attack_active = false
	_firing = false
	_moving = false
	_movement_speed = 0.0
	_animation_time = 0.0
	_last_position = Vector2.INF
	if model_view != null:
		model_view.reset_pose(true)
	if animation_sprite != null:
		animation_sprite.stop()
	_update_sprite(_facing, _moving, _animation_time)


func _update_sprite(facing: int, moving: bool, elapsed: float) -> void:
	if not is_node_ready():
		return
	if visual != null and visual.model_scene != null:
		if model_view == null:
			model_view = ActorModelView.new()
			model_view.name = "ActorModelView"
			add_child(model_view)
		if model_view.configure(visual.model_scene, visual.tint, visual.weapons):
			model_view.position = visual.feet_offset
			model_view.playback_enabled = _playback_enabled
			model_view.equip_weapon(_equipped_weapon_id if not _equipped_weapon_id.is_empty() else visual.default_weapon_id)
			model_view.set_aim(_aim_direction)
			model_view.set_movement(_movement_direction, _movement_speed if _moving else 0.0)
			model_view.show()
			sprite.hide()
			if animation_sprite != null:
				animation_sprite.hide()
				animation_sprite.stop()
			return
	if model_view != null:
		model_view.hide()
	if visual != null and _update_animation():
		sprite.hide()
		return
	if animation_sprite != null:
		animation_sprite.hide()
		animation_sprite.stop()
	sprite.visible = visual != null and visual.texture != null
	if not sprite.visible:
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
	_place_sprite(sprite, frame_size)
	if Engine.is_editor_hint():
		sprite.modulate = visual.tint


func _update_animation() -> bool:
	if visual.animations == null:
		return false
	var mode: String = "fire" if _attack_active or _firing else ("walk" if _moving else "idle")
	var clip: StringName = &""
	for candidate: StringName in [StringName("%s_%d" % [mode, _logical_facing]), StringName("idle_%d" % _logical_facing), &"idle_0"]:
		if visual.animations.has_animation(candidate) and visual.animations.get_frame_count(candidate) > 0:
			clip = candidate
			break
	if clip == &"":
		return false
	if animation_sprite == null:
		animation_sprite = AnimatedSprite2D.new()
		animation_sprite.name = "AnimatedSprite2D"
		animation_sprite.texture_filter = sprite.texture_filter
		animation_sprite.modulate = visual.tint
		animation_sprite.animation_finished.connect(_finish_attack)
		animation_sprite.animation_looped.connect(_finish_attack)
		animation_sprite.frame_changed.connect(_place_animation_frame)
		add_child(animation_sprite)
	var resource_changed: bool = animation_sprite.sprite_frames != visual.animations
	if resource_changed:
		animation_sprite.sprite_frames = visual.animations
	animation_sprite.speed_scale = 1.0 if _playback_enabled and not Engine.is_editor_hint() else 0.0
	animation_sprite.show()
	var stopped_at_start: bool = not animation_sprite.is_playing() and animation_sprite.frame == 0 and is_zero_approx(animation_sprite.frame_progress)
	if animation_sprite.animation != clip or stopped_at_start:
		var previous_frame: int = animation_sprite.frame
		var previous_progress: float = animation_sprite.frame_progress
		var same_action: bool = not resource_changed and animation_sprite.is_playing() and String(animation_sprite.animation).get_slice("_", 0) == String(clip).get_slice("_", 0)
		animation_sprite.play(clip)
		if same_action:
			animation_sprite.set_frame_and_progress(mini(previous_frame, visual.animations.get_frame_count(clip) - 1), previous_progress)
	_place_animation_frame()
	return true


func _finish_attack() -> void:
	if not String(animation_sprite.animation).begins_with("fire_"):
		return
	_attack_active = false
	if _firing:
		animation_sprite.stop()
	_update_sprite(_facing, _moving, _animation_time)


func _place_animation_frame() -> void:
	if visual == null or animation_sprite == null or animation_sprite.sprite_frames == null:
		return
	if not animation_sprite.sprite_frames.has_animation(animation_sprite.animation) or animation_sprite.frame >= animation_sprite.sprite_frames.get_frame_count(animation_sprite.animation):
		return
	var texture: Texture2D = animation_sprite.sprite_frames.get_frame_texture(animation_sprite.animation, animation_sprite.frame)
	if texture != null:
		_place_sprite(animation_sprite, texture.get_size())


func _place_sprite(display: Node2D, frame_size: Vector2) -> void:
	var density: float = visual.frame_pixel_density()
	if density > 0.0:
		display.scale = Vector2.ONE / density
		display.position = (frame_size / 2.0 - visual.frame_ground_anchor()) * display.scale + visual.feet_offset
	else:
		display.scale = visual.display_size / frame_size
		display.position = Vector2(0, -visual.display_size.y / 2.0) + visual.feet_offset


static func _world_direction(direction: Vector2) -> int:
	return posmod(roundi(direction.angle() / (PI / 4.0)), 8)


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
