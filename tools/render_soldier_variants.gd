extends SceneTree
## Capture both soldier weapons and their death art in isolated Survival gameplay.


func _initialize() -> void:
	_run.call_deferred()


func capture(surface: SubViewport, path: String) -> void:
	for frame: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	surface.get_texture().get_image().save_png(path)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Soldier captures need a graphical display.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://test-artifacts")
	var surface := SubViewport.new()
	surface.size = Vector2i(2560, 1600)
	surface.size_2d_override = Vector2i(1280, 800)
	surface.size_2d_override_stretch = true
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	var app: GameApp = load("res://scenes/main.tscn").instantiate()
	app.storage_root = "/private/tmp/nathaniel-soldier-variants-%d/" % Time.get_ticks_usec()
	surface.add_child(app)
	app.set_physics_process(false)
	app.audio.music_enabled = false
	app.audio.sound_enabled = false
	app.audio.music.stop()
	app.load_level(0)
	app.sim.level.wave_based = false
	app.fog.enabled = false
	app.effects.fog_enabled = false
	for enemy: Dictionary in app.sim.opponents(false).duplicate():
		app.sim.damage_entity(enemy.id, enemy.hp)
	app.sim.take_events()
	app.sim.corpses.clear()
	app.sim.weapon_pickups.clear()
	app.sim.nathaniel.position = Vector2(700, 480)
	app.sim.nathaniel.delay = 10000.0
	app.sim.hermes.position = Vector2(2000, 2000)
	var gun: Dictionary = app.sim.spawn_enemy("gunSoldier", Vector2(510, 450))
	var laser: Dictionary = app.sim.spawn_enemy("soldier", Vector2(440, 620))
	for unit: Dictionary in [gun, laser]:
		unit.target_id = app.sim.nathaniel.id
		unit.cooldown = unit.delay
		CombatRules.update_unit(app.sim, unit, 0.0)
	CombatRules.update_unit(app.sim, gun, 0.16)
	app.sim.set_paused(true)
	app.sim.fog.fill(2)
	app._sync_views()
	app.effects.add_events(app.sim.take_events(), app.views)
	app._physics_process(0.0)
	app.ui.show_menu("")
	app.camera_zoom = 2.1
	app.camera.zoom = Vector2.ONE * app.camera_zoom
	app.camera.position = IsoProjection.project(Vector2(560, 520)) - Vector2(0, 30)
	await capture(surface, "res://test-artifacts/soldier-variants-gameplay.png")
	for unit: Dictionary in [gun, laser]:
		app.sim.damage_entity(unit.id, unit.hp)
	for shot: Dictionary in app.sim.projectiles.duplicate():
		app.sim.remove_projectile(shot)
	app.effects.muzzle_flashes.clear()
	app._sync_views()
	app.effects.add_events(app.sim.take_events(), app.views)
	app.ui.update_game(app.sim)
	app.effects.transients.clear()
	app.effects.impact_flashes.clear()
	await capture(surface, "res://test-artifacts/soldier-corpses-gameplay.png")
	surface.free()
	await process_frame
	print("Soldier captures: test-artifacts/soldier-{variants,corpses}-gameplay.png")
	quit()
