class_name GameSimulation
extends RefCounted
## The gameplay boundary. Positions and distances are Swift-compatible y-up
## logical points; presentation, engine input and disk access live elsewhere.

var level: Dictionary = {}
var config: Dictionary:
	get:
		return level
var level_number: int = 1
var survival_map_id: String = ""
var entry_sectors: Array[Dictionary] = []
var entities: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var corpses: Array[Dictionary] = []
var weapon_pickups: Array[Dictionary] = []
var tech_pickups: Array[Dictionary] = []
var tech: int = 0
var tech_target_id: int = 0
var corpse_target_id: int = 0
var research_ranks: Dictionary = {"capacity": 0, "reach": 0, "cooling": 0, "plating": 0}
var research_session_id: int = 0
var _research_center_id: int = 0
static var _next_research_session: int = 1
var _external_paused: bool = false
var application_suspended: bool = false
var _tech_placement_retry: float = 0.0
var _tech_route_key: Array = []
var _tech_routes: WorldNavigation
var _tech_approach_revision: int = -1
var events: Array[Dictionary] = []
var resources: int = 30
var score: int = 0
var lives: int = 3
var elapsed_time: float = 0.0
var result: String = "playing"
var paused: bool:
	get:
		return _external_paused or application_suspended or research_session_id > 0
	set(value):
		_external_paused = value
var hermes_mode: String = "following"
var focused_character: String = "nathaniel"
var wave_elapsed: float = 0.0
var wave_since_last_spawn: float = 0.0
var pending_wave_kinds: Array[String] = []
var spawn_retry_remaining: float = 0.0
var spawn_blocked_reason: String = ""
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
var _placement_route_key: Array = []
var _placement_route_error: String = ""

func configure(config: Dictionary) -> void:
	level = config.duplicate(true)
	level_number = int(level.get("number", 1))
	survival_map_id = str(level.get("survival_map_id", SurvivalMapCatalog.LEGACY_ID)) if is_survival() else ""
	if is_survival():
		level.survival_map_id = survival_map_id
	entry_sectors.clear()
	for sector: Dictionary in level.get("entry_sectors", []):
		var positions: Array[Vector2] = []
		for position: Variant in sector.get("positions", []):
			positions.append(point(position))
		entry_sectors.append({"id": str(sector.get("id", "")), "enabled": bool(sector.get("enabled", true)), "positions": positions})
	_placement_route_key.clear()
	navigation.configure(level)
	entities.clear()
	_by_id.clear()
	_enemy_units.clear()
	_friendly_units.clear()
	_shots_by_owner.clear()
	projectiles.clear()
	corpses.clear()
	weapon_pickups.clear()
	tech_pickups.clear()
	tech = 0
	tech_target_id = 0
	corpse_target_id = 0
	_tech_route_key.clear()
	_tech_routes = null
	research_ranks = {"capacity": 0, "reach": 0, "cooling": 0, "plating": 0}
	end_research()
	_tech_placement_retry = 0.0
	events.clear()
	_next_id = 1
	resources = int(level.get("starting_resources", 0 if level_number >= 4 else 30))
	lives = int(level.get("starting_lives", 0 if level_number == 0 else 3))
	score = 0
	elapsed_time = 0.0
	wave_elapsed = 0.0
	wave_since_last_spawn = 0.0
	pending_wave_kinds.clear()
	spawn_retry_remaining = 0.0
	spawn_blocked_reason = ""
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

func is_survival() -> bool:
	return level_number == 0

func pursuit_target() -> Dictionary:
	return nathaniel if CombatRules.alive(nathaniel) else (hermes if CombatRules.alive(hermes) else {})

func allocate_id() -> int:
	var id: int = _next_id
	_next_id += 1
	return id

func _add(kind: String, position: Vector2) -> Dictionary:
	var unit: Dictionary = GameBalance.create(kind, allocate_id(), position)
	if not unit.is_empty():
		_apply_tower_plating(unit)
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
	if is_survival():
		CombatRules.acquire(self, enemy)
	elif kind == "grunt":
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
	if unit.kind in ["gunTower", "laserTower", "healTower"]:
		unit.research_base_max_hp = int(parameters.get("max_hp", GameBalance.STATS[unit.kind].max_hp))
		_apply_tower_plating(unit)

func place_map_tower(kind: String, position: Vector2) -> Dictionary:
	kind = GameBalance.canonical_kind(kind)
	if kind not in GameBalance.TOWERS or not CombatRules.alive(hermes):
		return {}
	if kind == "researchCenter" and (not is_survival() or not research_center().is_empty()):
		return {}
	set_hermes_mode("building")
	var tower: Dictionary = _add(kind, position)
	tower.construction_cost = 0
	if kind == "researchCenter":
		tower.owned = true
	navigation.update_towers(entities)
	return tower

func spawn_resource(amount: int, position: Vector2, expiration: float = GameBalance.RESOURCE_LIFETIME_SECONDS, carried: bool = false, source_kind: String = "soldier") -> Dictionary:
	if amount <= 0 or not position.is_finite() or not is_finite(expiration) or not GameBalance.RESOURCE_VALUES.has(source_kind):
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
		"cargo_slot": cargo_slot, "pickup_position": position,
		"recovery_eligible": false, "recovery_route": [], "recovery_drop_position": position}
	corpses.append(corpse)
	nathaniel.has_corpse = carried_resource_count() > 0
	return corpse

func carried_resource_count() -> int:
	var count: int = 0
	for corpse: Dictionary in corpses:
		if corpse.carried:
			count += 1
	return count

func recovery_state() -> Dictionary:
	for corpse: Dictionary in corpses:
		if int(corpse.id) == int(hermes.recovery_corpse_id):
			return corpse
	return {}

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
	if is_survival() or paused or result != "playing" or not CombatRules.alive(nathaniel) or not CombatRules.alive(hermes) or cost < 0 or resources < cost:
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
	corpse_target_id = 0
	_cancel_tech_collection()
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

func external_pause_active() -> bool:
	return _external_paused

func set_application_suspended(value: bool) -> void:
	application_suspended = value

func research_center() -> Dictionary:
	for unit: Dictionary in entities:
		if unit.kind == "researchCenter" and CombatRules.alive(unit):
			return unit
	return {}

func _research_center_connected(center: Dictionary) -> bool:
	return is_survival() and result == "playing" and CombatRules.alive(nathaniel) and CombatRules.alive(hermes) and hermes_mode == "building" and CombatRules.alive(center) and center.kind == "researchCenter" and bool(center.owned) and Vector2(center.position).distance_to(hermes.position) <= hermes_build_range()

func begin_research(center_id: int) -> bool:
	if not _research_center_connected(entity(center_id)):
		return false
	if research_session_id > 0:
		return _research_center_id == center_id
	_research_center_id = center_id
	research_session_id = _next_research_session
	_next_research_session += 1
	return true

func end_research() -> void:
	research_session_id = 0
	_research_center_id = 0

func _validate_research_session() -> void:
	if research_session_id > 0 and not _research_center_connected(entity(_research_center_id)):
		end_research()

func research_state() -> Dictionary:
	_validate_research_session()
	var tracks: Array[Dictionary] = []
	for track: String in GameBalance.RESEARCH:
		var catalog: Dictionary = GameBalance.RESEARCH[track]
		var rank: int = int(research_ranks[track])
		var maximum: int = catalog.costs.size()
		var cost: int = int(catalog.costs[rank]) if rank < maximum else -1
		var reason: String = ""
		if rank == maximum:
			reason = "Fully researched"
		elif research_session_id == 0:
			reason = "Open a connected Research center"
		elif application_suspended:
			reason = "Application suspended"
		elif tech < cost:
			reason = "Need %d more Tech" % (cost - tech)
		tracks.append({"id": track, "name": catalog.name, "category": catalog.category,
			"rank": rank, "max_rank": maximum, "cost": cost, "current": catalog.values[rank],
			"next": catalog.values[mini(rank + 1, maximum)], "unit": catalog.unit,
			"available": reason.is_empty(), "reason": reason})
	return {"active": research_session_id > 0, "center_id": _research_center_id,
		"session_id": research_session_id, "tech": tech, "tracks": tracks}

func purchase_research(track: String, expected_rank: int, session_id: int = -1) -> bool:
	_validate_research_session()
	if research_session_id == 0 or application_suspended or (session_id != -1 and session_id != research_session_id) or not GameBalance.RESEARCH.has(track):
		return false
	var rank: int = int(research_ranks[track])
	var catalog: Dictionary = GameBalance.RESEARCH[track]
	if rank != expected_rank or rank >= catalog.costs.size() or tech < int(catalog.costs[rank]):
		return false
	tech -= int(catalog.costs[rank])
	research_ranks[track] = rank + 1
	_apply_research()
	emit_event("research_purchased", {"track": track, "rank": rank + 1, "center_id": _research_center_id, "position": entity(_research_center_id).position})
	return true

func _apply_tower_plating(unit: Dictionary) -> void:
	if unit.kind not in ["gunTower", "laserTower", "healTower"]:
		return
	var fraction: float = float(unit.hp) / float(unit.max_hp)
	unit.research_base_max_hp = int(unit.get("research_base_max_hp", unit.max_hp))
	unit.max_hp = roundi(int(unit.research_base_max_hp) * float(GameBalance.RESEARCH.plating.values[int(research_ranks.plating)]))
	unit.hp = maxi(1 if fraction > 0 else 0, roundi(fraction * int(unit.max_hp)))

func _apply_research() -> void:
	nathaniel.resource_capacity = GameBalance.RESOURCE_CAPACITIES[int(research_ranks.capacity)]
	nathaniel.resource_reach = GameBalance.RESOURCE_REACHES[int(research_ranks.reach)]
	_apply_hermes_weapon(false)
	for unit: Dictionary in entities:
		_apply_tower_plating(unit)

func tech_pickup(id: int) -> Dictionary:
	for pickup: Dictionary in tech_pickups:
		if int(pickup.id) == id:
			return pickup
	return {}

func tech_collection_state() -> Dictionary:
	for pickup: Dictionary in tech_pickups:
		if pickup.phase == "collect":
			return pickup
	return {}

func approach_corpse(id: int) -> bool:
	if paused or result != "playing" or not CombatRules.alive(nathaniel):
		return false
	for corpse: Dictionary in corpses:
		if int(corpse.id) == id and corpse.phase in ["loose", "grab"] and carried_resource_count() < int(nathaniel.resource_capacity):
			move_to(corpse.position)
			corpse_target_id = id
			return true
	return false

func _tech_navigation() -> WorldNavigation:
	var key: Array = [navigation.revision]
	for unit: Dictionary in entities:
		if unit.kind == "spawner" and CombatRules.alive(unit):
			key.append([unit.id, unit.position, unit.size])
	if _tech_routes != null and key == _tech_route_key:
		return _tech_routes
	_tech_route_key = key
	_tech_routes = WorldNavigation.new()
	_tech_routes.width = navigation.width
	_tech_routes.height = navigation.height
	_tech_routes.tile_size = navigation.tile_size
	_tech_routes.terrain_radius_clearance = navigation.terrain_radius_clearance
	_tech_routes.blocked = navigation.blocked
	_tech_routes.towers.assign(navigation.towers)
	for unit: Dictionary in entities:
		if unit.kind == "spawner" and CombatRules.alive(unit):
			_tech_routes.obstacle_rects.append(Rect2(Vector2(unit.position) - Vector2(unit.size) * 0.5, unit.size))
	return _tech_routes

func spawn_tech(amount: int, position: Vector2, kind: String = "module") -> Dictionary:
	if amount <= 0 or amount > 9007199254740991 or not position.is_finite() or kind not in ["module", "core"]:
		return {}
	var origin: Vector2 = position.clamp(Vector2.ONE * 5.0, Vector2(navigation.width, navigation.height) * navigation.tile_size - Vector2.ONE * 5.0)
	var pickup: Dictionary = {"id": allocate_id(), "amount": amount, "position": origin,
		"kind": kind, "phase": "deferred", "phase_elapsed": 0.0, "owner_id": 0}
	tech_pickups.append(pickup)
	if _place_tech(pickup):
		return _merge_tech(pickup)
	return pickup

func _tech_ground_clear(position: Vector2, route_navigation: WorldNavigation = null) -> bool:
	if route_navigation == null:
		route_navigation = navigation
	if not route_navigation.walkable(position, float(nathaniel.radius)):
		return false
	for unit: Dictionary in entities:
		if unit.kind == "spawner" and CombatRules.alive(unit) and BattlefieldRules.overlaps(position, Vector2.ONE * 12.0, unit.position, unit.size):
			return false
	return true

func _tech_segment_clear(start: Vector2, goal: Vector2) -> bool:
	if not navigation.segment_clear(start, goal, 4.0):
		return false
	for unit: Dictionary in entities:
		if unit.kind == "spawner" and CombatRules.alive(unit) and WorldNavigation.segment_hits_rect(start, goal, Rect2(Vector2(unit.position) - Vector2(unit.size) * 0.5, unit.size).grow(4.0)):
			return false
	return true

func _place_tech(pickup: Dictionary) -> bool:
	if not CombatRules.alive(nathaniel):
		return false
	var origin: Vector2 = pickup.position
	var routes: WorldNavigation = _tech_navigation()
	var candidates: Array[Vector2] = [origin]
	var cell: Vector2i = navigation.cell(origin)
	# Search rings in order. A blocked death retains its value until ground opens.
	for ring: int in range(1, 9):
		for y: int in range(-ring, ring + 1):
			for x: int in range(-ring, ring + 1):
				if absi(x) == ring or absi(y) == ring:
					candidates.append(navigation.center(cell + Vector2i(x, y)))
	for candidate: Vector2 in candidates:
		if navigation.terrain_clear(origin) and not navigation.swept_terrain_clear(origin, candidate, 4.0):
			continue
		if not _tech_ground_clear(candidate) or routes.route(nathaniel.position, candidate, float(nathaniel.radius)).is_empty():
			continue
		pickup.position = candidate
		pickup.phase = "loose"
		emit_event("tech_dropped", {"pickup_id": pickup.id, "position": candidate, "amount": pickup.amount, "kind": pickup.kind})
		return true
	return false

func _merge_tech(pickup: Dictionary) -> Dictionary:
	if pickup.phase != "loose":
		return pickup
	for existing: Dictionary in tech_pickups:
		if existing == pickup or existing.phase != "loose" or int(existing.id) == tech_target_id:
			continue
		if Vector2(existing.position).distance_to(pickup.position) > GameBalance.TECH_MERGE_REACH or not _tech_segment_clear(existing.position, pickup.position):
			continue
		if int(existing.amount) > 9007199254740991 - int(pickup.amount):
			continue
		existing.amount = int(existing.amount) + int(pickup.amount)
		if pickup.kind == "core":
			existing.kind = "core"
		tech_pickups.erase(pickup)
		if tech_target_id == int(pickup.id):
			tech_target_id = int(existing.id)
		return existing
	return pickup

func _matter_has_priority() -> bool:
	if nathaniel.returning_cargo:
		return true
	var rescue: bool = false
	for corpse: Dictionary in corpses:
		if int(corpse.id) == corpse_target_id and corpse.phase in ["loose", "grab"]:
			rescue = true
	if rescue:
		return true
	corpse_target_id = 0
	for corpse: Dictionary in corpses:
		if corpse.phase in ["grab", "crush", "present", "feed"]:
			return true
		if corpse.phase == "loose" and carried_resource_count() < int(nathaniel.resource_capacity) and Vector2(nathaniel.position).distance_to(corpse.position) <= float(nathaniel.resource_reach):
			return true
	return false

func _tech_in_reach(pickup: Dictionary) -> bool:
	return CombatRules.alive(nathaniel) and Vector2(nathaniel.position).distance_to(pickup.position) <= float(nathaniel.resource_reach) and _tech_segment_clear(nathaniel.position, pickup.position)

func approach_tech(id: int) -> bool:
	var pickup: Dictionary = tech_pickup(id)
	if paused or result != "playing" or not CombatRules.alive(nathaniel) or pickup.is_empty() or pickup.phase == "deferred" or _matter_has_priority():
		return false
	if tech_target_id == id:
		return true
	var route: Array[Vector2] = _tech_navigation().route(nathaniel.position, pickup.position, float(nathaniel.radius))
	if route.is_empty():
		return false
	_cancel_tech_collection()
	tech_target_id = id
	_tech_approach_revision = -1
	nathaniel.manual_fire_target = null
	_stop(nathaniel)
	_command_move(nathaniel, pickup.position)
	_update_tech_approach()
	return true

func _cancel_tech_collection() -> void:
	tech_target_id = 0
	for pickup: Dictionary in tech_pickups:
		if pickup.phase == "collect":
			pickup.phase = "loose"
			pickup.phase_elapsed = 0.0
			pickup.owner_id = 0

func _update_tech_approach() -> void:
	if tech_target_id == 0:
		return
	var pickup: Dictionary = tech_pickup(tech_target_id)
	if pickup.is_empty() or _matter_has_priority() or not CombatRules.alive(nathaniel):
		_cancel_tech_collection()
		_stop(nathaniel)
	elif _tech_in_reach(pickup):
		_stop(nathaniel)
	else:
		var routes: WorldNavigation = _tech_navigation()
		var revision: int = hash(_tech_route_key)
		if _tech_approach_revision == revision:
			return
		var route: Array[Vector2] = routes.route(nathaniel.position, pickup.position, float(nathaniel.radius))
		if route.is_empty():
			_cancel_tech_collection()
			_stop(nathaniel)
		else:
			nathaniel.path = route
			nathaniel.navigation_revision = navigation.revision
			nathaniel.direct_movement = false
			_tech_approach_revision = revision

func _update_tech(delta: float) -> void:
	_tech_placement_retry -= delta
	if _tech_placement_retry <= 0.0:
		_tech_placement_retry = GameBalance.TECH_PLACEMENT_RETRY_SECONDS
		for deferred: Dictionary in tech_pickups.duplicate():
			if deferred.phase == "deferred" and _place_tech(deferred):
				_merge_tech(deferred)
	if result != "playing" or not CombatRules.alive(nathaniel) or _matter_has_priority():
		_cancel_tech_collection()
		return
	var active: Dictionary = tech_collection_state()
	if not active.is_empty() and (not _tech_in_reach(active) or int(active.owner_id) != int(nathaniel.id)):
		_cancel_tech_collection()
		active = {}
	if active.is_empty():
		var closest: float = INF
		for pickup: Dictionary in tech_pickups:
			if pickup.phase != "loose" or not _tech_in_reach(pickup):
				continue
			var distance: float = Vector2(nathaniel.position).distance_squared_to(pickup.position)
			if distance < closest:
				active = pickup
				closest = distance
		if active.is_empty():
			return
		active.phase = "collect"
		active.owner_id = int(nathaniel.id)
		active.phase_elapsed = 0.0
	active.phase_elapsed = minf(GameBalance.TECH_COLLECTION_SECONDS, float(active.phase_elapsed) + delta)
	if float(active.phase_elapsed) + BattlefieldRules.TIMER_EPSILON < GameBalance.TECH_COLLECTION_SECONDS:
		return
	if tech > 9007199254740991 - int(active.amount):
		return
	# Removal and credit are one domain transition, before any visual callback.
	tech_pickups.erase(active)
	tech += int(active.amount)
	if tech_target_id == int(active.id):
		tech_target_id = 0
		_stop(nathaniel)
	emit_event("tech_collected", {"pickup_id": active.id, "amount": active.amount, "position": active.position, "kind": active.kind})

func _tech_access_remains(position: Vector2) -> bool:
	if tech_pickups.is_empty():
		return true
	var candidate := WorldNavigation.new()
	candidate.configure(level)
	candidate.towers.assign(navigation.towers)
	candidate.towers.append(position)
	candidate.obstacle_rects.assign(_tech_navigation().obstacle_rects)
	for pickup: Dictionary in tech_pickups:
		if pickup.phase == "deferred":
			continue
		if not _tech_ground_clear(pickup.position, candidate) or candidate.route(nathaniel.position, pickup.position, float(nathaniel.radius)).is_empty():
			return false
	return true

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
	_validate_research_session()
	if paused or result != "playing" or not is_finite(delta) or delta < 0:
		return
	elapsed_time += delta
	# Preserve GameScene's player -> waves -> enemy -> corpse -> tower order.
	_update_cargo_return()
	_update_tech_approach()
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
				var stop_distance: float = float(unit.range) * (GameBalance.BOSS_APPROACH_RANGE_RATIO if unit.kind == "boss" else 1.0)
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
	var matter_was_busy: bool = _matter_has_priority()
	BattlefieldRules.update_corpses(self, delta)
	_update_tech(0.0 if matter_was_busy else delta)
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
	if hermes_mode != "following" or not CombatRules.alive(nathaniel) or CombatRules.distance(robot, nathaniel) <= GameBalance.HERMES_FOLLOW_DISTANCE:
		_stop(robot)
		return
	if robot.destination == null or robot.follow_destination == null or Vector2(robot.follow_destination).distance_to(nathaniel.position) > GameBalance.HERMES_FOLLOW_DISTANCE:
		robot.follow_destination = nathaniel.position
		_command_move(robot, nathaniel.position)

func move_to(destination: Vector2) -> void:
	if paused or result != "playing" or not CombatRules.alive(nathaniel):
		return
	# Focusing Hermes only changes the camera. All ground commands move Nathaniel.
	nathaniel.returning_cargo = false
	corpse_target_id = 0
	_cancel_tech_collection()
	nathaniel.manual_target_id = -1
	nathaniel.manual_fire_target = null
	_stop(nathaniel)
	_command_move(nathaniel, destination)

func stop_player() -> void:
	if not nathaniel.is_empty():
		corpse_target_id = 0
		_cancel_tech_collection()
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
	if unit.kind == "nathaniel" and tech_target_id != 0:
		return _tech_navigation().route(unit.position, destination, float(unit.radius))
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
		BattlefieldRules.interrupt_recovery(self, true)
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
	if not hermes.anchored:
		hermes.delay = float(GameBalance.STATS.hermes.delay) * float(GameBalance.RESEARCH.cooling.values[int(research_ranks.cooling)])

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
	if not _tech_access_remains(position):
		return "overlapsResource"
	if is_survival() and not entry_sectors.is_empty():
		var target: Dictionary = pursuit_target()
		if not target.is_empty():
			var key: Array = [position, navigation.revision, target.position, hash(entry_sectors)]
			if key != _placement_route_key:
				_placement_route_key = key
				_placement_route_error = "valid" if navigation.entry_routes_remain(entry_sectors, target.position, position, float(GameBalance.STATS.boss.radius)) else "blocksEntryRoute"
			return _placement_route_error
	return "valid"

func place_tower(kind: String, position: Vector2) -> bool:
	kind = GameBalance.canonical_kind(kind)
	if paused or result != "playing" or kind not in GameBalance.TOWERS or not CombatRules.alive(hermes):
		return false
	if kind == "researchCenter" and (not is_survival() or not research_center().is_empty()):
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
	emit_event("death", {"entity_id": unit.id, "kind": unit.kind, "position": unit.position, "facing": unit.facing})
	if unit.enemy:
		score += int(unit.score)
		if is_survival() and GameBalance.TECH_VALUES.has(unit.kind):
			spawn_tech(int(GameBalance.TECH_VALUES[unit.kind]), unit.position, "core" if unit.kind == "spawner" else "module")
		if GameBalance.RESOURCE_VALUES.has(unit.kind):
			var corpse: Dictionary = spawn_resource(int(GameBalance.RESOURCE_VALUES[unit.kind]), unit.position, GameBalance.RESOURCE_LIFETIME_SECONDS, false, unit.kind)
			corpse.recovery_eligible = CombatRules.alive(hermes) and hermes_mode == "building" and Vector2(unit.position).distance_to(hermes.position) <= hermes_build_range()
		if unit.kind == "boss" and level_number > 0 and level.get("has_boss", true) and result == "playing":
			result = "victory"
	elif unit.tower:
		_destroy_tower(unit)
	elif unit.kind == "hermes":
		unit.anchored = false
		BattlefieldRules.interrupt_recovery(self, true)
		BattlefieldRules.interrupt_delivery(self)
		_update_cargo_return()
		_dismantle_towers(false)
		if result == "playing":
			result = "gameOver"
	elif unit.kind == "nathaniel":
		corpse_target_id = 0
		_cancel_tech_collection()
		unit.manual_fire_target = null
		unit.returning_cargo = false
		BattlefieldRules.drop_resources(self)
		if result == "playing":
			if lives > 0:
				lives -= 1
				_respawn_player()
			else:
				result = "gameOver"
	if result != "playing":
		BattlefieldRules.interrupt_recovery(self, true)
	_validate_research_session()

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
	_validate_research_session()

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
		"tech": tech, "tech_pickups": tech_pickups, "research_ranks": research_ranks, "tech_target_id": tech_target_id, "corpse_target_id": corpse_target_id,
		"projectiles": projectiles, "corpses": corpses, "weapon_pickups": weapon_pickups, "resources": resources,
		"score": score, "lives": lives, "elapsed_time": elapsed_time, "result": result,
		"hermes_mode": hermes_mode, "focused_character": focused_character,
		"wave_elapsed": wave_elapsed, "wave_since_last_spawn": wave_since_last_spawn,
		"pending_wave_kinds": pending_wave_kinds, "spawn_retry_remaining": spawn_retry_remaining,
		"fog": fog, "rng_state": str(random.state), "next_id": _next_id})

func restore(saved: Dictionary) -> bool:
	if int(saved.get("schema", 0)) != 1 or not saved.get("level") is Dictionary or not saved.get("entities") is Array:
		return false
	if int(saved.level.get("number", 1)) == 0 and not SurvivalMapCatalog.contains(str(saved.level.get("survival_map_id", SurvivalMapCatalog.LEGACY_ID))):
		return false
	if not saved.get("pending_wave_kinds", []) is Array:
		return false
	for kind: Variant in saved.get("pending_wave_kinds", []):
		if kind not in GameBalance.ENEMIES:
			return false
	if not is_finite(float(saved.get("spawn_retry_remaining", 0.0))) or float(saved.get("spawn_retry_remaining", 0.0)) < 0.0:
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
	if not research_state_error(saved).is_empty():
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
			unit.recovery_corpse_id = int(unit.get("recovery_corpse_id", 0))
			unit.recovery_cooldown = float(unit.get("recovery_cooldown", 0.0))
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
		corpse.recovery_eligible = corpse.get("recovery_eligible", false)
		corpse.recovery_drop_position = point(corpse.get("recovery_drop_position", corpse.position))
		var recovery_route: Array[Vector2] = []
		for route_point: Variant in corpse.get("recovery_route", []):
			recovery_route.append(point(route_point))
		corpse.recovery_route = recovery_route
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
	for data: Dictionary in saved.get("tech_pickups", []):
		var pickup: Dictionary = data.duplicate(true)
		pickup.position = point(pickup.position)
		tech_pickups.append(pickup)
		_next_id = maxi(_next_id, int(pickup.id) + 1)
	tech = int(saved.get("tech", 0))
	tech_target_id = int(saved.get("tech_target_id", 0))
	corpse_target_id = int(saved.get("corpse_target_id", 0))
	if saved.has("research_ranks"):
		research_ranks = saved.research_ranks.duplicate()
	elif is_survival():
		research_ranks.capacity = GameBalance.RESOURCE_CAPACITIES.find(int(nathaniel.resource_capacity))
		research_ranks.reach = GameBalance.RESOURCE_REACHES.find(float(nathaniel.resource_reach))
	resources = int(saved.get("resources", resources))
	score = int(saved.get("score", 0))
	lives = int(saved.get("lives", lives))
	elapsed_time = float(saved.get("elapsed_time", 0.0))
	result = str(saved.get("result", "playing"))
	wave_elapsed = float(saved.get("wave_elapsed", elapsed_time))
	wave_since_last_spawn = float(saved.get("wave_since_last_spawn", 0.0))
	pending_wave_kinds.assign(saved.get("pending_wave_kinds", []))
	spawn_retry_remaining = float(saved.get("spawn_retry_remaining", 0.0))
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
	if is_survival():
		_apply_research()
	if hermes_mode != "building" or not CombatRules.alive(hermes) or result != "playing":
		BattlefieldRules.interrupt_recovery(self, true)
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
		if is_survival():
			result = "gameOver"
		else:
			_respawn_player()
	if int(hermes.hp) <= 0 and result == "playing":
		result = "gameOver"
	if not CombatRules.alive(hermes):
		BattlefieldRules.interrupt_delivery(self)
	if is_survival() and result == "playing":
		for enemy: Dictionary in _enemy_units:
			CombatRules.acquire(self, enemy)
	nathaniel.has_corpse = CombatRules.alive(nathaniel) and carried_resource_count() > 0
	_update_cargo_return()
	if result != "playing" or not CombatRules.alive(nathaniel):
		_cancel_tech_collection()
	else:
		for pickup: Dictionary in tech_pickups:
			if pickup.phase == "collect" and (not _tech_in_reach(pickup) or _matter_has_priority()):
				_cancel_tech_collection()
				break
	BattlefieldRules.update_fog(self)
	events.clear()
	return true

static func research_state_error(state: Dictionary) -> String:
	if not _research_integer(state.get("tech", 0)):
		return "Invalid tech balance"
	var ranks: Variant = state.get("research_ranks", {"capacity": 0, "reach": 0, "cooling": 0, "plating": 0})
	if not ranks is Dictionary or ranks.size() != GameBalance.RESEARCH.size():
		return "Invalid research ranks"
	for track: String in GameBalance.RESEARCH:
		if not _research_integer(ranks.get(track)) or int(ranks[track]) > GameBalance.RESEARCH[track].costs.size():
			return "Invalid research rank: " + track
	var player_id: int = 0
	var center_count: int = 0
	var center: Dictionary = {}
	var robot: Dictionary = {}
	var level_data: Variant = state.get("level", {})
	if not level_data is Dictionary:
		return "Invalid research level"
	var survival: bool = int(level_data.get("number", 1)) == 0
	if not state.get("entities", []) is Array:
		return "Invalid research entities"
	for unit: Variant in state.get("entities", []):
		if not unit is Dictionary:
			return "Invalid research entity"
		if unit.get("kind") == "nathaniel":
			player_id = int(unit.get("id", 0))
			if survival and state.has("research_ranks") and (int(unit.get("resource_capacity", 1)) != GameBalance.RESOURCE_CAPACITIES[int(ranks.capacity)] or float(unit.get("resource_reach", 44.0)) != GameBalance.RESOURCE_REACHES[int(ranks.reach)]):
				return "Research ranks conflict with backpack"
		if unit.get("kind") == "researchCenter":
			if not survival or unit.get("owned") != true or unit.get("tower") != true or unit.get("enemy", false) != false:
				return "Invalid research center ownership"
			if not _finite_number(unit.get("hp")) or float(unit.hp) <= 0 or unit.get("active") != true or not _weapon_point_valid(unit.get("position")) or unit.get("weapon") != "none" or not _finite_number(unit.get("damage")) or not _finite_number(unit.get("speed")) or float(unit.damage) != 0.0 or float(unit.speed) != 0.0:
				return "Invalid research center state"
			center_count += 1
			center = unit
		if unit.get("kind") == "hermes":
			robot = unit
		if unit.has("research_base_max_hp") and (not _research_integer(unit.research_base_max_hp) or int(unit.research_base_max_hp) <= 0):
			return "Invalid tower health baseline"
		if survival and unit.get("kind") in ["gunTower", "laserTower", "healTower"] and (int(ranks.plating) > 0 or unit.has("research_base_max_hp")):
			if not unit.has("research_base_max_hp") or int(unit.get("max_hp", 0)) != roundi(int(unit.research_base_max_hp) * float(GameBalance.RESEARCH.plating.values[int(ranks.plating)])):
				return "Research ranks conflict with tower health"
	if center_count > 1:
		return "Multiple research centers"
	if center_count == 1 and (robot.is_empty() or not _finite_number(robot.get("hp")) or float(robot.hp) <= 0 or robot.get("active") != true or state.get("hermes_mode", "building") == "following" or not _weapon_point_valid(robot.get("position")) or point(robot.position).distance_to(point(center.position)) > GameBalance.HERMES_BUILD_RANGE):
		return "Research center has no living deployed owner in range"
	var target: Variant = state.get("tech_target_id", 0)
	if not _research_integer(target):
		return "Invalid tech target"
	if not state.get("tech_pickups", []) is Array:
		return "Invalid tech pickups"
	var claims: int = 0
	var target_found: bool = int(target) == 0
	var width: float = float(level_data.get("width", 30)) * float(level_data.get("tile_size", 32.0))
	var height: float = float(level_data.get("height", 30)) * float(level_data.get("tile_size", 32.0))
	for pickup: Variant in state.get("tech_pickups", []):
		if not pickup is Dictionary or not _research_integer(pickup.get("amount")) or int(pickup.amount) <= 0:
			return "Invalid tech quantity"
		if pickup.get("kind") not in ["module", "core"] or not _weapon_point_valid(pickup.get("position")):
			return "Invalid tech kind or position"
		var position: Vector2 = point(pickup.position)
		if position.x < 0 or position.y < 0 or position.x >= width or position.y >= height:
			return "Tech pickup outside level bounds"
		if pickup.get("phase") not in ["loose", "collect", "deferred"] or not _finite_number(pickup.get("phase_elapsed")):
			return "Invalid tech collection phase"
		if float(pickup.phase_elapsed) < 0 or float(pickup.phase_elapsed) > GameBalance.TECH_COLLECTION_SECONDS or not _research_integer(pickup.get("owner_id")):
			return "Invalid tech collection ownership or timer"
		if pickup.phase == "collect":
			if player_id <= 0 or int(pickup.owner_id) != player_id:
				return "Invalid tech collector"
			claims += 1
		elif int(pickup.owner_id) != 0 or float(pickup.phase_elapsed) != 0:
			return "Unclaimed tech has collection state"
		if int(pickup.get("id", 0)) == int(target):
			if pickup.phase == "deferred":
				return "Tech target has no ground placement"
			target_found = true
	if claims > 1 or not target_found:
		return "Invalid tech collection claims or target"
	if claims > 0:
		for corpse: Dictionary in state.get("corpses", []):
			if corpse.get("phase") in ["grab", "crush", "present", "feed"]:
				return "Tech collection conflicts with active matter handling"
	var corpse_target: Variant = state.get("corpse_target_id", 0)
	if not _research_integer(corpse_target):
		return "Invalid corpse approach target"
	if int(corpse_target) != 0:
		var found: bool = false
		for corpse: Dictionary in state.get("corpses", []):
			if int(corpse.get("id", 0)) == int(corpse_target):
				found = true
		if not found:
			return "Missing corpse approach target"
	return ""

static func _research_integer(value: Variant) -> bool:
	return _finite_number(value) and float(value) >= 0 and float(value) <= 9007199254740991 and float(value) == float(int(value))

static func state_id_error(state: Dictionary) -> String:
	var used_ids: Dictionary = {}
	for collection: String in ["entities", "projectiles", "corpses", "weapon_pickups", "tech_pickups"]:
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
	var recovery_id: int = 0
	var recovery_cooldown: float = 0.0
	var furnace_remaining: float = 0.0
	var hermes_position := Vector2.ZERO
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
		if item.get("kind") == "hermes":
			if not _finite_number(item.get("furnace_remaining", 0.0)) or float(item.get("furnace_remaining", 0.0)) < 0 or float(item.get("furnace_remaining", 0.0)) > GameBalance.RESOURCE_FURNACE_SECONDS:
				return "Invalid furnace timer"
			furnace_remaining = float(item.get("furnace_remaining", 0.0))
			var stored_recovery_id: Variant = item.get("recovery_corpse_id", 0)
			if not _finite_number(stored_recovery_id) or float(stored_recovery_id) != float(int(stored_recovery_id)) or int(stored_recovery_id) < 0 or int(stored_recovery_id) == 9223372036854775807:
				return "Invalid recovery owner reference"
			recovery_id = int(stored_recovery_id)
			var stored_cooldown: Variant = item.get("recovery_cooldown", 0.0)
			if not _finite_number(stored_cooldown) or float(stored_cooldown) < 0 or float(stored_cooldown) > GameBalance.HERMES_WINCH_RESET_SECONDS:
				return "Invalid recovery cooldown"
			recovery_cooldown = float(stored_cooldown)
			hermes_position = point(item.get("position"))
	var slots: Array[int] = []
	var active_count: int = 0
	var recovery_count: int = 0
	var delivery_count: int = 0
	if not state.get("corpses", []) is Array:
		return "Invalid gathering corpses"
	for item: Variant in state.get("corpses", []):
		if not item is Dictionary or not _finite_number(item.get("amount")) or float(item.amount) <= 0 or float(item.amount) != float(int(item.amount)):
			return "Invalid resource amount"
		if not item.get("carried") is bool or not _finite_number(item.get("expiration")):
			return "Invalid resource ownership or expiry"
		if not item.get("disarmed", item.carried) is bool or (item.carried and not item.get("disarmed", true)):
			return "Invalid resource disarm state"
		if not _weapon_point_valid(item.get("position")) or not GameBalance.RESOURCE_VALUES.has(item.get("source_kind", "soldier")):
			return "Invalid resource position or source"
		if not item.get("recovery_eligible", false) is bool:
			return "Invalid recovery eligibility"
		if not _weapon_point_valid(item.get("recovery_drop_position", item.position)):
			return "Invalid recovery drop position"
		var route: Variant = item.get("recovery_route", [])
		if not route is Array or route.size() > 16:
			return "Invalid recovery route"
		for route_point: Variant in route:
			if not _weapon_point_valid(route_point):
				return "Invalid recovery route point"
		if not item.has("phase"):
			for key: String in ["phase_elapsed", "cargo_slot", "pickup_position"]:
				if item.has(key):
					return "Incomplete gathering state"
			continue
		if item.phase not in ["loose", "grab", "crush", "carry", "present", "feed", "winch_launch", "winch_reel", "winch_crush", "winch_feed"]:
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
		if item.phase in ["winch_launch", "winch_reel", "winch_crush", "winch_feed"]:
			if slot != -1 or int(item.id) != recovery_id or not item.get("recovery_eligible", false):
				return "Invalid recovery ownership"
			if not item.has("recovery_drop_position"):
				return "Missing recovery drop position"
			if item.phase != "winch_launch" and not item.get("disarmed", false):
				return "Secured recovery resource must be disarmed"
			if item.phase == "winch_launch" and not item.get("disarmed", false) and float(item.expiration) <= 0:
				return "Expired recovery launch"
			if item.get("disarmed", false) and float(item.expiration) != 0.0:
				return "Disarmed recovery resource has an expiry timer"
			var expected_route: Array[Vector2] = BattlefieldRules.recovery_route(hermes_position, point(item.pickup_position))
			if route.size() != expected_route.size():
				return "Recovery route conflicts with guide path"
			var decoded_route: Array[Vector2] = []
			for index: int in route.size():
				var route_point: Vector2 = point(route[index])
				if route_point.distance_to(expected_route[index]) > 0.001:
					return "Recovery route conflicts with guide path"
				decoded_route.append(route_point)
			var recovery: Dictionary = {"phase": item.phase, "phase_elapsed": float(item.phase_elapsed),
				"pickup_position": point(item.pickup_position), "recovery_route": decoded_route}
			if point(item.position).distance_to(BattlefieldRules.recovery_position(recovery)) > 0.001:
				return "Recovery position conflicts with phase progress"
			if item.phase in ["winch_crush", "winch_feed"] and furnace_remaining > 0:
				return "Recovery intake conflicts with furnace"
			recovery_count += 1
		elif item.phase == "loose":
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
		if item.phase in ["present", "feed"]:
			delivery_count += 1
	if active_count > 1:
		return "Multiple gathering actions share one arm pair"
	if recovery_count > 1 or (recovery_id != 0) != (recovery_count == 1):
		return "Recovery owner does not match one active job"
	if recovery_count > 0 and (recovery_cooldown > 0 or delivery_count > 0):
		return "Recovery job conflicts with reset or manual intake"
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
