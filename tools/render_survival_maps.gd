extends SceneTree
## Capture normal gameplay zoom and compare rendered frames on authored terrain.

const MAPS: Array[String] = ["abandoned_crossroads", "dry_wash", "freight_yard", "open_countryside"]
const DIRECTORY: String = "res://test-artifacts/survival-maps"
const WARMUP: int = 60
const SAMPLES: int = 360
var app: GameApp

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Survival captures require a graphical display")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1280, 800)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	app = load("res://scenes/main.tscn").instantiate() as GameApp
	app.storage_root = ProjectSettings.globalize_path(DIRECTORY.path_join("storage-%d" % Time.get_ticks_usec()))
	root.add_child(app)
	current_scene = app
	app.audio.music_enabled = false
	app.audio.sound_enabled = false
	app.audio.music.stop()
	var reports: Array[Dictionary] = []
	for map_id: String in MAPS:
		if not app.load_survival_map(map_id):
			push_error("Cannot capture survival map " + map_id)
			quit(1)
			return
		app.fog.enabled = false
		app.camera_zoom = 1.0
		app.camera.zoom = Vector2.ONE
		app.sim.random.seed = 137
		app._update_camera(1.0, true)
		app._sync_views()
		app.sim.set_paused(true)
		for frame: int in WARMUP:
			await RenderingServer.frame_post_draw
		var path: String = DIRECTORY.path_join(map_id + ".png")
		if root.get_texture().get_image().save_png(path) != OK:
			push_error("Cannot save " + path)
			quit(1)
			return
		app.sim.set_paused(false)
		var intervals: Array[float] = []
		var physics: Array[float] = []
		var previous: int = Time.get_ticks_usec()
		for frame: int in SAMPLES:
			await RenderingServer.frame_post_draw
			var now: int = Time.get_ticks_usec()
			intervals.append((now - previous) / 1000.0)
			previous = now
			physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		reports.append({"map_id": map_id, "wall_frame_ms": _summary(intervals), "physics_ms": _summary(physics),
			"enemy_count": app.sim.opponents(false).size(), "elapsed_seconds": app.sim.elapsed_time,
			"screenshot": ProjectSettings.globalize_path(path)})
		print("Captured " + map_id)
	var report := {"engine": Engine.get_version_info().string, "cpu": OS.get_processor_name(),
		"gpu": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"viewport": [1280, 800], "zoom": 1.0, "fog": false, "frame_cap": 60, "vsync": false,
		"warmup_frames": WARMUP, "sample_frames": SAMPLES, "seed": 137,
		"scope": "Opening wave on each authored map; rendered intervals include the 60 FPS cap. Not an input test or stress workload.",
		"reports": reports}
	var file := FileAccess.open(DIRECTORY.path_join("rendered-profile.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("Survival captures and rendered-profile.json: " + ProjectSettings.globalize_path(DIRECTORY))
	app.queue_free()
	await process_frame
	quit(0)

func _summary(samples: Array[float]) -> Dictionary:
	samples.sort()
	return {"median": samples[samples.size() / 2], "p95": samples[mini(samples.size() - 1, ceili(samples.size() * 0.95))], "maximum": samples.back()}
