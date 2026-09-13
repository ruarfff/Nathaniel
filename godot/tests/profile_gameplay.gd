extends SceneTree
## Repeatable simulation-only profile. No save data or user configuration is read.
## --headless --path godot --script res://tests/profile_gameplay.gd

func _initialize() -> void:
	var reports: Array[Dictionary] = []
	for number: int in range(6):
		var scene: PackedScene = load("res://levels/level_%d.tscn" % number) as PackedScene
		var node: GameLevel = scene.instantiate() as GameLevel
		var sim := GameSimulation.new()
		sim.configure(node.data())
		var report: Dictionary = _measure(sim, "level_%d" % number, 180)
		report["start_walkable"] = sim.navigation.terrain_clear(GameSimulation.point(sim.level.player_start))
		report["hermes_walkable"] = sim.navigation.terrain_clear(GameSimulation.point(sim.level.hermes_start))
		reports.append(report)
		node.free()
	var busy := GameSimulation.new()
	busy.configure({"number": 0, "width": 128, "height": 128, "tile_size": 32,
		"blocked": [], "player_start": Vector2(2048, 2048), "hermes_start": Vector2(2148, 2048),
		"wave_based": false, "enemies": [], "seed": 137})
	for player: Dictionary in [busy.nathaniel, busy.hermes]:
		player.hp = 1000000000
		player.max_hp = 1000000000
	for index: int in 30:
		var position := Vector2(1500 + (index % 6) * 160, 1500 + (index / 6) * 160)
		var tower: Dictionary = busy.place_map_tower(GameBalance.TOWERS[index % 3], position)
		tower.max_hp = 1000000
		tower.hp = 1000000
	for index: int in 200:
		var angle: float = index * TAU / 200
		var enemy: Dictionary = busy.spawn_enemy(GameBalance.ENEMIES[index % 4], Vector2(2048, 2048) + Vector2.from_angle(angle) * (650 + (index % 8) * 20))
		enemy.max_hp = 1000000
		enemy.hp = 1000000
	reports.append(_measure(busy, "busy_200_enemies_30_towers", 600))
	var output: Dictionary = {"engine": Engine.get_version_info().string,
		"platform": OS.get_name(), "architecture": Engine.get_architecture_name(),
		"processor": OS.get_processor_name(), "processors": OS.get_processor_count(),
		"physics_delta": 1.0 / 60.0, "warmup_frames": 60,
		"scope": "simulation only, rendered frame time measured separately",
		"busy_health_override": "High HP keeps original combat active without shrinking the workload",
		"reports": reports}
	var path: String = "/tmp/nathaniel-godot-profile.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(output, "\t"))
		file.close()
	print(JSON.stringify(output, "\t"))
	print("PROFILE written to " + path)
	quit(0)

func _measure(sim: GameSimulation, name: String, frames: int) -> Dictionary:
	for frame: int in 60:
		sim.step(1.0 / 60.0)
	var initial: int = sim.entities.size()
	var timings: Array[float] = []
	var maximum_projectiles: int = 0
	for frame: int in frames:
		var start: int = Time.get_ticks_usec()
		sim.step(1.0 / 60.0)
		timings.append((Time.get_ticks_usec() - start) / 1000.0)
		maximum_projectiles = maxi(maximum_projectiles, sim.projectiles.size())
	timings.sort()
	return {"workload": name, "frames": frames, "initial_entities": initial,
		"final_entities": sim.entities.size(), "maximum_projectiles": maximum_projectiles,
		"median_ms": timings[frames / 2], "p95_ms": timings[mini(frames - 1, ceili(frames * 0.95))],
		"max_ms": timings.back(), "state": sim.result}
