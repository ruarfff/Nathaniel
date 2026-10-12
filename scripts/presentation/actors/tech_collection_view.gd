class_name TechCollectionView
extends RefCounted
## Poses the separate collector from the domain pickup phase.

const COLLECTOR: PackedScene = preload("res://assets/generated/tech_collector.glb")

var _model: ActorModelView
var _attachment: Node3D
var _parts: Dictionary[String, Node3D] = {}
var _rest: Dictionary[String, Transform3D] = {}
var _phase: float = -1.0
var _pickup_id: int = -1


func sync(model: ActorModelView, pickups: Array, nathaniel: Dictionary, _playback_enabled: bool = true) -> void:
	if not is_instance_valid(model) or model.model_root == null:
		return
	if model != _model or not is_instance_valid(_attachment):
		_attach(model)
	if not is_instance_valid(_attachment):
		return
	var active: Dictionary = {}
	for pickup: Dictionary in pickups:
		if str(pickup.get("phase", "")) == "collect" and int(pickup.get("owner_id", -1)) == int(nathaniel.get("id", -2)):
			active = pickup
			break
	var fraction: float = clampf(float(active.get("phase_elapsed", 0.0)) / GameBalance.TECH_COLLECTION_SECONDS, 0.0, 1.0)
	var id: int = int(active.get("id", -1))
	# Walking changes the parent pose even if collection is idle.
	if active.is_empty() and _pickup_id == -1 and _phase == fraction:
		return
	_pickup_id = id
	_phase = fraction
	for part: String in _parts:
		_parts[part].transform = _rest[part]
	_parts.TechHeld.hide()
	if not active.is_empty():
		var offset: Vector2 = Vector2(active.get("position", Vector2.ZERO)) - Vector2(nathaniel.get("position", Vector2.ZERO))
		var ground := Vector3(offset.y / 32.0, 0.14, -offset.x / 32.0)
		var wrist: Node3D = _parts.TechWrist
		var stored: Vector3 = _attachment.to_global(Vector3(0.0, 0.40, 0.0))
		var target: Vector3 = wrist.global_position.lerp(ground, smoothstep(0.0, 0.40, fraction))
		if fraction >= 0.40:
			target = ground.lerp(stored, smoothstep(0.45, 1.0, fraction))
		var shoulder: Node3D = _parts.TechShoulder
		var elbow: Vector3 = shoulder.global_position.lerp(target, 0.5) + _attachment.global_basis.x * 0.17 + Vector3.UP * 0.12
		_link(_parts["Short upper link"], shoulder.global_position, elbow)
		_link(_parts["Short outer link"], elbow, target)
		wrist.global_position = target
		_parts.TechHeld.visible = fraction >= 0.40 and fraction < 0.98
		_parts.TechCassetteLid.rotation.x = -sin(fraction * PI) * 1.1
	_model.refresh_pose()


func _attach(model: ActorModelView) -> void:
	if is_instance_valid(_attachment):
		_attachment.queue_free()
	_model = model
	_parts.clear()
	_rest.clear()
	var backpack: Node3D = model.model_root.find_child("BackpackRoot", true, false) as Node3D
	if backpack == null:
		return
	_attachment = COLLECTOR.instantiate() as Node3D
	backpack.add_child(_attachment)
	_attachment.position = Vector3(0.36, 1.16, 0.37)
	for part: String in ["TechShoulder", "TechWrist", "TechHeld", "TechCassetteLid", "Short upper link", "Short outer link"]:
		var node: Node3D = _attachment.find_child(part, true, false) as Node3D
		if node != null:
			_parts[part] = node
			_rest[part] = node.transform
	_parts.TechHeld.hide()
	_model.refresh_pose()


func _link(node: Node3D, start: Vector3, end: Vector3) -> void:
	var mesh: MeshInstance3D = node as MeshInstance3D
	if mesh == null:
		return
	var up: Vector3 = (end - start).normalized()
	var across: Vector3 = _attachment.global_basis.z.slide(up).normalized()
	if across.is_zero_approx():
		across = Vector3.RIGHT.slide(up).normalized()
	var basis := Basis(across, up, across.cross(up)).orthonormalized()
	var length: float = mesh.mesh.get_aabb().size.y
	mesh.global_transform = Transform3D(basis * Basis.from_scale(Vector3(1, start.distance_to(end) / maxf(length, 0.001), 1)), (start + end) * 0.5)
