class_name WorldEffects
extends Node2D
## Scene-owned presentation parameters never change logical combat or placement.

const HEALING_RANGE_SEGMENTS: int = 96
const HERMES_RANGE_SEGMENTS: int = 96
## The 45-degree azimuth and 30-degree elevation project vertical distance by sqrt(2) * cos(30).
const HEIGHT_PROJECTION: float = 1.22474487139
const IMPACT_LIFETIME: float = 0.18
const CORPSE_SHADER: Shader = preload("res://scripts/presentation/corpse_self_destruct.gdshader")

@export_group("Corpses")
@export var corpse_visual: ActorVisual
@export var gun_soldier_corpse_visual: ActorVisual
@export var corpse_texture: Texture2D = preload("res://assets/Sprites/Objects/corpse.png")
@export var corpse_size := Vector2(30, 16)
@export_range(0.0, 1.0) var carried_corpse_alpha: float = 0.65

@export_group("Projectiles")
@export_range(0.1, 32.0) var projectile_radius: float = 3.0
@export var friendly_projectile_color := Color("ffd878")
@export var enemy_projectile_color := Color("ff7657")
@export_range(0.01, 0.5) var muzzle_flash_lifetime: float = 0.07

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

@export_group("Healing Recipients")
@export_range(0.1, 2.0, 0.05) var healing_flash_lifetime: float = 0.45
@export_range(0.0, 128.0) var healing_flash_height: float = 24.0
@export var healing_flash_color := Color("65e6ed")

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

@export_group("Hermes Base")
@export var hermes_range_color := Color("d9ad54")
@export var hermes_cable_color := Color("39444a")
@export var hermes_cable_band_color := Color("ba8d3e")
@export_range(2.0, 12.0, 0.5) var hermes_cable_width: float = 6.0
@export_range(0.1, 2.0, 0.05) var hermes_transfer_lifetime: float = 0.55

var simulation: GameSimulation:
	set(value):
		if simulation != value:
			_projectile_offsets.clear()
			muzzle_flashes.clear()
			transients.clear()
			healing_flashes.clear()
			hermes_transfers.clear()
			_laser_actors.clear()
			_laser_states.clear()
			_laser_pulses.clear()
			impact_flashes.clear()
			corpse_dissolves.clear()
			for sprite: Sprite2D in _corpse_sprites.values():
				sprite.queue_free()
			_corpse_sprites.clear()
			selected_healing_tower_id = -1
		simulation = value
var transients: Array[Dictionary] = []
var muzzle_flashes: Array[Dictionary] = []
var healing_flashes: Array[Dictionary] = []
var selected_healing_tower_id: int = -1
var _projectile_offsets: Dictionary = {}
var _laser_actors: Dictionary = {}
var _laser_states: Dictionary = {}
var _laser_pulses: Dictionary = {}
var _impact_visuals: Dictionary = {}
var impact_flashes: Array[Dictionary] = []
var corpse_dissolves: Array[Dictionary] = []
var _corpse_sprites: Dictionary = {}
var cursor_world := Vector2.ZERO
var placement := false
var placement_valid := false
var build_open := false
var hermes_transfers: Array[Dictionary] = []
var _hermes_ground: Node2D
var delivery_pulse_time := 0.0
var delivery_pulse_position := Vector2.ZERO
var target_pulse_id := -1
var target_pulse_time := 0.0
var fog_enabled := true


func _ready() -> void:
	_hermes_ground = Node2D.new()
	_hermes_ground.name = "HermesGroundEffects"
	_hermes_ground.z_index = -5
	_hermes_ground.draw.connect(_draw_hermes_ground)
	add_child(_hermes_ground)


func _process(delta: float) -> void:
	delivery_pulse_time = maxf(0.0, delivery_pulse_time - delta)
	target_pulse_time = maxf(0.0, target_pulse_time - delta)
	for effect: Dictionary in transients:
		effect.life -= delta
	transients = transients.filter(func(effect: Dictionary) -> bool: return effect.life > 0)
	if simulation != null and not simulation.paused and simulation.result == "playing":
		for corpse: Dictionary in corpse_dissolves:
			corpse.age = float(corpse.age) + delta
		corpse_dissolves = corpse_dissolves.filter(func(corpse: Dictionary) -> bool: return float(corpse.age) < GameBalance.RESOURCE_DISSOLVE_SECONDS)
		for id: int in _laser_states:
			_laser_states[id].age = float(_laser_states[id].age) + delta
		for impact: Dictionary in impact_flashes:
			impact.life -= delta
		impact_flashes = impact_flashes.filter(func(impact: Dictionary) -> bool: return impact.life > 0.0)
		for transfer: Dictionary in hermes_transfers:
			transfer.life -= delta
		hermes_transfers = hermes_transfers.filter(func(transfer: Dictionary) -> bool: return transfer.life > 0)
		for flash: Dictionary in muzzle_flashes:
			flash.life -= delta
		muzzle_flashes = muzzle_flashes.filter(func(flash: Dictionary) -> bool: return flash.life > 0)
		for flash: Dictionary in healing_flashes:
			flash.life -= delta
		healing_flashes = healing_flashes.filter(func(flash: Dictionary) -> bool: return flash.life > 0 and CombatRules.alive(simulation.entity(int(flash.target_id))))
	if simulation == null or not CombatRules.alive(simulation.hermes):
		hermes_transfers.clear()
	if _hermes_ground != null:
		_hermes_ground.queue_redraw()
	_sync_corpse_sprites()
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


func add_events(events: Array, actors: Dictionary = {}) -> void:
	for event: Dictionary in events:
		if event.get("type", "") == "corpse_expired":
			var age: float = float(event.get("elapsed_since_expiry", 0.0))
			if age < GameBalance.RESOURCE_DISSOLVE_SECONDS:
				corpse_dissolves.append({"id": event.corpse_id, "source_kind": event.get("source_kind", "soldier"),
					"position": event.position, "age": age})
			continue
		if event.get("type", "") == "hit":
			_add_impact(event, actors)
			continue
		if event.get("type", "") == "laser":
			if event.get("pulse", false):
				_laser_pulses[int(event.owner_id)] = event.duplicate()
			var owner: ActorView = actors.get(int(event.get("owner_id", -1))) as ActorView
			if is_instance_valid(owner) and owner.laser_visual() != null:
				continue
		if event.get("type", "") in ["build", "recycle"] and event.get("position") is Vector2:
			hermes_transfers.append({"position": event.position, "life": hermes_transfer_lifetime,
				"returning": event.type == "recycle"})
			continue
		if event.get("type", "") == "hermes_mode":
			continue
		if event.get("type", "") == "weapon_collected":
			continue
		if event.get("type", "") in ["gathering_phase", "delivery", "resource_delivered", "resource_upgrade"]:
			continue
		if event.get("type", "") == "heal":
			var target_id: int = int(event.get("target_id", -1))
			if simulation != null and CombatRules.alive(simulation.entity(target_id)):
				healing_flashes.append({"target_id": target_id, "life": healing_flash_lifetime})
			continue
		if event.get("type", "") == "shot" and event.has("shot_id") and event.get("direction") is Vector2:
			var actor: ActorView = actors.get(int(event.get("owner_id", -1))) as ActorView
			if actor != null:
				var muzzle: Vector2 = actor.weapon_muzzle(event.direction, event.get("weapon_id", ""))
				if muzzle.is_finite():
					# Capture the launch pose once. Turning the owner cannot steer an old shot.
					_projectile_offsets[int(event.shot_id)] = muzzle
					muzzle_flashes.append({"position": IsoProjection.project(event.position) + muzzle,
						"ground_position": event.position, "direction": IsoProjection.project(event.direction).normalized(),
						"life": muzzle_flash_lifetime})
					continue
		if event.has("position"):
			transients.append({"position": event.position, "life": transient_lifetime, "kind": event.get("type", "hit")})
	_sync_corpse_sprites()
	queue_redraw()


func hermes_range_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	if simulation == null or not CombatRules.alive(simulation.hermes):
		return points
	if not build_open and not simulation.hermes.get("anchored", false):
		return points
	var center: Vector2 = simulation.hermes.position
	var radius: float = simulation.hermes_build_range()
	for index: int in range(HERMES_RANGE_SEGMENTS):
		points.append(IsoProjection.project(center + Vector2.from_angle(TAU * index / HERMES_RANGE_SEGMENTS) * radius))
	points.append(points[0])
	return points


func hermes_link_paths() -> Array[PackedVector2Array]:
	var paths: Array[PackedVector2Array] = []
	if simulation == null or not CombatRules.alive(simulation.hermes) or not simulation.hermes.get("anchored", false):
		return paths
	for tower: Dictionary in simulation.entities:
		if not tower.get("tower", false) or not CombatRules.alive(tower):
			continue
		if fog_enabled and simulation.visibility_at(tower.position) != 2:
			continue
		paths.append(_hermes_cable_path(tower.position))
	return paths


func hermes_preview_path() -> PackedVector2Array:
	if not placement or not build_open or simulation == null or not CombatRules.alive(simulation.hermes) or not cursor_world.is_finite():
		return PackedVector2Array()
	return _hermes_cable_path(cursor_world)


func _hermes_cable_path(target: Vector2) -> PackedVector2Array:
	var origin: Vector2 = simulation.hermes.position
	var heading: Vector2 = origin.direction_to(target)
	var distance: float = origin.distance_to(target)
	var start: Vector2 = origin + heading * minf(25.0, distance * 0.2)
	var finish: Vector2 = target - heading * minf(18.0, distance * 0.2)
	var length: float = start.distance_to(finish)
	var bend: Vector2 = heading.orthogonal() * minf(14.0, length * 0.1)
	var count: int = maxi(2, ceili(length / 11.0))
	var points := PackedVector2Array()
	for index: int in range(count + 1):
		var fraction: float = float(index) / count
		points.append(IsoProjection.project(start.lerp(finish, fraction) + bend * sin(fraction * PI)))
	return points


func _draw_hermes_ground() -> void:
	var ring: PackedVector2Array = hermes_range_points()
	if not ring.is_empty():
		var opacity: float = 0.72 if build_open else 0.22
		_hermes_ground.draw_polyline(ring, Color("171d20", opacity * 0.7), 4.0 if build_open else 2.5, true)
		_hermes_ground.draw_polyline(ring, Color(hermes_range_color, opacity), 1.5 if build_open else 1.0, true)
		if build_open:
			for index: int in range(0, HERMES_RANGE_SEGMENTS, 8):
				var point: Vector2 = IsoProjection.unproject(ring[index])
				var direction: Vector2 = Vector2(simulation.hermes.position).direction_to(point)
				_hermes_ground.draw_line(IsoProjection.project(point - direction * 5.0), IsoProjection.project(point + direction * 5.0), Color(hermes_range_color, opacity), 2.0, true)
	for path: PackedVector2Array in hermes_link_paths():
		_draw_hermes_cable(path)
	var preview: PackedVector2Array = hermes_preview_path()
	if not preview.is_empty():
		var color: Color = valid_placement_color if placement_valid else invalid_placement_color
		for index: int in range(0, preview.size() - 1, 2):
			_hermes_ground.draw_line(preview[index], preview[index + 1], Color("171d20", 0.7), 4.0, true)
			_hermes_ground.draw_line(preview[index], preview[index + 1], color, 1.5, true)
		_draw_hermes_socket(preview[preview.size() - 1], color)
	if simulation == null or not CombatRules.alive(simulation.hermes):
		return
	for transfer: Dictionary in hermes_transfers:
		if fog_enabled and simulation.visibility_at(transfer.position) != 2:
			continue
		if not transfer.returning and not simulation.hermes.get("anchored", false):
			continue
		var path: PackedVector2Array = _hermes_cable_path(transfer.position)
		var fraction: float = clampf(1.0 - float(transfer.life) / hermes_transfer_lifetime, 0.0, 1.0)
		var offset: float = (1.0 - fraction if transfer.returning else fraction) * (path.size() - 1)
		var index: int = mini(floori(offset), path.size() - 2)
		var point: Vector2 = path[index].lerp(path[index + 1], offset - index)
		if transfer.returning:
			var remaining: PackedVector2Array = path.slice(0, index + 1)
			remaining.append(point)
			_draw_hermes_cable(remaining)
		var strength: float = sin(fraction * PI)
		_hermes_ground.draw_circle(point, 5.0, Color(hermes_cable_band_color, strength * 0.35))
		_hermes_ground.draw_circle(point, 2.2, Color("ffe6a0", strength))


func _draw_hermes_cable(path: PackedVector2Array) -> void:
	if path.size() < 2:
		return
	var shadow := PackedVector2Array()
	for point: Vector2 in path:
		shadow.append(point + Vector2(1.5, 2.5))
	_hermes_ground.draw_polyline(shadow, Color("101617", 0.4), hermes_cable_width + 2.0, true)
	_hermes_ground.draw_polyline(path, Color("151d21"), hermes_cable_width + 2.0, true)
	for index: int in range(path.size() - 1):
		var start: Vector2 = path[index].lerp(path[index + 1], 0.06)
		var finish: Vector2 = path[index].lerp(path[index + 1], 0.94)
		var color: Color = hermes_cable_band_color if index % 4 == 1 else hermes_cable_color
		_hermes_ground.draw_line(start, finish, color, hermes_cable_width, true)
		_hermes_ground.draw_line(start - Vector2(0, 1.5), finish - Vector2(0, 1.5), color.lightened(0.18), 1.0, true)
	_draw_hermes_socket(path[0], hermes_cable_band_color)
	_draw_hermes_socket(path[path.size() - 1], hermes_cable_band_color)


func _draw_hermes_socket(point: Vector2, color: Color) -> void:
	var socket := PackedVector2Array([point + Vector2(-6, 0), point + Vector2(0, -3.5), point + Vector2(6, 0), point + Vector2(0, 3.5)])
	_hermes_ground.draw_colored_polygon(socket, Color("1b252a"))
	socket.append(socket[0])
	_hermes_ground.draw_polyline(socket, color, 1.5, true)


func healing_markers() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	if simulation == null:
		return markers
	for flash: Dictionary in healing_flashes:
		var target: Dictionary = simulation.entity(int(flash.target_id))
		if not CombatRules.alive(target) or (fog_enabled and simulation.visibility_at(target.position) != 2):
			continue
		var remaining: float = clampf(float(flash.life) / healing_flash_lifetime, 0.0, 1.0)
		markers.append({"position": IsoProjection.project(target.position) - Vector2(0, healing_flash_height),
			"strength": remaining * remaining * (3.0 - 2.0 * remaining)})
	return markers


func healing_range_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	if simulation == null:
		return points
	var tower: Dictionary = simulation.entity(selected_healing_tower_id)
	if not CombatRules.alive(tower) or tower.get("kind", "") != "healTower":
		return points
	if fog_enabled and simulation.visibility_at(tower.position) != 2:
		return points
	var radius: float = float(tower.range)
	for index: int in range(HEALING_RANGE_SEGMENTS):
		var angle: float = TAU * float(index) / float(HEALING_RANGE_SEGMENTS)
		points.append(IsoProjection.project(Vector2(tower.position) + Vector2.from_angle(angle) * radius))
	points.append(points[0])
	return points


func _draw_healing_markers() -> void:
	for marker: Dictionary in healing_markers():
		var point: Vector2 = marker.position
		var strength: float = marker.strength
		var radius: float = 5.0 + 3.0 * strength
		draw_circle(point, radius * 1.6, Color(healing_flash_color, 0.12 * strength))
		draw_colored_polygon(PackedVector2Array([point - Vector2(0, radius), point + Vector2(radius * 0.4, 0),
			point + Vector2(0, radius), point - Vector2(radius * 0.4, 0)]), Color(healing_flash_color, 0.85 * strength))
		draw_line(point - Vector2(radius, 0), point + Vector2(radius, 0), Color(healing_flash_color, strength), 1.5, true)
		draw_circle(point, 1.8 * strength, Color("e7ffff", strength))


func sync_projectiles(actors: Dictionary) -> void:
	var live: Dictionary = {}
	if simulation != null:
		for shot: Dictionary in simulation.projectiles:
			var id: int = int(shot.id)
			live[id] = true
			if _projectile_offsets.has(id):
				continue
			# Saves contain logical shots, not presentation state. Rebuild from each
			# shot's direction, never the owner's current target or recoil pose.
			var actor: ActorView = actors.get(int(shot.owner_id)) as ActorView
			var muzzle: Vector2 = actor.weapon_muzzle(shot.direction, shot.get("weapon_id", "")) if actor != null else Vector2.INF
			_projectile_offsets[id] = muzzle if muzzle.is_finite() else Vector2.ZERO
	for id: int in _projectile_offsets.keys():
		if not live.has(id):
			_projectile_offsets.erase(id)
	queue_redraw()


func projectile_position(shot: Dictionary) -> Vector2:
	return IsoProjection.project(shot.position) + Vector2(_projectile_offsets.get(int(shot.id), Vector2.ZERO))


func sync_lasers(actors: Dictionary) -> void:
	_laser_actors = actors.duplicate()
	laser_beams()
	queue_redraw()


func laser_beams() -> Array[Dictionary]:
	var beams: Array[Dictionary] = []
	var active: Dictionary = {}
	if simulation == null:
		return beams
	for unit: Dictionary in simulation.entities:
		if not CombatRules.alive(unit) or unit.get("weapon", "") not in ["laser", "spawner_laser", "pulse_laser"]:
			continue
		var target: Dictionary = simulation.entity(int(unit.get("target_id", -1)))
		var pulse: bool = unit.weapon == "pulse_laser"
		var contact: Dictionary = {}
		if pulse and unit.get("firing", false):
			if not _laser_pulses.has(int(unit.id)) and CombatRules.alive(target):
				_laser_pulses[int(unit.id)] = {"target_id": target.id, "target_position": target.position, "target_kind": target.kind}
			contact = _laser_pulses.get(int(unit.id), {})
			if not contact.is_empty():
				target = simulation.entity(int(contact.target_id))
		if not CombatRules.alive(target) and contact.is_empty():
			continue
		var target_id: int = int(contact.target_id) if not contact.is_empty() else int(target.id)
		var target_kind: String = str(contact.target_kind) if not contact.is_empty() else str(target.kind)
		var target_position: Vector2 = target.position if CombatRules.alive(target) else contact.target_position
		var actor: ActorView = _laser_actors.get(int(unit.id)) as ActorView
		var style: LaserVisual = actor.laser_visual() if is_instance_valid(actor) else null
		var height: float = _contact_height(target_id, target_kind, _laser_actors)
		if style != null:
			actor.aim_laser(target_position - Vector2(unit.position), height)
		if not unit.get("firing", false):
			continue
		if simulation.visibility_at(unit.position) != 2 and (fog_enabled or style == null):
			continue
		var start: Vector2 = IsoProjection.project(unit.position) - Vector2(0, laser_height)
		var finish: Vector2 = IsoProjection.project(target_position) - Vector2(0, laser_height)
		if style != null:
			if unit.get("anchored", false) or (fog_enabled and simulation.visibility_at(target_position) != 2):
				continue
			var muzzle: Vector2 = actor.laser_muzzle()
			if not muzzle.is_finite():
				continue
			start = IsoProjection.project(unit.position) + muzzle
			finish = IsoProjection.project(target_position) - Vector2(0, height * HEIGHT_PROJECTION)
		active[int(unit.id)] = true
		if not _laser_states.has(int(unit.id)):
			_laser_states[int(unit.id)] = {"target_id": target_id, "age": float(unit.get("burst", 0.0))}
		elif int(_laser_states[int(unit.id)].target_id) != target_id:
			_laser_states[int(unit.id)] = {"target_id": target_id, "age": 0.0}
		beams.append({"owner_id": int(unit.id), "target_id": target_id, "start": start, "finish": finish,
			"style": style, "enemy": bool(unit.enemy), "age": float(unit.burst) if pulse else float(_laser_states[int(unit.id)].age)})
	for id: int in _laser_states.keys():
		if not active.has(id):
			_laser_states.erase(id)
	for id: int in _laser_pulses.keys():
		if not active.has(id):
			_laser_pulses.erase(id)
	return beams


func _contact_height(id: int, kind: String, actors: Dictionary) -> float:
	var actor: ActorView = actors.get(id) as ActorView
	if is_instance_valid(actor):
		return actor.laser_contact_height()
	if not _impact_visuals.has(kind):
		var resource_kind: String = {"gunTower": "gun_tower", "laserTower": "laser_tower", "healTower": "heal_tower", "gunSoldier": "gun_soldier"}.get(kind, kind)
		var path: String = "res://resources/actors/%s.tres" % resource_kind
		_impact_visuals[kind] = load(path) if ResourceLoader.exists(path) else null
	var visual: ActorVisual = _impact_visuals[kind] as ActorVisual
	return visual.contact_height if visual != null else 24.0


func _add_impact(event: Dictionary, actors: Dictionary) -> void:
	if simulation == null or not event.get("target_enemy", false) or not event.get("position") is Vector2:
		return
	var target_id: int = int(event.get("target_id", -1))
	var attacker_id: int = int(event.get("attacker_id", -1))
	var target: Dictionary = simulation.entity(target_id)
	var alive: bool = CombatRules.alive(target)
	for beam: Dictionary in laser_beams():
		if beam.owner_id == attacker_id and beam.target_id == target_id and beam.style != null:
			return
	var ground: Vector2 = target.position if alive else event.position
	var point: Vector2 = IsoProjection.project(ground) - Vector2(0, _contact_height(target_id, str(event.get("target_kind", "")), actors) * HEIGHT_PROJECTION)
	for impact: Dictionary in impact_flashes:
		if impact.target_id == target_id and impact.attacker_id == attacker_id:
			if not alive:
				impact.position = point
				impact.ground_position = ground
				impact.life = IMPACT_LIFETIME
			return
	impact_flashes.append({"target_id": target_id, "attacker_id": attacker_id, "position": point,
		"ground_position": ground, "life": IMPACT_LIFETIME})


func _draw_lasers() -> void:
	# Read the marker after the model's render-frame walk pose, not its last physics pose.
	for beam: Dictionary in laser_beams():
		var start: Vector2 = beam.start
		var finish: Vector2 = beam.finish
		var style: LaserVisual = beam.style
		if style == null:
			draw_line(start, finish, enemy_laser_color if beam.enemy else friendly_laser_color, laser_width, true)
			continue
		draw_line(start, finish, style.edge_color, style.edge_width, true)
		draw_line(start, finish, style.core_color, minf(style.core_width, style.edge_width), true)
		draw_circle(finish, style.contact_radius, style.edge_color)
		draw_circle(finish, style.contact_radius * 0.48, style.core_color)
		var age: float = beam.age
		if age < style.muzzle_flash_duration:
			var strength: float = 1.0 - age / maxf(0.001, style.muzzle_flash_duration)
			draw_circle(start, style.contact_radius * (0.6 + strength * 0.3), Color(style.core_color, strength))
		var phase: float = fmod(age, maxf(style.spark_interval, style.spark_duration))
		if phase < style.spark_duration:
			_draw_sparks(finish, start.direction_to(finish), phase / maxf(0.001, style.spark_duration), style.spark_length, style.edge_color, style.core_color)


func _draw_sparks(point: Vector2, direction: Vector2, elapsed: float, length: float, edge: Color, core: Color) -> void:
	var opacity: float = 1.0 - elapsed
	for angle: float in [-0.9, 0.3, 1.5]:
		var heading: Vector2 = direction.rotated(angle)
		var start: Vector2 = point + heading * (1.0 + elapsed * length * 0.7)
		var finish: Vector2 = start + heading * length * opacity
		draw_line(start, finish, Color(edge, opacity), 1.4, true)
		draw_line(start, start.lerp(finish, 0.45), Color(core, opacity), 0.6, true)


func impact_markers() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	if simulation == null:
		return markers
	for impact: Dictionary in impact_flashes:
		if fog_enabled:
			var target: Dictionary = simulation.entity(int(impact.target_id))
			if simulation.visibility_at(impact.ground_position) != 2 or simulation.visibility_at(target.get("position", impact.ground_position)) != 2:
				continue
		markers.append(impact)
	return markers


func _draw_impacts() -> void:
	for impact: Dictionary in impact_markers():
		var strength: float = clampf(float(impact.life) / IMPACT_LIFETIME, 0.0, 1.0)
		var point: Vector2 = impact.position
		draw_circle(point, 3.2 * strength, Color("fff4cd", strength))
		_draw_sparks(point, Vector2.UP, 1.0 - strength, 7.0, Color("e6ac4f"), Color("fff4cd"))


func corpse_art(source_kind: String = "soldier") -> ActorVisual:
	return gun_soldier_corpse_visual if source_kind == "gunSoldier" and gun_soldier_corpse_visual != null else corpse_visual


func corpse_rect(point: Vector2, source_kind: String = "soldier") -> Rect2:
	var visual: ActorVisual = corpse_art(source_kind)
	if visual != null and visual.texture != null:
		var density: float = visual.frame_pixel_density()
		if density > 0.0:
			return Rect2(point + visual.feet_offset - visual.frame_ground_anchor() / density, visual.texture.get_size() / density)
		return Rect2(point + visual.feet_offset - Vector2(visual.display_size.x * 0.5, visual.display_size.y), visual.display_size)
	return Rect2(point - corpse_size * 0.5, corpse_size)


func corpse_color(carried: bool, source_kind: String = "soldier") -> Color:
	var visual: ActorVisual = corpse_art(source_kind)
	var color: Color = visual.tint if visual != null and visual.texture != null else Color.WHITE
	color.a *= carried_corpse_alpha if carried else 1.0
	return color


func corpse_warning_strength(corpse: Dictionary) -> float:
	if corpse.get("disarmed", corpse.get("carried", false)):
		return 0.0
	var remaining: float = float(corpse.get("expiration", GameBalance.RESOURCE_LIFETIME_SECONDS))
	if remaining > GameBalance.RESOURCE_WARNING_SECONDS or remaining <= 0.0:
		return 0.0
	var elapsed: float = GameBalance.RESOURCE_WARNING_SECONDS - remaining
	return pow(maxf(0.0, sin(elapsed * TAU * 2.0)), 2.0)


func _sync_corpse_sprites() -> void:
	if simulation == null:
		return
	var live: Dictionary = {}
	for corpse: Dictionary in simulation.corpses:
		if ResourceGatheringView.ground_visible(corpse):
			_sync_corpse_sprite(corpse, 0.0, live)
	for corpse: Dictionary in corpse_dissolves:
		_sync_corpse_sprite(corpse, float(corpse.age) / GameBalance.RESOURCE_DISSOLVE_SECONDS, live)
	for id: int in _corpse_sprites.keys():
		if not live.has(id):
			(_corpse_sprites[id] as Sprite2D).queue_free()
			_corpse_sprites.erase(id)


func _sync_corpse_sprite(corpse: Dictionary, dissolve: float, live: Dictionary) -> void:
	var id: int = int(corpse.id)
	live[id] = true
	if not _corpse_sprites.has(id):
		var sprite := Sprite2D.new()
		sprite.name = "Corpse%d" % id
		sprite.centered = false
		sprite.z_index = -1
		var shader_material := ShaderMaterial.new()
		shader_material.shader = CORPSE_SHADER
		sprite.material = shader_material
		add_child(sprite)
		_corpse_sprites[id] = sprite
	var sprite: Sprite2D = _corpse_sprites[id]
	var source_kind: String = corpse.get("source_kind", "soldier")
	var visual: ActorVisual = corpse_art(source_kind)
	sprite.texture = visual.texture if visual != null and visual.texture != null else corpse_texture
	var rect: Rect2 = corpse_rect(IsoProjection.project(corpse.position), source_kind)
	sprite.position = rect.position
	sprite.scale = rect.size / sprite.texture.get_size()
	sprite.modulate = corpse_color(false, source_kind)
	sprite.visible = not fog_enabled or simulation.visibility_at(corpse.position) == 2
	var shader_material: ShaderMaterial = sprite.material
	shader_material.set_shader_parameter("warning", corpse_warning_strength(corpse) if dissolve <= 0.0 else 0.0)
	shader_material.set_shader_parameter("dissolve", dissolve)
	shader_material.set_shader_parameter("disarmed", bool(corpse.get("disarmed", false)))
	shader_material.set_shader_parameter("corpse_seed", float(id))


func _draw_corpse_flecks() -> void:
	for corpse: Dictionary in corpse_dissolves:
		if fog_enabled and simulation.visibility_at(corpse.position) != 2:
			continue
		var fraction: float = float(corpse.age) / GameBalance.RESOURCE_DISSOLVE_SECONDS
		var strength: float = sin(fraction * PI)
		var center: Vector2 = IsoProjection.project(corpse.position) - Vector2(0, 9)
		for index: int in range(4):
			var heading: Vector2 = Vector2.from_angle(float(index) * 2.4 + float(corpse.id))
			var point: Vector2 = center + heading * (8.0 + fraction * 13.0) - Vector2(0, fraction * 13.0)
			draw_colored_polygon(PackedVector2Array([point + Vector2(-1.5, 1), point + Vector2(0, -2), point + Vector2(2, 1)]), Color("81915c", strength * 0.8))


func _draw_crush_chips() -> void:
	for corpse: Dictionary in simulation.corpses:
		if str(corpse.get("phase", "")) != "crush" or simulation.visibility_at(corpse.position) != 2:
			continue
		var fraction: float = ResourceGatheringView.phase_fraction(corpse)
		var strength: float = sin(fraction * PI)
		var point: Vector2 = IsoProjection.project(corpse.get("pickup_position", corpse.position)) - Vector2(0, 7)
		draw_circle(point, 8.0 + fraction * 6.0, Color("b9a58a", strength * 0.20))
		for index: int in range(3):
			var heading: Vector2 = Vector2.from_angle(float(index) * 2.2 + 0.4)
			var chip: Vector2 = point + heading * (4.0 + fraction * 10.0)
			draw_line(chip, chip + heading * 2.0, Color("cabfb0", strength), 1.5, true)


func _draw() -> void:
	if simulation != null:
		var healing_range: PackedVector2Array = healing_range_points()
		if not healing_range.is_empty():
			draw_polyline(healing_range, Color(healing_flash_color, healing_flash_color.a * 0.75), 1.5, true)
		var destination: Variant = simulation.nathaniel.get("destination")
		if destination is Vector2:
			var point := IsoProjection.project(destination)
			var blocked: bool = simulation.nathaniel.direct_movement or not simulation.nathaniel.moving
			var color := invalid_placement_color if blocked else valid_placement_color
			draw_arc(point, 12, 0, TAU, 32, color, 2, true)
			if blocked:
				draw_line(point - Vector2(6, 6), point + Vector2(6, 6), color, 2, true)
				draw_line(point - Vector2(-6, 6), point + Vector2(-6, 6), color, 2, true)
		_draw_corpse_flecks()
		_draw_crush_chips()
		for shot: Dictionary in simulation.projectiles:
			if not fog_enabled or simulation.visibility_at(shot.position) == 2:
				var point := projectile_position(shot)
				draw_circle(point, projectile_radius, enemy_projectile_color if shot.enemy else friendly_projectile_color)
		for flash: Dictionary in muzzle_flashes:
			if not fog_enabled or simulation.visibility_at(flash.ground_position) == 2:
				var remaining: float = clampf(float(flash.life) / muzzle_flash_lifetime, 0.0, 1.0)
				var point: Vector2 = flash.position
				var direction: Vector2 = flash.direction
				var side: Vector2 = direction.orthogonal() * 2.5 * remaining
				draw_colored_polygon(PackedVector2Array([point - side, point + direction * (5.0 + 4.0 * remaining), point + side]), Color(friendly_projectile_color, remaining))
		_draw_lasers()
		_draw_impacts()
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
		_draw_healing_markers()
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
