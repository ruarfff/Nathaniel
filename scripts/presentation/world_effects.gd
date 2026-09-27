class_name WorldEffects
extends Node2D
## Scene-owned presentation parameters never change logical combat or placement.

@export_group("Corpses")
@export var corpse_texture: Texture2D = preload("res://assets/Sprites/Objects/corpse.png")
@export var corpse_size := Vector2(30, 16)
@export_range(0.0, 1.0) var carried_corpse_alpha: float = 0.65

@export_group("Projectiles")
@export_range(0.1, 32.0) var projectile_radius: float = 3.0
@export var friendly_projectile_color := Color("ffd878")
@export var enemy_projectile_color := Color("ff7657")

@export_group("Laser Beams")
@export_range(0.0, 128.0) var laser_height: float = 20.0
@export_range(0.1, 32.0) var laser_width: float = 2.5
@export var friendly_laser_color := Color("66dce3")
@export var enemy_laser_color := Color("ed5e72")

@export_group("Event Rings")
@export_range(0.01, 5.0, 0.01) var transient_lifetime: float = 0.25
@export_range(0.0, 128.0) var transient_start_radius: float = 4.5
@export_range(0.0, 500.0) var transient_growth_speed: float = 90.0
@export_range(0.1, 32.0) var transient_line_width: float = 2.0
@export var transient_color := Color(1, 0.6, 0.2, 0.75)

@export_group("Delivery Order Pulse")
@export_range(0.1, 3.0, 0.05) var delivery_pulse_lifetime: float = 0.9
@export var delivery_pulse_color := Color("65e6ed")

@export_group("Combat Targets")
@export_range(0.1, 3.0, 0.05) var target_pulse_lifetime: float = 0.75
@export var nathaniel_target_color := Color("b4e69b")
@export var hermes_target_color := Color("65e6ed")

@export_group("Placement Preview")
@export var placement_half_extents := Vector2(48, 24)
@export_range(0.1, 32.0) var placement_line_width: float = 2.0
@export var valid_placement_color := Color(0.55, 1, 0.45, 0.8)
@export var invalid_placement_color := Color(1, 0.3, 0.25, 0.8)

var simulation: GameSimulation
var transients: Array[Dictionary] = []
var cursor_world := Vector2.ZERO
var placement := false
var placement_valid := false
var delivery_pulse_time := 0.0
var delivery_pulse_position := Vector2.ZERO
var target_pulse_id := -1
var target_pulse_time := 0.0
var fog_enabled := true


func _process(delta: float) -> void:
	delivery_pulse_time = maxf(0.0, delivery_pulse_time - delta)
	target_pulse_time = maxf(0.0, target_pulse_time - delta)
	for effect: Dictionary in transients:
		effect.life -= delta
	transients = transients.filter(func(effect: Dictionary) -> bool: return effect.life > 0)
	queue_redraw()


func pulse_delivery(world: Vector2) -> void:
	delivery_pulse_position = world
	delivery_pulse_time = delivery_pulse_lifetime
	queue_redraw()


func pulse_target(id: int) -> void:
	target_pulse_id = id
	target_pulse_time = target_pulse_lifetime
	queue_redraw()


func target_markers() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	if simulation == null:
		return markers
	for unit: Dictionary in [simulation.nathaniel, simulation.hermes]:
		var target := simulation.entity(int(unit.get("target_id", -1)))
		if not CombatRules.alive(unit) or not CombatRules.alive(target) or not target.get("enemy", false):
			continue
		if fog_enabled and simulation.visibility_at(target.position) != 2:
			continue
		var is_nathaniel: bool = unit.kind == "nathaniel"
		markers.append({"target": target, "label": "N" if is_nathaniel else "H",
			"color": nathaniel_target_color if is_nathaniel else hermes_target_color})
	return markers


func _draw_target_markers() -> void:
	for marker: Dictionary in target_markers():
		var target: Dictionary = marker.target
		var point := IsoProjection.project(target.position)
		var is_nathaniel: bool = marker.label == "N"
		var radius := maxf(34.0, float(target.radius) + 12.0) + (0.0 if is_nathaniel else 8.0)
		var color: Color = marker.color
		var outline := Color("101c20")
		draw_set_transform(point, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, outline, 5.0, true)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, color, 2.5, true)
		if is_nathaniel and int(target.id) == target_pulse_id and target_pulse_time > 0.0:
			var remaining := target_pulse_time / target_pulse_lifetime
			draw_arc(Vector2.ZERO, radius + 45.0 * remaining * remaining, 0.0, TAU, 64, Color(color, remaining), 4.0, true)
		draw_set_transform(Vector2.ZERO)
		var label_point := point + Vector2(-radius - 22.0 if is_nathaniel else radius + 5.0, 6.0)
		draw_rect(Rect2(label_point - Vector2(3, 16), Vector2(20, 22)), outline)
		draw_string(ThemeDB.fallback_font, label_point, marker.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)


func add_events(events: Array) -> void:
	for event: Dictionary in events:
		if event.has("position"):
			transients.append({"position": event.position, "life": transient_lifetime, "kind": event.get("type", "hit")})


func _draw() -> void:
	if simulation != null:
		var destination: Variant = simulation.nathaniel.get("destination")
		if destination is Vector2:
			var point := IsoProjection.project(destination)
			var blocked: bool = simulation.nathaniel.direct_movement or not simulation.nathaniel.moving
			var color := invalid_placement_color if blocked else valid_placement_color
			draw_arc(point, 12, 0, TAU, 32, color, 2, true)
			if blocked:
				draw_line(point - Vector2(6, 6), point + Vector2(6, 6), color, 2, true)
				draw_line(point - Vector2(-6, 6), point + Vector2(-6, 6), color, 2, true)
		for corpse: Dictionary in simulation.corpses:
			if simulation.visibility_at(corpse.position) == 2:
				var point := IsoProjection.project(corpse.position)
				draw_texture_rect(corpse_texture, Rect2(point - corpse_size * 0.5, corpse_size), false, Color(1, 1, 1, carried_corpse_alpha if corpse.carried else 1))
		for shot: Dictionary in simulation.projectiles:
			if simulation.visibility_at(shot.position) == 2:
				var point := IsoProjection.project(shot.position)
				draw_circle(point, projectile_radius, enemy_projectile_color if shot.enemy else friendly_projectile_color)
		for unit: Dictionary in simulation.entities:
			if unit.get("firing", false) and unit.hp > 0:
				var target: Dictionary = simulation.entity(unit.target_id)
				if not target.is_empty() and target.hp > 0 and simulation.visibility_at(unit.position) == 2:
					draw_line(IsoProjection.project(unit.position) - Vector2(0, laser_height), IsoProjection.project(target.position) - Vector2(0, laser_height), enemy_laser_color if unit.enemy else friendly_laser_color, laser_width, true)
		if delivery_pulse_time > 0.0:
			var elapsed := 1.0 - delivery_pulse_time / delivery_pulse_lifetime
			draw_set_transform(IsoProjection.project(delivery_pulse_position), 0.0, Vector2(1.0, 0.5))
			for delay: float in [0.0, 0.25]:
				var phase := (elapsed - delay) / 0.75
				if phase >= 0.0 and phase < 1.0:
					var radius := lerpf(30.0, 90.0, 1.0 - pow(1.0 - phase, 2.0))
					var color := Color(delivery_pulse_color, (1.0 - phase) * delivery_pulse_color.a)
					draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, color, 3.0, true)
			draw_set_transform(Vector2.ZERO)
		_draw_target_markers()
	for effect: Dictionary in transients:
		if effect.position is Vector2:
			var radius: float = transient_start_radius + (transient_lifetime - float(effect.life)) * transient_growth_speed
			var color := Color(transient_color, transient_color.a * float(effect.life) / maxf(0.01, transient_lifetime))
			draw_circle(IsoProjection.project(effect.position), radius, color, false, transient_line_width)
	if placement:
		var point := IsoProjection.project(cursor_world)
		var color := valid_placement_color if placement_valid else invalid_placement_color
		var polygon := PackedVector2Array([point + Vector2(-placement_half_extents.x, 0), point + Vector2(0, -placement_half_extents.y), point + Vector2(placement_half_extents.x, 0), point + Vector2(0, placement_half_extents.y), point + Vector2(-placement_half_extents.x, 0)])
		draw_polyline(polygon, color, placement_line_width)
