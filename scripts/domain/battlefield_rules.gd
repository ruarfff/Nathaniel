class_name BattlefieldRules
extends RefCounted
## Corpse delivery, fog and original time-based wave/spawner cadence.

# Repeated frame subtraction can leave a tiny residue at a shared deadline.
const TIMER_EPSILON: float = 0.000000000001

static func update_corpses(sim: GameSimulation, delta: float) -> void:
	if sim.result != "playing":
		interrupt_recovery(sim, true)
		return
	if not CombatRules.alive(sim.nathaniel):
		drop_resources(sim)
	var remaining: float = delta
	while true:
		var recovery: Dictionary = _prepare_recovery(sim)
		var active: Dictionary = _prepare_gathering(sim)
		var tick: float = remaining
		if not active.is_empty():
			tick = minf(tick, maxf(0.0, phase_seconds(active.phase) - float(active.phase_elapsed)))
		if not recovery.is_empty():
			tick = minf(tick, maxf(0.0, phase_seconds(recovery.phase) - float(recovery.phase_elapsed)))
		if float(sim.hermes.recovery_cooldown) > 0:
			tick = minf(tick, float(sim.hermes.recovery_cooldown))
		if float(sim.hermes.furnace_remaining) > 0:
			tick = minf(tick, float(sim.hermes.furnace_remaining))
		for corpse: Dictionary in sim.corpses:
			if not corpse.disarmed:
				tick = minf(tick, maxf(0.0, float(corpse.expiration)))
		sim.hermes.recovery_cooldown = maxf(0.0, float(sim.hermes.recovery_cooldown) - tick)
		for corpse: Dictionary in sim.corpses.duplicate():
			if corpse.carried:
				corpse.position = sim.nathaniel.position
			if not corpse.disarmed:
				corpse.expiration = float(corpse.expiration) - tick
				if float(corpse.expiration) <= TIMER_EPSILON:
					sim.emit_event("corpse_expired", {"corpse_id": corpse.id,
						"source_kind": corpse.source_kind, "position": corpse.position,
						"elapsed_since_expiry": maxf(0.0, remaining - tick)})
					sim.corpses.erase(corpse)
					if corpse == active:
						active = {}
					if corpse == recovery:
						recovery = {}
						sim.hermes.recovery_corpse_id = 0
						sim.hermes.recovery_cooldown = GameBalance.HERMES_WINCH_RESET_SECONDS
		sim.hermes.furnace_remaining = maxf(0.0, float(sim.hermes.furnace_remaining) - tick)
		if not active.is_empty():
			active.phase_elapsed = float(active.phase_elapsed) + tick
		if not recovery.is_empty():
			recovery.phase_elapsed = float(recovery.phase_elapsed) + tick
			_update_recovery_position(sim, recovery)
		# A winch which becomes ready at this boundary still wins before grip.
		_prepare_recovery(sim)
		if not recovery.is_empty() and sim.corpses.has(recovery) and float(recovery.phase_elapsed) + TIMER_EPSILON >= phase_seconds(recovery.phase):
			_finish_recovery_phase(sim, recovery)
		if not active.is_empty() and active.phase in ["grab", "crush", "present", "feed"]:
			if float(active.phase_elapsed) + TIMER_EPSILON >= phase_seconds(active.phase):
				_finish_gathering_phase(sim, active)
		remaining -= tick
		if remaining <= 0:
			break
	_update_carry_flag(sim)

static func phase_seconds(phase: String) -> float:
	match phase:
		"grab": return GameBalance.RESOURCE_GRAB_SECONDS
		"crush": return GameBalance.RESOURCE_CRUSH_SECONDS
		"present": return GameBalance.RESOURCE_PRESENT_SECONDS
		"feed": return GameBalance.RESOURCE_FEED_SECONDS
		"winch_launch": return GameBalance.HERMES_WINCH_LAUNCH_SECONDS + GameBalance.HERMES_WINCH_CLAMP_SECONDS
		"winch_reel": return GameBalance.HERMES_WINCH_REEL_SECONDS
		"winch_crush": return GameBalance.HERMES_WINCH_CRUSH_SECONDS
		"winch_feed": return GameBalance.HERMES_WINCH_FEED_SECONDS
	return 0.0

static func _set_phase(sim: GameSimulation, corpse: Dictionary, phase: String) -> void:
	corpse.phase = phase
	corpse.phase_elapsed = 0.0
	sim.emit_event("gathering_phase", {"corpse_id": corpse.id, "phase": phase,
		"source_kind": corpse.source_kind, "position": corpse.position})

static func _prepare_gathering(sim: GameSimulation) -> Dictionary:
	var player: Dictionary = sim.nathaniel
	var can_deliver: bool = CombatRules.alive(player) and CombatRules.alive(sim.hermes) and Vector2(player.position).distance_to(sim.hermes.position) <= GameBalance.RESOURCE_DELIVERY_REACH
	var cargo_count: int = 0
	var delivery: Dictionary = {}
	var nearest: Dictionary = {}
	var nearest_distance: float = INF
	for corpse: Dictionary in sim.corpses:
		if corpse.carried:
			corpse.position = player.position
			cargo_count += 1
		if corpse.phase == "grab" and Vector2(player.position).distance_to(corpse.position) > float(player.resource_reach):
			corpse.cargo_slot = -1
			_set_phase(sim, corpse, "loose")
		if corpse.phase in ["present", "feed"] and not can_deliver:
			_set_phase(sim, corpse, "carry")
		if corpse.phase in ["grab", "crush", "present", "feed"]:
			return corpse
		if corpse.phase == "carry" and delivery.is_empty():
			delivery = corpse
		if corpse.phase == "loose" and (corpse.disarmed or float(corpse.expiration) > 0):
			var distance: float = Vector2(player.position).distance_to(corpse.position)
			if distance <= float(player.resource_reach) and distance < nearest_distance:
				nearest = corpse
				nearest_distance = distance
	if not CombatRules.alive(player):
		return {}
	if can_deliver and not delivery.is_empty() and float(sim.hermes.furnace_remaining) <= 0 and int(sim.hermes.recovery_corpse_id) == 0:
		_set_phase(sim, delivery, "present")
		return delivery
	if cargo_count < int(player.resource_capacity) and not nearest.is_empty():
		nearest.pickup_position = nearest.position
		_set_phase(sim, nearest, "grab")
		return nearest
	return {}

static func _finish_gathering_phase(sim: GameSimulation, corpse: Dictionary) -> void:
	match corpse.phase:
		"grab":
			var player: Dictionary = sim.nathaniel
			var slot: int = _available_cargo_slot(sim)
			if not CombatRules.alive(player) or Vector2(player.position).distance_to(corpse.position) > float(player.resource_reach) or slot < 0 or (not corpse.disarmed and float(corpse.expiration) <= 0):
				corpse.cargo_slot = -1
				_set_phase(sim, corpse, "loose")
				return
			corpse.cargo_slot = slot
			corpse.carried = true
			corpse.disarmed = true
			corpse.expiration = 0.0
			corpse.position = player.position
			_set_phase(sim, corpse, "crush")
		"crush":
			_set_phase(sim, corpse, "carry")
		"present":
			_set_phase(sim, corpse, "feed")
		"feed":
			sim.resources += int(corpse.amount)
			sim.corpses.erase(corpse)
			sim.hermes.furnace_remaining = GameBalance.RESOURCE_FURNACE_SECONDS
			sim.emit_event("delivery", {"amount": corpse.amount, "position": sim.hermes.position,
				"corpse_id": corpse.id, "source_kind": corpse.source_kind})

static func _available_cargo_slot(sim: GameSimulation) -> int:
	var occupied_slots: Array[int] = []
	for corpse: Dictionary in sim.corpses:
		if corpse.carried:
			occupied_slots.append(int(corpse.cargo_slot))
	for slot: int in int(sim.nathaniel.resource_capacity):
		if slot not in occupied_slots:
			return slot
	return -1

static func drop_resources(sim: GameSimulation) -> void:
	for corpse: Dictionary in sim.corpses:
		if str(corpse.phase).begins_with("winch_"):
			continue
		if corpse.carried:
			corpse.position = sim.nathaniel.position
			corpse.carried = false
		if corpse.phase != "loose":
			corpse.cargo_slot = -1
			_set_phase(sim, corpse, "loose")
	_update_carry_flag(sim)

static func interrupt_delivery(sim: GameSimulation) -> void:
	for corpse: Dictionary in sim.corpses:
		if corpse.phase in ["present", "feed"]:
			_set_phase(sim, corpse, "carry")
	sim.hermes.furnace_remaining = 0.0

static func _prepare_recovery(sim: GameSimulation) -> Dictionary:
	if not CombatRules.alive(sim.hermes) or sim.hermes_mode != "building" or sim.result != "playing":
		interrupt_recovery(sim, true)
		return {}
	var current: Dictionary = sim.recovery_state()
	if not current.is_empty():
		if (current.phase == "winch_launch" and (Vector2(current.position).distance_to(sim.hermes.position) > sim.hermes_build_range() or not _drop_position_clear(sim, current.position, _recovery_radius(current)))) or sim.visibility_at(current.position) != 2 or not _recovery_route_clear(sim, current):
			interrupt_recovery(sim)
			return {}
		return current
	if float(sim.hermes.recovery_cooldown) > TIMER_EPSILON:
		return {}
	var intake_reachable: bool = CombatRules.alive(sim.nathaniel) and Vector2(sim.nathaniel.position).distance_to(sim.hermes.position) <= GameBalance.RESOURCE_DELIVERY_REACH
	for corpse: Dictionary in sim.corpses:
		if corpse.phase in ["present", "feed"] or (corpse.carried and intake_reachable):
			return {}
	var candidate: Dictionary = {}
	var selected_route: Array[Vector2] = []
	for corpse: Dictionary in sim.corpses:
		if not corpse.get("recovery_eligible", false) or corpse.carried or corpse.phase not in ["loose", "grab"]:
			continue
		if not corpse.disarmed and float(corpse.expiration) <= TIMER_EPSILON:
			continue
		if Vector2(corpse.position).distance_to(sim.hermes.position) > sim.hermes_build_range() or sim.visibility_at(corpse.position) != 2:
			continue
		if not _drop_position_clear(sim, corpse.position, _recovery_radius(corpse)):
			continue
		var route: Array[Vector2] = recovery_route(sim.hermes.position, corpse.position)
		if not _route_clear(sim, route, _recovery_radius(corpse)):
			continue
		if candidate.is_empty() or _recovery_precedes(sim, corpse, candidate):
			candidate = corpse
			selected_route = route
	if candidate.is_empty():
		return {}
	# Replace only this body's pre-grip reservation. Held cargo and orders stay intact.
	candidate.cargo_slot = -1
	candidate.pickup_position = candidate.position
	candidate.recovery_drop_position = candidate.position
	candidate.recovery_route = selected_route
	sim.hermes.recovery_corpse_id = int(candidate.id)
	_set_phase(sim, candidate, "winch_launch")
	return candidate

static func _recovery_precedes(sim: GameSimulation, first: Dictionary, second: Dictionary) -> bool:
	if bool(first.disarmed) != bool(second.disarmed):
		return not first.disarmed
	if not first.disarmed and float(first.expiration) != float(second.expiration):
		return float(first.expiration) < float(second.expiration)
	var first_distance: float = Vector2(first.position).distance_squared_to(sim.hermes.position)
	var second_distance: float = Vector2(second.position).distance_squared_to(sim.hermes.position)
	return first_distance < second_distance if first_distance != second_distance else int(first.id) < int(second.id)

static func _recovery_radius(corpse: Dictionary) -> float:
	return 22.0 if corpse.source_kind == "boss" else 12.0

static func recovery_route(center: Vector2, origin: Vector2) -> Array[Vector2]:
	var direction: Vector2 = (origin - center).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var angle: float = direction.angle()
	var route: Array[Vector2] = [origin, center + direction * GameBalance.HERMES_WINCH_GUIDE_RADIUS]
	var turns: int = maxi(1, ceili(absf(angle) / (PI / 8.0)))
	for index: int in range(1, turns + 1):
		route.append(center + Vector2.from_angle(lerpf(angle, 0.0, float(index) / turns)) * GameBalance.HERMES_WINCH_GUIDE_RADIUS)
	route.append(center + GameBalance.HERMES_WINCH_INTAKE_OFFSET)
	return route

static func _pull_segment_clear(sim: GameSimulation, start: Vector2, goal: Vector2, radius: float) -> bool:
	if not sim.navigation.swept_terrain_clear(start, goal, radius):
		return false
	for unit: Dictionary in sim.entities:
		if not CombatRules.alive(unit):
			continue
		if unit.tower:
			if Geometry2D.get_closest_point_to_segment(unit.position, start, goal).distance_to(unit.position) <= 24.0 + radius:
				return false
		elif unit.kind == "spawner":
			if WorldNavigation.segment_hits_rect(start, goal, Rect2(Vector2(unit.position) - Vector2(unit.size) * 0.5, unit.size).grow(radius)):
				return false
	return true

static func _route_clear(sim: GameSimulation, route: Array[Vector2], radius: float) -> bool:
	for index: int in range(1, route.size()):
		# The intake plates compress the shell on the final authored leg.
		if index == route.size() - 1:
			var start: Vector2 = route[index - 1]
			var end: Vector2 = route[index]
			var steps: int = maxi(1, ceili(start.distance_to(end) / 8.0))
			for step: int in steps:
				var first: float = float(step) / steps
				var last: float = float(step + 1) / steps
				if not _pull_segment_clear(sim, start.lerp(end, first), start.lerp(end, last), lerpf(radius, 8.0, first)):
					return false
		elif not _pull_segment_clear(sim, route[index - 1], route[index], radius):
			return false
	return true

static func _reel_distance(corpse: Dictionary) -> float:
	var length: float = 0.0
	var route: Array = corpse.recovery_route
	for index: int in range(1, route.size() - 1):
		length += Vector2(route[index - 1]).distance_to(route[index])
	return length * clampf(float(corpse.phase_elapsed) / GameBalance.HERMES_WINCH_REEL_SECONDS, 0.0, 1.0)

static func _recovery_route_clear(sim: GameSimulation, corpse: Dictionary) -> bool:
	var route: Array[Vector2] = []
	if corpse.phase == "winch_launch":
		for position: Vector2 in corpse.recovery_route:
			route.append(position)
	elif corpse.phase == "winch_reel":
		route.append(corpse.position)
		var travelled: float = _reel_distance(corpse)
		for index: int in range(1, corpse.recovery_route.size() - 1):
			var length: float = Vector2(corpse.recovery_route[index - 1]).distance_to(corpse.recovery_route[index])
			if travelled < length:
				route.append(corpse.recovery_route[index])
			travelled = maxf(0.0, travelled - length)
		route.append(corpse.recovery_route[-1])
	else:
		route.assign([corpse.position, corpse.recovery_route[-1]])
	var radius: float = _recovery_radius(corpse)
	if corpse.phase == "winch_crush":
		radius = lerpf(radius, 8.0, clampf(float(corpse.phase_elapsed) / GameBalance.HERMES_WINCH_CRUSH_SECONDS, 0.0, 1.0))
	elif corpse.phase == "winch_feed":
		radius = 8.0
	return _route_clear(sim, route, radius)

static func recovery_position(corpse: Dictionary) -> Vector2:
	if corpse.phase == "winch_reel":
		var travelled: float = _reel_distance(corpse)
		var route: Array = corpse.recovery_route
		for index: int in range(1, route.size() - 1):
			var start: Vector2 = route[index - 1]
			var end: Vector2 = route[index]
			var length: float = start.distance_to(end)
			var position: Vector2 = start.move_toward(end, minf(travelled, length))
			if travelled <= length:
				return position
			travelled -= length
		return corpse.recovery_route[-2]
	elif corpse.phase == "winch_crush":
		return Vector2(corpse.recovery_route[-2]).lerp(corpse.recovery_route[-1], clampf(float(corpse.phase_elapsed) / GameBalance.HERMES_WINCH_CRUSH_SECONDS, 0.0, 1.0))
	elif corpse.phase == "winch_feed":
		return corpse.recovery_route[-1]
	return corpse.pickup_position

static func _update_recovery_position(sim: GameSimulation, corpse: Dictionary) -> void:
	corpse.position = recovery_position(corpse)
	if _drop_position_clear(sim, corpse.position, _recovery_radius(corpse)):
		corpse.recovery_drop_position = corpse.position

static func _finish_recovery_phase(sim: GameSimulation, corpse: Dictionary) -> void:
	match corpse.phase:
		"winch_launch":
			corpse.disarmed = true
			corpse.expiration = 0.0
			_set_phase(sim, corpse, "winch_reel")
		"winch_reel":
			_set_phase(sim, corpse, "winch_crush")
		"winch_crush":
			_set_phase(sim, corpse, "winch_feed")
		"winch_feed":
			sim.resources += int(corpse.amount)
			sim.corpses.erase(corpse)
			sim.hermes.recovery_corpse_id = 0
			sim.hermes.recovery_cooldown = GameBalance.HERMES_WINCH_RESET_SECONDS
			sim.hermes.furnace_remaining = GameBalance.RESOURCE_FURNACE_SECONDS
			sim.emit_event("delivery", {"amount": corpse.amount, "position": sim.hermes.position,
				"corpse_id": corpse.id, "source_kind": corpse.source_kind})

static func interrupt_recovery(sim: GameSimulation, clear_eligibility: bool = false) -> void:
	for corpse: Dictionary in sim.corpses:
		if clear_eligibility:
			corpse.recovery_eligible = false
		if not str(corpse.phase).begins_with("winch_"):
			continue
		var position: Vector2 = corpse.recovery_drop_position
		if corpse.disarmed and not _drop_position_clear(sim, position, _recovery_radius(corpse)):
			position = _safe_drop_position(sim, corpse)
		corpse.position = position
		corpse.pickup_position = position
		corpse.recovery_route = []
		corpse.cargo_slot = -1
		_set_phase(sim, corpse, "loose")
	sim.hermes.recovery_corpse_id = 0
	sim.hermes.recovery_cooldown = 0.0 if clear_eligibility else GameBalance.HERMES_WINCH_RESET_SECONDS

static func _drop_position_clear(sim: GameSimulation, position: Vector2, radius: float) -> bool:
	return position.distance_to(sim.hermes.position) >= GameBalance.HERMES_WINCH_BASE_CLEARANCE + radius and _pull_segment_clear(sim, position, position, radius)

static func _safe_drop_position(sim: GameSimulation, corpse: Dictionary) -> Vector2:
	var nearest: Vector2 = corpse.recovery_drop_position
	var distance: float = INF
	for y: int in sim.navigation.height:
		for x: int in sim.navigation.width:
			var position: Vector2 = sim.navigation.center(Vector2i(x, y))
			var separation: float = position.distance_squared_to(corpse.position)
			if separation < distance and _drop_position_clear(sim, position, _recovery_radius(corpse)):
				nearest = position
				distance = separation
	return nearest

static func _update_carry_flag(sim: GameSimulation) -> void:
	sim.nathaniel.has_corpse = false
	for corpse: Dictionary in sim.corpses:
		if corpse.carried:
			sim.nathaniel.has_corpse = true

static func overlaps(first: Vector2, first_size: Vector2, second: Vector2, second_size: Vector2) -> bool:
	var separation: Vector2 = (first - second).abs()
	var extent: Vector2 = (first_size + second_size) * 0.5
	# CGRect intersects includes touching object boundaries in the Swift game.
	return separation.x <= extent.x and separation.y <= extent.y

static func update_spawners(sim: GameSimulation, delta: float) -> void:
	for unit: Dictionary in sim.entities.duplicate():
		update_spawner(sim, unit, delta)

static func update_spawner(sim: GameSimulation, unit: Dictionary, delta: float) -> void:
	if unit.kind != "spawner" or not CombatRules.alive(unit):
		return
	unit.spawn_countdown = float(unit.spawn_countdown) - delta
	if float(unit.spawn_countdown) <= 0:
		unit.initial_spawns_remaining = maxi(0, int(unit.initial_spawns_remaining) - 1)
		unit.spawn_countdown = GameBalance.SPAWNER_INITIAL_INTERVAL_SECONDS if int(unit.initial_spawns_remaining) > 0 else GameBalance.SPAWNER_INTERVAL_SECONDS
		sim.spawn_enemy("grunt", Vector2(unit.position) + GameBalance.SPAWNER_SPAWN_OFFSET)

static func wave_interval(elapsed: float) -> float:
	return float(_wave_stage(elapsed).interval_seconds)

static func _wave_stage(elapsed: float) -> Dictionary:
	var selected: Dictionary = GameBalance.WAVE_STAGES[0]
	for stage: Dictionary in GameBalance.WAVE_STAGES:
		if elapsed > float(stage.after_seconds):
			selected = stage
	return selected

static func update_waves(sim: GameSimulation, delta: float) -> void:
	if not sim.level.get("wave_based", sim.level_number == 0 or sim.level_number >= 4):
		return
	sim.wave_elapsed += delta
	sim.wave_since_last_spawn += delta
	var stage: Dictionary = _wave_stage(sim.wave_elapsed)
	if sim.wave_since_last_spawn + 0.00000001 < float(stage.interval_seconds):
		return
	sim.wave_since_last_spawn = 0.0
	var maximum: int = int(stage.selection_count)
	var index: int = sim.random.randi_range(0, maximum - 1)
	var kind: String = "soldier"
	if index == 0:
		kind = "grunt"
	elif index == 2:
		kind = "spawner"
	elif index == 3:
		kind = "boss"
	if kind == "soldier" and sim.random.randi_range(0, 1) == 1:
		kind = "gunSoldier"
	var x: float = sim.navigation.width * sim.navigation.tile_size * (0.25 if index == 2 else sim.random.randf())
	var y: float = 200.0 if index == 2 else (10.0 if index == 0 else 50.0)
	var enemy: Dictionary = sim.spawn_enemy(kind, Vector2(x, minf(y, sim.navigation.height * sim.navigation.tile_size)))
	if index <= 2:
		enemy.target_id = sim.nathaniel.get("id", -1)

static func update_fog(sim: GameSimulation) -> void:
	var navigation: WorldNavigation = sim.navigation
	for index: int in sim.fog.size():
		if sim.fog[index] == 2:
			sim.fog[index] = 1
	for player: Dictionary in [sim.nathaniel, sim.hermes]:
		if not CombatRules.alive(player):
			continue
		var at: Vector2i = navigation.cell(player.position)
		var radius: int = ceili(float(player.vision) / navigation.tile_size)
		for y: int in range(maxi(0, at.y - radius), mini(navigation.height, at.y + radius + 1)):
			for x: int in range(maxi(0, at.x - radius), mini(navigation.width, at.x + radius + 1)):
				if navigation.center(Vector2i(x, y)).distance_to(player.position) <= float(player.vision):
					sim.fog[y * navigation.width + x] = 2
