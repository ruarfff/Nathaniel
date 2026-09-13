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


func _process(delta: float) -> void:
	for effect: Dictionary in transients:
		effect.life -= delta
	transients = transients.filter(func(effect: Dictionary) -> bool: return effect.life > 0)
	queue_redraw()


func add_events(events: Array) -> void:
	for event: Dictionary in events:
		if event.has("position"):
			transients.append({"position": event.position, "life": transient_lifetime, "kind": event.get("type", "hit")})


func _draw() -> void:
	if simulation != null:
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
