extends SceneTree
## Render a deliberate front/back overlap with the same nested scene Y-sort as the game.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(960, 540)
	var actors: Node2D = Node2D.new()
	actors.y_sort_enabled = true
	root.add_child(actors)
	var scenery: Node2D = Node2D.new()
	scenery.y_sort_enabled = true
	actors.add_child(scenery)
	for index: int in range(2):
		var tree: Sprite2D = load("res://scenes/scenery/tree.tscn").instantiate() as Sprite2D
		tree.position = Vector2(280 + index * 400, 300)
		tree.scale = Vector2(2, 2)
		scenery.add_child(tree)
		var actor: ActorView = load("res://scenes/actors/nathaniel.tscn").instantiate() as ActorView
		actors.add_child(actor)
		var point: Vector2 = tree.position + Vector2(12, -24 if index == 0 else 24)
		actor.scale = Vector2(2, 2)
		actor.apply_state({"id": index, "position": IsoProjection.unproject(point), "hp": 100, "max_hp": 100})
		var label: Label = Label.new()
		label.text = "BEHIND THE TREE" if index == 0 else "IN FRONT OF THE TREE"
		label.position = Vector2(160 + index * 400, 370)
		label.add_theme_font_size_override("font_size", 22)
		root.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png("/tmp/nathaniel-depth-preview.png")
	print("Depth preview: ", result)
	quit(result)
