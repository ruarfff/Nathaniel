extends SceneTree
## Static art keeps authored scale and ground contact without changing gameplay.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	_check_corpse_geometry()
	if "--unit" not in OS.get_cmdline_user_args():
		_check_source("spawner", Vector2i(2560, 2304), Vector2(1280, 1792))
		_check_source("soldier_corpse", Vector2i(1024, 1024), Vector2(512, 768))
		_check_source("gun_soldier_corpse", Vector2i(1024, 1024), Vector2(512, 768))
		_check_spawner()
		_check_corpse_scene()
		if "--render" in OS.get_cmdline_user_args():
			if DisplayServer.get_name() == "headless":
				expect(false, "Rendered static art checks need a graphical display")
			else:
				await _check_rendered()
	print("Static art checks: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_source(asset: String, canvas: Vector2i, anchor: Vector2) -> void:
	var resource_name: String = "corpse" if asset == "soldier_corpse" else asset
	var visual: ActorVisual = load("res://resources/actors/%s.tres" % resource_name)
	var image: Image = visual.texture.get_image()
	expect(image.get_size() == canvas, asset + " retains its full export canvas")
	expect(image.has_mipmaps(), asset + " imports mipmaps for small screen sizes")
	expect(image.detect_alpha() != Image.ALPHA_NONE and image.get_pixel(0, 0).a == 0.0, asset + " keeps a transparent background")
	var used: Rect2i = image.get_used_rect()
	expect(used.has_area() and used.position.x > 0 and used.position.y > 0 and used.end.x < canvas.x and used.end.y < canvas.y, asset + " fits inside its canvas")
	expect(visual.frame_pixel_density() == 8.0 and visual.frame_ground_anchor() == anchor, asset + " uses the exported density and anchor")
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/%s.json" % asset))
	expect(Vector2i(metadata.canvas[0], metadata.canvas[1]) == canvas, asset + " metadata matches runtime dimensions")
	expect(Vector2(metadata.anchor[0], metadata.anchor[1]) == anchor and metadata.render_density == 8, asset + " metadata matches ground contact and scale")
	expect(FileAccess.file_exists("res://art/blender/sources/%s.blend" % asset), asset + " retains an editable Blender source")


func _check_spawner() -> void:
	var actor: ActorView = load("res://scenes/actors/spawner.tscn").instantiate() as ActorView
	actor.visual = actor.visual.duplicate() as ActorVisual
	actor.visual.model_scene = null
	root.add_child(actor)
	actor.apply_state({"position": Vector2(64, 96)}, false, false)
	var contact: Vector2 = actor.sprite.position + (actor.visual.frame_ground_anchor() - actor.sprite.region_rect.size * 0.5) * actor.sprite.scale
	expect(contact.is_zero_approx(), "Spawner origin stays at its exported ground anchor")
	expect(actor.position == IsoProjection.project(Vector2(64, 96)), "Spawner ground position uses the existing isometric projection")
	expect(actor.sprite.scale == Vector2.ONE / 8.0, "Spawner scale is independent of its large canvas")
	expect(actor.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "Spawner uses smooth sampling")
	expect(actor.visual.display_size == Vector2(240, 168) and actor.visual.shadow_radius == 70.0, "Spawner keeps its existing health bounds and ground shadow")
	expect(actor.get_child_count() == 1 and actor.get_child(0) is Sprite2D, "Spawner art adds no movement footprint")
	actor.free()


func _check_corpse_geometry() -> void:
	var effects := WorldEffects.new()
	var point := Vector2(135, 74)
	expect(effects.corpse_rect(point) == Rect2(point - Vector2(15, 8), Vector2(30, 16)), "Legacy corpse PNG keeps its centered 30 by 16 display")
	expect(effects.corpse_color(false) == Color.WHITE and is_equal_approx(effects.corpse_color(true).a, 0.65), "Legacy carried opacity stays at 0.65")
	var visual := ActorVisual.new()
	var image := Image.create(80, 96, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	visual.texture = ImageTexture.create_from_image(image)
	visual.pixels_per_world_pixel = 8.0
	visual.ground_anchor = Vector2(35, 75)
	visual.feet_offset = Vector2(2, -1)
	visual.display_size = Vector2(999, 777)
	visual.tint = Color(0.8, 0.6, 0.4, 0.7)
	effects.corpse_visual = visual
	var rectangle: Rect2 = effects.corpse_rect(point)
	expect(rectangle.size == Vector2(10, 12), "HD corpse uses source dimensions and density without stretching")
	expect((rectangle.position + visual.ground_anchor / 8.0).is_equal_approx(point + visual.feet_offset), "HD corpse source ground contact remains at the requested position")
	expect(effects.corpse_color(false) == visual.tint and is_equal_approx(effects.corpse_color(true).a, 0.7 * 0.65), "Carrying multiplies authored alpha without changing the tint")
	visual.ground_anchor -= Vector2(8, 16)
	visual.texture = ImageTexture.create_from_image(image.get_region(Rect2i(8, 16, 64, 72)))
	var cropped: Rect2 = effects.corpse_rect(point)
	expect((cropped.position + Vector2(12, 24) / 8.0).is_equal_approx(rectangle.position + Vector2(20, 40) / 8.0), "Adjusted crop anchors preserve retained corpse pixels")
	visual.pixels_per_world_pixel = 0.0
	visual.display_size = Vector2(40, 18)
	expect(effects.corpse_rect(point) == Rect2(point + visual.feet_offset - Vector2(20, 18), Vector2(40, 18)), "A legacy ActorVisual keeps its bottom-center display anchor")
	visual.texture = null
	expect(effects.corpse_rect(point) == Rect2(point - Vector2(15, 8), Vector2(30, 16)), "An empty optional visual falls back to the legacy corpse texture")
	expect(effects.corpse_color(false) == Color.WHITE, "An empty optional visual does not tint the legacy fallback")
	effects.free()


func _check_corpse_scene() -> void:
	var effects: WorldEffects = load("res://scenes/effects/world_effects.tscn").instantiate() as WorldEffects
	expect(effects.corpse_visual != null and effects.corpse_visual.resource_path == "res://resources/actors/corpse.tres", "The game effects scene uses the shared corpse visual")
	expect(effects.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "Corpse rendering uses smooth sampling")
	var rectangle: Rect2 = effects.corpse_rect(Vector2.ZERO)
	expect(rectangle == Rect2(Vector2(-64, -96), Vector2(128, 128)), "The full corpse canvas preserves its world scale and anchor")
	expect(effects.corpse_texture != null and effects.corpse_size == Vector2(30, 16), "The original corpse PNG remains available as fallback")
	expect(is_equal_approx(effects.corpse_color(true).a, 0.65), "The new corpse keeps carried opacity")
	var actor: ActorView = load("res://scenes/actors/corpse.tscn").instantiate() as ActorView
	root.add_child(actor)
	actor.apply_state({}, false, false)
	expect(actor.visual == effects.corpse_visual, "The reusable corpse scene and WorldEffects share the same authored resource")
	var contact: Vector2 = actor.sprite.position + (actor.visual.frame_ground_anchor() - actor.sprite.region_rect.size * 0.5) * actor.sprite.scale
	expect(contact.is_zero_approx() and actor.sprite.scale == Vector2.ONE / 8.0, "The reusable corpse scene preserves the same ground contact and scale")
	expect(actor.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "The reusable corpse scene uses smooth sampling")
	actor.free()
	effects.free()


func _corpse_effect(parent: Node, position: Vector2, zoom: float, carried: bool) -> WorldEffects:
	var effects: WorldEffects = load("res://scenes/effects/world_effects.tscn").instantiate() as WorldEffects
	var simulation := GameSimulation.new()
	var world_point := Vector2(320, 320)
	simulation.configure({"width": 32, "height": 32, "tile_size": 32, "blocked": [],
		"player_start": world_point, "hermes_start": Vector2(480, 320), "enemies": [], "wave_based": false})
	simulation.spawn_resource(10, world_point, 10.0, carried)
	effects.simulation = simulation
	effects.scale = Vector2.ONE * zoom
	effects.position = position - IsoProjection.project(world_point) * zoom
	parent.add_child(effects)
	return effects


func _capture(viewport: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _label(parent: Node, text: String, position: Vector2, size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("e3d5bc"))
	parent.add_child(label)


func _check_rendered() -> void:
	var alpha_viewport := SubViewport.new()
	alpha_viewport.size = Vector2i(320, 300)
	alpha_viewport.transparent_bg = true
	alpha_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(alpha_viewport)
	var effects: WorldEffects = _corpse_effect(alpha_viewport, Vector2(160, 200), 2.0, false)
	var grounded: Image = await _capture(alpha_viewport)
	effects.simulation.corpses[0].carried = true
	effects.queue_redraw()
	var carried: Image = await _capture(alpha_viewport)
	var opaque: int = 0
	var faded: int = 0
	for y: int in range(grounded.get_height()):
		for x: int in range(grounded.get_width()):
			if grounded.get_pixel(x, y).a > 0.99:
				opaque += 1
				if absf(carried.get_pixel(x, y).a - 0.65) < 0.012:
					faded += 1
	expect(opaque > 100, "WorldEffects draws the actual soldier corpse with opaque interior pixels")
	expect(faded > opaque * 0.95, "The rendered carried corpse retains 65 percent opacity")
	alpha_viewport.free()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("28282a")
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	_label(viewport, "IRON & INK / STATIC ASSETS", Vector2(38, 25), 26)
	_label(viewport, "Fixed world scale / transparent exports / preserved ground anchors", Vector2(38, 67), 17)
	var spawner: ActorView = load("res://scenes/actors/spawner.tscn").instantiate() as ActorView
	viewport.add_child(spawner)
	spawner.apply_state({}, false, false)
	spawner.position = Vector2(335, 520)
	spawner.scale = Vector2.ONE * 2.2
	_label(viewport, "SPAWNER", Vector2(260, 124), 22)
	_corpse_effect(viewport, Vector2(955, 340), 3.0, false)
	_corpse_effect(viewport, Vector2(955, 605), 3.0, true)
	_label(viewport, "SOLDIER / SPENT MATTER", Vector2(790, 192), 22)
	_label(viewport, "CARRIED / 65% OPACITY", Vector2(790, 457), 22)
	var review: Image = await _capture(viewport)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-artifacts"))
	expect(review.save_png("res://test-artifacts/static-art-review.png") == OK, "Static art review capture is saved")
	viewport.free()
