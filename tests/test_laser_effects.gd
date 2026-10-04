extends SceneTree
## Exercise live beam attachment, resource variation, pause, removal and impacts.

class LaserActor extends ActorView:
	var muzzle: Vector2 = Vector2(11, -38)
	var target_offset := Vector2.ZERO
	var target_height: float = 0.0

	func aim_laser(offset: Vector2, height: float) -> void:
		target_offset = offset
		target_height = height

	func laser_muzzle() -> Vector2:
		return muzzle


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
