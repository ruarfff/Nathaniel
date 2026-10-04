class_name WorldEffects
extends Node2D
## Scene-owned presentation parameters never change logical combat or placement.

const HEALING_RANGE_SEGMENTS: int = 96
const HERMES_RANGE_SEGMENTS: int = 96

@export_group("Corpses")
@export var corpse_visual: ActorVisual
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
			selected_healing_tower_id = -1
		simulation = value
var transients: Array[Dictionary] = []
var muzzle_flashes: Array[Dictionary] = []
var healing_flashes: Array[Dictionary] = []
var selected_healing_tower_id: int = -1
var _projectile_offsets: Dictionary = {}
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
		if event.get("type", "") in ["build", "recycle"] and event.get("position") is Vector2:
			hermes_transfers.append({"position": event.position, "life": hermes_transfer_lifetime,
				"returning": event.type == "recycle"})
			continue
		if event.get("type", "") == "hermes_mode":
			continue
		if event.get("type", "") == "weapon_collected":
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


func corpse_rect(point: Vector2) -> Rect2:
	if corpse_visual != null and corpse_visual.texture != null:
		var density: float = corpse_visual.frame_pixel_density()
		if density > 0.0:
			return Rect2(point + corpse_visual.feet_offset - corpse_visual.frame_ground_anchor() / density, corpse_visual.texture.get_size() / density)
		return Rect2(point + corpse_visual.feet_offset - Vector2(corpse_visual.display_size.x * 0.5, corpse_visual.display_size.y), corpse_visual.display_size)
	return Rect2(point - corpse_size * 0.5, corpse_size)


func corpse_color(carried: bool) -> Color:
	var color: Color = corpse_visual.tint if corpse_visual != null and corpse_visual.texture != null else Color.WHITE
	color.a *= carried_corpse_alpha if carried else 1.0
	return color


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
		for corpse: Dictionary in simulation.corpses:
			if simulation.visibility_at(corpse.position) == 2:
				var point := IsoProjection.project(corpse.position)
				var texture: Texture2D = corpse_visual.texture if corpse_visual != null and corpse_visual.texture != null else corpse_texture
				draw_texture_rect(texture, corpse_rect(point), false, corpse_color(corpse.carried))
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
