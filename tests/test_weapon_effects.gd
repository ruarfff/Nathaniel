extends SceneTree
## Check muzzle placement through real actor views and the application event path.

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
		"blocked": [], "player_start": Vector2(84, 242), "hermes_start": Vector2(600, 242),
		"enemies": [], "wave_based": false})
	return sim


func _run() -> void:
	_check_launch_and_restore()
	_check_reusable_model()
	_check_healing_recipients()
	_check_healing_range()
	await _check_application()
	print("Weapon effects: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_launch_and_restore() -> void:
	var sim: GameSimulation = _game()
	var tower: Dictionary = sim.place_map_tower("gunTower", Vector2(1000, 1000))
	var actor: ActorView = load("res://scenes/actors/gun_tower.tscn").instantiate()
	root.add_child(actor)
	actor.set_process(false)
	var actors: Dictionary = {int(tower.id): actor}
	var effects := WorldEffects.new()
	root.add_child(effects)
	effects.set_process(false)
	effects.simulation = sim
	sim.take_events()
	var origin: Vector2 = tower.position
	var direction := Vector2(0.83, 0.37).normalized()
	tower.cooldown = tower.delay
	expect(CombatRules.shoot(sim, tower, origin + direction * 200), "Tower fires an arbitrary-angle shot")
	var shot: Dictionary = sim.projectiles.back()
	actor.apply_state(tower, false, false)
	var muzzle: Vector2 = actor.weapon_muzzle(direction)
	expect(muzzle.is_finite() and not muzzle.is_zero_approx(), "Gun model supplies an elevated barrel-tip offset")
	actor.notify_attack(direction)
	effects.add_events(sim.take_events(), actors)
	effects.sync_projectiles(actors)
	var launch: Vector2 = IsoProjection.project(origin) + muzzle
	expect(effects.projectile_position(shot).distance_to(launch) < 0.001, "First projectile point is the pre-recoil muzzle")
	expect(effects.muzzle_flashes.size() == 1 and Vector2(effects.muzzle_flashes[0].position).distance_to(launch) < 0.001, "Flash and bullet share the barrel-tip launch point")
	expect(effects.transients.is_empty(), "A rigged shot does not also produce a ring at the tower feet")
	expect(shot.position == origin, "Presentation keeps the logical projectile origin unchanged")

	tower.position += Vector2(100, -20)
	tower.facing = Vector2(-0.4, 0.9).normalized()
	actor.apply_state(tower, false, false)
	shot.position += direction * 27.0
	effects.sync_projectiles(actors)
	expect(effects.projectile_position(shot).distance_to(launch + IsoProjection.project(direction * 27.0)) < 0.001, "Owner movement and retargeting cannot move or steer an in-flight bullet")
	expect(Vector2(effects.muzzle_flashes[0].position).distance_to(launch) < 0.001, "Flash stays at the recorded emission point")
	var flash_life: float = effects.muzzle_flashes[0].life
	sim.set_paused(true)
	effects._process(1.0)
	expect(is_equal_approx(effects.muzzle_flashes[0].life, flash_life), "Pause freezes the muzzle flash")
	sim.set_paused(false)
	effects._process(1.0)
	expect(effects.muzzle_flashes.is_empty(), "Muzzle flash expires after resuming")

	tower.cooldown = tower.delay
	var second_direction: Vector2 = tower.facing
	expect(CombatRules.shoot(sim, tower, tower.position + second_direction * 200), "Retargeted tower fires again")
	actor.apply_state(tower, false, false)
	actor.notify_attack(second_direction)
	effects.add_events(sim.take_events(), actors)
	effects.sync_projectiles(actors)
	var second: Dictionary = sim.projectiles.back()
	expect(effects.projectile_position(second).distance_to(IsoProjection.project(tower.position) + actor.weapon_muzzle(second_direction)) < 0.001, "Next shot uses its own barrel position")
	expect(effects.projectile_position(shot).distance_to(launch + IsoProjection.project(direction * 27.0)) < 0.001, "Next shot leaves the previous shot's offset unchanged")

	var restored := GameSimulation.new()
	expect(restored.restore(sim.snapshot()), "Logical save restores with active gun shots")
	effects.simulation = restored
	expect(effects.muzzle_flashes.is_empty(), "Loading another simulation clears old flashes")
	effects.sync_projectiles(actors)
	var restored_shot: Dictionary = restored.projectiles[0]
	expect(effects.projectile_position(restored_shot).distance_to(IsoProjection.project(restored_shot.position) + muzzle) < 0.001, "Restored shot uses its own direction, independent of current tower aim")
	expect(effects.muzzle_flashes.is_empty(), "Restoring shots does not replay their firing flashes")
	restored.remove_projectile(restored_shot)
	effects.sync_projectiles(actors)
	expect(effects.projectile_position(restored_shot) == IsoProjection.project(restored_shot.position), "Removed shots release their cached launch offset")
	effects.simulation = _game()
	expect(effects.projectile_position(second) == IsoProjection.project(second.position), "New level cannot reuse a previous level's launch offset")

	var legacy: ActorView = load("res://scenes/actors/soldier.tscn").instantiate()
	root.add_child(legacy)
	expect(not legacy.weapon_muzzle(direction).is_finite(), "Sprite-only actors explicitly report no model muzzle")
	effects.add_events([{"type": "shot", "shot_id": 99, "owner_id": 99,
		"position": origin, "direction": direction}], {99: legacy})
	expect(effects.muzzle_flashes.is_empty() and effects.transients.size() == 1, "Sprite-only actors retain their existing shot effect")
	legacy.free()
	actor.free()
	effects.free()


func _check_reusable_model() -> void:
	var actor: ActorView = load("res://scenes/actors/soldier.tscn").instantiate()
	var original: ActorVisual = actor.visual
	var variant: ActorVisual = original.duplicate() as ActorVisual
	var gun_visual: ActorVisual = load("res://resources/actors/gun_tower.tres")
	variant.model_scene = gun_visual.model_scene
	actor.visual = variant
	root.add_child(actor)
	actor.model_view.set_process(false)
	var direction := Vector2(0.17, 0.97).normalized()
	actor.apply_state({"position": Vector2(180, 180), "facing": direction}, false, false)
	expect(actor.kind == "soldier" and actor.model_view != null and not actor.sprite.visible, "Assigning a model resource enables live aiming on another actor kind")
	expect(original.model_scene == null, "Reusing the model does not change the production soldier resource")
	var model: ActorModelView = actor.model_view
	var forward: Vector3 = model.aim_pivot.global_basis.x
	expect(Vector2(-forward.z, forward.x).normalized().dot(direction) > 0.99999, "Another actor kind aims continuously through apply_state")
	var first_muzzle: Vector2 = actor.weapon_muzzle(direction)
	var fired_direction := Vector2(-0.91, 0.23).normalized()
	actor.notify_attack(fired_direction)
	forward = model.aim_pivot.global_basis.x
	expect(Vector2(-forward.z, forward.x).normalized().dot(fired_direction) > 0.99999, "Another actor kind faces the launch direction through notify_attack")
	var fired_muzzle: Vector2 = actor.weapon_muzzle(fired_direction)
	expect(fired_muzzle.is_finite() and fired_muzzle.distance_to(first_muzzle) > 10.0, "Another actor kind exposes its transformed muzzle through weapon_muzzle")
	var rest: Transform3D = model.recoil.transform
	actor.apply_state({"position": Vector2(180, 180), "facing": fired_direction}, false, true)
	model._process(0.025)
	expect(not model.recoil.transform.is_equal_approx(rest), "Another actor kind plays the same firing recoil")
	actor.notify_respawn()
	expect(model.recoil.transform.is_equal_approx(rest), "Another actor kind resets the firing pose through notify_respawn")
	actor.free()


func _check_healing_recipients() -> void:
	var sim: GameSimulation = _game()
	var tower: Dictionary = sim.place_map_tower("healTower", Vector2(200, 242))
	var effects := WorldEffects.new()
	root.add_child(effects)
	effects.set_process(false)
	effects.simulation = sim
	sim.fog.fill(2)
	sim.take_events()
	CombatRules.update_unit(sim, tower, 1.0)
	effects.add_events(sim.take_events())
	expect(effects.healing_flashes.is_empty(), "A tower near healthy characters produces no healing flash")
	sim.nathaniel.hp -= 10
	CombatRules.update_unit(sim, tower, 1.0)
	effects.add_events(sim.take_events())
	expect(effects.healing_flashes.size() == 1 and int(effects.healing_flashes[0].target_id) == int(sim.nathaniel.id), "Successful healing flashes the character selected by the domain event")
	expect(effects.transients.is_empty(), "Healing does not produce the generic orange event ring")
	var markers: Array[Dictionary] = effects.healing_markers()
	expect(markers.size() == 1 and Vector2(markers[0].position) == IsoProjection.project(sim.nathaniel.position) - Vector2(0, effects.healing_flash_height), "Healing glint is above the recipient's feet")
	sim.nathaniel.position += Vector2(40, -20)
	markers = effects.healing_markers()
	expect(Vector2(markers[0].position) == IsoProjection.project(sim.nathaniel.position) - Vector2(0, effects.healing_flash_height), "Healing glint follows a moving recipient")
	sim.fog.fill(1)
	expect(effects.healing_markers().is_empty(), "Explored fog hides the healing recipient cue")
	effects.fog_enabled = false
	expect(effects.healing_markers().size() == 1, "Disabling fog allows the healing recipient cue")
	effects.fog_enabled = true
	sim.fog.fill(2)
	var flash_life: float = effects.healing_flashes[0].life
	sim.set_paused(true)
	effects._process(1.0)
	expect(is_equal_approx(effects.healing_flashes[0].life, flash_life), "Pause freezes healing feedback")
	sim.set_paused(false)
	sim.result = "victory"
	effects._process(1.0)
	expect(is_equal_approx(effects.healing_flashes[0].life, flash_life), "Finished simulation freezes healing feedback")
	sim.result = "playing"
	effects._process(effects.healing_flash_lifetime * 0.5)
	expect(float(effects.healing_markers()[0].strength) > 0.0 and float(effects.healing_markers()[0].strength) < 1.0, "Healing glint fades before it expires")
	effects._process(effects.healing_flash_lifetime)
	expect(effects.healing_flashes.is_empty() and effects.healing_markers().is_empty(), "Healing feedback expires after resuming")

	sim.nathaniel.hp = sim.nathaniel.max_hp
	sim.hermes.position = tower.position + Vector2(80, 0)
	sim.hermes.hp -= 10
	CombatRules.update_unit(sim, tower, 1.0)
	effects.add_events(sim.take_events())
	expect(effects.healing_flashes.size() == 1 and int(effects.healing_flashes[0].target_id) == int(sim.hermes.id), "Hermes receives the cue when Hermes is healed")
	sim.damage_entity(int(sim.hermes.id), int(sim.hermes.hp))
	expect(effects.healing_markers().is_empty(), "A dead recipient hides its cue even after game over")
	effects.simulation = _game()
	expect(effects.healing_flashes.is_empty(), "Replacing the simulation clears healing feedback")

	var removed: Dictionary = effects.simulation.place_map_tower("gunTower", Vector2(900, 900))
	effects.fog_enabled = false
	effects.add_events([{"type": "heal", "target_id": removed.id, "position": removed.position}])
	expect(effects.healing_markers().size() == 1, "Live recipient cue exists before recipient removal")
	effects.simulation.damage_entity(int(removed.id), int(removed.hp))
	expect(effects.healing_markers().is_empty(), "A removed recipient cannot leave a healing cue")
	effects._process(0.01)
	expect(effects.healing_flashes.is_empty(), "Removed recipients release pending healing feedback")
	effects.add_events([{"type": "heal", "target_id": -1, "position": Vector2.ZERO}])
	expect(effects.healing_flashes.is_empty() and effects.transients.is_empty(), "An invalid recipient cannot fall back to a misleading event ring")
	effects.add_events([{"type": "hit", "position": Vector2.ZERO}])
	expect(effects.transients.size() == 1, "Non-healing events retain their existing ring")
	effects.free()


func _check_healing_range() -> void:
	var effects := WorldEffects.new()
	root.add_child(effects)
	effects.set_process(false)
	expect(effects.healing_range_points().is_empty(), "No simulation has no healing range outline")
	var sim: GameSimulation = _game()
	var tower: Dictionary = sim.place_map_tower("healTower", Vector2(800, 700))
	effects.simulation = sim
	sim.fog.fill(2)
	expect(effects.healing_range_points().is_empty(), "Healing ranges stay hidden until a tower is selected")
	effects.selected_healing_tower_id = int(tower.id)
	var points: PackedVector2Array = effects.healing_range_points()
	expect(points.size() > 3 and points[0] == points[-1], "Selected healing range forms a closed outline")
	var matches_radius: bool = true
	for point: Vector2 in points:
		matches_radius = matches_radius and absf(IsoProjection.unproject(point).distance_to(tower.position) - float(tower.range)) < 0.001
	expect(matches_radius, "Every range vertex is the tower's actual logical healing distance")
	expect(points[0].distance_to(IsoProjection.project(Vector2(tower.position) + Vector2(float(tower.range), 0))) < 0.001, "Healing range uses the game's logical-to-isometric projection")
	sim.apply_design_parameters(tower, {"range": 317.5})
	points = effects.healing_range_points()
	matches_radius = true
	for point: Vector2 in points:
		matches_radius = matches_radius and absf(IsoProjection.unproject(point).distance_to(tower.position) - 317.5) < 0.001
	expect(matches_radius, "Authored healing range overrides change the visible boundary")
	sim.set_paused(true)
	effects._process(2.0)
	expect(effects.healing_range_points() == points, "Pause keeps the selected healing range visible and unchanged")
	sim.set_paused(false)
	sim.fog.fill(1)
	expect(effects.healing_range_points().is_empty(), "Explored fog hides the selected tower's healing range")
	sim.fog.fill(0)
	expect(effects.healing_range_points().is_empty(), "Unexplored fog hides the selected tower's healing range")
	effects.fog_enabled = false
	expect(effects.healing_range_points() == points, "Disabling fog exposes the same actual healing range")
	effects.fog_enabled = true
	sim.fog.fill(2)
	sim.apply_design_parameters(tower, {"hp": 0})
	expect(effects.healing_range_points().is_empty(), "A dead healing tower has no range outline")
	sim.apply_design_parameters(tower, {"hp": tower.max_hp})
	var gun: Dictionary = sim.place_map_tower("gunTower", Vector2(1100, 1000))
	effects.selected_healing_tower_id = int(gun.id)
	expect(effects.healing_range_points().is_empty(), "A non-healing tower cannot show a healing range")
	effects.selected_healing_tower_id = -999
	expect(effects.healing_range_points().is_empty(), "An invalid tower selection cannot show a healing range")
	effects.selected_healing_tower_id = int(tower.id)
	sim.damage_entity(int(tower.id), int(tower.hp))
	expect(effects.healing_range_points().is_empty(), "Removing the selected tower hides its healing range")
	var replacement: GameSimulation = _game()
	replacement.place_map_tower("healTower", Vector2(800, 700))
	replacement.fog.fill(2)
	effects.simulation = replacement
	expect(effects.selected_healing_tower_id == -1 and effects.healing_range_points().is_empty(), "A new simulation clears selection even when tower IDs repeat")
	effects.free()


func _check_application() -> void:
	var app: GameApp = load("res://scenes/main.tscn").instantiate()
	app.storage_root = "/private/tmp/nathaniel-gun-effects-%d/" % Time.get_ticks_usec()
	root.add_child(app)
	app.set_physics_process(false)
	expect(app.load_level(0), "Real application loads an isolated tower scenario")
	app.sim.nathaniel.delay = 100000.0
	app.sim.hermes.delay = 100000.0
	var resources_before: int = app.sim.resources
	var build_point: Vector2 = app.sim.hermes.position + Vector2(160, 0)
	var built: bool = app.sim.place_tower("gun_tower", build_point)
	expect(built, "Hermes builds a gun tower through the normal paid placement API")
	if not built:
		app.queue_free()
		await process_frame
		return
	var tower: Dictionary = app.sim.entities.back()
	expect(tower.kind == "gunTower" and tower.owned and app.sim.hermes_mode == "building", "Player placement creates an owned gun tower and stops Hermes")
	expect(app.sim.resources == resources_before - int(GameBalance.COSTS.gunTower), "The live gun tower uses the normal construction cost")
	var direction := Vector2(-0.31, 0.82).normalized()
	tower.cooldown = tower.delay
	app.sim.take_events()
	expect(CombatRules.shoot(app.sim, tower, tower.position + direction * 180), "Application scenario emits a shot before view synchronization")
	app._physics_process(0.0)
	var actor: ActorView = app.views[int(tower.id)]
	expect(actor.model_view != null and actor.model_view.visible and actor.visual.model_scene.resource_path == "res://scenes/actors/generated/gun_tower_model.tscn", "The normal game selects the reusable live model for a player-built gun tower")
	var shot: Dictionary = app.sim.projectiles.back()
	var expected: Vector2 = IsoProjection.project(tower.position) + actor.weapon_muzzle(direction)
	expect(app.effects.projectile_position(shot).distance_to(expected) < 0.001, "GameApp resolves the muzzle after creating and aiming the live actor")
	expect(app.effects.muzzle_flashes.size() == 1 and Vector2(app.effects.muzzle_flashes[0].position).distance_to(expected) < 0.001, "GameApp dispatches the same muzzle to flash and projectile")
	app.sim.damage_entity(int(tower.id), int(tower.hp))
	app._physics_process(0.0)
	expect(not app.views.has(int(tower.id)) and app.sim.projectiles.is_empty(), "Tower destruction removes its actor and logical shots")
	expect(app.effects.projectile_position(shot) == IsoProjection.project(shot.position), "Tower destruction clears the shot's presentation offset")
	app.show_main()
	expect(app.effects.muzzle_flashes.is_empty(), "Returning to the menu clears weapon flashes")
	app.queue_free()
	await process_frame
