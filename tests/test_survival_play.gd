extends SceneTree
## Exercise movement, base changes and matter delivery on the authored terrain.

const MAPS: Array[String] = ["abandoned_crossroads", "dry_wash", "freight_yard", "open_countryside"]
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	for map_id: String in MAPS:
		_test_map(map_id)
	for failure: String in failures:
		push_error(failure)
	print("%s survival play: %d assertions" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _test_map(map_id: String) -> void:
	var level: GameLevel = load("res://levels/survival/%s.tscn" % map_id).instantiate() as GameLevel
	var data: Dictionary = level.data()
	data.wave_based = false
	var sim := GameSimulation.new()
	sim.configure(data)
	var pickup: Vector2 = GameSimulation.point(data.weapon_pickups[0].position)
	sim.move_to(pickup)
	_advance(sim, 5)
	_check("heavy_rifle" in sim.nathaniel.owned_weapon_ids, map_id + ": pickup reachable at normal speed")
	for marker: Node2D in level.get_node("Clearings").get_children():
		var destination: Vector2 = IsoProjection.unproject(marker.position)
		var route: Array[Vector2] = sim.navigation.route(sim.nathaniel.position, destination, sim.nathaniel.radius)
		_check(not route.is_empty() or sim.nathaniel.position.distance_to(destination) < 4, map_id + ": route to clearing " + marker.name)
		sim.move_to(destination)
		_advance(sim, 35)
		_check(sim.nathaniel.position.distance_to(destination) < 5, map_id + ": Nathaniel reaches clearing " + marker.name)
		_check(sim.hermes.position.distance_to(sim.nathaniel.position) <= GameBalance.HERMES_FOLLOW_DISTANCE + 10, map_id + ": Hermes follows around obstacles")
		sim.set_hermes_mode("building")
		var tower_point: Vector2 = _build_point(sim)
		_check(tower_point.is_finite(), map_id + ": clearing permits a tower")
		if tower_point.is_finite():
			var wallet: int = sim.resources
			_check(sim.place_tower("gunTower", tower_point), map_id + ": tower builds without sealing entries")
			_check(sim.resources == wallet - 5, map_id + ": tower cost unchanged")
			_test_recovery(sim, map_id)
			sim.set_hermes_mode("following")
			_check(sim.opponents(true).filter(func(unit: Dictionary) -> bool: return unit.tower).is_empty(), map_id + ": teardown removes connected towers")
			_check(sim.resources == wallet + 6, map_id + ": recovered matter and one-quarter refund credited once")
		else:
			sim.set_hermes_mode("following")
	_test_cargo(sim, map_id)
	level.free()

func _build_point(sim: GameSimulation) -> Vector2:
	for distance: float in [112.0, 144.0, 176.0]:
		for index: int in 16:
			var candidate: Vector2 = sim.hermes.position + Vector2.from_angle(index * TAU / 16) * distance
			if sim.placement_error(candidate) == "valid":
				return candidate
	return Vector2.INF

func _test_recovery(sim: GameSimulation, map_id: String) -> void:
	var location := Vector2.INF
	for index: int in 16:
		var candidate: Vector2 = sim.hermes.position + Vector2.from_angle(index * TAU / 16) * 150
		if sim.navigation.segment_clear(sim.hermes.position, candidate, 16) and candidate.distance_to(sim.nathaniel.position) > 60:
			location = candidate
			break
	_check(location.is_finite(), map_id + ": clearing has a recovery route")
	if not location.is_finite():
		return
	var wallet: int = sim.resources
	var enemy: Dictionary = sim.spawn_enemy("soldier", location)
	sim.damage_entity(enemy.id, enemy.hp, sim.hermes.id)
	_advance(sim, 4)
	_check(sim.resources == wallet + 10 and sim.corpses.is_empty(), map_id + ": deployed Hermes recovers one body")

func _test_cargo(sim: GameSimulation, map_id: String) -> void:
	sim.set_hermes_mode("building")
	var wallet: int = sim.resources
	var corpse: Dictionary = sim.spawn_resource(10, sim.nathaniel.position)
	_advance(sim, 0.7)
	_check(corpse.carried, map_id + ": Nathaniel collects cargo")
	sim.return_to_hermes()
	_advance(sim, 15)
	_check(sim.resources == wallet + 10 and sim.corpses.is_empty(), map_id + ": return route delivers cargo once")

func _advance(sim: GameSimulation, seconds: float) -> void:
	for frame: int in roundi(seconds * 60):
		sim.step(1.0 / 60)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
