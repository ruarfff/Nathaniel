class_name GameSimulation
extends RefCounted
## The gameplay boundary. Positions and distances are Swift-compatible y-up
## logical points; presentation, engine input and disk access live elsewhere.

var level: Dictionary = {}
var config: Dictionary:
	get:
		return level
var level_number: int = 1
var entities: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var corpses: Array[Dictionary] = []
var events: Array[Dictionary] = []
var resources: int = 30
var score: int = 0
var lives: int = 3
var elapsed_time: float = 0.0
var result: String = "playing"
var paused: bool = false
var hermes_mode: String = "building"
var focused_character: String = "nathaniel"
var wave_elapsed: float = 0.0
var wave_since_last_spawn: float = 0.0
var fog: Array[int] = []
var navigation := WorldNavigation.new()
var random := RandomNumberGenerator.new()
var nathaniel: Dictionary:
	get:
		return entity(_nathaniel_id)
var hermes: Dictionary:
	get:
		return entity(_hermes_id)
var _by_id: Dictionary = {}
var _enemy_units: Array[Dictionary] = []
var _friendly_units: Array[Dictionary] = []
var _shots_by_owner: Dictionary = {}
var _next_id: int = 1
var _nathaniel_id: int = -1
var _hermes_id: int = -1
var _fog_elapsed: float = 0.0

func configure(config: Dictionary) -> void:
	level = config.duplicate(true)
	level_number = int(level.get("number", 1))
	navigation.configure(level)
	entities.clear()
	_by_id.clear()
	_enemy_units.clear()
	_friendly_units.clear()
	_shots_by_owner.clear()
	projectiles.clear()
	corpses.clear()
	events.clear()
	_next_id = 1
	resources = int(level.get("starting_resources", 0 if level_number >= 4 else 30))
	lives = int(level.get("starting_lives", 0 if level_number == 0 else 3))
	score = 0
	elapsed_time = 0.0
	wave_elapsed = 0.0
	wave_since_last_spawn = 0.0
	result = "playing"
	paused = false
	hermes_mode = "building"
	focused_character = "nathaniel"
	random.seed = int(level.get("seed", 137))
	var start: Vector2 = point(level.get("player_start", Vector2(84, 242)))
	_nathaniel_id = int(_add("nathaniel", start).id)
	_hermes_id = int(_add("hermes", point(level.get("hermes_start", start + Vector2(100, 0)))).id)
	for item: Dictionary in level.get("enemies", []):
		var enemy: Dictionary = spawn_enemy(item.kind, point(item.position))
		if not enemy.is_empty():
			apply_design_parameters(enemy, item)
	for item: Dictionary in level.get("towers", []):
		var tower: Dictionary = place_map_tower(item.kind, point(item.position))
		if not tower.is_empty():
			apply_design_parameters(tower, item)
	fog.clear()
	fog.resize(navigation.width * navigation.height)
	fog.fill(0)
	_fog_elapsed = 0.0
	BattlefieldRules.update_fog(self)

func entity(id: int) -> Dictionary:
	return _by_id.get(id, {})

func allocate_id() -> int:
	var id: int = _next_id
	_next_id += 1
	return id

func _add(kind: String, position: Vector2) -> Dictionary:
	var unit: Dictionary = GameBalance.create(kind, allocate_id(), position)
	if not unit.is_empty():
		entities.append(unit)
		_by_id[int(unit.id)] = unit
		_register_side(unit)
	return unit

func _register_side(unit: Dictionary) -> void:
	if unit.enemy:
		_enemy_units.append(unit)
	else:
		_friendly_units.append(unit)

func opponents(enemy_weapon: bool) -> Array[Dictionary]:
	return _friendly_units if enemy_weapon else _enemy_units

func shots_for_owner(id: int) -> Array[Dictionary]:
	if _shots_by_owner.has(id):
		return _shots_by_owner[id]
	return []

func add_projectile(shot: Dictionary) -> void:
	projectiles.append(shot)
	var owner_id: int = int(shot.owner_id)
	if not _shots_by_owner.has(owner_id):
		var shots: Array[Dictionary] = []
		_shots_by_owner[owner_id] = shots
	_shots_by_owner[owner_id].append(shot)

func remove_projectile(shot: Dictionary) -> void:
	projectiles.erase(shot)
	var owner_id: int = int(shot.owner_id)
	if _shots_by_owner.has(owner_id):
		_shots_by_owner[owner_id].erase(shot)
		if _shots_by_owner[owner_id].is_empty():
			_shots_by_owner.erase(owner_id)

func spawn_enemy(kind: String, position: Vector2) -> Dictionary:
	kind = GameBalance.canonical_kind(kind)
	if kind not in GameBalance.ENEMIES:
		return {}
	var enemy: Dictionary = _add(kind, position)
	if kind == "grunt":
		enemy.target_id = _nathaniel_id
	emit_event("spawn", {"kind": kind, "position": position})
	return enemy

func apply_design_parameters(unit: Dictionary, parameters: Dictionary) -> void:
	for key: String in ["max_hp", "range", "vision", "delay", "shot_speed"]:
		if parameters.has(key) and float(parameters[key]) > 0:
			unit[key] = parameters[key]
	for key: String in ["speed", "damage"]:
		if parameters.has(key) and float(parameters[key]) >= 0:
			unit[key] = parameters[key]
	unit.hp = clampi(int(parameters.get("hp", unit.max_hp)), 0, int(unit.max_hp))

func place_map_tower(kind: String, position: Vector2) -> Dictionary:
	kind = GameBalance.canonical_kind(kind)
	if kind not in GameBalance.TOWERS:
		return {}
	var tower: Dictionary = _add(kind, position)
	tower.construction_cost = 0
	navigation.update_towers(entities)
	return tower

func spawn_resource(amount: int, position: Vector2, expiration: float = 10.0, carried: bool = false) -> Dictionary:
	var corpse: Dictionary = {"id": allocate_id(), "amount": amount,
		"position": position, "expiration": expiration, "carried": carried}
	corpses.append(corpse)
	return corpse

func set_paused(value: bool) -> void:
	paused = value

func step(delta: float) -> void:
	if paused or result != "playing" or not is_finite(delta) or delta < 0:
		return
	elapsed_time += delta
	# Preserve GameScene's player -> waves -> enemy -> corpse -> tower order.
	if CombatRules.alive(nathaniel):
		_move(nathaniel, delta)
	CombatRules.update_unit(self, nathaniel, delta)
	if CombatRules.alive(hermes):
		_update_follow(hermes)
	CombatRules.update_unit(self, hermes, delta)
	if CombatRules.alive(hermes):
		_move(hermes, delta)
	BattlefieldRules.update_waves(self, delta)
	for unit: Dictionary in entities.duplicate():
		if not unit.enemy:
			continue
		CombatRules.acquire(self, unit)
		if CombatRules.alive(unit) and unit.kind != "spawner":
			var target: Dictionary = entity(int(unit.target_id))
			if CombatRules.alive(target):
				var stop_distance: float = float(unit.range) * (0.3 if unit.kind == "boss" else 1.0)
				if CombatRules.distance(unit, target) > stop_distance:
					_command_move(unit, target.position, stop_distance)
				else:
					_stop(unit)
			else:
				_stop(unit)
		BattlefieldRules.update_spawner(self, unit, delta)
		CombatRules.update_unit(self, unit, delta)
		if CombatRules.alive(unit):
			_move(unit, delta)
	BattlefieldRules.update_corpses(self, delta)
	for unit: Dictionary in entities.duplicate():
		if unit.tower:
			CombatRules.update_unit(self, unit, delta)
	_fog_elapsed += delta
	if _fog_elapsed >= 0.1:
		_fog_elapsed = 0.0
		BattlefieldRules.update_fog(self)
	_cleanup_dead()

func _update_follow(robot: Dictionary) -> void:
	if hermes_mode != "following" or not CombatRules.alive(nathaniel) or CombatRules.distance(robot, nathaniel) <= 100.0:
		_stop(robot)
		return
	if not robot.moving or robot.follow_destination == null or Vector2(robot.follow_destination).distance_to(nathaniel.position) > 100.0:
		robot.follow_destination = nathaniel.position
		_command_move(robot, nathaniel.position)

func move_to(destination: Vector2) -> void:
	if paused or result != "playing" or not CombatRules.alive(nathaniel):
		return
	# Focusing Hermes only changes the camera. All ground commands move Nathaniel.
	nathaniel.manual_target_id = -1
	_command_move(nathaniel, destination)

func move_player_direction(direction: Vector2, delta: float) -> void:
	if paused or result != "playing" or not CombatRules.alive(nathaniel):
		return
	_stop(nathaniel)
	if direction.length_squared() > 0:
		var position: Vector2 = nathaniel.position
		var destination: Vector2 = position + direction.normalized() * float(nathaniel.speed) * delta
		if navigation.segment_clear(position, destination, float(nathaniel.radius)):
			nathaniel.position = destination
			nathaniel.facing = direction.normalized()
			nathaniel.moving = true

func stop_player() -> void:
	if not nathaniel.is_empty():
		_stop(nathaniel)

func _stop(unit: Dictionary) -> void:
	unit.destination = null
	unit.path = []
	unit.moving = false
	unit.direct_movement = false

func _command_move(unit: Dictionary, destination: Vector2, arrival_range: float = 0.0) -> void:
	if unit.destination != null and Vector2(unit.destination).distance_to(destination) < navigation.tile_size * 0.5 and int(unit.navigation_revision) == navigation.revision:
		return
	unit.destination = destination
	unit.arrival_range = arrival_range
	unit.path = _plan_route(unit)
	unit.navigation_revision = navigation.revision
	unit.moving = not unit.path.is_empty()

func _plan_route(unit: Dictionary) -> Array[Vector2]:
	var destination: Vector2 = unit.destination
	var route: Array[Vector2]
	unit.direct_movement = false
	if float(unit.arrival_range) > 0 and not navigation.walkable(destination, float(unit.radius)):
		route = navigation.route_to_range(unit.position, destination, float(unit.radius), float(unit.arrival_range))
	else:
		route = navigation.route(unit.position, destination, float(unit.radius))
	if route.is_empty():
		# Swift MovementComponent falls back to direct motion with collision and
		# axis sliding when a requested destination has no complete A-star route.
		unit.direct_movement = true
		route.append(destination)
	return route

func _move(unit: Dictionary, delta: float) -> void:
	if unit.destination == null or float(unit.speed) <= 0:
		unit.moving = false
		return
	if int(unit.navigation_revision) != navigation.revision:
		unit.path = _plan_route(unit)
		unit.navigation_revision = navigation.revision
	var budget: float = float(unit.speed) * delta
	var route: Array = unit.path
	unit.moving = not route.is_empty()
	while budget > 0.0 and not route.is_empty():
		var target: Vector2 = route[0]
		var position: Vector2 = unit.position
		var separation: float = position.distance_to(target)
		var step_distance: float = minf(separation, budget)
		var proposed: Vector2 = position.move_toward(target, step_distance)
		if not navigation.segment_clear(position, proposed, float(unit.radius)):
			if unit.direct_movement:
				var slide_x := Vector2(proposed.x, position.y)
				var slide_y := Vector2(position.x, proposed.y)
				if navigation.segment_clear(position, slide_x, float(unit.radius)):
					proposed = slide_x
				elif navigation.segment_clear(position, slide_y, float(unit.radius)):
					proposed = slide_y
				else:
					break
			else:
				unit.navigation_revision = -1
				unit.moving = false
				break
		if proposed != position:
			unit.facing = (proposed - position).normalized()
		unit.position = proposed
		budget -= step_distance
		if proposed.distance_to(target) <= 0.001:
			route.pop_front()
		else:
			break
	if route.is_empty() and Vector2(unit.position).distance_to(unit.destination) <= 5.0:
		_stop(unit)

func target_enemy(id: int) -> void:
	var target: Dictionary = entity(id)
	var unit: Dictionary = nathaniel
	if paused or result != "playing" or not CombatRules.alive(target) or not target.enemy or not CombatRules.alive(unit):
		return
	if visibility_at(target.position) != 2:
		return
	unit.target_id = id
	unit.manual_target_id = id

func fire() -> bool:
	var target: Dictionary = entity(int(nathaniel.get("target_id", -1)))
	if paused or result != "playing" or not CombatRules.alive(target):
		return false
	return CombatRules.shoot(self, nathaniel, target.position)

func fire_at(position: Vector2) -> bool:
	if paused or result != "playing" or not CombatRules.alive(nathaniel):
		return false
	return CombatRules.shoot(self, nathaniel, position)

func set_hermes_mode(mode: String) -> void:
	mode = "building" if mode in ["independent", "locked", "stopped"] else mode
	if mode not in ["building", "following"] or hermes.is_empty():
		return
	if mode != hermes_mode:
		_stop(hermes)
		hermes.follow_destination = null
	hermes_mode = mode
	if mode == "following":
		for tower: Dictionary in entities.duplicate():
			if tower.tower and tower.owned and CombatRules.alive(tower):
				resources += int(tower.construction_cost) / 4
				_destroy_tower(tower)

func placement_error(position: Vector2) -> String:
	if not navigation.footprint_clear(position):
		return "blockedByTerrain"
	for unit: Dictionary in entities:
		if CombatRules.alive(unit) and BattlefieldRules.overlaps(position, Vector2(48, 48), unit.position, unit.size):
			return "overlapsStructure" if unit.tower else ("overlapsEnemy" if unit.enemy else "overlapsCharacter")
	for corpse: Dictionary in corpses:
		if BattlefieldRules.overlaps(position, Vector2(48, 48), corpse.position, Vector2(70, 60)):
			return "overlapsResource"
	return "valid"

func place_tower(kind: String, position: Vector2) -> bool:
	kind = GameBalance.canonical_kind(kind)
	if paused or result != "playing" or kind not in GameBalance.TOWERS or hermes_mode != "building" or not CombatRules.alive(hermes):
		return false
	var cost: int = int(GameBalance.COSTS[kind])
	if resources < cost or placement_error(position) != "valid":
		return false
	resources -= cost
	var tower: Dictionary = place_map_tower(kind, position)
	tower.owned = true
	tower.construction_cost = cost
	emit_event("build", {"kind": kind, "position": position})
	return true

func damage_entity(id: int, amount: int, attacker_id: int = -1) -> void:
	var unit: Dictionary = entity(id)
	if not CombatRules.alive(unit) or amount <= 0:
		return
	unit.hp = maxi(0, int(unit.hp) - amount)
	if int(unit.hp) > 0:
		if unit.enemy and not CombatRules.alive(entity(int(unit.target_id))) and CombatRules.alive(entity(attacker_id)):
			unit.target_id = attacker_id
		return
	unit.active = false
	unit.firing = false
	unit.target_id = -1
	unit.manual_target_id = -1
	_stop(unit)
	emit_event("death", {"kind": unit.kind, "position": unit.position})
	if unit.enemy:
		score += int(unit.score)
		if unit.kind == "soldier":
			spawn_resource(10, unit.position)
		elif unit.kind == "boss" and level_number > 0 and level.get("has_boss", true) and result == "playing":
			result = "victory"
	elif unit.tower:
		_destroy_tower(unit)
	elif unit.kind == "hermes":
		if result == "playing":
			result = "gameOver"
	elif unit.kind == "nathaniel":
		for corpse: Dictionary in corpses:
			if corpse.carried:
				corpse.carried = false
				corpse.expiration = 10.0
		unit.has_corpse = false
		if result == "playing":
			if lives > 0:
				lives -= 1
				_respawn_player()
			else:
				result = "gameOver"

func _respawn_player() -> void:
	nathaniel.hp = nathaniel.max_hp
	nathaniel.active = true
	nathaniel.position = point(level.get("player_start", Vector2(84, 242)))
	nathaniel.facing = Vector2(0, -1)
	nathaniel.target_id = -1
	nathaniel.manual_target_id = -1
	_stop(nathaniel)
	focused_character = "nathaniel"
	emit_event("respawn", {"position": nathaniel.position})

func _destroy_tower(tower: Dictionary) -> void:
	tower.hp = 0
	tower.active = false
	tower.firing = false
	for projectile: Dictionary in projectiles.duplicate():
		if int(projectile.owner_id) == int(tower.id):
			remove_projectile(projectile)
	entities.erase(tower)
	_friendly_units.erase(tower)
	_by_id.erase(int(tower.id))
	navigation.update_towers(entities)

func _cleanup_dead() -> void:
	var shooters: Dictionary = {}
	for shot: Dictionary in projectiles:
		shooters[int(shot.owner_id)] = true
	for unit: Dictionary in entities.duplicate():
		if unit.enemy and int(unit.hp) <= 0 and not shooters.has(int(unit.id)):
			entities.erase(unit)
			_enemy_units.erase(unit)
			_by_id.erase(int(unit.id))

func visibility_at(position: Vector2) -> int:
	var at: Vector2i = navigation.cell(position)
	at.x = clampi(at.x, 0, navigation.width - 1)
	at.y = clampi(at.y, 0, navigation.height - 1)
	return fog[at.y * navigation.width + at.x] if not fog.is_empty() else 0

func emit_event(type: String, details: Dictionary = {}) -> void:
	var event: Dictionary = details.duplicate()
	event.type = type
	events.append(event)
	if events.size() > 256:
		events.pop_front()

func take_events() -> Array[Dictionary]:
	var pending: Array[Dictionary] = events.duplicate()
	events.clear()
	return pending

func snapshot() -> Dictionary:
	return encode({"schema": 1, "level": level, "entities": entities,
		"projectiles": projectiles, "corpses": corpses, "resources": resources,
		"score": score, "lives": lives, "elapsed_time": elapsed_time, "result": result,
		"hermes_mode": hermes_mode, "focused_character": focused_character,
		"wave_elapsed": wave_elapsed, "wave_since_last_spawn": wave_since_last_spawn,
		"fog": fog, "rng_state": str(random.state), "next_id": _next_id})

func restore(saved: Dictionary) -> bool:
	if int(saved.get("schema", 0)) != 1 or not saved.get("level") is Dictionary or not saved.get("entities") is Array:
		return false
	var seen: Dictionary = {}
	var players: Dictionary = {}
	for item: Variant in saved.entities:
		if not item is Dictionary or not GameBalance.STATS.has(item.get("kind", "")) or seen.has(int(item.get("id", -1))):
			return false
		seen[int(item.id)] = true
		players[item.kind] = true
	if not players.has("nathaniel") or not players.has("hermes"):
		return false
	configure(saved.level)
	entities.clear()
	_by_id.clear()
	_enemy_units.clear()
	_friendly_units.clear()
	_shots_by_owner.clear()
	projectiles.clear()
	corpses.clear()
	_next_id = int(saved.get("next_id", 1))
	for data: Dictionary in saved.entities:
		var unit: Dictionary = GameBalance.create(data.kind, int(data.id), point(data.position))
		unit.merge(data, true)
		for key: String in ["position", "facing", "size"]:
			unit[key] = point(unit[key])
		for key: String in ["destination", "follow_destination"]:
			if unit[key] != null:
				unit[key] = point(unit[key])
		unit.path = []
		unit.navigation_revision = -1
		entities.append(unit)
		_by_id[int(unit.id)] = unit
		_register_side(unit)
		_next_id = maxi(_next_id, int(unit.id) + 1)
		if unit.kind == "nathaniel":
			_nathaniel_id = int(unit.id)
		elif unit.kind == "hermes":
			_hermes_id = int(unit.id)
	for data: Dictionary in saved.get("projectiles", []):
		var shot: Dictionary = data.duplicate(true)
		shot.position = point(shot.position)
		shot.direction = point(shot.direction)
		add_projectile(shot)
		_next_id = maxi(_next_id, int(shot.id) + 1)
	for data: Dictionary in saved.get("corpses", []):
		var corpse: Dictionary = data.duplicate(true)
		corpse.position = point(corpse.position)
		corpses.append(corpse)
		_next_id = maxi(_next_id, int(corpse.id) + 1)
	resources = int(saved.get("resources", resources))
	score = int(saved.get("score", 0))
	lives = int(saved.get("lives", lives))
	elapsed_time = float(saved.get("elapsed_time", 0.0))
	result = str(saved.get("result", "playing"))
	wave_elapsed = float(saved.get("wave_elapsed", elapsed_time))
	wave_since_last_spawn = float(saved.get("wave_since_last_spawn", 0.0))
	focused_character = str(saved.get("focused_character", "nathaniel"))
	if saved.has("rng_state"):
		random.state = int(saved.rng_state)
	var stored_fog: Array = saved.get("fog", [])
	if stored_fog.size() == fog.size():
		for index: int in fog.size():
			fog[index] = clampi(int(stored_fog[index]), 0, 2)
	navigation.update_towers(entities)
	set_hermes_mode(str(saved.get("hermes_mode", "building")))
	for unit: Dictionary in entities:
		if unit.destination != null and CombatRules.alive(unit):
			unit.path = _plan_route(unit)
			unit.navigation_revision = navigation.revision
			unit.moving = not unit.path.is_empty()
	if int(nathaniel.hp) <= 0 and result == "playing":
		# Old Swift pending respawns have already spent their spare life.
		_respawn_player()
	if int(hermes.hp) <= 0 and result == "playing":
		result = "gameOver"
	nathaniel.has_corpse = false
	for corpse: Dictionary in corpses:
		if corpse.carried and CombatRules.alive(nathaniel):
			nathaniel.has_corpse = true
	BattlefieldRules.update_fog(self)
	events.clear()
	return true

static func point(value: Variant) -> Vector2:
	if value is Vector2 or value is Vector2i:
		return Vector2(value)
	if value is Dictionary:
		return Vector2(float(value.get("x", 0)), float(value.get("y", 0)))
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO

static func encode(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i:
		return {"x": value.x, "y": value.y}
	if value is Dictionary:
		var output: Dictionary = {}
		for key: Variant in value:
			# Cached navigation is rebuilt from the requested goal on restore.
			if key not in ["path", "navigation_revision"]:
				output[str(key)] = encode(value[key])
		return output
	if value is Array:
		var output: Array = []
		for item: Variant in value:
			output.append(encode(item))
		return output
	return value
