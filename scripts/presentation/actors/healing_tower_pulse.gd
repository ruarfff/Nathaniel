@tool
class_name HealingTowerPulse
extends Node2D
## Light geometry belongs to the scene; pulse timing belongs to presentation.

const IDLE_PERIOD: float = 3.6
const PULSE_DURATION: float = 0.8
const PULSE_RISE: float = 0.1

## Pairs of endpoints in the source sprite's pixel coordinates.
@export var light_segments: PackedVector2Array = PackedVector2Array()
@export var light_color: Color = Color("7ff4df")
@export_range(1.0, 128.0) var ripple_radius: float = 34.0

var playback_enabled: bool = true
var _idle_time: float = 0.0
var _pulse_time: float = PULSE_DURATION
var _lights: Node2D
@onready var _sprite: Sprite2D = get_node("../Sprite2D")


func _ready() -> void:
	_lights = Node2D.new()
	_lights.name = "HealingLights"
	_sprite.add_child(_lights)
	_lights.draw.connect(_draw_lights)
	_update_light()
	set_process(not Engine.is_editor_hint())


func _exit_tree() -> void:
	if is_instance_valid(_lights):
		_lights.queue_free()


func pulse() -> void:
	_pulse_time = 0.0
	_update_light()
	queue_redraw()


func _process(delta: float) -> void:
	if not playback_enabled:
		return
	_idle_time = fmod(_idle_time + delta, IDLE_PERIOD)
	var was_pulsing: bool = _pulse_time < PULSE_DURATION
	_pulse_time = minf(PULSE_DURATION, _pulse_time + delta)
	_update_light()
	if was_pulsing:
		queue_redraw()


func _update_light() -> void:
	var idle: float = lerpf(0.07, 0.23, (1.0 - cos(TAU * _idle_time / IDLE_PERIOD)) * 0.5)
	var intensity: float = idle
	if _pulse_time < PULSE_RISE:
		intensity = lerpf(idle, 0.95, _pulse_time / PULSE_RISE)
	elif _pulse_time < PULSE_DURATION:
		var recovery: float = (_pulse_time - PULSE_RISE) / (PULSE_DURATION - PULSE_RISE)
		intensity = lerpf(0.95, idle, 1.0 - pow(1.0 - recovery, 2.0))
	_lights.modulate.a = intensity


func _draw_lights() -> void:
	if _sprite.texture == null:
		return
	var frame_size: Vector2 = _sprite.region_rect.size if _sprite.region_enabled else _sprite.texture.get_size()
	var center: Vector2 = frame_size * 0.5 if _sprite.centered else Vector2.ZERO
	for index: int in range(0, light_segments.size() - 1, 2):
		var start: Vector2 = light_segments[index] - center
		var end: Vector2 = light_segments[index + 1] - center
		for width: float in [40.0, 28.0, 18.0]:
			_lights.draw_line(start, end, Color(light_color, 0.06), width, true)
		_lights.draw_line(start, end, light_color.lightened(0.65), 7.0, true)


func _draw() -> void:
	if _pulse_time >= PULSE_DURATION:
		return
	var phase: float = _pulse_time / PULSE_DURATION
	var strength: float = minf(_pulse_time / PULSE_RISE, 1.0) * (1.0 - phase)
	var radius: float = ripple_radius * lerpf(0.78, 1.12, 1.0 - pow(1.0 - phase, 2.0))
	var actor: ActorView = get_parent() as ActorView
	var offset: Vector2 = actor.visual.feet_offset if actor != null and actor.visual != null else Vector2.ZERO
	draw_set_transform(offset + Vector2(0, 2.4), 0.0, Vector2(1.0, 0.4))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(light_color, strength * 0.55), 0.65, true)
