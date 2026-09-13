class_name GameBalance
extends RefCounted
## Shipped gameplay constants, independent of presentation and storage.

const ENEMIES: Array[String] = ["grunt", "soldier", "boss", "spawner"]
const TOWERS: Array[String] = ["gunTower", "laserTower", "healTower"]
const COSTS: Dictionary = {"gunTower": 5, "laserTower": 10, "healTower": 15}
const STATS: Dictionary = {
	"nathaniel": {"max_hp": 8000, "speed": 70.0, "range": 450.0, "vision": 500.0,
		"weapon": "gun", "delay": 0.8, "damage": 25, "shot_speed": 450.0,
		"size": Vector2(48, 72), "radius": 19.2, "score": 0},
	"hermes": {"max_hp": 2000, "speed": 40.0, "range": 450.0, "vision": 500.0,
		"weapon": "laser", "delay": 3.5, "damage": 25, "size": Vector2(80, 72),
		"radius": 32.0, "score": 0},
	"grunt": {"max_hp": 150, "speed": 70.0, "range": 250.0, "vision": 800.0,
		"weapon": "blaster", "delay": 0.8, "damage": 25, "shot_speed": 450.0,
		"size": Vector2(72, 33), "radius": 28.8, "score": 20},
	"soldier": {"max_hp": 200, "speed": 40.0, "range": 300.0, "vision": 300.0,
		"weapon": "gun", "delay": 0.8, "damage": 25, "shot_speed": 450.0,
		"size": Vector2(60, 72), "radius": 24.0, "score": 30},
	"boss": {"max_hp": 800, "speed": 60.0, "range": 500.0, "vision": 600.0,
		"weapon": "bow", "delay": 1.5, "damage": 25, "shot_speed": 240.0,
		"size": Vector2(80, 72), "radius": 32.0, "score": 100},
	"spawner": {"max_hp": 1500, "speed": 0.0, "range": 350.0, "vision": 400.0,
		"weapon": "spawner_laser", "delay": 3.5, "damage": 30,
		"size": Vector2(240, 168), "radius": 96.0, "score": 100},
	"gunTower": {"max_hp": 600, "speed": 0.0, "range": 500.0, "vision": 500.0,
		"weapon": "gun", "delay": 0.8, "damage": 25, "shot_speed": 450.0,
		"size": Vector2(48, 48), "radius": 24.0, "score": 0},
	"laserTower": {"max_hp": 600, "speed": 0.0, "range": 350.0, "vision": 350.0,
		"weapon": "laser", "delay": 3.5, "damage": 20,
		"size": Vector2(48, 48), "radius": 24.0, "score": 0},
	"healTower": {"max_hp": 600, "speed": 0.0, "range": 400.0, "vision": 400.0,
		"weapon": "heal", "delay": 1.0, "damage": 5,
		"size": Vector2(48, 48), "radius": 24.0, "score": 0},
}

static func canonical_kind(kind: String) -> String:
	for candidate: String in STATS:
		if candidate.to_lower() == kind.to_lower().replace("_", ""):
			return candidate
	return kind

static func create(kind: String, id: int, position: Vector2) -> Dictionary:
	kind = canonical_kind(kind)
	if not STATS.has(kind):
		return {}
	var value: Dictionary = STATS[kind].duplicate(true)
	value.merge({"id": id, "kind": kind, "position": position, "hp": value.max_hp,
		"destination": null, "path": [], "moving": false, "facing": Vector2(0, -1),
		"arrival_range": 0.0,
		"direct_movement": false,
		"target_id": -1, "manual_target_id": -1, "cooldown": 0.0, "burst": 0.0,
		"pending_damage": 0.0, "firing": false, "active": true, "owned": false,
		"construction_cost": COSTS.get(kind, 0), "spawn_countdown": 30.0,
		"initial_spawns_remaining": 3, "has_corpse": false, "navigation_revision": -1,
		"follow_destination": null, "enemy": kind in ENEMIES, "tower": kind in TOWERS})
	return value
