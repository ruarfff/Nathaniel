extends SceneTree
## Fixed workloads report tech conservation, collection cost, and spawner income.

const STEP: float = 1.0 / 60.0

func _initialize() -> void:
	var report: Dictionary = {
		"stack_workload": _stacks(),
		"immediate_spawner_kill": _spawner(false),
		"six_minute_spawner_farm": _spawner(true),
		"notes": "Synthetic open-ground workload. Children are killed immediately; combat risk and travel are not measured.",
	}
	DirAccess.make_dir_recursive_absolute("res://test-artifacts/research")
	var file := FileAccess.open("res://test-artifacts/research/profile.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print(JSON.stringify(report))
	quit()

func _simulation() -> GameSimulation:
	var sim := GameSimulation.new()
	sim.configure({"number": 0, "width": 64, "height": 64, "tile_size": 32,
		"player_start": Vector2(96, 96), "hermes_start": Vector2(96, 160),
		"blocked": [], "enemies": [], "towers": [], "wave_based": false})
	return sim

func _stacks() -> Dictionary:
	var sim := _simulation()
	var start: int = Time.get_ticks_usec()
	for index: int in 10000:
		var position := Vector2(400 + (index % 30) * 32, 400 + ((index / 30) as int % 30) * 32)
		sim.spawn_tech(1, position)
	var creation_ms: float = (Time.get_ticks_usec() - start) / 1000.0
	var amount: int = _quantity(sim)
	var samples: Array[int] = []
	for frame: int in 600:
		start = Time.get_ticks_usec()
		sim.step(STEP)
		samples.append(Time.get_ticks_usec() - start)
		sim.take_events()
	samples.sort()
	return {"deaths": 10000, "remaining_stacks": sim.tech_pickups.size(), "preserved_tech": amount,
		"creation_ms": creation_ms, "simulation_step_median_us": samples[300],
		"simulation_step_p95_us": samples[570], "simulation_step_max_us": samples[-1]}

func _spawner(farm: bool) -> Dictionary:
	var sim := _simulation()
	var spawner: Dictionary = sim.spawn_enemy("spawner", Vector2(1200, 1200))
	var children: int = 0
	if farm:
		for frame: int in 360 * 60:
			sim.step(STEP)
			for enemy: Dictionary in sim.opponents(false).duplicate():
				if enemy.kind == "grunt" and CombatRules.alive(enemy):
					children += 1
					sim.damage_entity(enemy.id, enemy.hp, sim.nathaniel.id)
			sim.take_events()
	var child_tech: int = _quantity(sim)
	sim.damage_entity(spawner.id, spawner.hp, sim.nathaniel.id)
	return {"seconds": 360 if farm else 0, "children_killed": children, "child_tech": child_tech,
		"tech_after_spawner_kill": _quantity(sim), "remaining_stacks": sim.tech_pickups.size()}

func _quantity(sim: GameSimulation) -> int:
	var total: int = sim.tech
	for pickup: Dictionary in sim.tech_pickups:
		total += int(pickup.amount)
	return total
