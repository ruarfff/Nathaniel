@tool
class_name HermesView
extends ActorView
## Hermes keeps his walking clips and folds into a live, fixed-body cannon.

const DEPLOY_SECONDS: float = 0.45
const ANCHOR_NAMES: Array[String] = ["AnchorLF", "AnchorLB", "AnchorRF", "AnchorRB"]
const JOINT_NAMES: Array[String] = ["DeployHipLeft", "DeployHipRight", "DeployKneeLeft", "DeployKneeRight", "DeployAnkleLeft", "DeployAnkleRight", "DeployShoulderLeft", "DeployShoulderRight"]

@export var anchored_model_scene: PackedScene

var _anchored: bool = false
var _received_state: bool = false
var _deployment_amount: float = 0.0
var _deployment_parts: Dictionary[Node3D, Transform3D] = {}


func _ready() -> void:
	super._ready()
	_prepare_anchor_model()
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


func _apply_deployment() -> void:
	if model_view == null or model_view.display == null:
		return
	var amount: float = _deployment_amount * _deployment_amount * (3.0 - 2.0 * _deployment_amount)
	model_view.visible = amount > 0.0
	model_view.playback_enabled = _playback_enabled
	model_view.set_aim(_aim_direction)
	model_view.display.self_modulate.a = amount
	if animation_sprite != null:
		animation_sprite.visible = amount < 1.0
		animation_sprite.self_modulate.a = 1.0 - amount
	sprite.self_modulate.a = 1.0 - amount
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
	_apply_deployment()


func weapon_muzzle(direction: Vector2, weapon_id: String = "") -> Vector2:
	if not _anchored or model_view == null:
		return Vector2.INF
	return model_view.weapon_muzzle(direction, weapon_id) + visual.feet_offset
