extends SceneTree
## Exercise the research loop and map identity through the application boundary.

var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var app := load("res://scenes/main.tscn").instantiate() as GameApp
	app.storage_root = "/private/tmp/nathaniel-research-lifecycle-%d-%d/" % [OS.get_process_id(), Time.get_ticks_usec()]
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	for map_id: String in SurvivalMapCatalog.NEW_RUN_IDS:
		app.map_selection_override = map_id
		app.command("survival")
		await process_frame
		app.set_physics_process(false)
		_test_map(app, map_id)
	app.save_store.delete_slot(1)
	app.audio.music.stop()
	app.queue_free()
	await process_frame
	for failure: String in failures:
		push_error(failure)
	print("Research lifecycle: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_map(app: GameApp, map_id: String) -> void:
	var sim: GameSimulation = app.sim
	_check(sim.survival_map_id == map_id and sim.tech == 0, map_id + ": new run starts without tech")
	sim.level.wave_based = false
	var body: Dictionary = sim.spawn_resource(10, sim.nathaniel.position)
	_advance(sim, 0.8)
	_check(body.carried, map_id + ": matter rack is full")
	for kind: String in ["grunt", "spawner"]:
		var enemy: Dictionary = sim.spawn_enemy(kind, sim.nathaniel.position)
		sim.damage_entity(enemy.id, enemy.hp, sim.nathaniel.id)
	_advance(sim, 1.0)
	_check(sim.tech == 9 and sim.tech_pickups.is_empty(), map_id + ": both drop types collect with full cargo")
	sim.resources = 100
	var point: Vector2 = _build_point(sim)
	_check(point.is_finite(), map_id + ": research has an accessible build location")
	if not point.is_finite():
		return
	_check(sim.place_tower("researchCenter", point), map_id + ": research builds")
	sim.tech = 126
	_check(sim.begin_research(sim.research_center().id), map_id + ": research opens")
	for track: String in ["capacity", "reach", "cooling", "plating"]:
		for rank: int in 2:
			_check(sim.purchase_research(track, rank, sim.research_session_id), map_id + ": buys " + track + " rank " + str(rank + 1))
	_check(sim.tech == 0, map_id + ": full catalog costs 126 tech")
	sim.end_research()
	sim.tech = 7
	sim.set_hermes_mode("following")
	_check(sim.research_center().is_empty() and sim.tech == 7 and sim.research_ranks.plating == 2, map_id + ": pack-up keeps tech and learned ranks")
	point = _build_point(sim)
	_check(point.is_finite() and sim.place_tower("researchCenter", point), map_id + ": center rebuilds")
	_check(sim.research_ranks.capacity == 2 and sim.nathaniel.resource_capacity == 3, map_id + ": rebuild keeps purchased capacity")
	sim.lives = 1
	sim.damage_entity(sim.nathaniel.id, sim.nathaniel.hp, -1)
	_check(sim.nathaniel.hp > 0 and sim.tech == 7 and sim.research_ranks.cooling == 2, map_id + ": spare life keeps tech and research")
	app.command("confirm_save", 1)
	app.show_main()
	app.command("load_slot", 1)
	sim = app.sim
	_check(sim.survival_map_id == map_id and sim.tech == 7 and sim.research_ranks.reach == 2, map_id + ": save/resume keeps map and research")
	_check(not sim.research_center().is_empty() and not sim.paused and sim.research_session_id == 0, map_id + ": resume keeps center with menu closed")
	sim.result = "gameOver"
	app.command("continue_result")
	_check(app.sim.survival_map_id == map_id and app.sim.tech == 0 and app.sim.research_ranks.capacity == 0 and app.sim.tech_pickups.is_empty(), map_id + ": Retry keeps map and clears research")
	app.sim.tech = 77
	app.map_selection_override = map_id
	app.command("survival")
	_check(app.sim.tech == 0 and app.sim.research_ranks.plating == 0 and app.sim.research_center().is_empty(), map_id + ": New Run clears economy and center")

func _build_point(sim: GameSimulation) -> Vector2:
	for distance: float in [112.0, 144.0, 176.0]:
		for index: int in 24:
			var candidate: Vector2 = sim.hermes.position + Vector2.from_angle(index * TAU / 24.0) * distance
			if sim.placement_error(candidate) == "valid":
				return candidate
	return Vector2.INF

func _advance(sim: GameSimulation, seconds: float) -> void:
	for frame: int in ceili(seconds * 60.0):
		sim.step(1.0 / 60.0)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
