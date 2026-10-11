extends SceneTree
## Survival intent, authored entry safety, deferred budgets and route protection.

var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	_test_immediate_pursuit()
	_test_target_retention_and_restore()
	_test_campaign_acquisition()
	_test_entry_validation()
	_test_deferred_waves()
	_test_spawner_births()
	_test_every_wave_variant()
	_test_tower_routes()
	_test_clearance()
	if failures.is_empty():
		print("PASS survival rules: %d assertions" % checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("FAIL survival rules: %d / %d assertions" % [failures.size(), checks])
		quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _game(number: int = 0) -> GameSimulation:
	var sim := GameSimulation.new()
	sim.configure({"number": number, "width": 52, "height": 52, "tile_size": 32,
		"blocked": [], "player_start": Vector2(1136, 1136), "hermes_start": Vector2(1232, 1136),
		"wave_based": false, "entry_sectors": [
			{"id": "west", "enabled": true, "positions": [Vector2(144, 144), Vector2(144, 496)]},
			{"id": "south", "enabled": true, "positions": [Vector2(496, 144), Vector2(848, 144)]}]})
	return sim

func _test_immediate_pursuit() -> void:
	for kind: String in GameBalance.ENEMIES:
		var sim: GameSimulation = _game()
		var origin := Vector2(144, 144)
		var enemy: Dictionary = sim.spawn_enemy(kind, origin)
		_check(CombatRules.distance(enemy, sim.nathaniel) > float(enemy.vision), "%s fixture starts outside vision" % kind)
		_check(enemy.target_id == sim.nathaniel.id, "%s receives Nathaniel on spawn" % kind)
		var hp: int = sim.nathaniel.hp
		enemy.cooldown = enemy.delay
		sim.step(0.1)
		_check(sim.nathaniel.hp == hp and sim.projectiles.is_empty(), "%s cannot fire beyond its normal range" % kind)
		_check(enemy.position != origin if kind != "spawner" else enemy.position == origin, "%s movement policy on first step" % kind)
		_check(enemy.target_id == sim.nathaniel.id, "%s retains initial target" % kind)

func _test_target_retention_and_restore() -> void:
	var sim: GameSimulation = _game()
	var enemy: Dictionary = sim.spawn_enemy("boss", Vector2(144, 144))
	var tower: Dictionary = sim.place_map_tower("gunTower", Vector2(1296, 1328))
	enemy.target_id = tower.id
	CombatRules.acquire(sim, enemy)
	_check(enemy.target_id == tower.id, "Survival keeps an existing living combat target")
	sim.damage_entity(int(tower.id), int(tower.hp))
	CombatRules.acquire(sim, enemy)
	_check(enemy.target_id == sim.nathaniel.id, "Destroyed target reacquires Nathaniel without sight")
	enemy.target_id = sim.spawn_enemy("soldier", Vector2(208, 144)).id
	CombatRules.acquire(sim, enemy)
	_check(enemy.target_id == sim.nathaniel.id, "Enemy-side target is not a valid pursuit target")
	sim.nathaniel.hp = 0
	enemy.target_id = -1
	CombatRules.acquire(sim, enemy)
	_check(enemy.target_id == sim.hermes.id, "Active run reacquires living Hermes when Nathaniel is unavailable")
	sim.nathaniel.hp = sim.nathaniel.max_hp
	var saved: Dictionary = sim.snapshot()
	for unit: Dictionary in saved.entities:
		if unit.enemy:
			unit.erase("target_id")
	var restored := GameSimulation.new()
	_check(restored.restore(saved), "Missing pursuit targets remain compatible on restore")
	for unit: Dictionary in restored.entities:
		if unit.enemy:
			_check(unit.target_id == restored.nathaniel.id, "Restore repairs every missing pursuit target")
	restored.damage_entity(int(restored.nathaniel.id), int(restored.nathaniel.hp))
	var terminal_position: Vector2 = restored.entity(int(enemy.id)).position
	restored.step(10.0)
	_check(restored.result == "gameOver" and restored.entity(int(enemy.id)).position == terminal_position, "Survival first death remains terminal")
	_check(restored.restore(restored.snapshot()) and restored.result == "gameOver", "Restore preserves terminal survival outcome")
	saved.entities[0].hp = 0
	_check(restored.restore(saved) and restored.result == "gameOver", "Inconsistent active survival save cannot revive a dead Nathaniel")

func _test_campaign_acquisition() -> void:
	var sim: GameSimulation = _game(4)
	sim.level.wave_based = true
	for kind: String in ["soldier", "gunSoldier", "boss", "spawner"]:
		var enemy: Dictionary = sim.spawn_enemy(kind, Vector2(144, 144))
		CombatRules.acquire(sim, enemy)
		_check(enemy.target_id == -1, "Campaign wave level retains sight acquisition for %s" % kind)
	var campaign_grunt: Dictionary = sim.spawn_enemy("grunt", Vector2(144, 144))
	_check(campaign_grunt.target_id == sim.nathaniel.id, "Original campaign grunt intent remains unchanged")

func _test_entry_validation() -> void:
	var sim: GameSimulation = _game()
	_check(BattlefieldRules.spawn_position_error(sim, "boss", Vector2(8, 144)) == "blockedByTerrain", "Spawn footprint stays inside bounds")
	_check(BattlefieldRules.spawn_position_error(sim, "grunt", sim.nathaniel.position) == "occupied", "Spawn rejects occupied hero space")
	_check(BattlefieldRules.spawn_position_error(sim, "grunt", Vector2(1136, 896)) == "nearPlayerBase", "Spawn uses world-space hero distance")
	var occupied: Dictionary = sim.spawn_enemy("soldier", Vector2(144, 144))
	_check(BattlefieldRules.spawn_position_error(sim, "grunt", occupied.position) == "occupied", "Spawn rejects a living enemy footprint")
	sim.damage_entity(int(occupied.id), int(occupied.hp))
	_check(BattlefieldRules.spawn_position_error(sim, "grunt", occupied.position) == "occupied", "Uncollected bodies reserve their occupied entry space")
	sim.corpses.clear()
	_check(BattlefieldRules.spawn_position_error(sim, "grunt", occupied.position).is_empty(), "Collected dead enemies do not reserve entry positions")
	var tower: Dictionary = sim.place_map_tower("healTower", Vector2(800, 600))
	_check(BattlefieldRules.spawn_position_error(sim, "grunt", Vector2(800, 360)) == "nearPlayerBase", "Spawn safety includes deployed towers")
	sim.damage_entity(int(tower.id), int(tower.hp))
	for y: int in sim.navigation.height:
		sim.navigation.blocked[Vector2i(20, y)] = true
	sim.navigation.invalidate()
	_check(BattlefieldRules.spawn_position_error(sim, "boss", Vector2(144, 144)) == "noRouteToPlayer", "Spawn rejects disconnected terrain")
	sim.fog.fill(2)
	_check(BattlefieldRules.spawn_position_error(sim, "boss", Vector2(144, 144)) == "noRouteToPlayer", "Spawn validity is independent of visibility")

func _test_deferred_waves() -> void:
	var sim: GameSimulation = _game()
	sim.level.wave_based = true
	for sector: Dictionary in sim.entry_sectors:
		for position: Vector2 in sector.positions:
			sim.navigation.blocked[sim.navigation.cell(position)] = true
	sim.navigation.invalidate()
	BattlefieldRules.update_waves(sim, 5.0)
	_check(sim.entities.size() == 2 and sim.pending_wave_kinds.size() == 1, "Blocked wave defers its selected enemy")
	_check(sim.spawn_blocked_reason == "blockedByTerrain", "Blocked wave exposes a useful reason")
	var first_kind: String = sim.pending_wave_kinds[0]
	BattlefieldRules.update_waves(sim, 5.0)
	_check(sim.pending_wave_kinds.size() == 2 and sim.pending_wave_kinds[0] == first_kind, "Later budgets cannot erase or reroll an earlier deferred enemy")
	var restored := GameSimulation.new()
	_check(restored.restore(sim.snapshot()) and restored.pending_wave_kinds == sim.pending_wave_kinds, "Save preserves every deferred wave budget")
	sim.navigation.blocked.clear()
	sim.navigation.invalidate()
	BattlefieldRules.update_waves(sim, GameBalance.SURVIVAL_SPAWN_RETRY_SECONDS)
	_check(sim.pending_wave_kinds.size() == 1 and sim.entities.back().kind == first_kind, "Open entry releases the oldest deferred enemy")
	_check(sim.spawn_blocked_reason.is_empty(), "Successful retry clears its blocked reason")
	var first_position: Vector2 = sim.entities.back().position
	BattlefieldRules.update_waves(sim, 0.1)
	_check(sim.pending_wave_kinds.is_empty() and sim.entities.size() == 4, "All retained budgets eventually spawn")
	_check(sim.entities.back().position != first_position, "Occupied entry uses another authored candidate")
	for sector: Dictionary in sim.entry_sectors:
		sector.enabled = false
	BattlefieldRules.update_waves(sim, 5.0)
	_check(sim.pending_wave_kinds.size() == 1 and sim.spawn_blocked_reason == "noEnabledEntrySector", "Disabled sectors cannot supply a spawn")
	sim = _game()
	sim.level.wave_based = true
	sim.entry_sectors.assign([{"id": "narrow_margin", "enabled": true, "positions": [Vector2(112, 144)]}])
	sim.pending_wave_kinds.assign(["spawner", "grunt"])
	BattlefieldRules.update_waves(sim, 0.0)
	_check(sim.entities.back().kind == "grunt" and sim.pending_wave_kinds == ["spawner"], "Blocked large enemy budget does not prevent valid smaller births")
	sim.entry_sectors[0].positions[0] = Vector2(496, 144)
	BattlefieldRules.update_waves(sim, GameBalance.SURVIVAL_SPAWN_RETRY_SECONDS)
	_check(sim.pending_wave_kinds.is_empty() and sim.entities.back().kind == "spawner", "Deferred large enemy still spawns when its entry becomes valid")

func _test_spawner_births() -> void:
	var sim: GameSimulation = _game()
	var spawner: Dictionary = sim.spawn_enemy("spawner", Vector2(128, 128))
	var old_offset: Vector2 = Vector2(spawner.position) + GameBalance.SPAWNER_SPAWN_OFFSET
	_check(old_offset.y < 0, "Spawner fixture makes the historical fixed offset invalid")
	spawner.spawn_countdown = 0.0
	BattlefieldRules.update_spawner(sim, spawner, 0.0)
	var child: Dictionary = sim.entities.back()
	_check(child.kind == "grunt" and child.position != old_offset, "Spawner selects a legal nearby birth")
	_check(child.target_id == sim.nathaniel.id and spawner.position == Vector2(128, 128), "Stationary out-of-sight spawner gives its child immediate intent")
	_check(sim.navigation.terrain_footprint_clear(child.position, float(child.radius)), "Child's full footprint is inside the map")
	_check(not BattlefieldRules.overlaps(child.position, child.size, spawner.position, spawner.size), "Child clears the parent footprint")
	var child_start: Vector2 = child.position
	sim.step(0.1)
	_check(child.position != child_start, "Spawner child moves on its first active step")
	sim = _game()
	spawner = sim.spawn_enemy("spawner", Vector2(304, 304))
	for y: int in range(1, 19):
		for x: int in range(1, 19):
			sim.navigation.blocked[Vector2i(x, y)] = true
	sim.navigation.invalidate()
	spawner.spawn_countdown = 0.0
	BattlefieldRules.update_spawner(sim, spawner, 0.0)
	_check(spawner.initial_spawns_remaining == GameBalance.SPAWNER_INITIAL_SPAWNS and sim.entities.size() == 3, "Blocked child preserves initial production budget")
	_check(not str(spawner.spawn_blocked_reason).is_empty(), "Blocked child exposes its reason")
	sim.navigation.blocked.clear()
	sim.navigation.invalidate()
	BattlefieldRules.update_spawner(sim, spawner, GameBalance.SURVIVAL_SPAWN_RETRY_SECONDS)
	_check(sim.entities.size() == 4 and spawner.initial_spawns_remaining == GameBalance.SPAWNER_INITIAL_SPAWNS - 1, "Deferred child is born after a candidate opens")
	_check(spawner.spawn_blocked_reason == "" and spawner.spawn_countdown == GameBalance.SPAWNER_INITIAL_INTERVAL_SECONDS, "Successful child resumes existing production cadence")

func _test_every_wave_variant() -> void:
	var observed: Dictionary = {}
	for seed_value: int in range(1, 100):
		var sim: GameSimulation = _game()
		sim.level.wave_based = true
		sim.wave_elapsed = 360.0
		sim.random.seed = seed_value
		BattlefieldRules.update_waves(sim, 1.0)
		if sim.entities.size() <= 2:
			continue
		var enemy: Dictionary = sim.entities.back()
		observed[enemy.kind] = true
		_check(enemy.target_id == sim.nathaniel.id, "Late-wave seed %d receives immediate pursuit" % seed_value)
	for kind: String in GameBalance.ENEMIES:
		_check(observed.has(kind), "Controlled late-wave seeds exercise %s" % kind)

func _corridor(alternate: bool) -> GameSimulation:
	var blocked: Array[Vector2i] = []
	for y: int in 20:
		if y in [9, 10, 11] or (alternate and y in [3, 4, 5]):
			continue
		blocked.append(Vector2i(10, y))
	var sim := GameSimulation.new()
	sim.configure({"number": 0, "width": 20, "height": 20, "tile_size": 32,
		"blocked": blocked, "player_start": Vector2(496, 336), "hermes_start": Vector2(432, 240),
		"wave_based": false, "entry_sectors": [
			{"id": "east", "enabled": true, "positions": [Vector2(560, 496)]},
			{"id": "unused_west", "enabled": true, "positions": [Vector2(112, 336)]}]})
	return sim

func _test_tower_routes() -> void:
	var sim: GameSimulation = _corridor(false)
	var revision: int = sim.navigation.revision
	_check(sim.placement_error(Vector2(336, 336)) == "blocksEntryRoute", "Tower cannot seal an enabled sector unused by the current wave")
	_check(not sim.place_tower("gunTower", Vector2(336, 336)) and sim.resources == 30, "Rejected seal spends no resources")
	_check(sim.navigation.revision == revision and sim.navigation.towers.is_empty(), "Placement preview leaves navigation unchanged")
	sim.entry_sectors[1].enabled = false
	_check(sim.placement_error(Vector2(336, 336)) == "valid", "Disabled sectors do not constrain placement")
	sim = _corridor(true)
	_check(sim.place_tower("gunTower", Vector2(336, 336)), "Tower is allowed when a wide alternate route remains")
	_check(sim.placement_error(Vector2(336, 144)) == "blocksEntryRoute", "Second tower cannot seal the remaining alternate route")
	var tower: Dictionary = sim.entities.back()
	sim.damage_entity(int(tower.id), int(tower.hp))
	_check(sim.placement_error(Vector2(336, 144)) == "valid", "Tower destruction restores route availability")
	_check(sim.place_tower("gunTower", Vector2(336, 336)), "First route can be closed again")
	sim.set_hermes_mode("following")
	_check(sim.placement_error(Vector2(336, 144)) == "valid", "Base teardown restores alternate routes")

func _test_clearance() -> void:
	var navigation := WorldNavigation.new()
	navigation.configure({"number": 0, "width": 12, "height": 12, "blocked": [Vector2i(5, 5)]})
	_check(not navigation.walkable(Vector2(144, 176), 32.0), "Boss radius cannot overlap a terrain footprint")
	_check(navigation.walkable(Vector2(112, 176), 32.0), "Boss can use space with full terrain clearance")
	_check(navigation.terrain_rect_clear(Vector2(240, 288), Vector2(240, 168)), "Wide spawner uses its actual rectangular bounds near north or south edge")
	_check(not navigation.terrain_rect_clear(Vector2(112, 288), Vector2(240, 168)), "Wide spawner cannot extend past an east or west edge")
	var route: Array[Vector2] = navigation.route(Vector2(80, 176), Vector2(304, 176), 32.0)
	_check(not route.is_empty(), "Largest mobile unit finds a route around terrain")
	var current := Vector2(80, 176)
	for waypoint: Vector2 in route:
		_check(navigation.segment_clear(current, waypoint, 32.0), "Each boss route segment retains footprint clearance")
		current = waypoint
