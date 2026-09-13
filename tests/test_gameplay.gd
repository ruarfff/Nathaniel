extends SceneTree
## Behavioral scenarios ported from NathanielTests, plus projection-independent
## travel and save reconstruction. No renderer or real user save files required.

var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	_test_lives_and_outcomes()
	_test_hermes_and_towers()
	_test_resources()
	_test_combat()
	_test_targeting_and_update_order()
	_test_spawners_and_waves()
	_test_navigation_and_restore()
	_test_real_campaign_routes()
	_test_encounter_parameters()
	_test_fog()
	if failures.is_empty():
		print("PASS gameplay: %d assertions" % checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("FAIL gameplay: %d / %d assertions" % [failures.size(), checks])
		quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _game(number: int = 1) -> GameSimulation:
	var sim := GameSimulation.new()
	sim.configure({"number": number, "width": 64, "height": 64, "tile_size": 32,
		"blocked": [], "player_start": Vector2(84, 242),
		"hermes_start": Vector2(600, 242), "enemies": [], "wave_based": false})
	return sim

func _advance(sim: GameSimulation, seconds: float, fps: int = 60) -> void:
	for index: int in roundi(seconds * fps):
		sim.step(1.0 / fps)

func _quiet_players(sim: GameSimulation) -> void:
	sim.nathaniel.delay = 100000.0
	sim.hermes.delay = 100000.0

func _test_lives_and_outcomes() -> void:
	var sim: GameSimulation = _game()
	for remaining: int in [2, 1, 0]:
		sim.move_to(Vector2(600, 500))
		sim.damage_entity(int(sim.nathaniel.id), 8000)
		_check(sim.lives == remaining and sim.result == "playing", "Campaign spare lives: %d" % remaining)
		_check(sim.nathaniel.hp == 8000 and sim.nathaniel.position == Vector2(84, 242), "Immediate full-health respawn")
		_check(sim.nathaniel.destination == null and not sim.nathaniel.moving, "Respawn clears route")
	sim.damage_entity(int(sim.nathaniel.id), 8000)
	_check(sim.result == "gameOver" and sim.lives == 0, "Fourth campaign death loses")
	sim = _game(0)
	sim.damage_entity(int(sim.nathaniel.id), 8000)
	_check(sim.result == "gameOver", "First survival death loses")
	for number: int in range(6):
		sim = _game(number)
		_check(sim.resources == (0 if number >= 4 else 30), "Original level wallet %d" % number)
		var boss: Dictionary = sim.spawn_enemy("boss", Vector2(1000, 1000))
		sim.damage_entity(int(boss.id), 800)
		_check(sim.result == ("playing" if number == 0 else "victory"), "Boss outcome %d" % number)
		_check(sim.score == 100, "Boss death rewards immediately")
		if number > 0:
			sim.damage_entity(int(sim.hermes.id), 2000)
			_check(sim.result == "victory", "Hermes death cannot replace victory")
	sim = _game()
	sim.set_paused(true)
	sim.step(20)
	_check(sim.elapsed_time == 0, "Pause freezes simulation time")
	sim.set_paused(false)
	sim.step(2)
	_check(sim.elapsed_time == 2, "Resume advances time")
	sim.damage_entity(int(sim.hermes.id), 2000)
	_check(sim.result == "gameOver" and sim.lives == 3, "Hermes death ends game without spending Nathaniel lives")
	sim = _game()
	sim.level.has_boss = false
	var optional_boss: Dictionary = sim.spawn_enemy("boss", Vector2(1000, 1000))
	sim.damage_entity(int(optional_boss.id), int(optional_boss.max_hp))
	_check(sim.result == "playing" and sim.score == 100, "Inspector has_boss=false disables boss victory while preserving kill score")

func _test_hermes_and_towers() -> void:
	var sim: GameSimulation = _game()
	sim.nathaniel.position = Vector2(1600, 242)
	sim.step(1)
	_check(sim.hermes.position == Vector2(600, 242) and sim.hermes_mode == "building", "Hermes starts stationary")
	sim.set_hermes_mode("following")
	sim.step(1)
	_check(Vector2(sim.hermes.position).distance_to(Vector2(640, 242)) < 0.01, "Hermes follows at 40 points/second without teleporting")
	sim.nathaniel.position = Vector2(740, 242)
	sim.step(1)
	_check(sim.hermes.position == Vector2(640, 242), "Hermes stops at 100 points")
	sim.set_hermes_mode("building")
	_check(sim.place_tower("gun_tower", Vector2(1000, 1000)), "Tower builds without Hermes radius")
	_check(sim.resources == 25, "Gun costs 5")
	_check(not sim.place_tower("gunTower", Vector2(1040, 1000)), "Overlapping towers rejected")
	_check(sim.place_tower("laserTower", Vector2(1100, 1000)), "Laser builds")
	_check(sim.place_tower("healTower", Vector2(1200, 1000)), "Heal builds")
	_check(sim.resources == 0, "All three original costs total 30")
	var map_tower: Dictionary = sim.place_map_tower("healTower", Vector2(1500, 1000))
	sim.set_hermes_mode("following")
	_check(sim.resources == 6, "Refund floors each 5/4 + 10/4 + 15/4")
	_check(sim.entities.size() == 3 and map_tower.hp == 600, "Follow dismantles only owned towers")
	sim.set_hermes_mode("following")
	_check(sim.resources == 6, "Follow refunds only once")
	_check(not sim.place_tower("gunTower", Vector2(1000, 1000)), "Follow forbids building")
	sim = _game()
	_check(sim.placement_error(Vector2(24, 24)) == "valid", "Tower may touch map edge")
	_check(sim.placement_error(Vector2(23.5, 96)) == "blockedByTerrain", "Tower footprint cannot cross map edge")
	sim.spawn_resource(10, Vector2(500, 500))
	_check(sim.placement_error(Vector2(500, 500)) == "overlapsResource", "Corpse blocks placement")
	var config: Dictionary = sim.level.duplicate(true)
	config.blocked = [Vector2i(1, 1)]
	sim.configure(config)
	_check(sim.placement_error(Vector2(88, 48)) == "valid", "Tower footprint may touch solid terrain")
	_check(sim.placement_error(Vector2(87.5, 48)) == "blockedByTerrain", "Half-point terrain overlap rejected")
	# Restoring an impossible old following deployment dismantles once at paid cost.
	sim = _game()
	_check(sim.place_tower("gunTower", Vector2(1000, 1000)), "Owned restore setup")
	sim.entities.back().construction_cost = 11
	var saved: Dictionary = sim.snapshot()
	saved.hermes_mode = "following"
	var restored := GameSimulation.new()
	_check(restored.restore(saved), "Following deployment restores")
	_check(restored.resources == 27 and restored.entities.size() == 2, "Saved paid cost refund")
	_check(restored.restore(restored.snapshot()) and restored.resources == 27, "Refund cannot duplicate on second restore")

func _test_resources() -> void:
	var sim: GameSimulation = _game(0)
	for kind: String in ["grunt", "boss", "spawner", "soldier"]:
		var enemy: Dictionary = sim.spawn_enemy(kind, Vector2(1000, 1000))
		sim.damage_entity(int(enemy.id), int(enemy.max_hp))
	_check(sim.corpses.size() == 1 and sim.corpses[0].amount == 10, "Only Soldier drops corpse worth ten")
	sim.corpses.clear()
	var corpse: Dictionary = sim.spawn_resource(10, sim.nathaniel.position)
	sim.step(0)
	_check(sim.nathaniel.has_corpse and sim.resources == 30, "Nathaniel carries without payment")
	sim.nathaniel.position = Vector2(300, 242)
	sim.step(20)
	_check(sim.corpses.size() == 1 and corpse.position == sim.nathaniel.position, "Carried corpses follow and do not expire")
	var restored := GameSimulation.new()
	_check(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))), "Carried corpse JSON restore")
	_check(restored.corpses[0].carried and restored.resources == 30, "Saved carry does not pay twice")
	sim.nathaniel.position = sim.hermes.position
	sim.step(0)
	_check(sim.resources == 40 and sim.corpses.is_empty() and not sim.nathaniel.has_corpse, "Hermes delivery pays once")
	sim.step(1)
	_check(sim.resources == 40, "No double credit")
	sim.spawn_resource(10, Vector2(1000, 1000))
	sim.step(9.9)
	_check(sim.corpses.size() == 1, "Loose corpse exists before ten seconds")
	sim.step(0.2)
	_check(sim.corpses.is_empty(), "Loose corpse expires after ten seconds")
	sim.spawn_resource(10, sim.hermes.position)
	sim.step(0)
	_check(sim.resources == 50, "Hermes also directly collects loose corpse")
	sim = _game()
	sim.spawn_resource(10, sim.nathaniel.position)
	sim.step(0)
	sim.damage_entity(int(sim.nathaniel.id), 8000)
	_check(not sim.corpses[0].carried and sim.corpses[0].expiration == 10.0, "Death drops corpse with reset expiry")

func _test_combat() -> void:
	var sim: GameSimulation = _game()
	_quiet_players(sim)
	sim.hermes.position = Vector2(1500, 1500)
	sim.nathaniel.position = Vector2(400, 200)
	var grunt: Dictionary = sim.spawn_enemy("grunt", Vector2(200, 200))
	_advance(sim, 1.5)
	_check(grunt.position == Vector2(200, 200), "Grunt fires without moving within range")
	_check(sim.nathaniel.hp == 7975, "Grunt ranged blaster damages once after travel")
	_check(grunt.weapon == "blaster" and grunt.delay == 0.8, "Original Grunt weapon")
	var original_id: int = int(grunt.target_id)
	sim.nathaniel.position = Vector2(1800, 200)
	sim.hermes.position = Vector2(210, 200)
	sim.damage_entity(int(grunt.id), 1, int(sim.hermes.id))
	sim.step(0.1)
	_check(int(grunt.target_id) == original_id and grunt.position.x > 200, "Enemy retains living target beyond sight despite attack")
	sim = _game()
	_quiet_players(sim)
	sim.nathaniel.position = Vector2(1500, 1500)
	sim.hermes.position = Vector2(1700, 1500)
	var tower: Dictionary = sim.place_map_tower("gunTower", Vector2(400, 200))
	tower.delay = 100000.0
	var soldier: Dictionary = sim.spawn_enemy("soldier", Vector2(200, 200))
	_advance(sim, 1.5)
	_check(soldier.target_id == tower.id and tower.hp == 575, "Soldier acquires and damages tower")
	soldier.position = Vector2(900, 200)
	tower.hp = 600
	_advance(sim, 7)
	_check(Vector2(soldier.position).distance_to(tower.position) <= 300.0 and tower.hp < 600, "Retained target tower is approached despite blocked endpoint")
	var boss: Dictionary = sim.spawn_enemy("boss", Vector2(1000, 700))
	boss.target_id = sim.nathaniel.id
	sim.nathaniel.position = Vector2(1400, 700)
	sim.step(0.5)
	_check(boss.moving and boss.position.x > 1000 and boss.shot_speed == 240.0, "Boss advances inside attack range at original arrow speed")
	for fps: int in [30, 60, 120]:
		sim = _game()
		_quiet_players(sim)
		var laser: Dictionary = sim.place_map_tower("laserTower", Vector2(1000, 1000))
		var enemy: Dictionary = sim.spawn_enemy("grunt", Vector2(1200, 1000))
		enemy.speed = 0.0
		enemy.delay = 100000.0
		laser.cooldown = 3.5
		_advance(sim, 1.5, fps)
		_check(absi(150 - int(enemy.hp) - 30) <= 1, "Laser tower frame-independent DPS at %d FPS" % fps)
		enemy.position = Vector2(1700, 1000)
		sim.step(1.0 / fps)
		_check(not laser.firing, "Laser stops out of range")
		sim = _game()
		sim.nathaniel.delay = 100000.0
		sim.hermes.position = Vector2(1000, 1000)
		sim.hermes.cooldown = 3.5
		enemy = sim.spawn_enemy("grunt", Vector2(1200, 1000))
		enemy.speed = 0.0
		enemy.delay = 100000.0
		_advance(sim, 1.5, fps)
		_check(absi(150 - int(enemy.hp) - 37) <= 1, "Hermes building DPS at %d FPS" % fps)
	sim = _game()
	sim.hermes.position = sim.nathaniel.position + Vector2(100, 0)
	sim.place_map_tower("healTower", Vector2(100, 250))
	sim.nathaniel.hp -= 6
	sim.hermes.hp -= 50
	sim.step(1)
	_check(sim.nathaniel.hp == 7999 and sim.hermes.hp == 1950, "Heal prioritizes Nathaniel")
	sim.step(1)
	_check(sim.nathaniel.hp == 8000 and sim.hermes.hp == 1950, "Heal targets one player per tick")
	sim.step(1)
	_check(sim.hermes.hp == 1955, "Heal proceeds to Hermes")
	# Dead enemy projectiles persist; tower projectiles are removed on destruction.
	sim = _game()
	soldier = sim.spawn_enemy("soldier", Vector2(1000, 1000))
	soldier.cooldown = 0.8
	_check(CombatRules.shoot(sim, soldier, Vector2(1200, 1000)), "Soldier projectile setup")
	sim.damage_entity(int(soldier.id), 200)
	_check(sim.projectiles.size() == 1 and sim.score == 30 and sim.corpses.size() == 1, "Enemy death pays immediately and keeps shot")
	sim.damage_entity(int(soldier.id), 200)
	_check(sim.score == 30 and sim.corpses.size() == 1, "Death reward once")
	tower = sim.place_map_tower("gunTower", Vector2(1400, 1000))
	tower.cooldown = 0.8
	CombatRules.shoot(sim, tower, Vector2(1500, 1000))
	sim.damage_entity(int(tower.id), 600)
	_check(sim.projectiles.size() == 1, "Tower death removes its shot only")

func _test_spawners_and_waves() -> void:
	var sim: GameSimulation = _game()
	_quiet_players(sim)
	var spawner: Dictionary = sim.spawn_enemy("spawner", Vector2(1000, 1000))
	sim.step(29)
	_check(sim.entities.size() == 3, "Spawner waits thirty seconds")
	sim.step(1)
	_check(sim.entities.size() == 4 and spawner.spawn_countdown == 30.0, "Spawner first production")
	_check(sim.entities.back().position == Vector2(1240, 832), "Spawner child y-up offset")
	sim.step(30)
	sim.step(30)
	_check(spawner.initial_spawns_remaining == 0 and spawner.spawn_countdown == 120.0, "Spawner original 30,60,90 then120 cadence")
	var restored := GameSimulation.new()
	_check(restored.restore(sim.snapshot()), "Spawner state restore")
	_check(restored.entity(int(spawner.id)).spawn_countdown == 120.0, "Spawner countdown persists")
	for timing: Array in [[0, 5], [60, 5], [60.01, 4], [120, 4], [120.01, 3], [180, 3], [180.01, 2], [240, 2], [240.01, 1], [365, 1]]:
		_check(BattlefieldRules.wave_interval(float(timing[0])) == float(timing[1]), "Wave threshold %s" % timing[0])
	sim = _game(0)
	sim.level.wave_based = true
	sim.wave_elapsed = 365.0
	for index: int in 30:
		BattlefieldRules.update_waves(sim, 1)
		var enemy: Dictionary = sim.entities.back()
		_check(enemy.position.x >= 0 and enemy.position.x < 2048, "Wave spawn X bounds")
		_check(enemy.position.y == (200.0 if enemy.kind == "spawner" else (10.0 if enemy.kind == "grunt" else 50.0)), "Wave bottom edge y-up offsets")
	# Spawner beam damage is paid in whole seconds, including fractional carry.
	sim = _game()
	_quiet_players(sim)
	sim.nathaniel.position = Vector2(1200, 1000)
	sim.hermes.position = Vector2(1800, 1800)
	spawner = sim.spawn_enemy("spawner", Vector2(1000, 1000))
	spawner.target_id = sim.nathaniel.id
	_advance(sim, 5)
	_check(sim.nathaniel.hp == 7970, "Spawner laser pays one whole-second tick in first burst")
	_check(spawner.position == Vector2(1000, 1000), "Spawner is stationary")
	sim.damage_entity(int(spawner.id), 1500)
	var count: int = sim.entities.size()
	BattlefieldRules.update_spawners(sim, 120)
	_check(sim.entities.size() == count, "Dead spawner cannot produce")

func _test_targeting_and_update_order() -> void:
	var sim: GameSimulation = _game()
	sim.focused_character = "hermes"
	var enemy: Dictionary = sim.spawn_enemy("soldier", Vector2(300, 242))
	sim.target_enemy(int(enemy.id))
	_check(sim.nathaniel.manual_target_id == enemy.id and sim.hermes.manual_target_id == -1, "Camera focus does not redirect manual targeting from Nathaniel")
	sim.move_to(Vector2(400, 400))
	_check(sim.nathaniel.manual_target_id == -1 and sim.hermes.destination == null, "Ground clears manual override and never commands Hermes")
	var distant: Dictionary = sim.spawn_enemy("soldier", Vector2(1800, 1800))
	sim.target_enemy(int(distant.id))
	_check(sim.nathaniel.manual_target_id == -1, "Cannot manually target inside unexplored fog")
	sim.nathaniel.cooldown = 0.8
	_check(sim.fire_at(Vector2(184, 242)), "Fire targets an arbitrary in-range logical mouse point")
	_check(sim.projectiles.back().radius == 12.0, "Bullet radius comes from original24px texture")
	sim.nathaniel.cooldown = 0.8
	_check(not sim.fire_at(Vector2(1800, 1800)), "Manual fire obeys range")
	# Threat score beats proximity on acquisition; living targets then stay sticky.
	sim = _game()
	var near: Dictionary = sim.spawn_enemy("soldier", Vector2(100, 250))
	var threat: Dictionary = sim.spawn_enemy("soldier", Vector2(400, 242))
	threat.target_id = sim.nathaniel.id
	CombatRules.acquire(sim, sim.nathaniel)
	_check(sim.nathaniel.target_id == threat.id, "Threat to player outweighs distance")
	near.hp = 1
	CombatRules.acquire(sim, sim.nathaniel)
	_check(sim.nathaniel.target_id == threat.id, "Friendly auto-target is sticky within vision")
	var tower: Dictionary = sim.place_map_tower("gunTower", Vector2(300, 500))
	near.position = Vector2(320, 500)
	near.hp = near.max_hp
	threat.position = Vector2(500, 500)
	threat.target_id = tower.id
	CombatRules.acquire(sim, tower)
	_check(tower.target_id == threat.id, "Tower considers threats to itself")
	var healer: Dictionary = sim.place_map_tower("healTower", Vector2(500, 500))
	CombatRules.acquire(sim, healer)
	_check(healer.target_id == -1, "Heal tower never acquires combat target")
	# Place the lethal enemy shot first in the global list. Player owner update
	# must still resolve its boss kill first, matching the Swift frame sequence.
	sim = _game()
	sim.nathaniel.position = Vector2(100, 200)
	sim.hermes.position = Vector2(200, 200)
	sim.hermes.hp = 25
	var boss: Dictionary = sim.spawn_enemy("boss", Vector2(300, 200))
	boss.hp = 25
	boss.cooldown = 1.5
	CombatRules.shoot(sim, boss, sim.hermes.position)
	sim.projectiles.back().position = sim.hermes.position
	sim.nathaniel.cooldown = 0.8
	CombatRules.shoot(sim, sim.nathaniel, boss.position)
	sim.projectiles.back().position = boss.position
	sim.step(0)
	_check(sim.result == "victory" and sim.hermes.hp == 0, "Boss victory before simultaneous lethal arrow")
	_check(sim.score == 100 and sim.projectiles.is_empty(), "Simultaneous shots resolve once")
	# Refund cancelled tower shots must never hit later.
	sim = _game()
	sim.place_tower("gunTower", Vector2(1000, 1000))
	tower = sim.entities.back()
	tower.cooldown = 0.8
	CombatRules.shoot(sim, tower, Vector2(1200, 1000))
	sim.set_hermes_mode("following")
	_check(sim.projectiles.is_empty() and sim.resources == 26, "Dismantle removes owned shots and refunds one")

func _test_navigation_and_restore() -> void:
	var navigation := WorldNavigation.new()
	navigation.configure({"width": 3, "height": 3, "tile_size": 32, "blocked": [[1, 0], [0, 1]]})
	_check(navigation.route(Vector2(16, 16), Vector2(80, 80), 0).is_empty(), "A-star never cuts blocked corners")
	_check(navigation.route(Vector2(48, 16), Vector2(80, 80), 0).is_empty(), "Blocked start has no path")
	var sim: GameSimulation = _game()
	sim.nathaniel.position = Vector2(272, 176)
	sim.hermes.position = Vector2(1400, 1400)
	sim.place_map_tower("healTower", Vector2(320, 200))
	sim.move_to(Vector2(400, 176))
	sim.step(0.1)
	_check(sim.nathaniel.moving, "Route around tower starts")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(sim.snapshot()))
	_check(saved.entities[0].destination == {"x": 400.0, "y": 176.0}, "Save stores requested goal instead of waypoint")
	var restored := GameSimulation.new()
	_check(restored.restore(saved), "Mid-route restore accepts JSON")
	var minimum: float = INF
	for index: int in 600:
		restored.step(1.0 / 60)
		minimum = minf(minimum, Vector2(restored.nathaniel.position).distance_to(Vector2(320, 200)))
	_check(minimum >= 43.2, "Restored route retains character radius around tower")
	_check(Vector2(restored.nathaniel.position).distance_to(Vector2(400, 176)) <= 16 and not restored.nathaniel.moving, "Restored route reaches goal")
	# Route invalidates after construction and resumes when the tower is removed.
	sim = _game()
	sim.nathaniel.position = Vector2(272, 176)
	sim.move_to(Vector2(500, 176))
	var tower: Dictionary = sim.place_map_tower("healTower", Vector2(368, 176))
	_advance(sim, 5)
	_check(Vector2(sim.nathaniel.position).distance_to(Vector2(500, 176)) < 16, "New tower invalidates and replans active route")
	sim.damage_entity(int(tower.id), 600)
	sim.move_to(Vector2(272, 176))
	_advance(sim, 4)
	_check(Vector2(sim.nathaniel.position).distance_to(Vector2(272, 176)) < 16, "Destroyed tower restores route")
	for direction: Vector2 in [Vector2.RIGHT, Vector2.UP, Vector2.ONE.normalized()]:
		sim = _game()
		sim.nathaniel.position = Vector2(1000, 1000)
		sim.move_to(Vector2(1000, 1000) + direction * 300)
		sim.step(1)
		_check(absf(Vector2(sim.nathaniel.position).distance_to(Vector2(1000, 1000)) - 70.0) < 0.001, "Direction-independent logical movement")
	var invalid: Dictionary = restored.snapshot()
	invalid.entities.append(invalid.entities[0].duplicate())
	var before: Vector2 = restored.nathaniel.position
	_check(not restored.restore(invalid) and restored.nathaniel.position == before, "Invalid duplicate-id save rejected without mutation")

func _test_fog() -> void:
	var sim: GameSimulation = _game()
	_check(sim.visibility_at(sim.nathaniel.position) == 2, "Player reveals fog")
	_check(sim.visibility_at(Vector2(1900, 1900)) == 0, "Remote fog unexplored")
	sim.nathaniel.position = Vector2(1800, 1800)
	sim.hermes.position = Vector2(1800, 1800)
	sim.step(0.1)
	_check(sim.visibility_at(Vector2(84, 242)) == 1, "Previous vision remains explored")
	var restored := GameSimulation.new()
	_check(restored.restore(sim.snapshot()) and restored.visibility_at(Vector2(84, 242)) == 1, "Exploration survives save")

func _test_real_campaign_routes() -> void:
	for number: int in range(6):
		var scene: PackedScene = load("res://levels/level_%d.tscn" % number) as PackedScene
		var node: GameLevel = scene.instantiate() as GameLevel
		var sim := GameSimulation.new()
		sim.configure(node.data())
		node.free()
		_check(sim.navigation.terrain_clear(sim.nathaniel.position), "Real level%d Nathaniel starts on open terrain" % number)
		_check(sim.navigation.terrain_clear(sim.hermes.position), "Real level%d Hermes starts on open terrain" % number)
		if number not in [1, 2, 3]:
			continue
		var bosses: Array[Dictionary] = []
		for unit: Dictionary in sim.entities:
			if unit.kind == "boss":
				bosses.append(unit)
		_check(not bosses.is_empty(), "Campaign%d contains its original boss" % number)
		for boss: Dictionary in bosses:
			var reachable: Array[Vector2] = []
			var boss_cell: Vector2i = sim.navigation.cell(boss.position)
			for y: int in range(maxi(0, boss_cell.y - 10), mini(sim.navigation.height, boss_cell.y + 11)):
				for x: int in range(maxi(0, boss_cell.x - 10), mini(sim.navigation.width, boss_cell.x + 11)):
					var goal: Vector2 = sim.navigation.center(Vector2i(x, y))
					if not sim.navigation.terrain_clear(goal) or goal.distance_to(boss.position) > 400:
						continue
					reachable = sim.navigation.route(sim.nathaniel.position, goal, float(sim.nathaniel.radius))
					if not reachable.is_empty():
						break
				if not reachable.is_empty():
					break
			_check(not reachable.is_empty(), "Campaign%d has a real route into gun range of boss" % number)

func _test_encounter_parameters() -> void:
	var sim: GameSimulation = _game()
	var enemy: Dictionary = sim.spawn_enemy("soldier", Vector2(1000, 1000))
	sim.apply_design_parameters(enemy, {"speed": 0.0, "damage": 0})
	_check(enemy.speed == 0.0 and enemy.damage == 0, "Inspector permits stationary harmless enemy overrides")
	var defaults: Dictionary = GameBalance.STATS.soldier
	sim.apply_design_parameters(enemy, {"max_hp": 0, "range": 0, "vision": 0, "delay": 0, "shot_speed": 0})
	for key: String in ["max_hp", "range", "vision", "delay", "shot_speed"]:
		_check(enemy[key] == defaults[key], "Inspector zero retains safe positive %s" % key)
	sim.apply_design_parameters(enemy, {"max_hp": 500, "hp": 900})
	_check(enemy.max_hp == 500 and enemy.hp == 500, "Encounter HP is clamped to configured maximum")
	sim.apply_design_parameters(enemy, {"hp": 0})
	_check(enemy.hp == 0, "Encounter can specify zero current HP")
