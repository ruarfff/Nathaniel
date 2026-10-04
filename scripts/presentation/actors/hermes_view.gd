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


func _ready() -> void:
	super._ready()
	_prepare_anchor_model()
	_prepare_mobile_model()
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
