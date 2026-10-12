extends SceneTree
## Capture the authored assets and native Research at desktop and landscape phone sizes.


func _initialize() -> void:
	_run.call_deferred()


func _capture(surface: SubViewport, name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	surface.get_texture().get_image().save_png("res://test-artifacts/" + name + ".png")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Research capture requires a graphical display.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://test-artifacts")
	var surface := SubViewport.new()
	surface.size = Vector2i(1280, 800)
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	var app := load("res://scenes/main.tscn").instantiate() as GameApp
	app.storage_root = "/private/tmp/nathaniel-research-capture-%d/" % Time.get_ticks_usec()
	surface.add_child(app)
	app.set_physics_process(false)
	app.audio.apply_settings(false, false)
	app.audio.music.stop()
	app.load_level(0)
	app.fog.enabled = false
	app.effects.fog_enabled = false
	app.sim.hermes.position = Vector2(480, 480)
	app.sim.nathaniel.position = Vector2(420, 400)
	app.sim.resources = 100
	app.sim.tech = 24
	var center := app.sim.place_map_tower("researchCenter", Vector2(590, 430))
	app.sim.place_map_tower("gunTower", Vector2(420, 570))
	app.sim.place_map_tower("laserTower", Vector2(620, 580))
	app.sim.place_map_tower("healTower", Vector2(330, 480))
	app.sim.spawn_tech(1, Vector2(485, 370))
	app.sim.spawn_tech(8, Vector2(565, 325), "core")
	app._physics_process(0.0)
	app.camera.position = IsoProjection.project(Vector2(495, 475)) + Vector2(0, 30)
	app.camera.force_update_scroll()
	app.ui.show_notice("")
	await create_timer(0.8).timeout
	app.sim.set_paused(true)
	app._sync_views()
	await _capture(surface, "research-gameplay-desktop")
	app.sim.set_paused(false)
	app._open_research(int(center.id))
	await _capture(surface, "research-menu-desktop")
	surface.size = Vector2i(844, 390)
	await process_frame
	await process_frame
	app.ui.research._layout()
	await _capture(surface, "research-menu-phone-list")
	app.ui.research.select_track("capacity")
	await _capture(surface, "research-menu-phone-detail")
	surface.size = Vector2i(667, 375)
	await process_frame
	await process_frame
	app.ui.research._layout()
	await _capture(surface, "research-menu-small-phone-detail")
	app.ui.research.back()
	await _capture(surface, "research-menu-small-phone-list")
	surface.size_2d_override = Vector2i(1280, 800)
	surface.size_2d_override_stretch = true
	await process_frame
	await process_frame
	app.ui.research._layout()
	await _capture(surface, "research-menu-stretched-phone-list")
	app.ui.research.select_track("capacity")
	await _capture(surface, "research-menu-stretched-phone-detail")
	surface.size_2d_override = Vector2i.ZERO
	surface.size_2d_override_stretch = false
	app.command("research_resume")
	app.sim.set_paused(true)
	app._sync_views()
	await _capture(surface, "research-gameplay-phone")
	surface.size = Vector2i(1280, 800)
	for map_id: String in ["dry_wash", "open_countryside", "freight_yard"]:
		await _capture_map(app, surface, map_id)
	surface.queue_free()
	await process_frame
	await create_timer(0.05).timeout
	print("Research captures: test-artifacts/research-{gameplay,menu}-{desktop,phone}.png")
	quit()


func _capture_map(app: GameApp, surface: SubViewport, map_id: String) -> void:
	app.load_survival_map(map_id)
	app.fog.enabled = false
	app.effects.fog_enabled = false
	app.sim.resources = 100
	var center: Dictionary = {}
	for index: int in range(32):
		var point: Vector2 = app.sim.hermes.position + Vector2.from_angle(index * TAU / 32.0) * 145
		if app.sim.place_tower("researchCenter", point):
			center = app.sim.research_center()
			break
	if center.is_empty():
		push_error("No valid Research center capture placement in " + map_id)
		return
	app.sim.spawn_tech(1, Vector2(center.position) + Vector2(75, 15))
	app.sim.spawn_tech(8, Vector2(center.position) + Vector2(10, -95), "core")
	app._physics_process(0.0)
	app.camera.position = IsoProjection.project((Vector2(center.position) + Vector2(app.sim.hermes.position)) / 2) + Vector2(0, 10)
	app.camera.force_update_scroll()
	app.ui.show_notice("")
	await create_timer(0.65).timeout
	app.sim.set_paused(true)
	app._sync_views()
	await _capture(surface, "research-gameplay-" + map_id)
