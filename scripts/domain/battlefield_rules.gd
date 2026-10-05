class_name BattlefieldRules
extends RefCounted
## Corpse delivery, fog and original time-based wave/spawner cadence.

# Repeated frame subtraction can leave a tiny residue at a shared deadline.
const TIMER_EPSILON: float = 0.000000000001

static func update_corpses(sim: GameSimulation, delta: float) -> void:
	if not CombatRules.alive(sim.nathaniel):
		drop_resources(sim)
	var remaining: float = delta
	while true:
		var active: Dictionary = _prepare_gathering(sim)
		var tick: float = remaining
		if not active.is_empty():
			tick = minf(tick, maxf(0.0, phase_seconds(active.phase) - float(active.phase_elapsed)))
		if float(sim.hermes.furnace_remaining) > 0:
			tick = minf(tick, float(sim.hermes.furnace_remaining))
		for corpse: Dictionary in sim.corpses:
			if not corpse.disarmed:
				tick = minf(tick, maxf(0.0, float(corpse.expiration)))
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
		sim.hermes.furnace_remaining = maxf(0.0, float(sim.hermes.furnace_remaining) - tick)
		if not active.is_empty():
			active.phase_elapsed = float(active.phase_elapsed) + tick
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
	if can_deliver and not delivery.is_empty() and float(sim.hermes.furnace_remaining) <= 0:
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
		unit.spawn_countdown = 30.0 if int(unit.initial_spawns_remaining) > 0 else 120.0
		sim.spawn_enemy("grunt", Vector2(unit.position) + Vector2(240, -168))

static func wave_interval(elapsed: float) -> float:
	if elapsed > 240:
		return 1.0
	if elapsed > 180:
		return 2.0
	if elapsed > 120:
		return 3.0
	if elapsed > 60:
		return 4.0
	return 5.0

static func update_waves(sim: GameSimulation, delta: float) -> void:
	if not sim.level.get("wave_based", sim.level_number == 0 or sim.level_number >= 4):
		return
	sim.wave_elapsed += delta
	sim.wave_since_last_spawn += delta
	if sim.wave_since_last_spawn + 0.00000001 < wave_interval(sim.wave_elapsed):
		return
	sim.wave_since_last_spawn = 0.0
	var maximum: int = 2
	for threshold: float in [60.0, 120.0, 180.0, 240.0, 300.0]:
		if sim.wave_elapsed > threshold:
			maximum += 1
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
