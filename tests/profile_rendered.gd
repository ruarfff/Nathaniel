extends SceneTree
## A real window, the complete GameApp frame path, and isolated test storage.
## Run without --headless. Results are written below ignored test-artifacts/.

const WARMUP_FRAMES: int = 60
const MEASURED_FRAMES: int = 600
const HIGH_HP: int = 1000000

var app: GameApp
var physics_ticks: int = 0
var artifact_directory: String
var used_cells: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Rendered profiling requires a graphical display; omit --headless")
		quit(1)
		return
	Engine.physics_ticks_per_second = 60
	Engine.max_fps = 60
	root.size = Vector2i(1280, 800)
	DisplayServer.window_set_title("Nathaniel — rendered performance test")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	artifact_directory = ProjectSettings.globalize_path("res://test-artifacts/rendered-profile").simplify_path()
	if DirAccess.make_dir_recursive_absolute(artifact_directory) != OK:
		push_error("Cannot create rendered profile artifact directory")
		quit(1)
		return
	app = load("res://scenes/main.tscn").instantiate() as GameApp
	# Set this before _ready constructs settings, progress and save services.
	app.storage_root = artifact_directory.path_join("storage-%d" % Time.get_ticks_usec())
	root.add_child(app)
	current_scene = app
	app.audio.music_enabled = false
	app.audio.sound_enabled = false
	app.audio.music.stop()
	if not app.load_level(0):
		push_error("Rendered profile could not load the survival level")
		quit(1)
		return
	app.sim.level.wave_based = false
	app.fog.enabled = false
	app.camera_zoom = 0.55
	app.camera.zoom = Vector2.ONE * app.camera_zoom
	if not _populate():
		quit(1)
		return
	app._update_camera(1.0, true)
	app._sync_views()
	physics_frame.connect(func() -> void: physics_ticks += 1)
	for frame: int in WARMUP_FRAMES:
		await RenderingServer.frame_post_draw
	var starting_ticks: int = physics_ticks
	var starting_elapsed: float = app.sim.elapsed_time
	var initial_entities: int = app.sim.entities.size()
	var intervals: Array[float] = []
	var process_times: Array[float] = []
	var physics_times: Array[float] = []
	var maximum_draw_calls: int = 0
	var maximum_render_objects: int = 0
	var maximum_nodes: int = 0
	var maximum_projectiles: int = 0
	var previous: int = Time.get_ticks_usec()
	for frame: int in MEASURED_FRAMES:
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		intervals.append((now - previous) / 1000.0)
		previous = now
		process_times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		maximum_draw_calls = maxi(maximum_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		maximum_render_objects = maxi(maximum_render_objects, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		maximum_nodes = maxi(maximum_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		maximum_projectiles = maxi(maximum_projectiles, app.sim.projectiles.size())
	var screenshot_path: String = artifact_directory.path_join("rendered-profile.png")
	var screenshot_image: Image = root.get_texture().get_image()
	var screenshot_error: Error = screenshot_image.save_png(screenshot_path)
	var output: Dictionary = {
		"engine": Engine.get_version_info().string,
		"platform": OS.get_name(),
		"architecture": Engine.get_architecture_name(),
		"processor": OS.get_processor_name(),
		"processors": OS.get_processor_count(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"display_server": DisplayServer.get_name(),
		"screen_refresh_hz": DisplayServer.screen_get_refresh_rate(),
		"viewport": {"width": screenshot_image.get_width(), "height": screenshot_image.get_height()},
		"window_size": {"width": root.size.x, "height": root.size.y},
		"logical_viewport": {"width": root.get_visible_rect().size.x, "height": root.get_visible_rect().size.y},
		"physics_hz": Engine.physics_ticks_per_second,
		"frame_cap": Engine.max_fps,
		"vsync": "disabled",
		"warmup_draw_frames": WARMUP_FRAMES,
		"measured_draw_frames": MEASURED_FRAMES,
		"measured_physics_ticks": physics_ticks - starting_ticks,
		"measured_game_seconds": app.sim.elapsed_time - starting_elapsed,
		"workload": "Survival terrain; 200 enemies (50 of each kind), 30 towers (10 of each), two players",
		"setup": "High HP retains workload; waves disabled; fog disabled to render all actors; camera zoom0.55; audio muted",
		"initial_entities": initial_entities,
		"final_entities": app.sim.entities.size(),
		"actor_views": app.views.size(),
		"maximum_projectiles": maximum_projectiles,
		"wall_frame_interval_ms": _summary(intervals),
		"engine_process_ms": _summary(process_times),
		"engine_physics_process_ms": _summary(physics_times),
		"maximum_draw_calls": maximum_draw_calls,
		"maximum_render_objects": maximum_render_objects,
		"maximum_node_count": maximum_nodes,
		"game_state": app.sim.result,
		"screenshot": screenshot_path,
		"screenshot_saved": screenshot_error == OK,
		"storage_root": app.storage_root,
	}
	var output_path: String = artifact_directory.path_join("rendered-profile.json")
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write rendered profile report")
		quit(1)
		return
	file.store_string(JSON.stringify(output, "\t") + "\n")
	file.close()
	print(JSON.stringify(output, "\t"))
	if screenshot_error != OK or app.sim.result != "playing" or app.sim.entities.size() != 232:
		push_error("Rendered workload changed unexpectedly or screenshot failed")
		quit(1)
		return
	print("PASS rendered profile: " + output_path)
	quit(0)


func _populate() -> bool:
	var navigation: WorldNavigation = app.sim.navigation
	var candidates: Array[Vector2] = []
	for y: int in range(2, navigation.height - 2):
		for x: int in range(2, navigation.width - 2):
			var point: Vector2 = navigation.center(Vector2i(x, y))
			if navigation.terrain_clear(point):
				candidates.append(point)
	if candidates.size() < 232:
		push_error("Survival level lacks enough open cells for the fixed workload")
		return false
	var middle: Vector2 = Vector2(navigation.width, navigation.height) * navigation.tile_size * 0.5
	app.sim.nathaniel.position = middle
	app.sim.hermes.position = middle + Vector2(64, 0)
	for player: Dictionary in [app.sim.nathaniel, app.sim.hermes]:
		player.hp = HIGH_HP
		player.max_hp = HIGH_HP
		used_cells[navigation.cell(player.position)] = true
	for index: int in 30:
		var candidate: Vector2 = candidates[(index * candidates.size()) / 30]
		var tower: Dictionary = app.sim.place_map_tower(GameBalance.TOWERS[index % 3], candidate)
		tower.hp = HIGH_HP
		tower.max_hp = HIGH_HP
		used_cells[navigation.cell(candidate)] = true
	for index: int in 200:
		var selected := Vector2.INF
		for offset: int in candidates.size():
			var candidate: Vector2 = candidates[(index * 73 + offset) % candidates.size()]
			var cell: Vector2i = navigation.cell(candidate)
			if not used_cells.has(cell) and navigation.walkable(candidate, 32.0):
				selected = candidate
				used_cells[cell] = true
				break
		if not selected.is_finite():
			push_error("Not enough tower-clear spawn positions for the fixed workload")
			return false
		var enemy: Dictionary = app.sim.spawn_enemy(GameBalance.ENEMIES[index % 4], selected)
		enemy.hp = HIGH_HP
		enemy.max_hp = HIGH_HP
	return true


func _summary(samples: Array[float]) -> Dictionary:
	var sorted: Array[float] = samples.duplicate()
	sorted.sort()
	var total: float = 0.0
	for sample: float in samples:
		total += sample
	return {"median": sorted[sorted.size() / 2], "p95": sorted[mini(sorted.size() - 1, ceili(sorted.size() * 0.95))], "maximum": sorted.back(), "mean": total / samples.size()}
