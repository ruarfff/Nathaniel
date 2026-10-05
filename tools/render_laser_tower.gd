extends SceneTree
## Capture the laser tower in the running game with isolated storage.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Laser tower captures need a graphical display.")
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
	app.storage_root = "/private/tmp/nathaniel-laser-tower-%d/" % Time.get_ticks_usec()
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
	app.sim.nathaniel.position = Vector2(600, 400)
	app.sim.hermes.position = Vector2(470, 590)
	var tower: Dictionary = app.sim.place_map_tower("laserTower", Vector2(570, 520))
	var target: Dictionary = app.sim.spawn_enemy("soldier", Vector2(750, 435))
	tower.target_id = target.id
	tower.cooldown = tower.delay
	CombatRules.update_unit(app.sim, tower, 0.03)
	app._sync_views()
	var hermes: HermesView = app.views[int(app.sim.hermes.id)]
	hermes._process(1.0)
	app.sim.set_paused(true)
	app.sim.fog.fill(2)
	app._sync_views()
	app.effects.add_events(app.sim.take_events(), app.views)
	app._physics_process(0.0)
	app.ui.show_menu("")
	app.camera_zoom = 1.8
	app.camera.zoom = Vector2.ONE * app.camera_zoom
	app.camera.position = IsoProjection.project(Vector2(600, 485)) - Vector2(0, 50)
	for frame: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	surface.get_texture().get_image().save_png("res://test-artifacts/laser-tower-gameplay.png")
	target.position = Vector2(530, 660)
	tower.facing = Vector2(tower.position).direction_to(target.position)
	app._sync_views()
	app.effects.sync_lasers(app.views)
	for frame: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	surface.get_texture().get_image().save_png("res://test-artifacts/laser-tower-turned.png")
	surface.free()
	await process_frame
	print("Laser tower captures: test-artifacts/laser-tower-{gameplay,turned}.png")
	quit()
