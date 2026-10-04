extends SceneTree
## Capture Hermes's mobile, deployed and reclaimed states in the actual level.


func _initialize() -> void:
	_run.call_deferred()


func _capture(surface: SubViewport, path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	surface.get_texture().get_image().save_png(path)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Hermes capture needs a graphical display.")
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
	app.storage_root = "/private/tmp/nathaniel-hermes-capture-%d/" % Time.get_ticks_usec()
	surface.add_child(app)
	app.set_physics_process(false)
	app.audio.music_enabled = false
	app.audio.sound_enabled = false
	app.audio.music.stop()
	app.load_level(0)
	app.fog.enabled = false
	app.effects.fog_enabled = false
	app.sim.nathaniel.position = Vector2(420, 420)
	app.sim.hermes.position = Vector2(480, 480)
	app.sim.fog.fill(2)
	app.command("build")
	app._physics_process(0.0)
	app.camera_zoom = 0.85
	app.camera.zoom = Vector2.ONE * app.camera_zoom
	app.camera.position = IsoProjection.project(app.sim.hermes.position) + Vector2(0, 55)
	await _capture(surface, "res://test-artifacts/hermes-mobile-gameplay.png")
	for kind: String in ["gunTower", "laserTower", "healTower"]:
		var built := false
		var angle_offset: int = {"gunTower": 3, "laserTower": 11, "healTower": 19}[kind]
		for step: int in range(24):
			var point: Vector2 = app.sim.hermes.position + Vector2.from_angle((step + angle_offset) * TAU / 24.0) * 155.0
			if app.sim.place_tower(kind, point):
				built = true
				break
		if not built:
			push_error("Cannot place %s in Hermes capture." % kind)
			quit(1)
			return
	app._physics_process(0.0)
	app.ui.show_notice("")
	app.effects.placement = false
	await create_timer(0.65).timeout
	var target: Dictionary = app.sim.spawn_enemy("grunt", app.sim.hermes.position + Vector2(190, -125))
	app.sim.hermes.cooldown = app.sim.hermes.delay
	CombatRules.shoot(app.sim, app.sim.hermes, target.position)
	app._physics_process(0.0)
	app.sim.set_paused(true)
	app._sync_views()
	await _capture(surface, "res://test-artifacts/hermes-base-gameplay.png")
	app.sim.set_paused(false)
	app.command("follow")
	app._physics_process(0.0)
	await create_timer(0.65).timeout
	app.camera.position = IsoProjection.project(app.sim.hermes.position) + Vector2(0, 55)
	await _capture(surface, "res://test-artifacts/hermes-reclaimed-gameplay.png")
	surface.free()
	await process_frame
	print("Hermes captures: test-artifacts/hermes-{mobile,base,reclaimed}-gameplay.png")
	quit()
