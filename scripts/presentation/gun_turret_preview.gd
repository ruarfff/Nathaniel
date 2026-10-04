extends Node2D
## Isolated art fixture. It never reads or writes player storage.

const ORIGIN := Vector2(1000, 1000)
const TARGET_DISTANCE: float = 96.0

var mouse_aim: bool = true
var target_direction := Vector2(0.83, 0.37).normalized()
var sim := GameSimulation.new()
var tower: Dictionary
var target: Dictionary
var actor: ActorView
var target_actor: ActorView
var effects: WorldEffects
var actors: Dictionary = {}
var world := Node2D.new()
var actor_layer := Node2D.new()


func _ready() -> void:
	sim.configure({"number": 0, "width": 64, "height": 64, "tile_size": 32,
		"blocked": [], "player_start": Vector2(1900, 1800), "hermes_start": Vector2(1850, 1800),
		"enemies": [], "wave_based": false})
	tower = sim.place_map_tower("gunTower", ORIGIN)
	target = sim.spawn_enemy("soldier", ORIGIN + target_direction * TARGET_DISTANCE)
	target.hp = 100000
	target.max_hp = 100000
	world.name = "World"
	add_child(world)
	actor_layer.name = "Actors"
	actor_layer.y_sort_enabled = true
	world.add_child(actor_layer)
	actor = preload("res://scenes/actors/gun_tower.tscn").instantiate()
	actor_layer.add_child(actor)
	actors[int(tower.id)] = actor
	target_actor = preload("res://scenes/actors/soldier.tscn").instantiate()
	actor_layer.add_child(target_actor)
	effects = preload("res://scenes/effects/world_effects.tscn").instantiate()
	effects.simulation = sim
	effects.fog_enabled = false
	world.add_child(effects)
	sim.take_events()
	_resize()
	get_viewport().size_changed.connect(_resize)
	update_views()


func _resize() -> void:
	var size: Vector2 = get_viewport_rect().size
	world.scale = Vector2.ONE * minf(3.0, minf(size.x / 450.0, size.y / 245.0))
	world.position = size * Vector2(0.5, 0.65) - IsoProjection.project(ORIGIN) * world.scale
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_aim and not sim.paused:
		var aim: Vector2 = IsoProjection.unproject(world.to_local(get_global_mouse_position())) - ORIGIN
		if aim.length_squared() > 4.0:
			target_direction = aim.normalized()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE and not sim.paused:
			fire()
		elif event.keycode == KEY_P:
			sim.set_paused(not sim.paused)
			update_views()


func fire() -> void:
	tower.cooldown = tower.delay
	CombatRules.shoot(sim, tower, ORIGIN + target_direction * TARGET_DISTANCE)
	update_views()


func _physics_process(delta: float) -> void:
	if not sim.paused:
		target.position = ORIGIN + target_direction * TARGET_DISTANCE
		CombatRules.update_unit(sim, tower, delta)
	update_views()


func update_views() -> void:
	actor.apply_state(tower, false, not sim.paused)
	target.facing = -target_direction
	target_actor.apply_state(target, false, not sim.paused)
	var events: Array[Dictionary] = sim.take_events()
	for event: Dictionary in events:
		if event.get("type") == "shot":
			actor.notify_attack(event.direction)
	effects.add_events(events, actors)
	effects.sync_projectiles(actors)
	queue_redraw()


func _draw() -> void:
	draw_rect(get_viewport_rect(), Color("414237"))
	if actor == null:
		return
	draw_set_transform(world.position, 0.0, world.scale)
	for index: int in range(-6, 7):
		var offset: float = index * 32.0
		draw_line(IsoProjection.project(ORIGIN + Vector2(-192, offset)), IsoProjection.project(ORIGIN + Vector2(192, offset)), Color(0.8, 0.82, 0.7, 0.13), 0.5)
		draw_line(IsoProjection.project(ORIGIN + Vector2(offset, -192)), IsoProjection.project(ORIGIN + Vector2(offset, 192)), Color(0.8, 0.82, 0.7, 0.13), 0.5)
	draw_circle(IsoProjection.project(ORIGIN), 2, Color("e6cb8b"))
	draw_set_transform(Vector2.ZERO)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(28, 40), "Gun tower · continuous turret aim", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("eee6d0"))
	draw_string(font, Vector2(28, 70), "Move pointer to aim · Space fires · P pauses", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("eee6d0"))
	draw_string(font, Vector2(28, 99), "64×32 ground grid · fixed pedestal · barrel-tip shots", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("c3c6b1"))
	if sim.paused:
		draw_string(font, Vector2(get_viewport_rect().size.x - 92, 40), "Paused", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("e6cb8b"))
