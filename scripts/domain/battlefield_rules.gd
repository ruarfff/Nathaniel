class_name BattlefieldRules
extends RefCounted
## Corpse delivery, fog and original time-based wave/spawner cadence.

static func update_corpses(sim: GameSimulation, delta: float) -> void:
	var player: Dictionary = sim.nathaniel
	var robot: Dictionary = sim.hermes
	for corpse: Dictionary in sim.corpses.duplicate():
		if not corpse.carried and CombatRules.alive(player) and overlaps(corpse.position, Vector2(70, 60), player.position, player.size):
			corpse.carried = true
		if corpse.carried:
			if CombatRules.alive(player):
				corpse.position = player.position
			else:
				corpse.carried = false
				corpse.expiration = 10.0
		if not corpse.carried:
			corpse.expiration = float(corpse.expiration) - delta
		if float(corpse.expiration) <= 0:
			sim.corpses.erase(corpse)
		elif CombatRules.alive(robot) and overlaps(corpse.position, Vector2(70, 60), robot.position, robot.size):
			sim.resources += int(corpse.amount)
			sim.corpses.erase(corpse)
			sim.emit_event("delivery", {"amount": corpse.amount, "position": robot.position})
	if not player.is_empty():
		player.has_corpse = false
		for corpse: Dictionary in sim.corpses:
			if corpse.carried:
				player.has_corpse = true

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
