@tool
class_name ResearchCenterView
extends ActorView
## Folds the saved bench parts without changing construction or research state.

# Rounded out from the exported alpha bounds, including the arch and all feet.
const BODY_BOUNDS := Rect2(-41, -59, 82, 79)

var _parts: Dictionary[String, Node3D] = {}
var _rest: Dictionary[String, Transform3D] = {}
var _deployment: float = 0.0
var _scan_elapsed: float = 1.0
var _removal: String = ""
var _removal_elapsed: float = 0.0


func apply_state(entity: Dictionary, selected: bool = false, playback_enabled: bool = true, defer_laser_aim: bool = false) -> void:
	super.apply_state(entity, selected, playback_enabled, defer_laser_aim)
	if model_view == null or model_view.model_root == null:
		return
	if _parts.is_empty():
		for part: String in ["ResearchArchLeft", "ResearchArchRight", "ResearchCrosspiece", "ResearchScan", "ResearchFoot1", "ResearchFoot2", "ResearchFoot3", "ResearchFoot4"]:
			var node: Node3D = model_view.model_root.find_child(part, true, false) as Node3D
			if node != null:
				_parts[part] = node
				_rest[part] = node.transform
		_pose()


func notify_research() -> void:
	_scan_elapsed = 0.0


func begin_removal(reason: String) -> void:
	_removal = reason
	_removal_elapsed = 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _playback_enabled or _parts.is_empty():
		return
	var changed: bool = _deployment < 1.0 or _scan_elapsed < 1.0 or not _removal.is_empty()
	_deployment = minf(1.0, _deployment + delta / 0.45)
	_scan_elapsed = minf(1.0, _scan_elapsed + delta / 0.55)
	if not _removal.is_empty():
		_removal_elapsed += delta
		if _removal_elapsed >= 0.45:
			queue_free()
			return
	if changed:
		_pose()


func _pose() -> void:
	var open: float = _deployment
	if Engine.is_editor_hint():
		open = 1.0
	if not _removal.is_empty():
		open = 1.0 - clampf(_removal_elapsed / 0.4, 0.0, 1.0)
	var fold: float = 1.0 - smoothstep(0.0, 1.0, open)
	for part: String in _parts:
		var rest: Transform3D = _rest[part]
		var pose: Transform3D = rest
		if part.begins_with("ResearchArch"):
			var sign: float = -1.0 if part.ends_with("Left") else 1.0
			pose.basis = rest.basis * Basis(Vector3.BACK, sign * fold * 1.22)
		elif part == "ResearchCrosspiece":
			pose.origin.y -= fold * 0.59
		elif part.begins_with("ResearchFoot"):
			pose.origin.x *= 1.0 - fold * 0.22
			pose.origin.z *= 1.0 - fold * 0.22
		elif part == "ResearchScan":
			_parts[part].visible = _scan_elapsed < 1.0 and _removal.is_empty()
			pose.origin.x += lerpf(-0.29, 0.29, _scan_elapsed)
		_parts[part].transform = pose
	if _removal == "destroyed":
		model_view.display.modulate = Color.WHITE.lerp(Color("383135", 0.0), clampf(_removal_elapsed / 0.45, 0.0, 1.0))
	model_view.refresh_pose()


func sprite_contains_screen_point(screen: Vector2) -> bool:
	if model_view != null and model_view.visible:
		var local: Vector2 = model_view.to_local(get_canvas_transform().affine_inverse() * screen)
		return BODY_BOUNDS.has_point(local)
	return super.sprite_contains_screen_point(screen)
