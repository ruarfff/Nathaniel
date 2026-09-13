extends SceneTree
## Render a deterministic content preview without loading or changing saves.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1152, 720)
	var number: int = int(OS.get_cmdline_user_args()[1]) if OS.get_cmdline_user_args().size() > 1 else 1
	var level: GameLevel = load("res://levels/level_%d.tscn" % number).instantiate() as GameLevel
	root.add_child(level)
	var actors: Node2D = Node2D.new()
	actors.y_sort_enabled = true
	root.add_child(actors)
	level.get_node("Scenery").reparent(actors)
	var starts: Dictionary = level.data()
	for kind: String in ["nathaniel", "hermes"]:
		var actor: ActorView = load("res://scenes/actors/%s.tscn" % kind).instantiate() as ActorView
		actors.add_child(actor)
		actor.apply_state({"id": 1, "position": starts.player_start if kind == "nathaniel" else starts.hermes_start,
			"hp": 100, "max_hp": 100}, true)
	var camera: Camera2D = Camera2D.new()
	camera.position = IsoProjection.project(starts.player_start + Vector2(200, 140))
	camera.zoom = Vector2(1.3, 1.3)
	root.add_child(camera)
	await process_frame
	await RenderingServer.frame_post_draw
	var output: String = "/tmp/nathaniel-content-preview.png"
	if not OS.get_cmdline_user_args().is_empty():
		output = OS.get_cmdline_user_args()[0]
	var error: Error = root.get_texture().get_image().save_png(output)
	print("Content preview: ", output, " (", error, ")")
	quit(error)
