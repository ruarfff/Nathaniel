class_name GameSwiftSaveImport
extends RefCounted
## Converts the actual SavedGameState Codable schema, versions 1 and 2.

const AtomicJSON = preload("res://scripts/infrastructure/atomic_json.gd")
const TOWER_COSTS: Dictionary = {"gunTower": 5, "laserTower": 10, "healTower": 15}
const FACING: Array[Vector2] = [Vector2(0, -1), Vector2(-1, -1), Vector2(0, 1), Vector2.LEFT, Vector2(1, -1), Vector2(1, 1), Vector2.RIGHT, Vector2(-1, 1)]


static func convert(source: Dictionary, level_config: Dictionary) -> Dictionary:
	var issue := validate(source)
	if not issue.is_empty():
		return AtomicJSON.failure(issue)
	if level_config.is_empty() or level_config.get("number") != source.levelNumber:
		return AtomicJSON.failure("A matching migrated level is required")
	var entities: Array[Dictionary] = []
	var player := _character(source.nathaniel, "nathaniel", 1)
	# Swift resumes old saves after the spare life has already been spent.
	if player.hp <= 0:
		player.hp = player.max_hp
		player.position = level_config.get("player_start", player.position)
		player.destination = null
	entities.append(player)
	var hermes := _character(source.hermes.characterState, "hermes", 2)
	# Swift's Hermes restoration intentionally clears independent movement.
	hermes.destination = null
	entities.append(hermes)
	var next_id: int = 3
	for enemy: Dictionary in source.enemies:
		var entity := _character(enemy, enemy.type, next_id)
		entity["target_id"] = int(enemy.targetIndex) + 1 if enemy.get("targetIndex") != null else -1
		if enemy.type == "spawner":
			var has_production: bool = enemy.get("timeUntilNextSpawn") != null and enemy.get("initialSpawnsRemaining") != null
			entity["spawn_countdown"] = maxf(0.0, float(enemy.timeUntilNextSpawn)) if has_production else 30.0
			entity["initial_spawns_remaining"] = clampi(int(enemy.initialSpawnsRemaining), 0, 3) if has_production else 3
		entities.append(entity)
		next_id += 1
	for tower: Dictionary in source.towers:
		var entity := _character(tower, tower.type, next_id)
		entity["owned"] = tower.isHermesOwned
		var cost: int = int(tower.constructionCost) if tower.get("constructionCost") != null else int(TOWER_COSTS[tower.type])
		entity["construction_cost"] = maxi(0, cost) if tower.isHermesOwned else 0
		# Swift writes and restores zero here, even when old data stores a cooldown.
		entity["cooldown"] = 0.0
		entities.append(entity)
		next_id += 1
	var corpses: Array[Dictionary] = []
	for corpse: Dictionary in source.get("battlefieldResources", []) if source.get("battlefieldResources") != null else []:
		corpses.append({"id": next_id, "position": corpse.position.duplicate(), "amount": int(corpse.amount), "expiration": float(corpse.timeToExpiration), "carried": corpse.isCarried and player.hp > 0})
		next_id += 1
	var elapsed := float(source.elapsedTime)
	var interval: float = 1.0 if elapsed > 240 else (2.0 if elapsed > 180 else (3.0 if elapsed > 120 else (4.0 if elapsed > 60 else 5.0)))
	var until_next: float = float(source.get("timeUntilNextWave", 0.0)) if source.get("timeUntilNextWave") != null else 0.0
	var state: Dictionary = {
		"schema": 1, "level": level_config.duplicate(true), "entities": entities,
		"corpses": corpses, "projectiles": [], "resources": int(source.resources),
		"score": int(source.score), "lives": maxi(0, int(source.lives) - (1 if int(source.saveVersion) < 2 else 0)),
		"elapsed_time": elapsed, "result": "gameOver" if hermes.hp <= 0 else "playing",
		"hermes_mode": "following" if source.hermes.mode == "following" else "independent",
		"focused_character": "nathaniel", "wave_elapsed": elapsed,
		"wave_since_last_spawn": interval - clampf(until_next, 0, interval),
		"fog": [], "next_id": next_id,
	}
	return {"success": true, "state": state, "warnings": ["Swift saves omit explored fog, projectiles, weapon timers, random generator state, and camera state; these start fresh. Hermes movement and tower cooldown reset as in Swift load. Old tower costs use the shipped 5/10/15 defaults."]}


static func validate(source: Dictionary) -> String:
	if not AtomicJSON.is_integer(source.get("saveVersion")) or int(source.saveVersion) not in [1, 2]:
		return "Unsupported Swift saveVersion; expected 1 or 2"
	if not AtomicJSON.is_integer(source.get("levelNumber")) or int(source.levelNumber) not in [0, 1, 2, 3, 4, 5]:
		return "Invalid Swift levelNumber"
	for key: String in ["elapsedTime", "score", "lives", "resources"]:
		if not AtomicJSON.is_number(source.get(key)) or float(source[key]) < 0:
			return "Invalid Swift counter: " + key
	if not _valid_character(source.get("nathaniel")):
		return "Invalid Swift Nathaniel state"
	if not source.get("hermes") is Dictionary or not _valid_character(source.hermes.get("characterState")) or source.hermes.get("mode") not in ["following", "independent", "locked"]:
		return "Invalid Swift Hermes state"
	if not source.get("enemies") is Array or not source.get("towers") is Array:
		return "Invalid Swift entity lists"
	for enemy: Variant in source.enemies:
		if not _valid_character(enemy) or enemy.get("type") not in ["grunt", "soldier", "boss", "spawner"]:
			return "Invalid Swift enemy state"
		if enemy.get("targetIndex") != null and (not AtomicJSON.is_integer(enemy.targetIndex) or int(enemy.targetIndex) not in [0, 1]):
			return "Invalid Swift targetIndex"
		for key: String in ["timeUntilNextSpawn", "initialSpawnsRemaining"]:
			if enemy.get(key) != null and not AtomicJSON.is_number(enemy[key]):
				return "Invalid Swift production state"
	for tower: Variant in source.towers:
		if not _valid_character(tower) or not TOWER_COSTS.has(tower.get("type")) or not tower.get("isHermesOwned") is bool:
			return "Invalid Swift tower state"
		if tower.get("constructionCost") != null and not AtomicJSON.is_number(tower.constructionCost):
			return "Invalid Swift tower construction cost"
	if source.get("battlefieldResources") != null:
		if not source.battlefieldResources is Array:
			return "Invalid Swift battlefield resources"
		for corpse: Variant in source.battlefieldResources:
			if not corpse is Dictionary or not AtomicJSON.is_point(corpse.get("position")) or not AtomicJSON.is_number(corpse.get("amount")) or not AtomicJSON.is_number(corpse.get("timeToExpiration")) or not corpse.get("isCarried") is bool:
				return "Invalid Swift corpse state"
	if source.get("timeUntilNextWave") != null and not AtomicJSON.is_number(source.timeUntilNextWave):
		return "Invalid Swift wave timer"
	return ""


static func _valid_character(value: Variant) -> bool:
	if not value is Dictionary or not AtomicJSON.is_point(value.get("position")):
		return false
	if not AtomicJSON.is_number(value.get("currentHP")) or not AtomicJSON.is_number(value.get("maxHP")) or value.maxHP <= 0 or value.currentHP > value.maxHP:
		return false
	if value.get("destination") != null and not AtomicJSON.is_point(value.destination):
		return false
	return AtomicJSON.is_integer(value.get("facingDirection", 0)) and int(value.get("facingDirection", 0)) in range(8)


static func _character(source: Dictionary, kind: String, id: int) -> Dictionary:
	var facing := FACING[int(source.get("facingDirection", 0))].normalized()
	return {"id": id, "kind": kind, "position": source.position.duplicate(), "hp": int(source.currentHP), "max_hp": int(source.maxHP), "destination": source.get("destination"), "facing": {"x": facing.x, "y": facing.y}, "owned": false, "construction_cost": 0, "target_id": -1, "manual_target_id": -1, "cooldown": 0.0, "burst": 0.0, "pending_damage": 0.0, "firing": false}
