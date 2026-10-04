@tool
class_name ActorModelView
extends Node2D
## Projects an authored 3D weapon into the existing 2D actor and Y-sort layer.

const RECOIL_DISTANCE: float = 0.06
const RECOIL_DURATION: float = 0.16

var viewport: SubViewport
var display: Sprite2D
var model_root: Node3D
var camera: Camera3D
var aim_pivot: Node3D
var recoil: Node3D
var muzzle: Node3D
var locomotion_pivot: Node3D
var animation_player: AnimationPlayer
var weapon_id: String = ""
var playback_enabled: bool = true
var _scene: PackedScene
var _canvas: Vector2i = Vector2i(128, 128)
var _anchor: Vector2 = Vector2(64, 96)
var _max_density: float = 8.0
var _density: float = 1.0
var _aim: Vector2 = Vector2.UP
var _pivot_rest: Transform3D
var _recoil_rest: Transform3D
var _muzzle_from_pivot: Transform3D
var _recoil_elapsed: float = RECOIL_DURATION
var _dirty: bool = true
var _weapons: Array[WeaponVisual] = []
var _weapon_nodes: Dictionary = {}
var _weapon_markers: Dictionary = {}
var _weapon_hands: Node3D
var _hands_rest: Transform3D
var _recoil_distance: float = RECOIL_DISTANCE
var _recoil_duration: float = RECOIL_DURATION
var _locomotion_rest: Transform3D
var _hip_nodes: Array[Node3D] = []
var _hip_rests: Array[Transform3D] = []
var _movement: Vector2 = Vector2.RIGHT
var _speed: float = 0.0
var _walk_time: float = 0.0
var _walk_clip: StringName = &""
var _idle_clip: StringName = &""


func configure(scene: PackedScene, tint: Color, weapons: Array[WeaponVisual] = []) -> bool:
	if _scene == scene and _weapons == weapons:
		if Engine.is_editor_hint() and display != null:
			display.modulate = tint
		return display != null
	if viewport != null:
		viewport.free()
	if display != null:
		display.free()
	display = null
	_weapon_nodes.clear()
	_weapon_markers.clear()
	_hip_nodes.clear()
	_hip_rests.clear()
	_weapons = weapons.duplicate()
	weapon_id = ""
	_walk_clip = &""
	_idle_clip = &""
	_walk_time = 0.0
	_recoil_distance = RECOIL_DISTANCE
	_recoil_duration = RECOIL_DURATION
	_scene = scene
	viewport = SubViewport.new()
	viewport.name = "ModelViewport"
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	model_root = scene.instantiate() as Node3D
	_canvas = model_root.get_meta("logical_canvas", _canvas)
	_anchor = model_root.get_meta("logical_ground_anchor", _anchor)
	_max_density = float(model_root.get_meta("max_pixel_density", _max_density))
	viewport.size = _canvas
	viewport.add_child(model_root)
	camera = model_root.find_child("Camera3D", true, false) as Camera3D
	aim_pivot = model_root.find_child("AimPivot", true, false) as Node3D
	if camera == null or aim_pivot == null:
		push_error("Actor model needs Camera3D and AimPivot nodes: " + scene.resource_path)
		return false
	_pivot_rest = aim_pivot.transform
	if not _attach_weapons():
		return false
	recoil = model_root.find_child("Recoil", true, false) as Node3D
	muzzle = model_root.find_child("Muzzle", true, false) as Node3D
	if camera == null or aim_pivot == null or recoil == null or muzzle == null:
		push_error("Actor model needs Camera3D, AimPivot, Recoil and Muzzle nodes: " + scene.resource_path)
		return false
	camera.make_current()
	_recoil_rest = recoil.transform
	_muzzle_from_pivot = aim_pivot.global_transform.affine_inverse() * muzzle.global_transform
	_recoil_elapsed = _recoil_duration
	_weapon_hands = model_root.find_child("WeaponHands", true, false) as Node3D
	if _weapon_hands != null:
		_hands_rest = _weapon_hands.transform
	_setup_locomotion()
	display = Sprite2D.new()
	display.name = "ModelSprite"
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	display.modulate = tint
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	display.material = material
	add_child(display)
	_resize(1.0)
	if not _weapons.is_empty():
		equip_weapon(_weapons[0].weapon_id)
	set_aim(_aim)
	return true


func _attach_weapons() -> bool:
	if _weapons.is_empty():
		return true
	var mount: Node3D = model_root.find_child("WeaponMount", true, false) as Node3D
	if mount == null:
		push_error("Modular actor model needs a WeaponMount: " + _scene.resource_path)
		return false
	for weapon: WeaponVisual in _weapons:
		if weapon == null or weapon.model_scene == null or weapon.weapon_id.is_empty() or _weapon_nodes.has(weapon.weapon_id):
			push_error("Actor weapon resources need a model and unique weapon_id: " + _scene.resource_path)
			return false
		var node: Node3D = weapon.model_scene.instantiate() as Node3D
		mount.add_child(node)
		node.hide()
		var barrel: Node3D = node.find_child("Recoil", true, false) as Node3D
		var marker: Node3D = node.find_child("Muzzle", true, false) as Node3D
		if barrel == null or marker == null:
			push_error("Weapon model needs Recoil and Muzzle nodes: " + weapon.model_scene.resource_path)
			return false
		_weapon_nodes[weapon.weapon_id] = {"root": node, "recoil": barrel, "muzzle": marker,
			"rest": barrel.transform, "visual": weapon}
		_weapon_markers[weapon.weapon_id] = aim_pivot.global_transform.affine_inverse() * marker.global_transform
	return true


func equip_weapon(id: String) -> bool:
	if id.is_empty():
		return _weapons.is_empty()
	if not _weapon_nodes.has(id):
		return false
	if weapon_id == id:
		return true
	reset_pose()
	for key: String in _weapon_nodes:
		_weapon_nodes[key].root.visible = key == id
	var entry: Dictionary = _weapon_nodes[id]
	weapon_id = id
	recoil = entry.recoil
	muzzle = entry.muzzle
	_recoil_rest = entry.rest
	var definition: WeaponVisual = entry.visual
	_recoil_distance = definition.recoil_distance
	_recoil_duration = definition.recoil_duration
	reset_pose()
	_dirty = true
	return true


func _setup_locomotion() -> void:
	locomotion_pivot = model_root.find_child("LocomotionPivot", true, false) as Node3D
	animation_player = model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if locomotion_pivot == null or animation_player == null:
		return
	_locomotion_rest = locomotion_pivot.transform
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip: StringName in animation_player.get_animation_list():
		if String(clip).get_slice("/", String(clip).get_slice_count("/") - 1) == "walk":
			_walk_clip = clip
		elif String(clip).get_slice("/", String(clip).get_slice_count("/") - 1) == "idle":
			_idle_clip = clip
	for name: String in ["LeftHip", "RightHip"]:
		var hip: Node3D = model_root.find_child(name, true, false) as Node3D
		if hip != null:
			_hip_nodes.append(hip)
			_hip_rests.append(hip.transform)
	_update_locomotion(0.0)


func set_movement(direction: Vector2, speed: float) -> void:
	if direction.is_finite() and not direction.is_zero_approx():
		_movement = direction.normalized()
	var changed: bool = not is_equal_approx(_speed, speed)
	_speed = maxf(0.0, speed)
	if changed:
		_update_locomotion(0.0)


func set_aim(direction: Vector2) -> void:
	if direction.is_zero_approx() or not direction.is_finite() or aim_pivot == null:
		return
	var normalized: Vector2 = direction.normalized()
	var pose: Transform3D = _aim_transform(normalized)
	if not aim_pivot.transform.is_equal_approx(pose):
		aim_pivot.transform = pose
		_dirty = true
	_aim = normalized
	_update_locomotion(0.0)


func fire(direction: Vector2, fired_weapon_id: String = "") -> void:
	if not fired_weapon_id.is_empty() and not _weapons.is_empty() and fired_weapon_id != weapon_id:
		return
	set_aim(direction)
	_recoil_elapsed = 0.0
	_apply_recoil()


func reset_pose(reset_movement: bool = false) -> void:
	_recoil_elapsed = _recoil_duration
	_apply_recoil()
	if reset_movement:
		_speed = 0.0
		_walk_time = 0.0
		_update_locomotion(0.0)


func refresh_pose() -> void:
	_dirty = true


func weapon_muzzle(direction: Vector2, fired_weapon_id: String = "") -> Vector2:
	if camera == null or muzzle == null or aim_pivot == null:
		return Vector2.INF
	var heading: Vector2 = _aim if direction.is_zero_approx() else direction
	if not heading.is_finite():
		return Vector2.INF
	# Query the firing pose without moving a turret which may now track another target.
	var pivot_parent: Node3D = aim_pivot.get_parent() as Node3D
	var pose: Transform3D = pivot_parent.global_transform * _aim_transform(heading)
	var marker: Transform3D = _muzzle_from_pivot
	if not _weapons.is_empty():
		var id: String = weapon_id if fired_weapon_id.is_empty() else fired_weapon_id
		if not _weapon_markers.has(id):
			return Vector2.INF
		marker = _weapon_markers[id]
	var point: Vector3 = (pose * marker).origin
	return camera.unproject_position(point) / _density - _anchor


func _aim_transform(direction: Vector2) -> Transform3D:
	# The exported barrel points +X; logical +X is Godot -Z and logical +Y is +X.
	var yaw: float = atan2(direction.x, direction.y)
	return Transform3D(_pivot_rest.basis * Basis(Vector3.UP, yaw), _pivot_rest.origin)


func _process(delta: float) -> void:
	if display == null:
		return
	if playback_enabled and not Engine.is_editor_hint():
		if _recoil_elapsed < _recoil_duration:
			_recoil_elapsed = minf(_recoil_duration, _recoil_elapsed + delta)
			_apply_recoil()
		if _speed > 0.01:
			_update_locomotion(delta)
	if not is_visible_in_tree() or not _on_screen():
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	# Screen transforms omit stretch when subwindows are embedded. Use the
	# destination viewport's pixel transform, including output size and zoom.
	var screen: Transform2D = get_viewport().get_final_transform() * get_global_transform_with_canvas()
	var density: float = clampf(ceilf(maxf(screen.x.length(), screen.y.length())), 1.0, _max_density)
	if not is_equal_approx(_density, density):
		_resize(density)
	if _dirty:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_dirty = false
	else:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _apply_recoil() -> void:
	if recoil == null:
		return
	var kick_time: float = 0.025
	var amount: float = _recoil_elapsed / kick_time
	if _recoil_elapsed >= kick_time:
		var remaining: float = 1.0 - (_recoil_elapsed - kick_time) / maxf(0.001, _recoil_duration - kick_time)
		amount = remaining * remaining
	var displacement := Vector3(-_recoil_distance * amount, 0, 0)
	recoil.transform = _recoil_rest.translated_local(displacement)
	if _weapon_hands != null:
		_weapon_hands.transform = _hands_rest.translated(displacement)
	_dirty = true


func _update_locomotion(delta: float) -> void:
	if locomotion_pivot == null or animation_player == null or _idle_clip == &"" or _walk_clip == &"":
		return
	var aim_yaw: float = atan2(_aim.x, _aim.y)
	var travel_yaw: float = atan2(_movement.x, _movement.y)
	var body_offset: float = wrapf(travel_yaw - aim_yaw, -PI, PI)
	if absf(body_offset) > PI / 2.0:
		body_offset = wrapf(body_offset + PI, -PI, PI)
	var body_yaw: float = aim_yaw + clampf(body_offset, -PI / 3.0, PI / 3.0) if _speed > 0.01 else aim_yaw
	var body: Transform3D = Transform3D(_locomotion_rest.basis * Basis(Vector3.UP, body_yaw), _locomotion_rest.origin)
	if not locomotion_pivot.transform.is_equal_approx(body):
		locomotion_pivot.transform = body
		_dirty = true
	var clip: StringName = _walk_clip if _speed > 0.01 else _idle_clip
	if delta <= 0.0 and animation_player.current_animation == clip and not _dirty:
		return
	if animation_player.current_animation != clip:
		animation_player.play(clip)
	var animation: Animation = animation_player.get_animation(clip)
	_walk_time = fposmod(_walk_time + delta * clampf(_speed / 70.0, 0.25, 2.0), maxf(0.001, animation.length))
	animation_player.seek(_walk_time if _speed > 0.01 else 0.0, true)
	# Rotate the authored forward stride toward actual travel while keeping the
	# hips within sixty degrees of the gun, including strafe and backpedal steps.
	var stride: Basis = Basis(Vector3.UP, travel_yaw - body_yaw)
	if _speed > 0.01:
		for index: int in _hip_nodes.size():
			var rest: Transform3D = _hip_rests[index]
			var hip: Node3D = _hip_nodes[index]
			var relative: Basis = rest.basis.inverse() * hip.basis
			hip.basis = rest.basis * stride * relative * stride.inverse()
	_dirty = true


func _resize(density: float) -> void:
	_density = density
	viewport.size = Vector2i(Vector2(_canvas) * density)
	display.scale = Vector2.ONE / density
	display.position = Vector2(_canvas) / 2.0 - _anchor
	_dirty = true


func _on_screen() -> bool:
	var bounds: Rect2 = get_global_transform_with_canvas() * Rect2(-_anchor, Vector2(_canvas))
	return get_viewport().get_visible_rect().intersects(bounds)
