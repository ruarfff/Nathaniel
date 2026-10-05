extends SceneTree
## Verify enemy pulse rules, saved combat phase and the three authored emitters.

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
		"blocked": [], "player_start": Vector2(400, 400), "hermes_start": Vector2(1800, 1800),
		"enemies": [], "wave_based": false})
	sim.fog.fill(2)
	return sim


func _run() -> void:
	for kind: String in ["soldier", "boss"]:
		_check_pulse(kind)
	for kind: String in ["soldier", "boss", "spawner"]:
		await _check_model(kind)
	print("Enemy lasers: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_pulse(kind: String) -> void:
	var sim := game()
	var unit: Dictionary = sim.spawn_enemy(kind, Vector2(500, 400))
	unit.target_id = sim.nathaniel.id
	unit.cooldown = float(unit.delay) - 0.05
	var health: int = sim.nathaniel.hp
	CombatRules.update_unit(sim, unit, 0.04)
	expect(sim.nathaniel.hp == health, kind + " waits for its original shot interval")
	CombatRules.update_unit(sim, unit, 0.01)
	expect(sim.nathaniel.hp == health - 25 and sim.projectiles.is_empty(), kind + " deals one instant 25-point hit without a projectile")
	expect(unit.firing and unit.burst == 0.0, kind + " exposes its brief pulse phase")
	var events: Array = sim.take_events()
	var pulse: Dictionary = {}
	for event: Dictionary in events:
		if event.type == "laser":
			pulse = event
	expect(pulse.get("pulse", false) and pulse.target_id == sim.nathaniel.id, kind + " records its contact before damage")
	var restored := GameSimulation.new()
	expect(restored.restore(sim.snapshot()), kind + " pulse saves restore")
	var copy: Dictionary = restored.entity(int(unit.id))
	expect(copy.weapon == "pulse_laser" and copy.firing and copy.cooldown == unit.cooldown, kind + " restores its firing and recovery phase")
	restored.set_paused(true)
	restored.step(1.0)
	expect(copy.burst == 0.0 and restored.nathaniel.hp == health - 25, kind + " pause freezes pulse phase and damage")
	restored.set_paused(false)
	CombatRules.update_unit(restored, copy, GameBalance.LASER_PULSE_SECONDS)
	expect(not copy.firing and restored.nathaniel.hp == health - 25, kind + " pulse expires without more damage")
	CombatRules.update_unit(restored, copy, float(copy.delay) - GameBalance.LASER_PULSE_SECONDS)
	expect(restored.nathaniel.hp == health - 50, kind + " retains its repeat interval")
	copy.position = Vector2(1500, 1500)
	CombatRules.update_unit(restored, copy, 10.0)
	expect(restored.nathaniel.hp == health - 50, kind + " cannot hit outside range")
	unit.weapon = "gun" if kind == "soldier" else "bow"
	unit.cooldown = unit.delay
	CombatRules.shoot(sim, unit, sim.nathaniel.position)
	unit.cooldown = 0.31
	expect(restored.restore(sim.snapshot()), kind + " legacy projectile state restores")
	copy = restored.entity(int(unit.id))
	expect(copy.weapon == "pulse_laser" and copy.cooldown == 0.31 and not copy.firing, kind + " old weapon upgrades without replaying a shot")
	expect(restored.projectiles.size() == 1, kind + " keeps its already travelling legacy shot")


func _check_model(kind: String) -> void:
	var actor: ActorView = load("res://scenes/actors/%s.tscn" % kind).instantiate()
	root.add_child(actor)
	actor.set_process(false)
	var model: ActorModelView = actor.model_view
	model.set_process(false)
	var sim := game()
	var unit: Dictionary = sim.spawn_enemy(kind, Vector2(500, 400))
	unit.target_id = sim.nathaniel.id
	var recipient: ActorView = load("res://scenes/actors/nathaniel.tscn").instantiate()
	root.add_child(recipient)
	expect(recipient.laser_contact_height() == 40.0, "Nathaniel contact is on the upper body")
	var effects := WorldEffects.new()
	effects.simulation = sim
	var views: Dictionary = {int(unit.id): actor, int(sim.nathaniel.id): recipient}
	expect(model != null and model.muzzle != null and actor.visual.laser != null, kind + " loads its authored live emitter and style")
	var body_rest: Transform3D = model.locomotion_pivot.transform
	for direction: int in range(8):
		var heading := Vector2.RIGHT.rotated(direction * PI / 4.0)
		unit.facing = heading
		unit.moving = kind != "spawner"
		unit.firing = true
		actor.apply_state(unit, false, true)
		for distance: float in [120.0, 300.0]:
			sim.nathaniel.position = Vector2(unit.position) + heading * distance
			model.aim_laser(heading * distance, recipient.laser_contact_height())
			model._process(0.07)
			var target := Vector3(heading.y * distance, recipient.laser_contact_height(), -heading.x * distance) / 32.0
			var ray: Vector3 = model.muzzle.global_basis.x.normalized()
			var expected: Vector3 = (target - model.muzzle.global_position).normalized()
			expect(ray.dot(expected) > 0.9999, "%s barrel meets target at heading %d distance %.0f" % [kind, direction, distance])
			effects.sync_lasers(views)
			var beams := effects.laser_beams()
			expect(beams.size() == 1 and Vector2(beams[0].start).is_equal_approx(actor.position + actor.laser_muzzle()), kind + " beam follows its live muzzle")
		if kind == "spawner":
			expect(model.locomotion_pivot.transform.is_equal_approx(body_rest), "Spawner body stays rooted while crown aims")
		if "--render" in OS.get_cmdline_user_args():
			model.refresh_pose()
			model._process(0.0)
			await process_frame
			await RenderingServer.frame_post_draw
			var image: Image = model.viewport.get_texture().get_image()
			var opaque: int = 0
			var border: int = 0
			for y: int in image.get_height():
				for x: int in image.get_width():
					if image.get_pixel(x, y).a > 0.02:
						opaque += 1
						if x == 0 or y == 0 or x == image.get_width() - 1 or y == image.get_height() - 1:
							border += 1
			expect(opaque > 100 and border == 0, "%s heading %d renders within its fixed canvas" % [kind, direction])
	model.playback_enabled = false
	var muzzle: Vector2 = model.live_weapon_muzzle()
	model._process(0.4)
	expect(model.live_weapon_muzzle().is_equal_approx(muzzle), kind + " pause freezes walk and emitter")
	if kind == "boss":
		var shutter: Node3D = model.model_root.find_child("ApertureLeft", true, false)
		model.set_firing(true)
		var opened: Basis = shutter.basis
		model.set_firing(false)
		expect(not shutter.basis.is_equal_approx(opened), "Boss crest opens for firing and closes afterward")
	if kind != "spawner":
		unit.cooldown = unit.delay
		sim.nathaniel.hp = 1
		CombatRules.update_unit(sim, unit, 0.01)
		effects.add_events(sim.take_events(), views)
		effects.sync_lasers(views)
		expect(effects.laser_beams().size() == 1, kind + " lethal hit retains a brief beam at the last contact")
		unit.firing = false
		expect(effects.laser_beams().is_empty(), kind + " ended pulse leaves no beam")
	unit.hp = 0
	expect(effects.laser_beams().is_empty(), kind + " dead owner leaves no beam")
	effects.free()
	actor.free()
	recipient.free()
	await process_frame
