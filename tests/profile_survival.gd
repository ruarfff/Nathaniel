extends SceneTree
## Compare the same six-minute wave seeds on legacy and authored terrain.

const MAPS: Array[String] = ["legacy_survival", "abandoned_crossroads", "dry_wash", "freight_yard", "open_countryside"]
const SEEDS: Array[int] = [137, 733]
const FPS: int = 60
const SECONDS: int = 360

func _initialize() -> void:
	var reports: Array[Dictionary] = []
	for map_id: String in MAPS:
		var path: String = "res://levels/level_0.tscn" if map_id == "legacy_survival" else "res://levels/survival/%s.tscn" % map_id
		var level: GameLevel = load(path).instantiate() as GameLevel
		for seed_value: int in SEEDS:
			var data: Dictionary = level.data()
			data.seed = seed_value
			var sim := GameSimulation.new()
			sim.configure(data)
			for hero: Dictionary in [sim.nathaniel, sim.hermes]:
				hero.hp = 1000000000
				hero.max_hp = 1000000000
			sim.set_hermes_mode("building")
			var timings: Array[float] = []
			var peak_enemies: int = 0
			var first_contact: float = -1.0
			var recovered: int = 0
			var peak_pending: int = 0
			for frame: int in SECONDS * FPS:
				var start: int = Time.get_ticks_usec()
				sim.step(1.0 / FPS)
				if frame >= FPS:
					timings.append((Time.get_ticks_usec() - start) / 1000.0)
				peak_enemies = maxi(peak_enemies, sim.opponents(false).size())
				peak_pending = maxi(peak_pending, sim.pending_wave_kinds.size())
				for event: Dictionary in sim.take_events():
					if event.type == "hit" and not event.get("target_enemy", true) and first_contact < 0:
						first_contact = sim.elapsed_time
					if event.type == "delivery":
						recovered += 1
			timings.sort()
			var report := {"map_id": map_id, "seed": seed_value, "first_enemy_hit_seconds": first_contact,
				"peak_enemies": peak_enemies, "final_enemies": sim.opponents(false).size(),
				"peak_pending_waves": peak_pending, "final_pending_waves": sim.pending_wave_kinds.size(),
				"spawn_blocked_reason": sim.spawn_blocked_reason,
				"delivered_bodies": recovered, "resource_gain": sim.resources - int(data.starting_resources),
				"median_ms": timings[timings.size() / 2], "p95_ms": timings[ceili(timings.size() * 0.95)], "max_ms": timings.back()}
			reports.append(report)
			print(JSON.stringify(report))
		level.free()
	var directory: String = "res://test-artifacts/survival-maps"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var file := FileAccess.open(directory.path_join("simulation-profile.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string,
		"cpu": OS.get_processor_name(), "platform": OS.get_name(), "delta": 1.0 / FPS,
		"warmup_frames": FPS, "sample_frames": SECONDS * FPS - FPS,
		"workload": "Same wave seeds, stationary Nathaniel and deployed Hermes at each authored start; high hero HP permits all six minutes. No towers or balance overrides.",
		"reports": reports}, "\t") + "\n")
	quit(0)
