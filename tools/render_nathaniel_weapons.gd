extends SceneTree
## Capture the normal game's weapon view at exact 4K, using isolated storage.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Nathaniel capture needs a graphical display.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://test-artifacts")
	var surface := SubViewport.new()
	surface.size = Vector2i(3840, 2160)
	surface.size_2d_override = Vector2i(1280, 720)
	surface.size_2d_override_stretch = true
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	var app: GameApp = load("res://scenes/main.tscn").instantiate()
	app.storage_root = "/private/tmp/nathaniel-weapons-capture-%d/" % Time.get_ticks_usec()
	surface.add_child(app)
	app.set_physics_process(false)
	app.audio.music_enabled = false
	app.audio.sound_enabled = false
	app.audio.music.stop()
	app.load_level(2)
	app.fog.enabled = false
	app.effects.fog_enabled = false
	app.sim.nathaniel.position = Vector2(2016, 720)
	app.sim.hermes.position = Vector2(2110, 770)
	app.sim.hermes.delay = 100000.0
	var target: Dictionary = app.sim.spawn_enemy("grunt", Vector2(2145, 635))
	app.sim.place_map_tower("gunTower", Vector2(2095, 850))
	app.sim.spawn_weapon_pickup("heavy_rifle", app.sim.nathaniel.position)
	app._physics_process(0.0)
	app.ui.show_notice("")
	var direction: Vector2 = (Vector2(target.position) - Vector2(app.sim.nathaniel.position)).normalized()
	for weapon_id: String in ["rifle", "heavy_rifle"]:
		app.sim.equip_weapon(weapon_id)
		app.sim.nathaniel.equip_ready_remaining = 0.0
		app.sim.nathaniel.cooldown = 100.0
		app.sim.nathaniel.aim_direction = direction
		app.sim.take_events()
		for shot: Dictionary in app.sim.projectiles.duplicate():
			app.sim.remove_projectile(shot)
		app.effects.muzzle_flashes.clear()
		CombatRules.shoot(app.sim, app.sim.nathaniel, target.position)
		app._physics_process(0.0)
		app.camera_zoom = 2.0
		app.camera.zoom = Vector2.ONE * 2.0
		app.camera.position = IsoProjection.project(app.sim.nathaniel.position) + Vector2(40, -70)
		app.sim.set_paused(true)
		for actor: ActorView in app.views.values():
			if actor.model_view != null:
				actor.model_view.playback_enabled = false
		await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		var image := surface.get_texture().get_image()
		image.save_png("res://test-artifacts/nathaniel-%s-gameplay-4k.png" % weapon_id)
		app.sim.set_paused(false)
	surface.free()
	await process_frame
	print("Nathaniel captures: test-artifacts/nathaniel-{rifle,heavy_rifle}-gameplay-4k.png")
	quit()
