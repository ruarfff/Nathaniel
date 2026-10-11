extends SceneTree
## Frozen domain phases at gameplay scale and close detail, in both Hermes forms.

var boss: bool = "--boss" in OS.get_cmdline_user_args()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Resource gathering capture needs a graphical display.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://test-artifacts")
	var output := SubViewport.new()
	output.size = Vector2i(3840, 2160)
	output.size_2d_override = Vector2i(1280, 720)
	output.size_2d_override_stretch = true
	output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(output)
	for row: int in range(3):
		var backdrop := ColorRect.new()
		backdrop.color = Color("b3a387") if row % 2 == 0 else Color("373b3a")
		backdrop.position = Vector2(0, row * 240)
		backdrop.size = Vector2(1280, 240)
		output.add_child(backdrop)
		for column: int in range(6):
			var phase: String = ["grab", "crush", "carry", "present", "feed", "consume"][column]
			var pair := Node2D.new()
			pair.position = Vector2((115 if row == 0 else 105) + column * 213 - (50 if row == 0 and column >= 3 else 0), 198 + row * 240)
			pair.scale = Vector2.ONE * (1.5 if row == 0 else 1.0)
			output.add_child(pair)
			var nathaniel: ActorView = load("res://scenes/actors/nathaniel.tscn").instantiate()
			var hermes: HermesView = load("res://scenes/actors/hermes.tscn").instantiate()
			pair.add_child(nathaniel)
			pair.add_child(hermes)
			var player: Dictionary = {"position": Vector2.ZERO, "hp": 100, "resource_capacity": 1 if row < 2 else 3,
				"aim_direction": Vector2(-0.65, -0.75), "moving": false}
			var receiver: Dictionary = {"position": Vector2(32, -32), "hp": 100, "anchored": row == 2,
				"facing": Vector2.RIGHT, "furnace_remaining": GameBalance.RESOURCE_FURNACE_SECONDS * 0.5 if phase == "consume" else 0.0}
			var corpse: Dictionary = {"id": 1, "position": Vector2(-20, 8), "pickup_position": Vector2(-20, 8),
				"phase": phase, "phase_elapsed": BattlefieldRules.phase_seconds(phase) * 0.5,
				"carried": phase != "grab", "cargo_slot": 0, "source_kind": "boss" if boss else "soldier"}
			var cargo: Array = [] if phase == "consume" else [corpse]
			if row == 2:
				cargo.append({"phase": "carry", "carried": true, "cargo_slot": 1})
				cargo.append({"phase": "carry", "carried": true, "cargo_slot": 2})
			nathaniel.apply_state(player, false, false)
			hermes.apply_state(receiver, false, false)
			nathaniel.sync_gathering(cargo, player, receiver, hermes)
			hermes.sync_intake(cargo, player, receiver)
			if column < 3:
				hermes.hide()
			if phase == "grab":
				var body := Sprite2D.new()
				var art: ActorVisual = load("res://resources/actors/boss_corpse.tres" if boss else "res://resources/actors/corpse.tres")
				body.texture = art.texture
				body.scale = Vector2.ONE / art.frame_pixel_density()
				body.centered = false
				body.position = IsoProjection.project(corpse.position) - art.frame_ground_anchor() / art.frame_pixel_density()
				pair.add_child(body)
				pair.move_child(body, 0)
			var label := Label.new()
			label.text = phase.capitalize()
			label.position = Vector2(15 + column * 213, 12 + row * 240)
			label.add_theme_font_size_override("font_size", 20)
			label.add_theme_color_override("font_color", Color("f4e4bf") if row == 1 else Color("18282b"))
			output.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	output.get_texture().get_image().save_png("res://test-artifacts/%s-gathering-stages-4k.png" % ("boss" if boss else "resource"))
	output.free()
	await process_frame
	if not boss:
		await _capture_gameplay()
		await _capture_winch_studies()
	await _capture_self_destruct()
	print("Resource gathering capture: test-artifacts/%s-gathering-stages-4k.png" % ("boss" if boss else "resource"))
	quit()


func _capture_gameplay() -> void:
	var output := SubViewport.new()
	output.size = Vector2i(3840, 2160)
	output.size_2d_override = Vector2i(1280, 720)
	output.size_2d_override_stretch = true
	output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(output)
	var app: GameApp = load("res://scenes/main.tscn").instantiate()
	app.storage_root = "/private/tmp/nathaniel-gathering-capture-%d/" % Time.get_ticks_usec()
	output.add_child(app)
	app.set_physics_process(false)
	app.audio.music_enabled = false
	app.audio.sound_enabled = false
	app.audio.music.stop()
	app.load_level(2)
	app.fog.enabled = false
	app.effects.fog_enabled = false
	app.sim.nathaniel.position = Vector2(2016, 720)
	app.sim.nathaniel.aim_direction = Vector2(-0.65, -0.75)
	app.sim.nathaniel.resource_capacity = 3
	app.sim.hermes.position = app.sim.nathaniel.position + Vector2(32, -32)
	app.sim.hermes.facing = Vector2.RIGHT
	app.sim.hermes.delay = 100000.0
	app.sim.take_events()
	app.sim.set_paused(true)
	for slot: int in range(3):
		app.sim.spawn_resource(10, app.sim.nathaniel.position, 10.0, true)
	app._physics_process(0.0)
	app.camera_zoom = 2.0
	app.camera.zoom = Vector2.ONE * 2.0
	app.camera.position = IsoProjection.project(app.sim.nathaniel.position) + Vector2(35, -40)
	app.ui.show_notice("")
	for phase: String in ["carry", "feed", "consume"]:
		if phase == "feed":
			app.sim.corpses[0].phase = "feed"
			app.sim.corpses[0].phase_elapsed = GameBalance.RESOURCE_FEED_SECONDS * 0.6
		elif phase == "consume":
			app.sim.corpses.remove_at(0)
			app.sim.hermes.furnace_remaining = GameBalance.RESOURCE_FURNACE_SECONDS * 0.5
		app._physics_process(0.0)
		await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		output.get_texture().get_image().save_png("res://test-artifacts/resource-gathering-%s-gameplay-4k.png" % phase)
	output.free()
	await process_frame


func _capture_self_destruct() -> void:
	var output := SubViewport.new()
	output.size = Vector2i(3840, 1440)
	output.size_2d_override = Vector2i(1280, 480)
	output.size_2d_override_stretch = true
	output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(output)
	for row: int in range(2):
		var strip := SubViewport.new()
		strip.size = Vector2i(3840, 720)
		strip.size_2d_override = Vector2i(1280, 240)
		strip.size_2d_override_stretch = true
		strip.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		output.add_child(strip)
		var backdrop := ColorRect.new()
		backdrop.color = Color("b3a387") if row == 0 else Color("373b3a")
		backdrop.size = Vector2(1280, 240)
		backdrop.z_index = -30
		strip.add_child(backdrop)
		var terrain := TileMapLayer.new()
		terrain.tile_set = load("res://resources/environment_tileset.tres")
		terrain.scale = Vector2.ONE * 0.125
		terrain.position = Vector2(640, 0)
		terrain.z_index = -20
		strip.add_child(terrain)
		for y: int in range(-25, 26):
			for x: int in range(-25, 26):
				terrain.set_cell(Vector2i(x, y), 0, Vector2i(1, 0) if row == 0 else Vector2i(4, 1))
		if row == 1:
			for index: int in range(12):
				var rubble: Sprite2D = load("res://scenes/scenery/generated/environment_rocks.tscn").instantiate()
				rubble.position = Vector2(25 + index * 114, 110 if index % 2 == 0 else 204)
				rubble.z_index = -5
				strip.add_child(rubble)
		var effects: WorldEffects = load("res://scenes/effects/world_effects.tscn").instantiate()
		var sim := GameSimulation.new()
		sim.configure({"number": 1, "width": 64, "height": 64, "tile_size": 32, "blocked": [],
			"player_start": Vector2(1500, 1500), "hermes_start": Vector2(1600, 1500), "enemies": [], "wave_based": false})
		sim.set_paused(true)
		effects.simulation = sim
		effects.fog_enabled = false
		strip.add_child(effects)
		effects.set_process(false)
		for column: int in range(5):
			var point: Vector2 = IsoProjection.unproject(Vector2(145 + column * 245, 165))
			var remaining: float = [6.0, 2.875, 2.625, 0.0, 0.1][column]
			var corpse: Dictionary = sim.spawn_resource(10, point, maxf(remaining, 0.1), false, "boss" if boss else ("soldier" if column % 2 == 0 else "gunSoldier"))
			if column == 3:
				sim.corpses.erase(corpse)
				effects.add_events([{"type": "corpse_expired", "corpse_id": corpse.id, "position": point,
					"source_kind": corpse.source_kind, "elapsed_since_expiry": 0.3}])
			elif column == 4:
				corpse.disarmed = true
			var label := Label.new()
			label.text = ["Armed", "Warning / bright", "Warning / dim", "Dissolving / lost", "Disarmed / safe"][column]
			label.position = Vector2(30 + column * 245, 22)
			label.add_theme_font_size_override("font_size", 20)
			label.add_theme_color_override("font_color", Color("18282b") if row == 0 else Color("f4e4bf"))
			strip.add_child(label)
		effects._process(0.0)
		var title := Label.new()
		title.text = "Sand / normal zoom" if row == 0 else "Dark rubble / normal zoom"
		title.position = Vector2(20, 206)
		title.add_theme_font_size_override("font_size", 16)
		title.add_theme_color_override("font_color", Color("18282b") if row == 0 else Color("f4e4bf"))
		strip.add_child(title)
		var preview := TextureRect.new()
		preview.texture = strip.get_texture()
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.size = Vector2(1280, 240)
		preview.position = Vector2(0, row * 240)
		output.add_child(preview)
	for frame: int in range(4):
		await process_frame
		await RenderingServer.frame_post_draw
	output.get_texture().get_image().save_png("res://test-artifacts/%s-self-destruct-stages-4k.png" % ("boss" if boss else "corpse"))
	output.free()
	await process_frame
	print("Corpse self-destruct capture: test-artifacts/%s-self-destruct-stages-4k.png" % ("boss" if boss else "corpse"))


func _winch_panel(output: SubViewport, point: Vector2, direction: Vector2, phase: String, fraction: float, source_kind: String) -> void:
	var pair := Node2D.new()
	pair.position = point
	output.add_child(pair)
	var sim := GameSimulation.new()
	sim.configure({"number": 1, "width": 64, "height": 64, "tile_size": 32, "blocked": [],
		"player_start": Vector2(900, 900), "hermes_start": Vector2(600, 600), "enemies": [], "wave_based": false})
	sim.set_hermes_mode("building")
	sim.fog.fill(2)
	sim.set_paused(true)
	pair.position -= IsoProjection.project(sim.hermes.position)
	var hermes: HermesView = load("res://scenes/actors/hermes.tscn").instantiate()
	pair.add_child(hermes)
	hermes.apply_state(sim.hermes, false, false)
	var corpse: Dictionary = sim.spawn_resource(10, Vector2(sim.hermes.position) + direction * 100.0, 2.875, false, source_kind)
	corpse.phase = phase
	corpse.phase_elapsed = BattlefieldRules.phase_seconds(phase) * fraction
	corpse.pickup_position = corpse.position
	corpse.disarmed = phase != "winch_launch"
	corpse.recovery_route = [corpse.position, Vector2(sim.hermes.position) + direction * GameBalance.HERMES_WINCH_GUIDE_RADIUS,
		Vector2(sim.hermes.position) + Vector2(GameBalance.HERMES_WINCH_GUIDE_RADIUS, 0), Vector2(sim.hermes.position) + GameBalance.HERMES_WINCH_INTAKE_OFFSET]
	if phase == "winch_reel":
		corpse.position = Vector2(sim.hermes.position) + direction * lerpf(100.0, GameBalance.HERMES_WINCH_GUIDE_RADIUS, fraction)
	elif phase == "winch_crush":
		corpse.position = Vector2(sim.hermes.position) + Vector2(GameBalance.HERMES_WINCH_GUIDE_RADIUS, 0).lerp(GameBalance.HERMES_WINCH_INTAKE_OFFSET, fraction)
	elif phase == "winch_feed":
		corpse.position = Vector2(sim.hermes.position) + GameBalance.HERMES_WINCH_INTAKE_OFFSET
	sim.hermes.recovery_corpse_id = corpse.id
	if phase == "consume":
		sim.corpses.clear()
		sim.hermes.recovery_corpse_id = 0
		sim.hermes.furnace_remaining = GameBalance.RESOURCE_FURNACE_SECONDS * 0.5
	hermes.sync_intake(sim.corpses, sim.nathaniel, sim.hermes)
	var effects: WorldEffects = load("res://scenes/effects/world_effects.tscn").instantiate()
	effects.simulation = sim
	effects.fog_enabled = false
	pair.add_child(effects)
	effects.set_process(false)
	effects.sync_lasers({int(sim.hermes.id): hermes})
	effects._process(0.0)
	effects._hermes_ground.hide()


func _capture_winch_studies() -> void:
	for study: String in ["stages", "directions"]:
		var output := SubViewport.new()
		output.size = Vector2i(3840, 2160)
		output.size_2d_override = Vector2i(1920, 1080)
		output.size_2d_override_stretch = true
		output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(output)
		var backdrop := ColorRect.new()
		backdrop.color = Color("b3a387")
		backdrop.size = Vector2(1920, 1080)
		backdrop.z_index = -30
		output.add_child(backdrop)
		var rows: int = 3 if study == "stages" else 2
		var columns: int = 6 if study == "stages" else 4
		for row: int in rows:
			for column: int in columns:
				var heading: float = [0.0, PI, -PI * 0.5][row] if study == "stages" else TAU * (row * 4 + column) / 8.0
				var phase: String = ["winch_launch", "winch_reel", "winch_reel", "winch_crush", "winch_feed", "consume"][column] if study == "stages" else "winch_reel"
				var fraction: float = [0.35, 0.04, 0.5, 0.5, 0.5, 0.5][column] if study == "stages" else 0.5
				var cell: Vector2 = Vector2(1920.0 / columns, 1080.0 / rows)
				_winch_panel(output, Vector2(column * cell.x + cell.x * 0.5, row * cell.y + cell.y * 0.48), Vector2.from_angle(heading), phase, fraction, "boss" if row > 0 else "soldier")
				var label := Label.new()
				label.text = ["Fire / armed", "Contact / disarmed", "Reel", "Crush", "Feed", "Furnace"][column] if study == "stages" else "Heading %d / %s" % [row * 4 + column, "boss" if row > 0 else "soldier"]
				label.position = Vector2(column * cell.x + 8, row * cell.y + 12)
				label.add_theme_font_size_override("font_size", 14)
				label.add_theme_color_override("font_color", Color("18282b"))
				output.add_child(label)
		for frame: int in range(4):
			await process_frame
			await RenderingServer.frame_post_draw
		output.get_texture().get_image().save_png("res://test-artifacts/hermes-winch-%s-4k.png" % study)
		output.free()
		await process_frame
	print("Hermes winch captures: test-artifacts/hermes-winch-{stages,directions}-4k.png")
