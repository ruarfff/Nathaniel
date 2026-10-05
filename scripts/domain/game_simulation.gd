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
var weapon_pickups: Array[Dictionary] = []
var events: Array[Dictionary] = []
var resources: int = 30
var score: int = 0
var lives: int = 3
var elapsed_time: float = 0.0
var result: String = "playing"
var paused: bool = false
var hermes_mode: String = "following"
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
	weapon_pickups.clear()
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
	hermes_mode = "following"
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
	for item: Dictionary in level.get("weapon_pickups", []):
		spawn_weapon_pickup(str(item.get("weapon_id", "")), point(item.get("position")))
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
	if kind not in GameBalance.TOWERS or not CombatRules.alive(hermes):
		return {}
	set_hermes_mode("building")
	var tower: Dictionary = _add(kind, position)
	tower.construction_cost = 0
	navigation.update_towers(entities)
	return tower

func spawn_resource(amount: int, position: Vector2, expiration: float = GameBalance.RESOURCE_LIFETIME_SECONDS, carried: bool = false, source_kind: String = "soldier") -> Dictionary:
	if amount <= 0 or not position.is_finite() or not is_finite(expiration) or source_kind not in ["soldier", "gunSoldier"]:
		return {}
	var cargo_slot: int = -1
	var disarmed: bool = carried
	if carried:
		var occupied_slots: Array[int] = []
		for existing: Dictionary in corpses:
			if int(existing.cargo_slot) >= 0:
				occupied_slots.append(int(existing.cargo_slot))
		for slot: int in int(nathaniel.resource_capacity):
			if slot not in occupied_slots:
				cargo_slot = slot
				break
		position = nathaniel.position
		carried = cargo_slot >= 0 and CombatRules.alive(nathaniel)
		if not carried:
			cargo_slot = -1
		expiration = 0.0
	var corpse: Dictionary = {"id": allocate_id(), "amount": amount,
		"position": position, "expiration": expiration, "carried": carried, "disarmed": disarmed, "source_kind": source_kind,
		"phase": "carry" if carried else "loose", "phase_elapsed": 0.0,
		"cargo_slot": cargo_slot, "pickup_position": position}
	corpses.append(corpse)
	nathaniel.has_corpse = carried_resource_count() > 0
	return corpse

func carried_resource_count() -> int:
	var count: int = 0
	for corpse: Dictionary in corpses:
		if corpse.carried:
			count += 1
	return count

func gathering_state() -> Dictionary:
	var carried: Dictionary = {}
	for corpse: Dictionary in corpses:
		if corpse.phase in ["grab", "crush", "present", "feed"]:
			return _gathering_details(corpse)
		if corpse.carried and carried.is_empty():
			carried = corpse
	return _gathering_details(carried) if not carried.is_empty() else {"phase": "idle", "elapsed": 0.0, "corpse_id": -1}

func _gathering_details(corpse: Dictionary) -> Dictionary:
	return {"phase": corpse.phase, "elapsed": corpse.phase_elapsed, "corpse_id": corpse.id,
		"cargo_slot": corpse.cargo_slot, "source_kind": corpse.source_kind,
		"pickup_position": corpse.pickup_position}

func gathering_upgrade_cost(kind: String) -> int:
	if nathaniel.is_empty():
		return -1
	var index: int = -1
	var costs: Array[int] = []
	if kind == "capacity":
		index = GameBalance.RESOURCE_CAPACITIES.find(int(nathaniel.resource_capacity))
		costs = GameBalance.RESOURCE_CAPACITY_COSTS
	elif kind == "reach":
		index = GameBalance.RESOURCE_REACHES.find(float(nathaniel.resource_reach))
		costs = GameBalance.RESOURCE_REACH_COSTS
	return costs[index] if index >= 0 and index < costs.size() else -1

func upgrade_gathering(kind: String) -> bool:
	var cost: int = gathering_upgrade_cost(kind)
	if paused or result != "playing" or not CombatRules.alive(nathaniel) or not CombatRules.alive(hermes) or cost < 0 or resources < cost:
		return false
	if kind == "capacity":
		nathaniel.resource_capacity = int(nathaniel.resource_capacity) + 1
	else:
		var index: int = GameBalance.RESOURCE_REACHES.find(float(nathaniel.resource_reach))
		nathaniel.resource_reach = GameBalance.RESOURCE_REACHES[index + 1]
	resources -= cost
	emit_event("gathering_upgrade", {"kind": kind, "cost": cost, "position": nathaniel.position})
	return true

func return_to_hermes() -> bool:
	if paused or result != "playing" or not CombatRules.alive(nathaniel) or not CombatRules.alive(hermes) or carried_resource_count() == 0:
		return false
	nathaniel.returning_cargo = true
	_stop(nathaniel)
	_update_cargo_return()
	return true

func _update_cargo_return() -> void:
	if not nathaniel.returning_cargo:
		return
	if not CombatRules.alive(nathaniel) or not CombatRules.alive(hermes) or carried_resource_count() == 0:
		nathaniel.returning_cargo = false
		_stop(nathaniel)
	elif Vector2(nathaniel.position).distance_to(hermes.position) <= GameBalance.RESOURCE_RETURN_DISTANCE:
		_stop(nathaniel)
	else:
		_command_move(nathaniel, hermes.position, GameBalance.RESOURCE_RETURN_DISTANCE)

func set_paused(value: bool) -> void:
	paused = value

func spawn_weapon_pickup(weapon_id: String, position: Vector2) -> Dictionary:
	if not GameBalance.WEAPONS.has(weapon_id) or not position.is_finite():
		return {}
	var pickup: Dictionary = {"id": allocate_id(), "weapon_id": weapon_id, "position": position}
	weapon_pickups.append(pickup)
	return pickup

func equip_weapon(weapon_id: String) -> bool:
	if paused or result != "playing" or not CombatRules.alive(nathaniel) or not GameBalance.WEAPONS.has(weapon_id) or weapon_id not in nathaniel.owned_weapon_ids:
		return false
	if nathaniel.equipped_weapon_id == weapon_id:
		return true
	nathaniel.merge(GameBalance.WEAPONS[weapon_id], true)
	nathaniel.equipped_weapon_id = weapon_id
	nathaniel.equip_ready_remaining = GameBalance.WEAPON_EQUIP_SECONDS
	nathaniel.manual_fire_target = null
	return true

func _collect_weapon_pickups() -> void:
	if not CombatRules.alive(nathaniel):
		return
	for pickup: Dictionary in weapon_pickups.duplicate():
		if Vector2(nathaniel.position).distance_to(pickup.position) > GameBalance.WEAPON_PICKUP_RADIUS:
			continue
		var newly_owned: bool = pickup.weapon_id not in nathaniel.owned_weapon_ids
		if newly_owned:
			nathaniel.owned_weapon_ids.append(pickup.weapon_id)
		weapon_pickups.erase(pickup)
		emit_event("weapon_collected", {"pickup_id": pickup.id, "weapon_id": pickup.weapon_id,
			"position": pickup.position, "newly_owned": newly_owned})

func step(delta: float) -> void:
	if paused or result != "playing" or not is_finite(delta) or delta < 0:
		return
	elapsed_time += delta
	# Preserve GameScene's player -> waves -> enemy -> corpse -> tower order.
	_update_cargo_return()
	if CombatRules.alive(nathaniel):
		_move(nathaniel, delta)
	_collect_weapon_pickups()
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
	if nathaniel.returning_cargo and carried_resource_count() == 0:
		_update_cargo_return()
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
	if robot.destination == null or robot.follow_destination == null or Vector2(robot.follow_destination).distance_to(nathaniel.position) > 100.0:
		robot.follow_destination = nathaniel.position
		_command_move(robot, nathaniel.position)

func move_to(destination: Vector2) -> void:
	if paused or result != "playing" or not CombatRules.alive(nathaniel):
		return
	# Focusing Hermes only changes the camera. All ground commands move Nathaniel.
	nathaniel.returning_cargo = false
	nathaniel.manual_target_id = -1
	nathaniel.manual_fire_target = null
	_stop(nathaniel)
	_command_move(nathaniel, destination)

func stop_player() -> void:
	if not nathaniel.is_empty():
		nathaniel.returning_cargo = false
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
	unit.moving = false
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
				break
		if proposed != position:
			unit.moving = true
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
	unit.manual_fire_target = null

func fire() -> bool:
	var target: Dictionary = entity(int(nathaniel.get("target_id", -1)))
	if paused or result != "playing" or not CombatRules.alive(target):
		return false
	return fire_at(target.position)

func fire_at(position: Vector2) -> bool:
	if paused or result != "playing" or not CombatRules.alive(nathaniel) or not position.is_finite():
		return false
	if not CombatRules.ready_to_shoot(nathaniel) or Vector2(nathaniel.position).distance_to(position) > float(nathaniel.range):
		return false
	nathaniel.manual_fire_target = position
	if CombatRules.shoot(self, nathaniel, position):
		nathaniel.manual_fire_target = null
	return true

func set_hermes_mode(mode: String) -> void:
	mode = "building" if mode in ["independent", "locked", "stopped"] else mode
	if mode not in ["building", "following"] or hermes.is_empty():
		return
	if mode != hermes_mode:
		_stop(hermes)
		hermes.follow_destination = null
		hermes_mode = mode
		_apply_hermes_weapon(true)
		emit_event("hermes_mode", {"mode": mode, "position": hermes.position, "anchored": hermes.anchored})
	if mode == "following":
		_dismantle_towers(CombatRules.alive(hermes))

func _apply_hermes_weapon(reset_phase: bool) -> void:
	hermes.anchored = hermes_mode == "building" and CombatRules.alive(hermes)
	var profile: Dictionary = GameBalance.HERMES_ANCHORED_WEAPON if hermes.anchored else GameBalance.STATS.hermes
	reset_phase = reset_phase or hermes.weapon != profile.weapon
	for key: String in ["weapon", "damage", "delay", "range", "shot_speed"]:
		if profile.has(key):
			hermes[key] = profile[key]
		else:
			hermes.erase(key)
	if reset_phase:
		hermes.cooldown = 0.0
		hermes.burst = 0.0
		hermes.pending_damage = 0.0
		hermes.firing = false

func _dismantle_towers(refund_paid: bool) -> void:
	for tower: Dictionary in entities.duplicate():
		if not tower.tower:
			continue
		var refund: int = int(tower.construction_cost) / 4 if refund_paid and tower.owned and CombatRules.alive(tower) else 0
		resources += refund
		emit_event("recycle", {"owner_id": tower.id, "kind": tower.kind, "position": tower.position, "refund": refund})
		_destroy_tower(tower)

func hermes_build_range() -> float:
	return GameBalance.HERMES_BUILD_RANGE

func placement_error(position: Vector2) -> String:
	if not CombatRules.alive(hermes):
		return "noHermes"
	if not position.is_finite():
		return "blockedByTerrain"
	if Vector2(hermes.position).distance_to(position) > hermes_build_range():
		return "outOfBuildRange"
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
	if paused or result != "playing" or kind not in GameBalance.TOWERS or not CombatRules.alive(hermes):
		return false
	var cost: int = int(GameBalance.COSTS[kind])
	if resources < cost or placement_error(position) != "valid":
		return false
	set_hermes_mode("building")
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
	var applied_damage: int = mini(int(unit.hp), amount)
	unit.hp = maxi(0, int(unit.hp) - amount)
	emit_event("hit", {"target_id": id, "attacker_id": attacker_id,
		"position": unit.position, "amount": applied_damage,
		"target_kind": unit.kind, "target_enemy": unit.enemy})
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
		if unit.kind in ["soldier", "gunSoldier"]:
			spawn_resource(10, unit.position, 10.0, false, unit.kind)
		elif unit.kind == "boss" and level_number > 0 and level.get("has_boss", true) and result == "playing":
			result = "victory"
	elif unit.tower:
		_destroy_tower(unit)
	elif unit.kind == "hermes":
		unit.anchored = false
		BattlefieldRules.interrupt_delivery(self)
		_update_cargo_return()
		_dismantle_towers(false)
		if result == "playing":
			result = "gameOver"
	elif unit.kind == "nathaniel":
		unit.manual_fire_target = null
		unit.returning_cargo = false
		BattlefieldRules.drop_resources(self)
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
	nathaniel.aim_direction = Vector2(0, -1)
	nathaniel.manual_fire_target = null
	nathaniel.returning_cargo = false
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
		"projectiles": projectiles, "corpses": corpses, "weapon_pickups": weapon_pickups, "resources": resources,
		"score": score, "lives": lives, "elapsed_time": elapsed_time, "result": result,
		"hermes_mode": hermes_mode, "focused_character": focused_character,
		"wave_elapsed": wave_elapsed, "wave_since_last_spawn": wave_since_last_spawn,
		"fog": fog, "rng_state": str(random.state), "next_id": _next_id})

func restore(saved: Dictionary) -> bool:
	if int(saved.get("schema", 0)) != 1 or not saved.get("level") is Dictionary or not saved.get("entities") is Array:
		return false
	if saved.get("hermes_mode", "building") not in ["following", "building", "independent", "locked", "stopped"]:
		return false
	if not state_id_error(saved).is_empty():
		return false
	var players: Dictionary = {}
	for item: Dictionary in saved.entities:
		if not GameBalance.STATS.has(item.get("kind", "")):
			return false
		players[item.kind] = true
	if not players.has("nathaniel") or not players.has("hermes"):
		return false
	if not weapon_state_error(saved).is_empty():
		return false
	if not gathering_state_error(saved).is_empty():
		return false
	configure(saved.level)
	entities.clear()
	_by_id.clear()
	_enemy_units.clear()
	_friendly_units.clear()
	_shots_by_owner.clear()
	projectiles.clear()
	corpses.clear()
	weapon_pickups.clear()
	_next_id = int(saved.get("next_id", 1))
	for data: Dictionary in saved.entities:
		var unit: Dictionary = GameBalance.create(data.kind, int(data.id), point(data.position))
		unit.merge(data, true)
		if unit.kind in ["soldier", "boss"] and unit.weapon in ["gun", "bow"]:
			unit.weapon = "pulse_laser"
			unit.firing = false
			unit.burst = 0.0
			unit.pending_damage = 0.0
		for key: String in ["position", "facing", "size"]:
			unit[key] = point(unit[key])
		for key: String in ["destination", "follow_destination"]:
			if unit[key] != null:
				unit[key] = point(unit[key])
		if unit.kind == "nathaniel":
			unit.owned_weapon_ids = unit.owned_weapon_ids.duplicate()
			unit.aim_direction = point(data.get("aim_direction", unit.facing)).normalized()
			if unit.aim_direction == Vector2.ZERO:
				unit.aim_direction = Vector2(0, -1)
			unit.recovery_delay = float(data.get("recovery_delay", unit.delay))
			if unit.manual_fire_target != null:
				unit.manual_fire_target = point(unit.manual_fire_target)
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
		if not shot.has("weapon_id"):
			shot.weapon_id = "rifle" if int(shot.owner_id) == _nathaniel_id else ("bow" if shot.get("kind") == "arrow" else ("blaster" if shot.get("kind") == "redbullet" else "gun"))
		add_projectile(shot)
		_next_id = maxi(_next_id, int(shot.id) + 1)
	for data: Dictionary in saved.get("corpses", []):
		var corpse: Dictionary = data.duplicate(true)
		_next_id = maxi(_next_id, int(corpse.id) + 1)
		corpse.disarmed = corpse.get("disarmed", corpse.carried)
		if corpse.disarmed:
			corpse.expiration = 0.0
		elif float(corpse.expiration) <= 0:
			continue
		corpse.source_kind = corpse.get("source_kind", "soldier")
		corpse.position = point(corpse.position)
		corpse.pickup_position = point(corpse.get("pickup_position", corpse.position))
		corpse.phase = corpse.get("phase", "carry" if corpse.carried else "loose")
		corpse.phase_elapsed = float(corpse.get("phase_elapsed", 0.0))
		corpse.cargo_slot = int(corpse.get("cargo_slot", carried_resource_count() if corpse.carried else -1))
		if corpse.phase == "grab":
			corpse.cargo_slot = -1
		if not data.has("phase") and corpse.carried and int(corpse.cargo_slot) >= int(nathaniel.resource_capacity):
			corpse.carried = false
			corpse.phase = "loose"
			corpse.position = nathaniel.position
			corpse.cargo_slot = -1
		corpses.append(corpse)
	for data: Dictionary in saved.get("weapon_pickups", []):
		var pickup: Dictionary = data.duplicate(true)
		pickup.position = point(pickup.position)
		weapon_pickups.append(pickup)
		_next_id = maxi(_next_id, int(pickup.id) + 1)
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
	hermes_mode = str(saved.get("hermes_mode", "building"))
	if hermes_mode in ["independent", "locked", "stopped"]:
		hermes_mode = "building"
	_apply_hermes_weapon(false)
	if hermes_mode == "following" or not CombatRules.alive(hermes):
		_dismantle_towers(hermes_mode == "following" and CombatRules.alive(hermes))
	else:
		_stop(hermes)
		hermes.follow_destination = null
	for unit: Dictionary in entities:
		if unit.destination != null and CombatRules.alive(unit):
			unit.path = _plan_route(unit)
			unit.navigation_revision = navigation.revision
			unit.moving = not unit.path.is_empty()
	if int(nathaniel.hp) <= 0 and result == "playing":
		# Old Swift pending respawns have already spent their spare life.
		BattlefieldRules.drop_resources(self)
		_respawn_player()
	if int(hermes.hp) <= 0 and result == "playing":
		result = "gameOver"
	if not CombatRules.alive(hermes):
		BattlefieldRules.interrupt_delivery(self)
	nathaniel.has_corpse = false
	for corpse: Dictionary in corpses:
		if corpse.carried and CombatRules.alive(nathaniel):
			nathaniel.has_corpse = true
	_update_cargo_return()
	BattlefieldRules.update_fog(self)
	events.clear()
	return true

static func state_id_error(state: Dictionary) -> String:
	var used_ids: Dictionary = {}
	for collection: String in ["entities", "projectiles", "corpses", "weapon_pickups"]:
		if not state.get(collection, []) is Array:
			return "Invalid state collection: " + collection
		for item: Variant in state.get(collection, []):
			if not item is Dictionary or not _finite_number(item.get("id")):
				return "Missing or invalid object ID: " + collection
			var id: int = int(item.id)
			if id < 1 or id == 9223372036854775807 or float(id) != float(item.id):
				return "Object ID must be a positive allocator integer: " + collection
			if used_ids.has(id):
				return "Duplicate object ID: " + collection
			used_ids[id] = true
	return ""

static func gathering_state_error(state: Dictionary) -> String:
	var capacity: int = GameBalance.RESOURCE_CAPACITIES[0]
	for item: Variant in state.get("entities", []):
		if not item is Dictionary:
			return "Invalid gathering entity"
		if item.get("kind") == "nathaniel":
			if not item.get("returning_cargo", false) is bool:
				return "Invalid cargo return intent"
			var stored_capacity: Variant = item.get("resource_capacity", capacity)
			var stored_reach: Variant = item.get("resource_reach", GameBalance.RESOURCE_REACHES[0])
			if not _finite_number(stored_capacity) or float(stored_capacity) != float(int(stored_capacity)) or stored_capacity not in GameBalance.RESOURCE_CAPACITIES:
				return "Invalid resource capacity"
			if not _finite_number(stored_reach) or stored_reach not in GameBalance.RESOURCE_REACHES:
				return "Invalid resource reach"
			capacity = int(stored_capacity)
		if item.get("kind") == "hermes" and item.has("furnace_remaining"):
			if not _finite_number(item.furnace_remaining) or float(item.furnace_remaining) < 0 or float(item.furnace_remaining) > GameBalance.RESOURCE_FURNACE_SECONDS:
				return "Invalid furnace timer"
	var slots: Array[int] = []
	var active_count: int = 0
	if not state.get("corpses", []) is Array:
		return "Invalid gathering corpses"
	for item: Variant in state.get("corpses", []):
		if not item is Dictionary or not _finite_number(item.get("amount")) or float(item.amount) <= 0 or float(item.amount) != float(int(item.amount)):
			return "Invalid resource amount"
		if not item.get("carried") is bool or not _finite_number(item.get("expiration")):
			return "Invalid resource ownership or expiry"
		if not item.get("disarmed", item.carried) is bool or (item.carried and not item.get("disarmed", true)):
			return "Invalid resource disarm state"
		if not _weapon_point_valid(item.get("position")) or item.get("source_kind", "soldier") not in ["soldier", "gunSoldier"]:
			return "Invalid resource position or source"
		if not item.has("phase"):
			for key: String in ["phase_elapsed", "cargo_slot", "pickup_position"]:
				if item.has(key):
					return "Incomplete gathering state"
			continue
		if item.phase not in ["loose", "grab", "crush", "carry", "present", "feed"]:
			return "Invalid gathering phase"
		if bool(item.carried) != (item.phase in ["crush", "carry", "present", "feed"]):
			return "Resource phase conflicts with ownership"
		if not _weapon_point_valid(item.get("pickup_position")):
			return "Invalid gathering origin"
		if not _finite_number(item.get("phase_elapsed")) or float(item.phase_elapsed) < 0 or float(item.phase_elapsed) > BattlefieldRules.phase_seconds(item.phase):
			return "Invalid gathering timer"
		if not _finite_number(item.get("cargo_slot")) or float(item.cargo_slot) != float(int(item.cargo_slot)):
			return "Invalid cargo slot"
		var slot: int = int(item.cargo_slot)
		if item.phase == "loose":
			if slot != -1:
				return "Loose resource occupies cargo slot"
		elif item.phase == "grab" and slot == -1:
			pass
		else:
			if slot < 0 or slot >= capacity or slot in slots:
				return "Invalid or duplicate occupied cargo slot"
			slots.append(slot)
		if item.phase in ["grab", "crush", "present", "feed"]:
			active_count += 1
	if active_count > 1:
		return "Multiple gathering actions share one arm pair"
	return ""

static func weapon_state_error(state: Dictionary) -> String:
	for collection: String in ["entities", "projectiles", "corpses"]:
		if not state.get(collection, []) is Array:
			return "Invalid weapon state collection"
		for item: Variant in state.get(collection, []):
			if not item is Dictionary:
				return "Invalid weapon state item"
			if collection == "projectiles" and item.has("weapon_id") and item.weapon_id not in GameBalance.WEAPONS and item.weapon_id not in ["gun", "blaster", "bow"]:
				return "Unknown projectile weapon"
			if collection != "entities" or item.get("kind") != "nathaniel":
				continue
			var owned: Variant = item.get("owned_weapon_ids", ["rifle"])
			if not owned is Array or owned.is_empty() or owned.size() > GameBalance.WEAPONS.size() or "rifle" not in owned:
				return "Invalid owned weapons"
			var seen_weapons: Dictionary = {}
			for weapon_id: Variant in owned:
				if not weapon_id is String or not GameBalance.WEAPONS.has(weapon_id) or seen_weapons.has(weapon_id):
					return "Invalid owned weapon"
				seen_weapons[weapon_id] = true
			if item.get("equipped_weapon_id", "rifle") not in owned:
				return "Equipped weapon is not owned"
			for key: String in ["equip_ready_remaining", "recovery_delay"]:
				if item.has(key) and (not _finite_number(item[key]) or float(item[key]) < 0):
					return "Invalid weapon timer: " + key
			if item.has("aim_direction") and (not _weapon_point_valid(item.aim_direction) or not is_equal_approx(point(item.aim_direction).length(), 1.0)):
				return "Invalid weapon aim direction"
			if item.get("manual_fire_target") != null and not _weapon_point_valid(item.manual_fire_target):
				return "Invalid manual fire target"
	var level_data: Variant = state.get("level", {})
	if not level_data is Dictionary:
		return "Invalid weapon pickup level"
	for source: Dictionary in [level_data, state]:
		var pickups: Variant = source.get("weapon_pickups", [])
		if not pickups is Array:
			return "Invalid weapon pickups"
		for pickup: Variant in pickups:
			if not pickup is Dictionary or not pickup.get("weapon_id") is String or not GameBalance.WEAPONS.has(pickup.weapon_id) or not _weapon_point_valid(pickup.get("position")):
				return "Invalid weapon pickup"
	return ""

static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _weapon_point_valid(value: Variant) -> bool:
	if value is Vector2 or value is Vector2i:
		return Vector2(value).is_finite()
	if value is Dictionary:
		return _finite_number(value.get("x")) and _finite_number(value.get("y"))
	if value is Array and value.size() == 2:
		return _finite_number(value[0]) and _finite_number(value[1])
	return false

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
