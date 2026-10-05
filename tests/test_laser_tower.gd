extends SceneTree
## Exercise the live turret, beam contact and existing tower combat lifecycle.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func game() -> GameSimulation:
	var sim := GameSimulation.new()
	sim.configure({"number": 0, "width": 64, "height": 64, "tile_size": 32,
		"blocked": [], "player_start": Vector2(1200, 1200), "hermes_start": Vector2(400, 500),
		"enemies": [], "wave_based": false})
	sim.fog.fill(2)
	return sim


func _run() -> void:
	_check_cycle()
	await _check_turret()
	print("Laser tower: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_cycle() -> void:
	var sim := game()
	sim.resources = 30
	expect(sim.place_tower("laserTower", Vector2(400, 400)), "Laser tower builds through the normal placement rules")
	var tower: Dictionary = sim.entities.back()
	expect(sim.resources == 20 and tower.range == 350.0 and tower.damage == 20 and tower.delay == 3.5, "Laser tower retains cost, range, damage and recovery")
	var target: Dictionary = sim.spawn_enemy("soldier", Vector2(600, 400))
	tower.cooldown = 0.0
	CombatRules.update_unit(sim, tower, 3.49)
	expect(not tower.firing and target.hp == 200, "Tower waits for its firing interval")
	CombatRules.update_unit(sim, tower, 0.01)
	expect(tower.firing and target.hp == 200 and sim.projectiles.is_empty(), "Beam starts and carries fractional damage without a projectile")
	CombatRules.update_unit(sim, tower, 0.49)
	expect(target.hp == 190, "Half a second of contact deals ten damage")
	var restored := GameSimulation.new()
	expect(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))), "Active tower survives a JSON save round trip")
	var copy: Dictionary = restored.entity(tower.id)
	var victim: Dictionary = restored.entity(target.id)
	expect(copy.firing and is_equal_approx(copy.burst, 0.5) and copy.facing.is_equal_approx(tower.facing), "Save retains beam phase and turret direction")
	restored.set_paused(true)
	restored.step(1.0)
	expect(victim.hp == 190 and is_equal_approx(copy.burst, 0.5), "Pause stops beam damage and duration")
	restored.set_paused(false)
	CombatRules.update_unit(restored, copy, 1.0)
	expect(not copy.firing and victim.hp == 170, "A full 1.5-second burst deals thirty damage and stops")
	CombatRules.update_unit(restored, copy, 3.49)
	expect(not copy.firing and victim.hp == 170, "Recovery follows the completed burst")
	CombatRules.update_unit(restored, copy, 0.01)
	expect(copy.firing, "The next beam starts after recovery")
	victim.position = Vector2(copy.position) + Vector2(351, 0)
	CombatRules.update_unit(restored, copy, 0.1)
	expect(not copy.firing and victim.hp == 170, "A target leaving range immediately loses beam contact")
	sim.set_hermes_mode("following")
	expect(sim.entity(tower.id).is_empty() and sim.resources == 22, "Packing Hermes removes the tower and returns its normal refund")


func _check_turret() -> void:
	var sim := game()
	var tower: Dictionary = sim.place_map_tower("laserTower", Vector2(400, 400))
	var target: Dictionary = sim.spawn_enemy("soldier", Vector2(600, 400))
	tower.target_id = target.id
	tower.firing = true
	var actor: ActorView = load("res://scenes/actors/laser_tower.tscn").instantiate()
	root.add_child(actor)
	var model: ActorModelView = actor.model_view
	expect(model != null and model.pitch_pivot != null and actor.laser_visual() != null, "Tower loads a live yaw/tilt rig and beam style")
	if model == null or model.pitch_pivot == null:
		actor.free()
		return
	model.set_process(false)
	var base: Node3D = model.model_root.find_child("Ground*plinth", true, false)
	expect(base != null, "Saved folding pedestal is present")
	var base_rest: Transform3D = base.global_transform
	var recoil_rest: Transform3D = model.recoil.transform
	var effects := WorldEffects.new()
	effects.simulation = sim
	var views: Dictionary = {int(tower.id): actor}
	for index: int in range(16):
		var heading := Vector2.RIGHT.rotated(index * TAU / 16.0)
		tower.facing = heading
		actor.apply_state(tower)
		for distance: float in [64.0, 350.0]:
			target.position = Vector2(tower.position) + heading * distance
			effects.sync_lasers(views)
			var beams := effects.laser_beams()
			expect(beams.size() == 1, "Active tower draws one beam")
			var contact := Vector3(heading.y * distance, 40.0, -heading.x * distance) / 32.0
			var ray: Vector3 = model.muzzle.global_basis.x.normalized()
			expect(ray.dot((contact - model.muzzle.global_position).normalized()) > 0.9999, "Tilted barrel points at target contact for heading %d" % index)
			expect(Vector2(beams[0].start).is_equal_approx(actor.position + actor.laser_muzzle()), "Beam starts at the current lens")
			expect(Vector2(beams[0].finish).is_equal_approx(IsoProjection.project(target.position) - Vector2(0, 40.0 * WorldEffects.HEIGHT_PROJECTION)), "Beam ends on the enemy body")
			expect(base.global_transform.is_equal_approx(base_rest), "Turret rotation leaves the pedestal fixed")
		actor.notify_attack(heading)
		model._process(0.025)
		expect(model.recoil.transform.is_equal_approx(recoil_rest), "Laser firing does not add ballistic recoil")
		actor.aim_laser(heading * 64.0, 12.0)
		var low_contact := Vector3(heading.y * 64.0, 12.0, -heading.x * 64.0) / 32.0
		expect(model.muzzle.global_basis.x.normalized().dot((low_contact - model.muzzle.global_position).normalized()) > 0.9999, "Turret tilts down to low targets")
		if "--render" in OS.get_cmdline_user_args():
			model.refresh_pose()
			model._process(0.0)
			await process_frame
			await RenderingServer.frame_post_draw
			var image: Image = model.viewport.get_texture().get_image()
			var rect: Rect2i = image.get_used_rect()
			expect(rect.has_area() and rect.position.x > 0 and rect.position.y > 0 and rect.end.x < image.get_width() and rect.end.y < image.get_height(), "Turret renders without clipping at heading %d" % index)
	effects.sync_lasers(views)
	effects.add_events([{"type": "laser", "owner_id": tower.id, "position": tower.position}], views)
	expect(effects.transients.is_empty() and effects.muzzle_flashes.is_empty(), "Styled laser uses its aperture flash instead of a ground ring or gun flash")
	effects._process(0.05)
	var age: float = effects.laser_beams()[0].age
	var muzzle: Vector2 = actor.laser_muzzle()
	sim.set_paused(true)
	model.playback_enabled = false
	model._process(0.4)
	effects._process(0.4)
	expect(actor.laser_muzzle().is_equal_approx(muzzle) and effects.laser_beams()[0].age == age, "Pause freezes turret and beam effects")
	sim.fog.fill(0)
	expect(effects.laser_beams().is_empty(), "Fog hides tower fire")
	sim.fog.fill(2)
	sim.set_paused(false)
	sim.damage_entity(target.id, target.hp, tower.id)
	effects.add_events(sim.take_events(), views)
	expect(effects.laser_beams().is_empty() and not effects.impact_markers().is_empty(), "Lethal contact ends the beam and leaves hit feedback")
	var next: Dictionary = sim.spawn_enemy("grunt", Vector2(400, 600))
	tower.target_id = next.id
	tower.firing = true
	effects.sync_lasers(views)
	expect(effects.laser_beams().size() == 1 and effects.laser_beams()[0].target_id == next.id, "Tower can track a new enemy")
	sim.damage_entity(tower.id, tower.hp)
	expect(effects.laser_beams().is_empty(), "Destroyed tower leaves no beam")
	effects.free()
	actor.free()
	await process_frame
