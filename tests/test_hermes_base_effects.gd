extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _game() -> GameSimulation:
	var sim := GameSimulation.new()
	sim.configure({"number": 0, "width": 64, "height": 64, "tile_size": 32,
		"blocked": [], "player_start": Vector2(200, 200), "hermes_start": Vector2(600, 600),
		"enemies": [], "wave_based": false, "initial_resources": 1000})
	sim.set_hermes_mode("following")
	sim.take_events()
	return sim


func _run() -> void:
	var effects: WorldEffects = load("res://scenes/effects/world_effects.tscn").instantiate()
	root.add_child(effects)
	effects.set_process(false)
	effects.fog_enabled = false
	_check_range(effects)
	_check_links(effects)
	_check_transfers(effects)
	_check_layer(effects)
	effects.free()
	if "--render" in OS.get_cmdline_user_args():
		await _check_rendered()
	print("Hermes base effects: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_range(effects: WorldEffects) -> void:
	var sim: GameSimulation = _game()
	effects.simulation = sim
	expect(effects.hermes_range_points().is_empty(), "Mobile Hermes has no persistent build ring")
	effects.build_open = true
	var points: PackedVector2Array = effects.hermes_range_points()
	expect(points.size() == 97 and points[0] == points[points.size() - 1], "Build shows a closed projected ring while Hermes follows")
	var exact: bool = true
	for point: Vector2 in points:
		exact = exact and absf(IsoProjection.unproject(point).distance_to(sim.hermes.position) - sim.hermes_build_range()) < 0.001
	expect(exact, "Every ring vertex represents the domain build radius in logical coordinates")
	var before: Vector2 = points[0]
	sim.hermes.position += Vector2(80, 25)
	expect(effects.hermes_range_points()[0].is_equal_approx(before + IsoProjection.project(Vector2(80, 25))), "Open Build ring follows the current Hermes ground position")
	sim.set_hermes_mode("building")
	effects.build_open = false
	expect(not effects.hermes_range_points().is_empty(), "Anchored Hermes keeps his radius visible after Build closes")
	sim.set_hermes_mode("following")
	expect(effects.hermes_range_points().is_empty(), "Following removes the persistent radius")
	effects.build_open = true
	sim.damage_entity(int(sim.hermes.id), int(sim.hermes.hp))
	expect(effects.hermes_range_points().is_empty(), "Hermes death removes the radius even with Build open")
	effects.simulation = null
	expect(effects.hermes_range_points().is_empty(), "Leaving the level clears the radius")
	effects.build_open = false


func _check_links(effects: WorldEffects) -> void:
	var sim: GameSimulation = _game()
	effects.simulation = sim
	sim.set_hermes_mode("building")
	var first: Dictionary = sim.place_map_tower("gunTower", Vector2(740, 600))
	var second: Dictionary = sim.place_map_tower("healTower", Vector2(600, 760))
	var paths: Array[PackedVector2Array] = effects.hermes_link_paths()
	expect(paths.size() == 2, "Every live tower has one conduit to anchored Hermes, including authored towers")
	var first_path: PackedVector2Array = paths[0]
	var first_start: Vector2 = IsoProjection.unproject(first_path[0])
	var first_finish: Vector2 = IsoProjection.unproject(first_path[first_path.size() - 1])
	expect(first_start.distance_to(sim.hermes.position) <= 25.01 and first_finish.distance_to(first.position) <= 18.01, "Conduit sockets meet Hermes and tower footprints in logical coordinates")
	var wallet: int = sim.resources
	var tower_position: Vector2 = second.position
	effects._process(0.1)
	expect(sim.resources == wallet and second.position == tower_position, "Presentation never changes resources or tower positions")
	effects.fog_enabled = true
	sim.fog.fill(0)
	expect(effects.hermes_link_paths().is_empty(), "A hidden tower is not revealed by its conduit")
	effects.fog_enabled = false
	sim.damage_entity(int(first.id), int(first.hp))
	expect(effects.hermes_link_paths().size() == 1, "Destroying a tower removes only its conduit")
	effects.build_open = true
	effects.placement = true
	effects.cursor_world = Vector2(820, 600)
	expect(not effects.hermes_preview_path().is_empty(), "Armed Build previews the candidate connection")
	effects.placement = false
	expect(effects.hermes_preview_path().is_empty(), "Cancelling the tower selection removes its preview")
	sim.set_hermes_mode("following")
	effects.build_open = false
	expect(effects.hermes_link_paths().is_empty(), "Following removes every persistent conduit")
	effects.placement = true
	effects.build_open = true
	sim.damage_entity(int(sim.hermes.id), int(sim.hermes.hp))
	expect(effects.hermes_link_paths().is_empty() and effects.hermes_preview_path().is_empty(), "Hermes death removes live and preview connections")
	effects.placement = false
	effects.build_open = false


func _check_transfers(effects: WorldEffects) -> void:
	var sim: GameSimulation = _game()
	effects.simulation = sim
	sim.resources = 1000
	expect(sim.place_tower("gunTower", Vector2(740, 600)), "Build transfer fixture places a paid tower")
	effects.add_events(sim.take_events())
	expect(effects.hermes_transfers.size() == 1 and not effects.hermes_transfers[0].returning, "Build emits one outward matter transfer")
	expect(effects.transients.is_empty(), "Building uses the physical cable instead of an unrelated expanding ring")
	sim.set_paused(true)
	effects._process(effects.hermes_transfer_lifetime * 0.5)
	expect(is_equal_approx(effects.hermes_transfers[0].life, effects.hermes_transfer_lifetime), "Pause freezes matter transfer")
	sim.set_paused(false)
	effects._process(effects.hermes_transfer_lifetime + 0.01)
	expect(effects.hermes_transfers.is_empty() and effects.hermes_link_paths().size() == 1, "Transfer ends while the idle physical connection remains")
	sim.set_hermes_mode("following")
	effects.add_events(sim.take_events())
	expect(effects.hermes_transfers.size() == 1 and effects.hermes_transfers[0].returning, "Reclaim emits one inward matter transfer")
	effects._process(effects.hermes_transfer_lifetime + 0.01)
	expect(effects.hermes_transfers.is_empty() and effects.hermes_link_paths().is_empty(), "Reclaimed conduits finish without idle animation or abandoned links")
	effects.add_events([{"type": "recycle", "position": Vector2(740, 600)}])
	sim.damage_entity(int(sim.hermes.id), int(sim.hermes.hp))
	effects._process(0.0)
	expect(effects.hermes_transfers.is_empty(), "Hermes death cancels any unfinished transfer")
	effects.add_events([{"type": "recycle", "position": Vector2(740, 600)}])
	effects.simulation = _game()
	expect(effects.hermes_transfers.is_empty(), "Loading another simulation clears old matter transfers")


func _check_layer(effects: WorldEffects) -> void:
	var ground: Node2D = effects.get_node("HermesGroundEffects") as Node2D
	var main: Node = load("res://scenes/main.tscn").instantiate()
	var level: Node = load("res://levels/level_0.tscn").instantiate()
	var actors: Node2D = main.get_node("World/Actors") as Node2D
	var terrain: Node2D = level.get_node("Ground") as Node2D
	expect(ground.z_index + effects.z_index < actors.z_index and ground.z_index + effects.z_index > terrain.z_index, "Conduits and range draw above native ground and below actor silhouettes")
	expect(effects.z_index == 0, "Elevated projectiles retain their existing effects layer")
	main.free()
	level.free()


func _capture(viewport: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _check_rendered() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1000, 640)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var backdrop := Polygon2D.new()
	backdrop.polygon = PackedVector2Array([Vector2.ZERO, Vector2(1000, 0), Vector2(1000, 640), Vector2(0, 640)])
	backdrop.color = Color("a69a82")
	backdrop.z_index = -20
	viewport.add_child(backdrop)
	var effects: WorldEffects = load("res://scenes/effects/world_effects.tscn").instantiate()
	effects.position = Vector2(500, -280)
	effects.fog_enabled = false
	effects.simulation = _game()
	viewport.add_child(effects)
	effects.set_process(false)
	var base: Image = await _capture(viewport)
	effects.simulation.set_hermes_mode("building")
	effects.simulation.place_map_tower("gunTower", Vector2(780, 600))
	effects.simulation.place_map_tower("laserTower", Vector2(600, 780))
	effects.simulation.place_map_tower("healTower", Vector2(460, 530))
	effects.build_open = true
	effects._process(0.0)
	var deployed: Image = await _capture(viewport)
	var visible: int = 0
	for point: Vector2 in effects.hermes_range_points():
		var screen := Vector2i(point + effects.position)
		if deployed.get_pixelv(screen) != base.get_pixelv(screen):
			visible += 1
	expect(visible > 85, "The rendered radius covers the projected domain boundary")
	var paths: Array[PackedVector2Array] = effects.hermes_link_paths()
	var cable_point: Vector2 = paths[0][paths[0].size() / 2] + effects.position
	var occluder := Polygon2D.new()
	occluder.polygon = PackedVector2Array([cable_point + Vector2(-10, -10), cable_point + Vector2(10, -10), cable_point + Vector2(10, 10), cable_point + Vector2(-10, 10)])
	occluder.color = Color("ef35a0")
	viewport.add_child(occluder)
	var occluded: Image = await _capture(viewport)
	expect(occluded.get_pixelv(Vector2i(cable_point)).is_equal_approx(occluder.color), "Actor-layer pixels cover a ground cable without cable overdraw")
	occluder.free()
	effects.build_open = false
	effects.simulation.set_hermes_mode("following")
	effects._process(0.0)
	var following: Image = await _capture(viewport)
	expect(following.get_data() == base.get_data(), "Rendered range and connections leave no residual pixels after Follow")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-artifacts"))
	expect(deployed.save_png("res://test-artifacts/hermes-ground-effects-review.png") == OK, "Hermes ground effects capture is saved")
	viewport.free()
