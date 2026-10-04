extends SceneTree
## Capture the actual turret fixture and measure a fixed graphical workload.


func _initialize() -> void:
	_run.call_deferred()


func _capture(viewport: Viewport = null) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return (root if viewport == null else viewport).get_texture().get_image()


func _surface(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.size_2d_override = Vector2i(ceili(800.0 * size.x / size.y), 800)
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Turret capture requires a graphical display.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://test-artifacts")
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1280, 800)
	var surface: SubViewport = _surface(Vector2i(1280, 800))
	var fixture = load("res://scenes/tests/gun_turret_preview.tscn").instantiate()
	fixture.mouse_aim = false
	surface.add_child(fixture)
	fixture.set_physics_process(false)
	fixture.effects.set_process(false)
	for facing: String in ["front", "rear"]:
		fixture.target_direction = Vector2(0.83, 0.37).normalized() * (1.0 if facing == "front" else -1.0)
		fixture.target.position = fixture.ORIGIN + fixture.target_direction * fixture.TARGET_DISTANCE
		fixture.tower.facing = fixture.target_direction
		for shot: Dictionary in fixture.sim.projectiles.duplicate():
			fixture.sim.remove_projectile(shot)
		fixture.effects.muzzle_flashes.clear()
		fixture.fire()
		fixture.sim.set_paused(true)
		fixture.update_views()
		await _capture(surface)
		(await _capture(surface)).save_png("res://test-artifacts/gun-turret-%s.png" % facing)
		fixture.sim.set_paused(false)
	surface.size_2d_override = Vector2i(1423, 800)
	surface.size = Vector2i(3840, 2160)
	fixture._resize()
	await _capture(surface)
	(await _capture(surface)).save_png("res://test-artifacts/gun-turret-4k.png")
	surface.free()
	await _gameplay_capture()
	await _profile(Vector2i(1280, 800), "")
	await _profile(Vector2i(3840, 2160), "-4k")
	print("Turret captures: test-artifacts/gun-turret-{front,rear,4k}.png")
	quit(0)


func _gameplay_capture() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1280, 800)
	var app: GameApp = load("res://scenes/main.tscn").instantiate()
	app.storage_root = "/private/tmp/nathaniel-turret-capture-%d/" % Time.get_ticks_usec()
	root.add_child(app)
	app.set_physics_process(false)
	app.audio.music_enabled = false
	app.audio.sound_enabled = false
	app.audio.music.stop()
	if not app.load_level(2):
		push_error("Cannot load the turret gameplay capture level.")
		quit(1)
		return
	app.fog.enabled = false
	app.effects.fog_enabled = false
	app.sim.nathaniel.position = Vector2(2016, 720)
	app.sim.hermes.position = Vector2(2080, 720)
	app.sim.nathaniel.delay = 100000.0
	app.sim.hermes.delay = 100000.0
	var tower: Dictionary = app.sim.place_map_tower("gunTower", Vector2(2250, 610))
	var target: Dictionary = app.sim.spawn_enemy("grunt", Vector2(2340, 590))
	tower.cooldown = tower.delay
	app.sim.fog.fill(2)
	app.camera_zoom = 2.0
	app.camera.zoom = Vector2.ONE * app.camera_zoom
	app.camera.position = IsoProjection.project(tower.position) + Vector2(30, -30)
	app.sim.take_events()
	CombatRules.shoot(app.sim, tower, target.position)
	app._physics_process(0.0)
	app.sim.set_paused(true)
	for actor: ActorView in app.views.values():
		if actor.model_view != null:
			actor.model_view.playback_enabled = false
	await _capture()
	(await _capture()).save_png("res://test-artifacts/gun-turret-gameplay.png")
	app.free()
	await process_frame


func _profile(viewport_size: Vector2i, suffix: String) -> void:
	var surface: SubViewport = _surface(viewport_size)
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var container := Node2D.new()
	surface.add_child(container)
	var towers: Array[ActorView] = []
	for index: int in range(30):
		var actor: ActorView = load("res://scenes/actors/gun_tower.tscn").instantiate()
		container.add_child(actor)
		actor.scale = Vector2.ONE * 2
		actor.position = Vector2(100 + (index % 6) * 210, 130 + (index / 6) * 145)
		towers.append(actor)
	var timings: Array[float] = []
	for frame: int in range(180):
		var started: int = Time.get_ticks_usec()
		for index: int in towers.size():
			var direction := Vector2.from_angle(float(frame) * 0.018 + index * 0.15)
			towers[index].model_view.set_aim(direction)
			if frame % 48 == index % 48:
				towers[index].notify_attack(direction)
		await process_frame
		await RenderingServer.frame_post_draw
		if frame >= 60:
			timings.append(float(Time.get_ticks_usec() - started) / 1000.0)
	timings.sort()
	var pixels: int = 0
	for actor: ActorView in towers:
		pixels += actor.model_view.viewport.size.x * actor.model_view.viewport.size.y
	var record: Dictionary = {"godot": Engine.get_version_info().string,
		"os": OS.get_name(), "cpu": OS.get_processor_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"workload": "30 visible live gun towers, scale 2, all turning, staggered recoil, no terrain or other actors",
		"viewport": [viewport_size.x, viewport_size.y], "warmup_frames": 60, "sample_frames": timings.size(), "vsync": "disabled", "fps_cap": 0,
		"median_frame_ms": timings[timings.size() / 2], "p95_frame_ms": timings[ceili(timings.size() * 0.95) - 1],
		"model_render_pixels": pixels, "renderer_texture_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)}
	var file := FileAccess.open("res://test-artifacts/gun-turret-profile%s.json" % suffix, FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "\t") + "\n")
	print("Live turret workload: median %.2f ms, p95 %.2f ms; %d rendered pixels" % [record.median_frame_ms, record.p95_frame_ms, pixels])
	surface.free()
	await process_frame
