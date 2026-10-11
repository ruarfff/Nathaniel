extends SceneTree
## Scripted effect sequences and survival collection using normal death and delivery rules.


func _initialize() -> void:
	_run.call_deferred()


func output_view(size: Vector2i = Vector2i(1280, 720)) -> SubViewport:
	var output := SubViewport.new()
	output.size = size * 3
	output.size_2d_override = size
	output.size_2d_override_stretch = true
	output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(output)
	return output


func capture(output: SubViewport, filename: String) -> void:
	for frame: int in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var path: String = "res://test-artifacts/" + filename + ".png"
	output.get_texture().get_image().save_png(path)
	print("Captured " + path)


func _explosions() -> void:
	var output: SubViewport = output_view(Vector2i(1280, 880))
	for row: int in range(4):
		var kind: String = "grunt" if row < 2 else "spawner"
		var dark: bool = row % 2 == 1
		var strip: SubViewport = output_view(Vector2i(1280, 220))
		var terrain := TileMapLayer.new()
		terrain.tile_set = load("res://resources/environment_tileset.tres")
		terrain.scale = Vector2.ONE * 0.125
		terrain.position = Vector2(640, 0)
		terrain.z_index = -20
		strip.add_child(terrain)
		for y: int in range(-30, 31):
			for x: int in range(-30, 31):
				terrain.set_cell(Vector2i(x, y), 0, Vector2i(4, 1) if dark else Vector2i(1, 0))
		for column: int in range(5):
			var sim := GameSimulation.new()
			sim.configure({"number": 0, "width": 64, "height": 64, "tile_size": 32, "blocked": [],
				"player_start": Vector2(1500, 1500), "hermes_start": Vector2(1600, 1500), "enemies": [], "wave_based": false})
			var effects: WorldEffects = load("res://scenes/effects/world_effects.tscn").instantiate()
			effects.simulation = sim
			effects.fog_enabled = false
			strip.add_child(effects)
			effects.set_process(false)
			var point: Vector2 = IsoProjection.unproject(Vector2(128 + column * 256, 186))
			var unit: Dictionary = sim.spawn_enemy(kind, point)
			unit.facing = Vector2(-1, -1)
			sim.take_events()
			sim.damage_entity(unit.id, 10000)
			effects.add_events(sim.take_events())
			var age: float = ([0.0, 0.08, 0.16, 0.30, 0.4] if kind == "grunt" else [0.0, 0.2, 0.4, 0.65, 0.8])[column]
			effects._process(age)
			var label := Label.new()
			label.text = "%s · %.2f s" % [kind.capitalize(), age]
			label.position = Vector2(20 + column * 256, 10)
			label.add_theme_font_size_override("font_size", 19)
			label.add_theme_color_override("font_color", Color("f4e4bf") if dark else Color("18282b"))
			strip.add_child(label)
		var preview := TextureRect.new()
		preview.texture = strip.get_texture()
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.size = Vector2(1280, 220)
		preview.position = Vector2(0, row * 220)
		output.add_child(preview)
	await capture(output, "enemy-death-sequences-4k")
	output.free()
	# The strips are root siblings so they render before the board reads them.
	for child: Node in root.get_children():
		if child is SubViewport:
			child.queue_free()
	await process_frame


func _survival() -> void:
	var output: SubViewport = output_view()
	var app: GameApp = load("res://scenes/main.tscn").instantiate()
	app.storage_root = "/private/tmp/nathaniel-deaths-capture-%d/" % Time.get_ticks_usec()
	output.add_child(app)
	app.set_physics_process(false)
	app.audio.sound_enabled = false
	app.audio.music_enabled = false
	app.audio.music.stop()
	app.load_level(0)
	app.sim.level.wave_based = false
	app.fog.enabled = false
	app.effects.fog_enabled = false
	app.sim.hermes.position = app.sim.nathaniel.position + Vector2(80, -80)
	app.sim.hermes.speed = 0
	app.sim.hermes.delay = 100000
	app.sim.nathaniel.aim_direction = Vector2(-0.65, -0.75)
	var boss: Dictionary = app.sim.spawn_enemy("boss", app.sim.nathaniel.position + Vector2(-24, 8))
	app.sim.damage_entity(boss.id, 1000)
	app.camera_zoom = 1.5
	var start_wallet: int = app.sim.resources
	for stage: String in ["grab", "crush", "carry", "feed", "credited"]:
		app.sim.set_paused(false)
		if stage == "grab":
			app.sim.step(0.15)
		elif stage == "crush":
			app.sim.step(0.22)
		elif stage == "carry":
			app.sim.step(0.30)
		elif stage == "feed":
			app.sim.hermes.position = app.sim.nathaniel.position + Vector2(32, -32)
			app.sim.step(0.42)
		else:
			app.sim.step(0.18)
		app.sim.set_paused(true)
		app._physics_process(0)
		app.camera.zoom = Vector2.ONE * 1.5
		app.camera.position = IsoProjection.project(app.sim.nathaniel.position) + Vector2(50, -30)
		app.ui.show_notice("Scripted survival · boss %s · resources %d" % [stage, app.sim.resources])
		await capture(output, "boss-survival-" + stage + "-4k")
	if app.sim.resources != start_wallet + 10 or not app.sim.corpses.is_empty():
		push_error("Capture did not complete one normal boss delivery")
	var dying_units: Array[Dictionary] = []
	for index: int in range(5):
		var unit: Dictionary = app.sim.spawn_enemy("spawner" if index == 4 else "grunt", app.sim.nathaniel.position + Vector2(-70 + index * 45, -30))
		dying_units.append(unit)
	app.sim.take_events()
	for unit: Dictionary in dying_units:
		app.sim.damage_entity(unit.id, 10000)
	app._physics_process(0)
	app.sim.set_paused(false)
	app.effects._process(0.16)
	app.sim.set_paused(true)
	app.ui.show_notice("Scripted survival · simultaneous shell deaths · normal zoom")
	app.camera.zoom = Vector2.ONE
	await capture(output, "enemy-deaths-simultaneous-gameplay-4k")
	output.free()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Enemy death captures require a display")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://test-artifacts")
	await _explosions()
	await _survival()
	quit()
