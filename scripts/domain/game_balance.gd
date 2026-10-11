class_name GameBalance
extends RefCounted
## Shipped gameplay constants, independent of presentation and storage.

const ENEMIES: Array[String] = ["grunt", "soldier", "gunSoldier", "boss", "spawner"]
const TOWERS: Array[String] = ["gunTower", "laserTower", "healTower"]
const COSTS: Dictionary = {"gunTower": 5, "laserTower": 10, "healTower": 15}
const HERMES_BUILD_RANGE: float = 240.0
const HERMES_FOLLOW_DISTANCE: float = 100.0
const BOSS_APPROACH_RANGE_RATIO: float = 0.3
const SPAWNER_INITIAL_SPAWNS: int = 3
const SPAWNER_INITIAL_INTERVAL_SECONDS: float = 30.0
const SPAWNER_INTERVAL_SECONDS: float = 120.0
const SPAWNER_SPAWN_OFFSET: Vector2 = Vector2(240, -168)
const SURVIVAL_SPAWN_SAFE_DISTANCE: float = 320.0
const SURVIVAL_SPAWN_RETRY_SECONDS: float = 0.25
const SURVIVAL_ENTRY_SEARCH_LIMIT: int = 64
const SURVIVAL_CHILD_SEARCH_LIMIT: int = 24
## Stages are ordered by elapsed time. A stage starts strictly after its threshold.
## Selection indexes are grunt, soldier, spawner, boss, then extra soldier choices.
const WAVE_STAGES: Array[Dictionary] = [
	{"after_seconds": 0.0, "interval_seconds": 5.0, "selection_count": 2},
	{"after_seconds": 60.0, "interval_seconds": 4.0, "selection_count": 3},
	{"after_seconds": 120.0, "interval_seconds": 3.0, "selection_count": 4},
	{"after_seconds": 180.0, "interval_seconds": 2.0, "selection_count": 5},
	{"after_seconds": 240.0, "interval_seconds": 1.0, "selection_count": 6},
	{"after_seconds": 300.0, "interval_seconds": 1.0, "selection_count": 7},
]
## Boss matter uses the soldier value until final balance is selected.
const RESOURCE_VALUES: Dictionary = {"soldier": 10, "gunSoldier": 10, "boss": 10}
const RESOURCE_CAPACITIES: Array[int] = [1, 2, 3]
const RESOURCE_CAPACITY_COSTS: Array[int] = [20, 40]
const RESOURCE_REACHES: Array[float] = [44.0, 60.0, 76.0]
const RESOURCE_REACH_COSTS: Array[int] = [15, 30]
const RESOURCE_DELIVERY_REACH: float = 48.0
const RESOURCE_RETURN_DISTANCE: float = 40.0
const RESOURCE_GRAB_SECONDS: float = 0.28
const RESOURCE_CRUSH_SECONDS: float = 0.32
const RESOURCE_PRESENT_SECONDS: float = 0.22
const RESOURCE_FEED_SECONDS: float = 0.38
const RESOURCE_FURNACE_SECONDS: float = 0.55
const RESOURCE_LIFETIME_SECONDS: float = 10.0
const RESOURCE_WARNING_SECONDS: float = 3.0
const RESOURCE_DISSOLVE_SECONDS: float = 0.6
## Initial side-winch timings; throughput still needs balance playtests.
const HERMES_WINCH_LAUNCH_SECONDS: float = 0.2
const HERMES_WINCH_CLAMP_SECONDS: float = 0.1
const HERMES_WINCH_REEL_SECONDS: float = 0.7
const HERMES_WINCH_CRUSH_SECONDS: float = 0.15
const HERMES_WINCH_FEED_SECONDS: float = 0.15
const HERMES_WINCH_RESET_SECONDS: float = 0.2
const HERMES_WINCH_GUIDE_RADIUS: float = 72.0
const HERMES_WINCH_BASE_CLEARANCE: float = 44.0
const HERMES_WINCH_INTAKE_OFFSET: Vector2 = Vector2(10, 0)
const HERMES_ANCHORED_WEAPON: Dictionary = {
	"weapon": "gun", "damage": 80, "delay": 0.8, "range": 300.0, "shot_speed": 650.0,
}
const WEAPON_EQUIP_SECONDS: float = 0.35
const WEAPON_PICKUP_RADIUS: float = 32.0
const LASER_BURST_SECONDS: float = 1.5
const LASER_PULSE_SECONDS: float = 0.18
const WEAPON_AIM_SPEED: float = TAU
const WEAPON_AIM_TOLERANCE: float = PI / 180.0
const WEAPONS: Dictionary = {
	"rifle": {"weapon": "gun", "damage": 25, "delay": 0.8, "range": 450.0, "shot_speed": 450.0},
	"heavy_rifle": {"weapon": "gun", "damage": 50, "delay": 1.6, "range": 450.0, "shot_speed": 450.0},
}
## Speed is logical points/second; range and vision are logical points.
## Bullets and pulses use damage per hit and delay between shots.
## Beams use damage per active second and delay as rest after a burst. Spawners pay
## damage in whole-second ticks; other beams carry fractional HP.
## healTower uses damage as HP restored per tick and delay as its tick interval.
## See docs/balance.md for units and timing conventions.
const STATS: Dictionary = {
	"nathaniel": {"max_hp": 8000, "speed": 80.0, "vision": 500.0,
		"size": Vector2(48, 72), "radius": 19.2, "score": 0},
	"hermes": {"max_hp": 8000, "speed": 65.0, "range": 450.0, "vision": 500.0,
		"weapon": "laser", "delay": 3.0, "damage": 120, "size": Vector2(80, 72),
		"radius": 32.0, "score": 0},
	"grunt": {"max_hp": 150, "speed": 70.0, "range": 250.0, "vision": 800.0,
		"weapon": "blaster", "delay": 0.8, "damage": 25, "shot_speed": 450.0,
		"size": Vector2(72, 33), "radius": 28.8, "score": 20},
	"soldier": {"max_hp": 200, "speed": 40.0, "range": 300.0, "vision": 300.0,
		"weapon": "pulse_laser", "delay": 0.8, "damage": 25, "shot_speed": 450.0,
		"size": Vector2(60, 72), "radius": 24.0, "score": 30},
	"gunSoldier": {"max_hp": 200, "speed": 40.0, "range": 300.0, "vision": 300.0,
		"weapon": "gun", "delay": 0.8, "damage": 25, "shot_speed": 450.0,
		"size": Vector2(60, 72), "radius": 24.0, "score": 30},
	"boss": {"max_hp": 800, "speed": 60.0, "range": 500.0, "vision": 600.0,
		"weapon": "pulse_laser", "delay": 0.8, "damage": 25, "shot_speed": 240.0,
		"size": Vector2(80, 72), "radius": 32.0, "score": 100},
	"spawner": {"max_hp": 1500, "speed": 0.0, "range": 350.0, "vision": 400.0,
		"weapon": "spawner_laser", "delay": 3.0, "damage": 75,
		"size": Vector2(240, 168), "radius": 96.0, "score": 100},
	"gunTower": {"max_hp": 600, "speed": 0.0, "range": 500.0, "vision": 500.0,
		"weapon": "gun", "delay": 0.8, "damage": 25, "shot_speed": 450.0,
		"size": Vector2(48, 48), "radius": 24.0, "score": 0},
	"laserTower": {"max_hp": 600, "speed": 0.0, "range": 350.0, "vision": 350.0,
		"weapon": "laser", "delay": 3.5, "damage": 150,
		"size": Vector2(48, 48), "radius": 24.0, "score": 0},
	"healTower": {"max_hp": 600, "speed": 0.0, "range": 400.0, "vision": 400.0,
		"weapon": "heal", "delay": 2.0, "damage": 40,
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
	if kind == "nathaniel":
		value.merge(WEAPONS.rifle, true)
	value.merge({"id": id, "kind": kind, "position": position, "hp": value.max_hp,
		"destination": null, "path": [], "moving": false, "facing": Vector2(0, -1),
		"arrival_range": 0.0,
		"direct_movement": false,
		"target_id": -1, "manual_target_id": -1, "cooldown": 0.0, "burst": 0.0,
		"pending_damage": 0.0, "firing": false, "active": true, "owned": false,
		"construction_cost": COSTS.get(kind, 0), "spawn_countdown": SPAWNER_INITIAL_INTERVAL_SECONDS,
		"initial_spawns_remaining": SPAWNER_INITIAL_SPAWNS, "has_corpse": false, "navigation_revision": -1,
		"follow_destination": null, "enemy": kind in ENEMIES, "tower": kind in TOWERS})
	if kind == "nathaniel":
		value.merge({"equipped_weapon_id": "rifle", "owned_weapon_ids": ["rifle"],
			"aim_direction": Vector2(0, -1), "manual_fire_target": null,
			"equip_ready_remaining": 0.0, "recovery_delay": value.delay,
			"resource_capacity": RESOURCE_CAPACITIES[0], "resource_reach": RESOURCE_REACHES[0],
			"returning_cargo": false})
	elif kind == "hermes":
		value.anchored = false
		value.furnace_remaining = 0.0
		value.recovery_corpse_id = 0
		value.recovery_cooldown = 0.0
	return value
