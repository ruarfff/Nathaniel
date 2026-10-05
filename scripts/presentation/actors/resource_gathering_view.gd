@tool
class_name ResourceGatheringView
extends RefCounted
## Poses authored handling parts from simulation time; never changes cargo state.

const FEED_HANDOFF: float = 0.72
const LINK_LENGTH: float = 0.36

var model: ActorModelView
var backpack: Node3D
var intake: Node3D
var active_bundle: Node3D
var intake_bundle: Node3D
var _slots: Array[Node3D] = []
var _racks: Array[Node3D] = []
var _bundles: Array[Node3D] = []
var _arms: Array[Dictionary] = []
var _rest: Dictionary[Node3D, Transform3D] = {}
var _lip: Node3D
var _grille: Node3D
var _glow: MeshInstance3D
var _heat_material: StandardMaterial3D
var _contact_material: StandardMaterial3D
var _corpses: Array = []
var _nathaniel: Dictionary = {}
var _hermes: Dictionary = {}
var _receiver: ActorModelView


func _init(owner_model: ActorModelView) -> void:
	model = owner_model
	backpack = _node("BackpackRoot")
	intake = _node("IntakeTarget")
	if backpack != null:
		for index: int in range(1, 4):
			_slots.append(_node("CargoSlot%d" % index))
			_racks.append(_node("CargoRack%d" % index))
			_bundles.append(_node("CargoBundle%d" % index))
		for suffix: String in ["Left", "Right"]:
			var arm: Dictionary = {}
			for part: String in ["Shoulder", "Upper", "Elbow", "Forearm", "Extension", "Wrist", "Jaw"]:
				arm[part] = _node("Gather%s%s" % [part, suffix])
			_arms.append(arm)
		var jaw: Node3D = _arms[0].Jaw
		if jaw != null:
			for mesh: MeshInstance3D in jaw.find_children("*", "MeshInstance3D", true, false):
				if "crushing" in str(mesh.name).to_lower():
					_contact_material = StandardMaterial3D.new()
					_contact_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					_contact_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					_contact_material.albedo_color = Color("ffc26c", 0.0)
					mesh.material_overlay = _contact_material
					break
		if _bundles[0] != null:
			active_bundle = _bundles[0].duplicate() as Node3D
			active_bundle.name = "HeldBundle"
			model.model_root.add_child(active_bundle)
			active_bundle.hide()
	_lip = _node("IntakeLip")
	_grille = _node("IntakeGrille")
	_glow = _node("FurnaceGlow") as MeshInstance3D
	intake_bundle = _node("IntakeBundle")
	if intake_bundle != null:
		intake_bundle.hide()
	if _glow != null:
		_heat_material = StandardMaterial3D.new()
		_heat_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_heat_material.albedo_color = Color("251813")
		_glow.material_override = _heat_material
	for bundle: Node3D in _bundles:
		if bundle != null:
			bundle.hide()
	for index: int in _racks.size():
		if _racks[index] != null:
			_racks[index].visible = index == 0


func _node(part_name: String) -> Node3D:
	var part: Node3D = model.model_root.find_child(part_name, true, false) as Node3D
	if part != null:
		_rest[part] = part.transform
	return part


static func ground_visible(corpse: Dictionary) -> bool:
	return str(corpse.get("phase", "carry" if corpse.get("carried", false) else "loose")) in ["loose", "grab"]


static func phase_fraction(corpse: Dictionary) -> float:
	return clampf(float(corpse.get("phase_elapsed", 0.0)) / maxf(0.001, BattlefieldRules.phase_seconds(str(corpse.get("phase", "")))), 0.0, 1.0)


func sync(corpses: Array, nathaniel: Dictionary, hermes: Dictionary, receiver: ActorModelView) -> void:
	_corpses = corpses
	_nathaniel = nathaniel
	_hermes = hermes
	_receiver = receiver
	apply_pose()


func apply_pose() -> void:
	if backpack != null:
		_pose_backpack()
	if intake != null:
		_pose_intake()
	model.refresh_pose()


func _active_corpse() -> Dictionary:
	for corpse: Dictionary in _corpses:
		if str(corpse.get("phase", "")) in ["grab", "crush", "present", "feed"]:
			return corpse
	return {}


func _pose_backpack() -> void:
	if _contact_material != null:
		_contact_material.albedo_color = Color("ffc26c", 0.0)
	for arm: Dictionary in _arms:
		for part: Node3D in arm.values():
			if part != null:
				part.transform = _rest[part]
	for index: int in _racks.size():
		if _racks[index] != null:
			_racks[index].visible = index < int(_nathaniel.get("resource_capacity", 1))
		if _bundles[index] != null:
			_bundles[index].hide()
	if active_bundle != null:
		active_bundle.hide()
	if float(_nathaniel.get("hp", 1.0)) <= 0.0:
		return
	for corpse: Dictionary in _corpses:
		var slot: int = int(corpse.get("cargo_slot", -1))
		if str(corpse.get("phase", "carry" if corpse.get("carried", false) else "loose")) == "carry" and slot >= 0 and slot < _bundles.size() and _bundles[slot] != null:
			_bundles[slot].show()
	var active: Dictionary = _active_corpse()
	if active.is_empty() or active_bundle == null:
		return
	var slot: int = clampi(int(active.get("cargo_slot", 0)), 0, _slots.size() - 1)
	if _slots[slot] == null:
		return
	var phase: String = str(active.phase)
	var fraction: float = phase_fraction(active)
	if phase == "crush" and active.get("disarmed", active.get("carried", false)) and _contact_material != null:
		_contact_material.albedo_color = Color("ffc26c", 1.0 - smoothstep(0.0, 0.16, float(active.get("phase_elapsed", 0.0))))
	var rack_point: Vector3 = _slots[slot].global_position
	var pickup: Vector2 = Vector2(active.get("pickup_position", active.get("position", Vector2.ZERO))) - Vector2(_nathaniel.get("position", Vector2.ZERO))
	var ground := Vector3(pickup.y / 32.0, 0.12, -pickup.x / 32.0)
	var point: Vector3 = ground
	var size: float = 1.0
	var spread: float = 0.20
	var left: Node3D = _arms[0].Shoulder
	var right: Node3D = _arms[1].Shoulder
	if left == null or right == null:
		return
	var side: Vector3 = (right.global_position - left.global_position).normalized()
	if phase == "grab":
		var folded: Vector3 = (_arms[0].Wrist.global_position + _arms[1].Wrist.global_position) * 0.5
		point = folded.lerp(ground, smoothstep(0.0, 0.8, fraction))
		spread = lerpf(0.32, 0.25, smoothstep(0.7, 1.0, fraction))
	elif phase == "crush":
		var lifted: Vector3 = ground + Vector3.UP * 0.3
		point = ground.lerp(lifted, smoothstep(0.0, 0.3, fraction)).lerp(rack_point, smoothstep(0.6, 1.0, fraction))
		size = lerpf(1.65, 1.0, smoothstep(0.0, 0.65, fraction))
		spread = lerpf(0.25, 0.16, smoothstep(0.0, 0.65, fraction))
	else:
		var target: Vector3 = _receiver_point()
		var staging: Vector3 = rack_point.lerp(target, 0.4) + Vector3.UP * 0.10
		if phase == "present":
			point = rack_point.lerp(staging, smoothstep(0.0, 1.0, fraction))
		else:
			point = staging.lerp(target, smoothstep(0.0, FEED_HANDOFF, fraction))
			if fraction > FEED_HANDOFF:
				point = target.lerp(rack_point, smoothstep(FEED_HANDOFF, 1.0, fraction))
	if phase != "grab" and not (phase == "feed" and fraction >= FEED_HANDOFF):
		active_bundle.show()
		active_bundle.global_transform = Transform3D(_slots[slot].global_basis.scaled(Vector3.ONE * size), point)
	_pose_arm(_arms[0], point - side * spread, -side)
	_pose_arm(_arms[1], point + side * spread, side)


func _receiver_point() -> Vector3:
	var offset: Vector2 = Vector2(_hermes.get("position", Vector2.ZERO)) - Vector2(_nathaniel.get("position", Vector2.ZERO))
	var target := Vector3(0.0, 0.78 if _hermes.get("anchored", false) else 1.3, 0.0)
	if is_instance_valid(_receiver) and _receiver.gathering_view != null and _receiver.gathering_view.intake != null:
		target = _receiver.gathering_view.intake.global_position
	return target + Vector3(offset.y / 32.0, 0.0, -offset.x / 32.0)


func _pose_arm(arm: Dictionary, target: Vector3, outward: Vector3) -> void:
	var shoulder: Node3D = arm.Shoulder
	var elbow: Node3D = arm.Elbow
	var wrist: Node3D = arm.Wrist
	if shoulder == null or elbow == null or wrist == null:
		return
	var origin: Vector3 = shoulder.global_position
	var midpoint: Vector3 = origin + (target - origin + outward * 0.85 + Vector3.UP * 0.3).normalized() * LINK_LENGTH
	shoulder.global_basis = _basis_y(midpoint - origin, outward)
	if arm.Upper != null:
		arm.Upper.transform = Transform3D.IDENTITY
	elbow.global_position = midpoint
	elbow.global_basis = _basis_y(target - midpoint, outward)
	if arm.Forearm != null:
		arm.Forearm.transform = Transform3D.IDENTITY
	_stretch_link(arm.Extension if arm.Extension != null else arm.Forearm, midpoint.distance_to(target))
	wrist.global_position = target
	wrist.global_basis = backpack.global_basis * _rest[wrist].basis


func _stretch_link(link: Node3D, length: float) -> void:
	if link == null:
		return
	var ratio: float = length / LINK_LENGTH
	link.transform = Transform3D(Basis.from_scale(Vector3(1.0, ratio, 1.0)), Vector3.ZERO)


func _basis_y(direction: Vector3, outward: Vector3) -> Basis:
	var up: Vector3 = direction.normalized()
	var across: Vector3 = outward.slide(up).normalized()
	if across.length_squared() < 0.001:
		across = Vector3.RIGHT.slide(up).normalized()
	return Basis(across, up, across.cross(up)).orthonormalized()


func _pose_intake() -> void:
	var active: Dictionary = _active_corpse()
	var phase: String = str(active.get("phase", ""))
	var fraction: float = phase_fraction(active)
	var open: float = 0.0
	if phase == "present":
		open = smoothstep(0.0, 1.0, fraction)
	elif phase == "feed":
		open = 1.0 - smoothstep(FEED_HANDOFF, 1.0, fraction)
	if _lip != null:
		var rest: Transform3D = _rest[_lip]
		_lip.transform = Transform3D(rest.basis * Basis(Vector3.RIGHT, (1.0 - open) * PI * 0.5), rest.origin)
	if _grille != null:
		var rest: Transform3D = _rest[_grille]
		_grille.transform = rest.translated(Vector3.UP * open * 0.18)
	if intake_bundle != null:
		intake_bundle.visible = phase == "feed" and fraction >= FEED_HANDOFF
		intake_bundle.scale = Vector3.ONE * lerpf(1.0, 0.12, smoothstep(FEED_HANDOFF, 1.0, fraction))
	if _heat_material != null:
		var remaining: float = clampf(float(_hermes.get("furnace_remaining", 0.0)) / GameBalance.RESOURCE_FURNACE_SECONDS, 0.0, 1.0)
		var heat: float = sin((1.0 - remaining) * PI) if remaining > 0.0 else 0.0
		_heat_material.albedo_color = Color("251813").lerp(Color("ffb54c"), heat)
