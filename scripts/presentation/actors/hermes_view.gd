@tool
class_name HermesView
extends ActorView
## Hermes walks with an independent shoulder laser and folds into a fixed cannon.

const DEPLOY_SECONDS: float = 0.45
const ANCHOR_NAMES: Array[String] = ["AnchorLF", "AnchorLB", "AnchorRF", "AnchorRB"]
const JOINT_NAMES: Array[String] = ["DeployHipLeft", "DeployHipRight", "DeployKneeLeft", "DeployKneeRight", "DeployAnkleLeft", "DeployAnkleRight", "DeployShoulderLeft", "DeployShoulderRight"]

@export var anchored_model_scene: PackedScene
@export var mobile_model_scene: PackedScene

var mobile_model_view: ActorModelView
var _anchored: bool = false
var _received_state: bool = false
var _deployment_amount: float = 0.0
var _deployment_parts: Dictionary[Node3D, Transform3D] = {}
var _hook_viewport: SubViewport
var _hook_display: Sprite2D
var _hook_clamp: Node3D
var _hook_jaws: Array[Node3D] = []
var _hook_jaw_rests: Array[Transform3D] = []
var _hook_contact: StandardMaterial3D
var _recovery_cable := PackedVector2Array()
var _last_recovery_cable := PackedVector2Array()
var _last_hook_point: Vector2 = Vector2.INF
var _hook_ground: Vector2 = Vector2.INF


func _ready() -> void:
	super._ready()
	_prepare_anchor_model()
	_prepare_mobile_model()
	_prepare_winch_clamp()
	_apply_deployment()


func apply_state(entity: Dictionary, selected: bool = false, playback_enabled: bool = true) -> void:
	_anchored = bool(entity.get("anchored", false))
	if not _received_state:
		_deployment_amount = 1.0 if _anchored else 0.0
		_received_state = true
	super.apply_state(entity, selected, playback_enabled)
	_apply_deployment()


func _process(delta: float) -> void:
	if not _playback_enabled or Engine.is_editor_hint():
		return
	var target: float = 1.0 if _anchored else 0.0
	if is_equal_approx(_deployment_amount, target):
		return
	_deployment_amount = move_toward(_deployment_amount, target, delta / DEPLOY_SECONDS)
	_apply_deployment()


func _update_sprite(facing: int, moving: bool, elapsed: float) -> void:
	super._update_sprite(facing, moving, elapsed)
	if is_node_ready():
		_apply_deployment()


func _prepare_anchor_model() -> void:
	if anchored_model_scene == null or model_view != null:
		return
	model_view = ActorModelView.new()
	model_view.name = "AnchorModel"
	add_child(model_view)
	if not model_view.configure(anchored_model_scene, visual.tint):
		return
	for part_name: String in ["DeployBody"] + ANCHOR_NAMES + JOINT_NAMES:
		var part: Node3D = model_view.model_root.find_child(part_name, true, false) as Node3D
		if part != null:
			_deployment_parts[part] = part.transform


func _prepare_mobile_model() -> void:
	if mobile_model_scene == null or mobile_model_view != null:
		return
	mobile_model_view = ActorModelView.new()
	mobile_model_view.name = "MobileModel"
	add_child(mobile_model_view)
	mobile_model_view.configure(mobile_model_scene, visual.tint)


func _apply_deployment() -> void:
	if model_view == null or model_view.display == null:
		return
	var amount: float = _deployment_amount * _deployment_amount * (3.0 - 2.0 * _deployment_amount)
	model_view.visible = amount > 0.0
	model_view.playback_enabled = _playback_enabled
	model_view.set_aim(_aim_direction)
	model_view.display.self_modulate.a = amount
	var live_mobile: bool = mobile_model_view != null and mobile_model_view.display != null
	if live_mobile:
		mobile_model_view.visible = amount < 1.0
		mobile_model_view.position = visual.feet_offset
		mobile_model_view.playback_enabled = _playback_enabled
		mobile_model_view.set_movement(_movement_direction, _movement_speed if _moving else 0.0)
		mobile_model_view.display.self_modulate.a = 1.0 - amount
	if animation_sprite != null:
		animation_sprite.visible = not live_mobile and amount < 1.0
		animation_sprite.self_modulate.a = 1.0 - amount
	sprite.self_modulate.a = 1.0 - amount
	if live_mobile:
		sprite.hide()
	for part: Node3D in _deployment_parts:
		var rest: Transform3D = _deployment_parts[part]
		var pose: Transform3D = rest
		if part.name == "DeployBody":
			pose.origin.y += 0.52 * (1.0 - amount)
		elif String(part.name).begins_with("Anchor"):
			pose.basis = rest.basis.scaled(Vector3.ONE * maxf(0.001, amount))
		else:
			pose.basis = Basis.IDENTITY.slerp(rest.basis, amount)
		if not part.transform.is_equal_approx(pose):
			part.transform = pose
			model_view.refresh_pose()
	queue_redraw()


func notify_respawn() -> void:
	_anchored = false
	_received_state = false
	_deployment_amount = 0.0
	super.notify_respawn()
	if mobile_model_view != null:
		mobile_model_view.reset_pose(true)
	_apply_deployment()
	_recovery_cable.clear()
	_last_recovery_cable.clear()
	_last_hook_point = Vector2.INF
	_hook_ground = Vector2.INF
	if _hook_display != null:
		_hook_display.hide()


func notify_attack(direction: Vector2 = Vector2.ZERO, weapon_id: String = "") -> void:
	if _anchored:
		super.notify_attack(direction, weapon_id)


func aim_laser(target_offset: Vector2, target_height: float) -> void:
	if not _anchored and mobile_model_view != null and _health > 0.0:
		mobile_model_view.aim_laser(target_offset, target_height)


func laser_muzzle() -> Vector2:
	if _anchored or _health <= 0.0 or mobile_model_view == null or not mobile_model_view.visible:
		return Vector2.INF
	return mobile_model_view.live_weapon_muzzle() + visual.feet_offset


func weapon_muzzle(direction: Vector2, weapon_id: String = "") -> Vector2:
	if not _anchored or model_view == null:
		return Vector2.INF
	return model_view.weapon_muzzle(direction, weapon_id) + visual.feet_offset


func gathering_model() -> ActorModelView:
	return model_view if _anchored else mobile_model_view


func sync_intake(corpses: Array, nathaniel: Dictionary, hermes: Dictionary) -> void:
	super.sync_intake(corpses, nathaniel, hermes)
	if mobile_model_view != null and mobile_model_view.gathering_view != null:
		mobile_model_view.gathering_view.sync(corpses, nathaniel, hermes, null)
	var inactive: ActorModelView = mobile_model_view if _anchored else model_view
	if inactive != null and inactive.gathering_view != null and inactive.gathering_view.intake_bundle != null:
		inactive.gathering_view.intake_bundle.hide()
		inactive.refresh_pose()
	_sync_winch(hermes)


func _prepare_winch_clamp() -> void:
	if anchored_model_scene == null or model_view == null or model_view.gathering_view == null or model_view.gathering_view.winch_clamp == null:
		return
	_hook_viewport = SubViewport.new()
	_hook_viewport.name = "WinchClampViewport"
	_hook_viewport.own_world_3d = true
	_hook_viewport.transparent_bg = true
	_hook_viewport.msaa_3d = Viewport.MSAA_4X
	_hook_viewport.size = Vector2i(256, 256)
	_hook_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_hook_viewport)
	var scene: Node3D = anchored_model_scene.instantiate()
	_hook_viewport.add_child(scene)
	_hook_clamp = scene.find_child("WinchClamp", true, false) as Node3D
	for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		mesh.visible = _hook_clamp.is_ancestor_of(mesh)
	_hook_clamp.global_transform = Transform3D.IDENTITY
	for suffix: String in ["Left", "Right"]:
		var jaw: Node3D = _hook_clamp.find_child("WinchJaw" + suffix, true, false) as Node3D
		_hook_jaws.append(jaw)
		_hook_jaw_rests.append(jaw.transform)
	_hook_contact = StandardMaterial3D.new()
	_hook_contact.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hook_contact.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hook_contact.albedo_color = Color("ffc26c", 0.0)
	for mesh: MeshInstance3D in _hook_clamp.find_children("*", "MeshInstance3D", true, false):
		if "flat contact pad" in str(mesh.name):
			mesh.material_overlay = _hook_contact
	_hook_display = Sprite2D.new()
	_hook_display.name = "WinchClamp"
	_hook_display.texture = _hook_viewport.get_texture()
	_hook_display.centered = false
	_hook_display.offset = Vector2(-128, -192)
	_hook_display.scale = Vector2.ONE * 0.5
	_hook_display.z_index = 3
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	_hook_display.material = material
	add_child(_hook_display)
	_hook_display.hide()


func _model_point(point: Vector3) -> Vector2:
	var canvas: Vector2i = model_view.model_root.get_meta("logical_canvas")
	var density: float = float(model_view.viewport.size.x) / canvas.x
	return model_view.camera.unproject_position(point) / density - Vector2(model_view.model_root.get_meta("logical_ground_anchor")) + visual.feet_offset


func recovery_cable() -> PackedVector2Array:
	return _recovery_cable


func recovery_ground() -> Vector2:
	return _hook_ground


func set_recovery_visible(value: bool) -> void:
	if value or _hook_display == null:
		return
	_hook_display.hide()
	_recovery_cable.clear()
	_last_recovery_cable.clear()
	_last_hook_point = Vector2.INF
	_hook_ground = Vector2.INF


func _sync_winch(hermes: Dictionary) -> void:
	_recovery_cable.clear()
	if _hook_display == null:
		return
	_hook_display.hide()
	var rig: ResourceGatheringView = model_view.gathering_view
	var active: Dictionary = rig.recovery_corpse()
	if active.is_empty():
		var remaining: float = float(hermes.get("recovery_cooldown", 0.0))
		if _anchored and _health > 0.0 and remaining > 0.0 and _last_hook_point.is_finite():
			var fraction: float = clampf(1.0 - remaining / GameBalance.HERMES_WINCH_RESET_SECONDS, 0.0, 1.0)
			var target: Vector2 = _model_point(rig.winch_clamp.global_position)
			_hook_display.position = _last_hook_point.lerp(target, smoothstep(0.0, 1.0, fraction))
			_hook_display.show()
			_recovery_cable = _last_recovery_cable.duplicate()
			if _recovery_cable.size() >= 2:
				_recovery_cable[_recovery_cable.size() - 2] = _recovery_cable[_recovery_cable.size() - 3].lerp(_hook_display.position, 0.5)
				_recovery_cable[_recovery_cable.size() - 1] = _hook_display.position
			_hook_contact.albedo_color = Color("ffc26c", 0.0)
			rig.winch_clamp.hide()
			_hook_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		else:
			_last_hook_point = Vector2.INF
			_last_recovery_cable.clear()
		return
	var offset: Vector2 = Vector2(active.position) - Vector2(hermes.position)
	_hook_ground = active.position
	var fraction: float = ResourceGatheringView.phase_fraction(active)
	var phase: String = str(active.phase)
	var launch_fraction: float = GameBalance.HERMES_WINCH_LAUNCH_SECONDS / BattlefieldRules.phase_seconds("winch_launch")
	var outlet: Vector2 = _model_point(rig.winch_outlet.global_position)
	var guide: Vector2 = _model_point(rig.winch_guide.global_position)
	var endpoint: Vector2 = IsoProjection.project(offset) - Vector2(0, 8)
	if phase == "winch_launch":
		endpoint = guide.lerp(endpoint, smoothstep(0.0, launch_fraction, fraction))
	elif phase in ["winch_crush", "winch_feed"]:
		endpoint = _model_point(rig.intake_bundle.global_position)
	var heading: Vector2 = offset.normalized() if offset.length_squared() > 0.001 else Vector2.RIGHT
	if phase in ["winch_crush", "winch_feed"]:
		heading = Vector2.RIGHT
	_hook_clamp.global_basis = Basis(Vector3.UP, -heading.angle())
	var size: float = 1.7 if active.get("source_kind", "") == "boss" else 1.0
	if phase == "winch_crush":
		size = lerpf(size, 1.0, fraction)
	_hook_clamp.scale = Vector3.ONE * size
	var spread: float = 0.11 * (1.0 - smoothstep(launch_fraction, 1.0, fraction)) if phase == "winch_launch" else 0.0
	for index: int in _hook_jaws.size():
		_hook_jaws[index].transform = _hook_jaw_rests[index].translated(Vector3((spread if index == 1 else -spread), 0, 0))
	_hook_contact.albedo_color = Color("ffc26c", 1.0 - smoothstep(0.0, GameBalance.HERMES_WINCH_CLAMP_SECONDS, float(active.get("phase_elapsed", 0.0)))) if phase == "winch_reel" else Color("ffc26c", 0.0)
	_hook_display.position = endpoint
	_hook_display.show()
	_hook_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_recovery_cable.append(outlet)
	# Feed cable around the low rail so a rear pull never crosses the torso.
	var start_angle: float = atan2(-0.60, 0.465)
	var turn: float = angle_difference(start_angle, heading.angle())
	for index: int in range(9):
		var angle: float = start_angle + turn * float(index) / 8.0
		_recovery_cable.append(_model_point(Vector3(sin(angle) * 1.20, 0.52, -cos(angle) * 1.20)))
	_recovery_cable.append(guide)
	_recovery_cable.append(guide.lerp(endpoint, 0.5) + Vector2(0, 1.0 if phase == "winch_launch" else 0.3))
	_recovery_cable.append(endpoint)
	_last_hook_point = endpoint
	_last_recovery_cable = _recovery_cable.duplicate()
