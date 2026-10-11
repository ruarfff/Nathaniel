extends SceneTree
## Exercise live beam attachment, resource variation, pause, removal and impacts.

class LaserActor extends ActorView:
	var muzzle: Vector2 = Vector2(11, -38)
	var target_offset := Vector2.ZERO
	var target_height: float = 0.0
	var aim_calls: int = 0
	var clear_calls: int = 0

	func aim_laser(offset: Vector2, height: float) -> void:
		aim_calls += 1
		target_offset = offset
		target_height = height

	func clear_laser_aim() -> void:
		clear_calls += 1

	func laser_muzzle() -> Vector2:
		return muzzle


class GroundEffects extends WorldEffects:
	var ground_draws: int = 0

	func _draw_hermes_ground() -> void:
		ground_draws += 1
		super._draw_hermes_ground()


class DrawEffects extends WorldEffects:
	var draws: int = 0
	var physics_draws: int = 0

	func _draw() -> void:
		draws += 1
		if Engine.is_in_physics_frame():
			physics_draws += 1
		super._draw()


class PhysicsEffectsDriver extends Node:
	var effects: WorldEffects
	var ticks: int = 0

	func _physics_process(_delta: float) -> void:
		ticks += 1
		effects.sync_projectiles({})
		effects.sync_lasers({})
		effects.add_events([])
		effects.pulse_delivery(Vector2.ZERO)


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
	sim.fog.fill(2)
	return sim


func _run() -> void:
	_check_beams()
	_check_impacts()
	_check_fog()
	_check_impact_scope()
	_check_laser_aim_lifecycle()
	await _check_retained_ground()
	await _check_physics_redraws()
	print("Laser effects: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_beams() -> void:
	var sim: GameSimulation = _game()
	var target: Dictionary = sim.spawn_enemy("soldier", Vector2(720, 242))
	sim.hermes.target_id = target.id
	sim.hermes.firing = true
	var emitter := LaserActor.new()
	emitter.visual = load("res://resources/actors/hermes.tres")
	var recipient := ActorView.new()
	recipient.visual = ActorVisual.new()
	recipient.visual.contact_height = 30.0
	var views: Dictionary = {int(sim.hermes.id): emitter, int(target.id): recipient}
	var effects := WorldEffects.new()
	effects.simulation = sim
	effects.sync_lasers(views)
	var beams: Array[Dictionary] = effects.laser_beams()
	expect(beams.size() == 1, "Firing mobile Hermes produces one beam")
	expect(beams[0].start == IsoProjection.project(sim.hermes.position) + emitter.muzzle, "Beam starts at the current projected emitter")
	expect(Vector2(beams[0].finish).is_equal_approx(IsoProjection.project(target.position) - Vector2(0, 30.0 * WorldEffects.HEIGHT_PROJECTION)), "Beam ends at the authored contact height")
	expect(emitter.target_offset == Vector2(target.position) - Vector2(sim.hermes.position) and emitter.target_height == 30.0, "Aim receives a logical ground offset and vertical height")
	emitter.muzzle += Vector2(3, -2)
	sim.hermes.position += Vector2(4, 7)
	target.position += Vector2(-5, 2)
	beams = effects.laser_beams()
	expect(beams[0].start == IsoProjection.project(sim.hermes.position) + emitter.muzzle, "Walking pose and owner motion update the emitter without a new event")
	expect(Vector2(beams[0].finish).is_equal_approx(IsoProjection.project(target.position) - Vector2(0, 30.0 * WorldEffects.HEIGHT_PROJECTION)), "Moving target keeps its contact attached")
	effects.add_events([{"type": "laser", "owner_id": sim.hermes.id, "position": sim.hermes.position}], views)
	expect(effects.transients.is_empty(), "Styled laser starts at the aperture without a ground ring")
	effects._process(0.05)
	var age: float = effects.laser_beams()[0].age
	sim.set_paused(true)
	effects._process(1.0)
	expect(effects.laser_beams()[0].age == age, "Pause freezes beam spark and aperture-flash time")
	sim.set_paused(false)
	effects._process(0.05)
	expect(effects.laser_beams()[0].age > age, "Beam effects continue after resume")
	var next_target: Dictionary = sim.spawn_enemy("grunt", Vector2(750, 300))
	sim.hermes.target_id = next_target.id
	expect(effects.laser_beams()[0].age == 0.0, "Retargeting a live burst starts fresh contact sparks")
	sim.hermes.target_id = target.id
	sim.hermes.firing = false
	expect(effects.laser_beams().is_empty(), "Burst end removes the beam immediately")
	sim.hermes.firing = true
	expect(effects.laser_beams()[0].age == 0.0, "A new burst restarts its aperture flash")
	sim.hermes.anchored = true
	expect(effects.laser_beams().is_empty(), "Deployment cannot leave a shoulder beam")
	sim.hermes.anchored = false
	emitter.muzzle = Vector2.INF
	expect(effects.laser_beams().is_empty(), "Missing emitter never falls back to the actor feet")
	emitter.muzzle = Vector2(11, -38)
	sim.hermes.target_id = -1
	expect(effects.laser_beams().is_empty(), "Target loss removes the beam")
	sim.hermes.target_id = target.id
	target.hp = 0
	expect(effects.laser_beams().is_empty(), "Target death removes the beam")
	target.hp = target.max_hp
	sim.hermes.hp = 0
	expect(effects.laser_beams().is_empty(), "Emitter death removes the beam")
	sim.hermes.hp = sim.hermes.max_hp
	var style := LaserVisual.new()
	style.edge_color = Color.BLUE
	var variant: ActorVisual = emitter.visual.duplicate() as ActorVisual
	variant.laser = style
	emitter.visual = variant
	expect(effects.laser_beams()[0].style == style, "A resource selects a different beam appearance without renderer changes")
	variant.laser = null
	beams = effects.laser_beams()
	expect(beams[0].style == null and beams[0].start == IsoProjection.project(sim.hermes.position) - Vector2(0, effects.laser_height), "Unstyled lasers keep the original elevated origin and treatment")
	effects.simulation = _game()
	expect(effects.laser_beams().is_empty(), "Replacing a simulation clears beam lifecycle state")
	emitter.free()
	recipient.free()
	effects.free()


func _check_impact_scope() -> void:
	var sim: GameSimulation = _game()
	var target: Dictionary = sim.spawn_enemy("soldier", Vector2(720, 242))
	var views: Dictionary = {}
	for index: int in range(3):
		var unit: Dictionary = sim.spawn_enemy("soldier", Vector2(850 + index * 40, 242))
		unit.target_id = sim.nathaniel.id
		unit.firing = true
		var actor := LaserActor.new()
		actor.visual = load("res://resources/actors/soldier.tres")
		views[int(unit.id)] = actor
	var effects := WorldEffects.new()
	effects.simulation = sim
	effects.sync_lasers(views)
	var before: Array[int] = []
	for actor: LaserActor in views.values():
		before.append(actor.aim_calls)
	var hit: Dictionary = {"type": "hit", "target_id": target.id, "attacker_id": sim.nathaniel.id,
		"target_kind": "soldier", "target_enemy": true, "position": target.position, "amount": 1}
	effects.add_events([hit, hit, hit], views)
	var index: int = 0
	for actor: LaserActor in views.values():
		expect(actor.aim_calls == before[index], "Projectile hit batches do not pose unrelated laser actors")
		index += 1
	expect(effects.impact_flashes.size() == 1, "Scoped hit checks preserve merged projectile contacts")
	expect(effects.laser_beams().size() == 3, "Scoped hit checks preserve unrelated active pulse beams")
	for actor: LaserActor in views.values():
		actor.free()
	effects.free()


func _check_laser_aim_lifecycle() -> void:
	var sim: GameSimulation = _game()
	var target: Dictionary = sim.spawn_enemy("grunt", Vector2(720, 242))
	var emitter := LaserActor.new()
	emitter.visual = load("res://resources/actors/hermes.tres")
	var effects := WorldEffects.new()
	effects.simulation = sim
	sim.hermes.target_id = target.id
	effects.sync_lasers({int(sim.hermes.id): emitter})
	expect(emitter.aim_calls == 1 and emitter.clear_calls == 0, "A deferred laser actor receives its live target pose outside a burst")
	sim.hermes.target_id = -1
	effects.sync_lasers({int(sim.hermes.id): emitter})
	expect(emitter.clear_calls == 1, "Target loss clears the deferred mounted pitch")
	sim.hermes.weapon = "pulse_laser"
	sim.hermes.target_id = target.id
	sim.hermes.firing = true
	effects.sync_lasers({int(sim.hermes.id): emitter})
	var contact_offset: Vector2 = emitter.target_offset
	sim.damage_entity(int(target.id), int(target.hp))
	sim.hermes.target_id = -1
	var beams: Array[Dictionary] = effects.laser_beams()
	expect(beams.size() == 1 and emitter.target_offset == contact_offset and emitter.clear_calls == 1, "A lethal pulse retains its contact and pitch after target removal")
	sim.hermes.firing = false
	effects.sync_lasers({int(sim.hermes.id): emitter})
	expect(emitter.clear_calls == 2 and effects.laser_beams().is_empty(), "Pulse completion clears the retained target pose")
	var removed: Dictionary = sim.spawn_enemy("soldier", Vector2(950, 242))
	sim.damage_entity(int(removed.id), int(removed.hp))
	var before: int = emitter.clear_calls
	effects.sync_lasers({int(removed.id): emitter})
	expect(emitter.clear_calls == before + 1, "Removed entities clear their registered laser actor pose")
	emitter.free()
	effects.free()


func _ground_redraw(effects: GroundEffects, expected: bool, message: String, delta: float = 0.0) -> void:
	var before: int = effects.ground_draws
	effects._process(delta)
	await process_frame
	await process_frame
	expect((effects.ground_draws > before) == expected, message)


func _check_physics_redraws() -> void:
	var effects := DrawEffects.new()
	root.add_child(effects)
	var driver := PhysicsEffectsDriver.new()
	driver.effects = effects
	root.add_child(driver)
	for tick: int in range(6):
		await physics_frame
	driver.set_physics_process(false)
	await process_frame
	await process_frame
	expect(driver.ticks >= 5, "Redraw regression fixture exercises real physics ticks")
	expect(effects.draws > 0 and effects.physics_draws == 0, "Processing effects draw on rendered frames without physics redraw flushes")
	effects.set_process(false)
	effects.physics_draws = 0
	driver.set_physics_process(true)
	for tick: int in range(3):
		await physics_frame
	driver.set_physics_process(false)
	await process_frame
	expect(effects.physics_draws > 0, "Effects with processing disabled keep immediate redraws from direct APIs")
	var before: int = effects.draws
	effects.add_events([])
	await process_frame
	await process_frame
	expect(effects.draws > before, "Direct nonphysics API calls still request a redraw")
	driver.free()
	effects.free()


func _check_retained_ground() -> void:
	var sim: GameSimulation = _game()
	sim.set_hermes_mode("building")
	var tower: Dictionary = sim.place_map_tower("gunTower", Vector2(780, 242))
	var enemy: Dictionary = sim.spawn_enemy("grunt", Vector2(950, 400))
	var effects := GroundEffects.new()
	effects.simulation = sim
	root.add_child(effects)
	effects.set_process(false)
	await _ground_redraw(effects, true, "Deployed conduits record their initial draw commands")
	await _ground_redraw(effects, false, "Stationary conduits reuse draw commands across frames", 0.1)
	effects.position += Vector2(80, 20)
	enemy.position += Vector2(10, 10)
	await _ground_redraw(effects, false, "Camera translation and unrelated actors do not rebuild ground geometry")
	tower.position += Vector2(10, 0)
	await _ground_redraw(effects, true, "Moving a tower updates its retained conduit")
	_visibility(sim, tower.position, 0)
	await _ground_redraw(effects, true, "Fog hides an existing retained conduit")
	effects.fog_enabled = false
	await _ground_redraw(effects, true, "Disabling fog restores the retained conduit")
	effects.fog_enabled = true
	await _ground_redraw(effects, true, "Enabling fog removes the hidden retained conduit")
	_visibility(sim, tower.position, 2)
	await _ground_redraw(effects, true, "Revealing a tower restores its conduit")
	sim.hermes.position += Vector2(3, 5)
	await _ground_redraw(effects, true, "Hermes movement updates every ground connection")
	effects.build_open = true
	await _ground_redraw(effects, true, "Opening Build updates range emphasis")
	effects.placement = true
	effects.cursor_world = Vector2(860, 300)
	await _ground_redraw(effects, true, "Placement creates a retained preview")
	effects.cursor_world += Vector2(8, 4)
	await _ground_redraw(effects, true, "Cursor movement updates the preview")
	effects.placement_valid = true
	await _ground_redraw(effects, true, "Placement validity updates the preview color")
	for property: String in ["hermes_range_color", "hermes_cable_color", "hermes_cable_band_color", "valid_placement_color", "invalid_placement_color"]:
		effects.set(property, (effects.get(property) as Color).lightened(0.1))
		await _ground_redraw(effects, true, "Runtime ground color edits invalidate retained commands")
	effects.hermes_cable_width += 1.0
	await _ground_redraw(effects, true, "Runtime cable width edits invalidate retained commands")
	effects.placement = false
	await _ground_redraw(effects, true, "Cancelling placement clears the preview")
	effects.build_open = false
	await _ground_redraw(effects, true, "Closing Build restores the persistent range treatment")
	sim.damage_entity(int(tower.id), int(tower.hp))
	await _ground_redraw(effects, true, "Tower death clears its retained conduit")
	effects.add_events([{"type": "build", "position": Vector2(780, 242)}])
	await _ground_redraw(effects, true, "Build transfer creates animated ground commands")
	await _ground_redraw(effects, true, "Transfer progress updates commands even when endpoints are fixed", 0.1)
	sim.set_paused(true)
	await _ground_redraw(effects, false, "Paused transfer geometry remains retained", 0.1)
	effects.hermes_transfer_lifetime += 0.1
	await _ground_redraw(effects, true, "Changing transfer lifetime updates its current phase")
	sim.set_paused(false)
	await _ground_redraw(effects, true, "Transfer expiry removes its retained pulse", 1.0)
	sim.set_hermes_mode("following")
	effects.add_events([{"type": "recycle", "position": Vector2(780, 242)}])
	await _ground_redraw(effects, true, "A returning transfer remains visible after deployment ends")
	await _ground_redraw(effects, true, "Returning transfer progress rebuilds its shortened cable", 0.1)
	sim.set_paused(true)
	sim.damage_entity(int(sim.hermes.id), int(sim.hermes.hp))
	await _ground_redraw(effects, true, "Hermes death clears a paused retained transfer")
	await _ground_redraw(effects, false, "Empty ground effects do not redraw")
	var replacement: GameSimulation = _game()
	replacement.set_hermes_mode("building")
	effects.simulation = replacement
	await _ground_redraw(effects, true, "Simulation replacement recreates visible ground effects")
	effects.simulation = null
	await _ground_redraw(effects, true, "Leaving the level clears retained ground commands")
	effects.free()


func _check_impacts() -> void:
	var sim: GameSimulation = _game()
	var target: Dictionary = sim.spawn_enemy("soldier", Vector2(720, 242))
	var effects := WorldEffects.new()
	effects.simulation = sim
	var event: Dictionary = {"type": "hit", "target_id": target.id, "attacker_id": sim.nathaniel.id,
		"target_kind": "soldier", "target_enemy": true, "position": target.position, "amount": 1}
	effects.add_events([event])
	expect(effects.impact_flashes.size() == 1 and effects.transients.is_empty(), "An enemy hit creates a compact impact without an expanding ground ring")
	var expected_height: float = (load("res://resources/actors/soldier.tres") as ActorVisual).contact_height
	expect(Vector2(effects.impact_flashes[0].position).is_equal_approx(IsoProjection.project(target.position) - Vector2(0, expected_height * WorldEffects.HEIGHT_PROJECTION)), "An impact uses the target's authored height without a live actor")
	effects.add_events([event])
	expect(effects.impact_flashes.size() == 1, "Repeated damage ticks do not stack impact bursts")
	sim.set_paused(true)
	effects._process(1.0)
	expect(effects.impact_flashes.size() == 1 and effects.impact_flashes[0].life == WorldEffects.IMPACT_LIFETIME, "Pause freezes the impact")
	sim.set_paused(false)
	effects._process(0.1)
	sim.damage_entity(int(target.id), int(target.hp))
	effects.add_events([event])
	expect(effects.impact_flashes.size() == 1 and effects.impact_flashes[0].life == WorldEffects.IMPACT_LIFETIME, "A lethal hit refreshes contact even after its actor is removed")
	effects._process(1.0)
	expect(effects.impact_flashes.is_empty(), "Compact impacts expire")
	effects.add_events([{"type": "hit", "position": Vector2.ZERO}])
	expect(effects.impact_flashes.is_empty() and effects.transients.is_empty(), "An incomplete hit cannot produce a misleading ground ring")
	var next_target: Dictionary = sim.spawn_enemy("soldier", Vector2(720, 242))
	sim.hermes.target_id = next_target.id
	sim.hermes.firing = true
	var emitter := LaserActor.new()
	emitter.visual = load("res://resources/actors/hermes.tres")
	var views: Dictionary = {int(sim.hermes.id): emitter}
	effects.sync_lasers(views)
	var contact: Dictionary = {"type": "hit", "target_id": next_target.id, "attacker_id": sim.hermes.id,
		"target_kind": "soldier", "target_enemy": true, "position": next_target.position, "amount": 1}
	effects.add_events([contact], views)
	expect(effects.impact_flashes.is_empty(), "A live styled beam supplies contact sparks without stacking damage-tick impacts")
	sim.hermes.burst = 0.7
	var restored := GameSimulation.new()
	expect(restored.restore(sim.snapshot()), "Active laser state restores through the existing save format")
	effects.simulation = restored
	effects.sync_lasers(views)
	expect(effects.laser_beams().size() == 1, "A loaded active beam reconstructs its muzzle and contact without replayed events")
	expect(is_equal_approx(effects.laser_beams()[0].age, 0.7), "A loaded burst resumes its phase without replaying the aperture flash")
	effects.simulation = sim
	effects.sync_lasers(views)
	sim.damage_entity(int(next_target.id), int(next_target.hp))
	effects.add_events([contact], views)
	expect(effects.laser_beams().is_empty() and effects.impact_flashes.size() == 1, "A lethal styled-laser hit retains a final contact after the beam stops")
	effects.add_events([event])
	effects.simulation = _game()
	expect(effects.impact_flashes.is_empty(), "Replacing a simulation clears old impacts")
	emitter.free()
	effects.free()


func _visibility(sim: GameSimulation, position: Vector2, value: int) -> void:
	var cell: Vector2i = sim.navigation.cell(position)
	sim.fog[cell.y * sim.navigation.width + cell.x] = value


func _check_fog() -> void:
	var sim: GameSimulation = _game()
	var target: Dictionary = sim.spawn_enemy("soldier", Vector2(720, 242))
	sim.hermes.target_id = target.id
	sim.hermes.firing = true
	var emitter := LaserActor.new()
	emitter.visual = (load("res://resources/actors/hermes.tres") as ActorVisual).duplicate() as ActorVisual
	var effects := WorldEffects.new()
	effects.simulation = sim
	effects.sync_lasers({int(sim.hermes.id): emitter})
	_visibility(sim, target.position, 1)
	expect(effects.laser_beams().is_empty(), "Explored fog hides a styled beam and its contact at the target")
	_visibility(sim, target.position, 0)
	expect(effects.laser_beams().is_empty(), "Unexplored fog hides a styled beam and its target contact")
	_visibility(sim, target.position, 2)
	_visibility(sim, sim.hermes.position, 1)
	expect(effects.laser_beams().is_empty(), "A hidden emitter cannot expose a styled beam or its contact")
	effects.fog_enabled = false
	expect(effects.laser_beams().size() == 1, "Disabling fog exposes the styled beam at its actual endpoints")
	effects.fog_enabled = true
	_visibility(sim, sim.hermes.position, 2)
	emitter.visual.laser = null
	_visibility(sim, target.position, 1)
	expect(effects.laser_beams().size() == 1, "An unstyled legacy laser retains its owner-only fog gate")
	_visibility(sim, sim.hermes.position, 1)
	effects.fog_enabled = false
	expect(effects.laser_beams().is_empty(), "An unstyled legacy laser retains its source visibility gate with fog disabled")
	effects.fog_enabled = true
	sim.hermes.firing = false
	sim.fog.fill(2)
	var hit: Dictionary = {"type": "hit", "target_id": target.id, "attacker_id": sim.hermes.id,
		"target_kind": "soldier", "target_enemy": true, "position": target.position, "amount": 1}
	effects.add_events([hit])
	expect(effects.impact_markers().size() == 1, "A visible hit exposes one compact impact")
	_visibility(sim, target.position, 1)
	expect(effects.impact_markers().is_empty(), "Fog hides a live target's impact")
	_visibility(sim, target.position, 2)
	_visibility(sim, sim.hermes.position, 0)
	expect(effects.impact_markers().size() == 1, "A visible target retains generic hit feedback when its attacker is hidden")
	effects.fog_enabled = false
	expect(effects.impact_markers().size() == 1, "Disabling fog exposes compact impacts")
	effects.fog_enabled = true
	sim.fog.fill(2)
	sim.damage_entity(int(target.id), int(target.hp))
	effects.add_events([hit])
	_visibility(sim, hit.position, 0)
	expect(effects.impact_markers().is_empty(), "Lethal contacts stay hidden after the target is removed in fog")
	effects.simulation = _game()
	expect(effects.impact_markers().is_empty() and effects.laser_beams().is_empty(), "Scene replacement clears all visible contacts and beams")
	emitter.free()
	effects.free()
