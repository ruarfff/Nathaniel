extends SceneTree
## Capture each saved enemy emitter firing in an isolated Survival scene.


func _initialize() -> void:
	_run.call_deferred()


func capture(surface: SubViewport, path: String) -> void:
	for frame: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	surface.get_texture().get_image().save_png(path)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Enemy laser captures need a graphical display.")
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
	app.storage_root = "/private/tmp/nathaniel-enemy-lasers-%d/" % Time.get_ticks_usec()
	surface.add_child(app)
	app.set_physics_process(false)
	app.audio.music_enabled = false
	app.audio.sound_enabled = false
	app.audio.music.stop()
	for kind: String in ["soldier", "boss", "spawner"]:
		app.load_level(0)
		app.sim.level.wave_based = false
		app.fog.enabled = false
		app.effects.fog_enabled = false
		for enemy: Dictionary in app.sim.opponents(false).duplicate():
			app.sim.damage_entity(int(enemy.id), int(enemy.hp))
		app.sim.take_events()
		app.sim.corpses.clear()
		app.sim.weapon_pickups.clear()
		app.sim.nathaniel.position = Vector2(625, 430)
		app.sim.nathaniel.delay = 10000.0
		app.sim.nathaniel.facing = Vector2(-185, 60).normalized()
		app.sim.nathaniel.aim_direction = app.sim.nathaniel.facing
		app.sim.hermes.position = Vector2(2000, 2000)
		app.sim.hermes.delay = 10000.0
		var unit: Dictionary = app.sim.spawn_enemy(kind, Vector2(440, 490))
		unit.speed = 0.0
		unit.target_id = app.sim.nathaniel.id
		unit.cooldown = unit.delay
		app.sim.fog.fill(2)
		app.sim.set_paused(false)
		CombatRules.update_unit(app.sim, unit, 0.05)
		app.sim.set_paused(true)
		app._sync_views()
		app.effects.add_events(app.sim.take_events(), app.views)
		app._physics_process(0.0)
		app.ui.show_menu("")
		app.camera_zoom = 1.7 if kind == "spawner" else 2.5
		app.camera.zoom = Vector2.ONE * app.camera_zoom
		app.camera.position = IsoProjection.project(Vector2(530, 460)) - Vector2(0, 45)
		await capture(surface, "res://test-artifacts/%s-laser-gameplay.png" % kind)
		if kind == "boss":
			unit.firing = false
			app._sync_views()
			await capture(surface, "res://test-artifacts/boss-laser-closed.png")
	surface.free()
	await process_frame
	print("Enemy laser captures: test-artifacts/{soldier,boss,spawner}-laser-gameplay.png")
	quit()
