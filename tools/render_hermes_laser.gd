extends SceneTree
## Capture the mounted laser and its contact effect in the actual Survival level.


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
		push_error("Hermes laser capture needs a graphical display.")
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
	app.storage_root = "/private/tmp/nathaniel-laser-capture-%d/" % Time.get_ticks_usec()
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
		app.sim.damage_entity(int(enemy.id), int(enemy.hp))
	app.sim.take_events()
	app.sim.nathaniel.position = Vector2(390, 470)
	app.sim.nathaniel.delay = 10000.0
	app.sim.hermes.position = Vector2(480, 480)
	app.sim.hermes.facing = Vector2(0, 1)
	(app.views[int(app.sim.hermes.id)] as HermesView).notify_respawn()
	app._sync_views()
	var target: Dictionary = app.sim.spawn_enemy("grunt", Vector2(625, 430))
	target.hp = 10000
	target.max_hp = 10000
	target.speed = 0.0
	target.delay = 10000.0
	app.sim.hermes.manual_target_id = target.id
	app.sim.hermes.target_id = target.id
	app.sim.hermes.cooldown = app.sim.hermes.delay
	app.sim.fog.fill(2)
	app._physics_process(0.05)
	app.sim.set_paused(true)
	app._sync_views()
	app.ui.show_menu("")
	app.camera_zoom = 1.0
	app.camera.zoom = Vector2.ONE
	app.camera.position = IsoProjection.project(Vector2(520, 460)) + Vector2(0, 60)
	await _capture(surface, "res://test-artifacts/hermes-laser-gameplay.png")
	app.camera_zoom = 2.0
	app.camera.zoom = Vector2.ONE * 2.0
	app.camera.position = IsoProjection.project(Vector2(530, 460)) - Vector2(0, 30)
	await _capture(surface, "res://test-artifacts/hermes-laser-detail.png")
	var hermes: HermesView = app.views[int(app.sim.hermes.id)] as HermesView
	var mount: Vector3 = hermes.mobile_model_view.aim_pivot.global_position
	var across_body := -Vector2(-mount.z, mount.x).normalized()
	target.position = Vector2(app.sim.hermes.position) + across_body * 60.0
	app._sync_views()
	app.camera.position = IsoProjection.project(app.sim.hermes.position) - Vector2(0, 70)
	await _capture(surface, "res://test-artifacts/hermes-laser-close.png")
	target.position = Vector2(625, 430)
	app.sim.set_paused(false)
	app.sim.nathaniel.position = Vector2(480, 740)
	for frame: int in range(12):
		app._physics_process(1.0 / 60.0)
		await process_frame
	app.sim.set_paused(true)
	app._sync_views()
	app.camera_zoom = 1.0
	app.camera.zoom = Vector2.ONE
	app.camera.position = IsoProjection.project(Vector2(520, 480)) + Vector2(0, 60)
	await _capture(surface, "res://test-artifacts/hermes-laser-walking.png")
	surface.free()
	await process_frame
	print("Hermes laser captures: test-artifacts/hermes-laser-{gameplay,detail,close,walking}.png")
	quit()
