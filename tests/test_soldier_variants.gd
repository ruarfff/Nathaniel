extends SceneTree
## Soldier weapons, corpse identity, authored encounters and live gun attachment.

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
		"blocked": [], "player_start": Vector2(600, 400), "hermes_start": Vector2(1800, 1800),
		"enemies": [], "wave_based": false})
	sim.fog.fill(2)
	return sim


func _run() -> void:
	_check_weapons()
	_check_corpses()
	_check_encounters()
	await _check_model()
	print("Soldier variants: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_weapons() -> void:
	var sim := game()
	var gun: Dictionary = sim.spawn_enemy("gunSoldier", Vector2(400, 400))
	var laser: Dictionary = sim.spawn_enemy("soldier", Vector2(400, 500))
	expect(gun.weapon == "gun" and laser.weapon == "pulse_laser", "Both soldier mechanisms coexist")
	for key: String in ["hp", "speed", "range", "delay", "damage", "score"]:
		expect(gun[key] == laser[key], "Soldier variants share " + key)
	gun.target_id = sim.nathaniel.id
	gun.cooldown = 0.0
	CombatRules.update_unit(sim, gun, 0.79)
	expect(sim.projectiles.is_empty(), "Gun soldier waits for its shot interval")
	CombatRules.update_unit(sim, gun, 0.01)
	expect(sim.projectiles.size() == 1 and sim.nathaniel.hp == 8000, "Gun soldier launches a travelling shot without instant damage")
	var shot: Dictionary = sim.projectiles[0]
	expect(shot.enemy and shot.speed == 450.0 and shot.damage == 25, "Enemy bullet uses the soldier projectile profile")
	CombatRules.update_unit(sim, gun, 0.10)
	expect(shot.position == Vector2(445, 400) and sim.nathaniel.hp == 8000, "Bullet travels before contact")
	var snapshot: Dictionary = sim.snapshot()
	expect(GameSaveStore.validate_state(snapshot).is_empty(), "Gun soldiers and active bullets pass save validation")
	var restored := GameSimulation.new()
	expect(restored.restore(JSON.parse_string(JSON.stringify(snapshot))), "Gun soldier snapshot restores")
	var copy: Dictionary = restored.entity(gun.id)
	expect(copy.kind == "gunSoldier" and copy.weapon == "gun" and is_equal_approx(copy.cooldown, gun.cooldown), "Save keeps gun identity and cooldown")
	for step: int in range(6):
		CombatRules.update_unit(restored, copy, 0.05)
	expect(restored.nathaniel.hp == 7975 and restored.projectiles.is_empty(), "Restored bullet hits once after travelling")
	gun.position = Vector2(100, 100)
	gun.cooldown = gun.delay
	expect(not CombatRules.shoot(sim, gun, sim.nathaniel.position), "Gun soldier obeys its range")
	laser.target_id = sim.nathaniel.id
	laser.cooldown = laser.delay
	CombatRules.update_unit(sim, laser, 0.0)
	expect(sim.nathaniel.hp == 7975, "Laser soldier still applies instant damage")


func _check_corpses() -> void:
	var sim := game()
	for index: int in range(2):
		var kind: String = "soldier" if index == 0 else "gunSoldier"
		var unit: Dictionary = sim.spawn_enemy(kind, Vector2(300, 500 + index * 200))
		sim.damage_entity(unit.id, 1000)
		expect(sim.corpses.back().source_kind == kind and sim.corpses.back().amount == 10, kind + " leaves its own ten-resource corpse")
	expect(sim.score == 60, "Both soldier types give the same score")
	sim.nathaniel.position = sim.corpses[1].position
	BattlefieldRules.update_corpses(sim, 0.7)
	expect(sim.corpses[1].carried and sim.corpses[1].source_kind == "gunSoldier", "Carrying retains corpse identity")
	var saved: Dictionary = sim.snapshot()
	expect(GameSaveStore.validate_state(saved).is_empty(), "Both corpse types pass save validation")
	var restored := GameSimulation.new()
	expect(restored.restore(JSON.parse_string(JSON.stringify(saved))), "Mixed corpses restore")
	expect(restored.corpses[0].source_kind == "soldier" and restored.corpses[1].source_kind == "gunSoldier" and restored.corpses[1].carried, "Save preserves loose and carried corpse types")
	restored.hermes.position = restored.nathaniel.position
	BattlefieldRules.update_corpses(restored, 0.7)
	expect(restored.resources == 40 and restored.corpses.size() == 1, "Gun corpse delivery pays ten resources once")
	BattlefieldRules.update_corpses(restored, 0.0)
	expect(restored.resources == 40, "Delivered corpse cannot pay twice")
	saved.corpses[0].erase("source_kind")
	expect(GameSaveStore.validate_state(saved).is_empty() and restored.restore(saved), "Old corpses without identity still load")
	expect(restored.corpses[0].source_kind == "soldier", "Old corpse uses the default soldier image")
	saved.corpses[0].source_kind = "unknown"
	expect(not GameSaveStore.validate_state(saved).is_empty(), "Save rejects unknown corpse types")
	var effects: WorldEffects = load("res://scenes/effects/world_effects.tscn").instantiate()
	var laser_art: ActorVisual = effects.corpse_art("soldier")
	var gun_art: ActorVisual = effects.corpse_art("gunSoldier")
	expect(laser_art != gun_art and laser_art.texture != gun_art.texture, "Death types select different authored images")
	expect(effects.corpse_rect(Vector2.ZERO, "gunSoldier") == effects.corpse_rect(Vector2.ZERO, "soldier"), "Death images keep the same world scale and ground anchor")
	expect(is_equal_approx(effects.corpse_color(true, "gunSoldier").a, 0.65), "Gun corpse retains the carrying opacity")
	effects.free()


func _check_encounters() -> void:
	for number: int in range(1, 4):
		var level: GameLevel = load("res://levels/level_%d.tscn" % number).instantiate()
		var counts: Dictionary = {"soldier": 0, "gunSoldier": 0}
		for spawn: Dictionary in level.data().enemies:
			if counts.has(spawn.kind):
				counts[spawn.kind] += 1
		expect(counts.soldier > 0 and counts.gunSoldier > 0, "Campaign %d contains both soldier types" % number)
		level.free()
	var sim := game()
	sim.level.wave_based = true
	sim.random.seed = 12345
	var seen: Dictionary = {}
	for index: int in range(40):
		BattlefieldRules.update_waves(sim, 5.0)
		seen[sim.entities.back().kind] = true
	expect(seen.has("soldier") and seen.has("gunSoldier"), "Wave encounters spawn both types")
	var restored := GameSimulation.new()
	expect(restored.restore(sim.snapshot()), "Mixed wave saves restore")
	BattlefieldRules.update_waves(sim, 5.0)
	BattlefieldRules.update_waves(restored, 5.0)
	expect(sim.entities.back().kind == restored.entities.back().kind and sim.entities.back().position == restored.entities.back().position, "Loaded waves retain deterministic type and position")


func _check_model() -> void:
	var actor: ActorView = load("res://scenes/actors/gun_soldier.tscn").instantiate()
	root.add_child(actor)
	actor.set_process(false)
	var model: ActorModelView = actor.model_view
	model.set_process(false)
	expect(actor.laser_visual() == null and model.muzzle != null, "Gun soldier uses its live barrel without a laser style")
	var sim := game()
	var unit: Dictionary = sim.spawn_enemy("gunSoldier", Vector2(400, 400))
	var effects := WorldEffects.new()
	effects.simulation = sim
	for index: int in range(8):
		var direction := Vector2.RIGHT.rotated(index * PI / 4.0)
		unit.facing = direction
		unit.moving = true
		actor.apply_state(unit, false, true)
		model._process(0.07)
		var launch: Vector2 = actor.weapon_muzzle(direction, "gun")
		expect(launch.distance_to(model.live_weapon_muzzle()) < 0.01, "Gun bullet starts at its visible muzzle in heading %d" % index)
		var recoil_rest: Transform3D = model.recoil.transform
		actor.notify_attack(direction, "gun")
		model._process(0.025)
		expect(not model.recoil.transform.is_equal_approx(recoil_rest), "Gun soldier recoils when firing")
		model.reset_pose()
		unit.cooldown = unit.delay
		CombatRules.shoot(sim, unit, Vector2(unit.position) + direction * 200)
		effects.add_events(sim.take_events(), {unit.id: actor})
		var shot: Dictionary = sim.projectiles.back()
		var point: Vector2 = effects.projectile_position(shot)
		model.set_aim(-direction)
		effects.sync_projectiles({unit.id: actor})
		expect(effects.projectile_position(shot) == point, "Later turns do not move an emitted bullet")
		model.set_aim(direction)
		if "--render" in OS.get_cmdline_user_args():
			model.refresh_pose()
			model._process(0.0)
			await process_frame
			await RenderingServer.frame_post_draw
			var image: Image = model.viewport.get_texture().get_image()
			var used: Rect2i = image.get_used_rect()
			expect(used.has_area() and used.position.x > 0 and used.position.y > 0 and used.end.x < image.get_width() and used.end.y < image.get_height(), "Gun soldier renders without clipping in heading %d" % index)
	model.playback_enabled = false
	var point: Vector2 = model.live_weapon_muzzle()
	model._process(0.5)
	expect(model.live_weapon_muzzle().is_equal_approx(point), "Pause freezes the gun pose")
	actor.free()
	effects.free()
	await process_frame
