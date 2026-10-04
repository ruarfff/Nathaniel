extends SceneTree
## Checks HD art in the real actor views. --render also checks visible occlusion.

const KINDS: Array[String] = ["gun_tower", "laser_tower", "heal_tower"]

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
	for kind: String in KINDS:
		_check_tower(kind)
	_check_legacy()
	_check_crop()
	if "--render" in OS.get_cmdline_user_args():
		if DisplayServer.get_name() == "headless":
			expect(false, "Rendered HD checks need a graphical display; omit --headless")
		else:
			await _check_rendered()
	print("HD art checks: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _actor(kind: String, parent: Node = null) -> ActorView:
	if parent == null:
		parent = root
	var actor: ActorView = load("res://scenes/actors/%s.tscn" % kind).instantiate() as ActorView
	parent.add_child(actor)
	return actor


func _check_tower(kind: String) -> void:
	var actor: ActorView = _actor(kind)
	var image: Image = actor.visual.texture.get_image()
	expect(image.get_size() == Vector2i(1024, 1024), kind + " retains its full-resolution source")
	expect(image.has_mipmaps(), kind + " has mipmaps for small on-screen sizes")
	expect(image.detect_alpha() != Image.ALPHA_NONE and image.get_pixel(0, 0).a == 0.0, kind + " has a transparent canvas")
	var bounds: Rect2i = image.get_used_rect()
	expect(bounds.has_area() and bounds.position.x > 0 and bounds.position.y > 0 and bounds.end.x < 1024 and bounds.end.y < 1024, kind + " artwork fits inside the export canvas")
	expect(actor.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, kind + " uses smooth sampling")
	if actor.model_view != null:
		var model: ActorModelView = actor.model_view
		var contact: Vector2 = model.camera.unproject_position(Vector3.ZERO) * model.display.scale + model.display.position - Vector2(model.viewport.size) * model.display.scale / 2.0
		expect(model.display.scale.is_equal_approx(Vector2.ONE), kind + " starts at native display density")
		expect(contact.length() < 0.0001, kind + " grounds the live model origin at the actor feet: " + str(contact))
		expect(model.find_children("*", "CollisionObject3D", true, false).is_empty(), kind + " artwork adds no gameplay footprint")
	else:
		expect(actor.sprite.scale.is_equal_approx(Vector2.ONE / 8.0), kind + " preserves shared scale")
		var contact: Vector2 = actor.sprite.position + (actor.visual.ground_anchor - actor.sprite.region_rect.size / 2.0) * actor.sprite.scale
		expect(contact.is_equal_approx(Vector2.ZERO), kind + " grounds the model origin at the actor feet")
		expect(actor.find_children("*", "CollisionObject2D", true, false).is_empty(), kind + " artwork adds no gameplay footprint")
	var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/%s.json" % kind))
	expect(metadata is Dictionary and metadata.get("canvas") == [1024.0, 1024.0], kind + " metadata records the canvas")
	expect(metadata is Dictionary and metadata.get("anchor") == [512.0, 768.0], kind + " metadata records ground contact")
	expect(metadata is Dictionary and metadata.get("render_density") == 8.0, kind + " metadata records shared density")
	var import_config := ConfigFile.new()
	expect(import_config.load("res://assets/generated/%s.png.import" % kind) == OK, kind + " import settings are present")
	expect(import_config.get_value("params", "compress/mode") == 0 and import_config.get_value("params", "process/size_limit") == 0, kind + " imports losslessly at full size")
	expect(import_config.get_value("params", "process/fix_alpha_border") == true and import_config.get_value("params", "process/premult_alpha") == false, kind + " retains clean straight-alpha edges")
	var base_size: Vector2 = Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	var screen_scale: float = minf(3840.0 / base_size.x, 2160.0 / base_size.y) * 2.0
	expect(actor.visual.pixels_per_world_pixel >= screen_scale, kind + " has enough source pixels for 4K at maximum 2x zoom")
	actor.free()


func _check_legacy() -> void:
	var actor: ActorView = _actor("nathaniel")
	var legacy := ActorVisual.new()
	legacy.texture = load("res://assets/Sprites/Characters/nathanielspritesheet.png")
	legacy.columns = 8
	legacy.rows = 2
	legacy.display_size = Vector2(48, 72)
	actor.visual = legacy
	actor.apply_state({"position": Vector2(100, 80), "facing": Vector2(1, 0), "moving": true})
	expect(actor.sprite.visible, "PNG-only legacy resources still render")
	expect((actor.sprite.region_rect.size * actor.sprite.scale).is_equal_approx(legacy.display_size), "Legacy sheets keep their original display dimensions")
	expect((actor.sprite.position + Vector2(0, legacy.display_size.y / 2.0)).is_equal_approx(legacy.feet_offset), "Legacy sheets keep their bottom-center anchor")
	actor.free()


func _check_crop() -> void:
	var actor: ActorView = _actor("gun_tower")
	var visual: ActorVisual = actor.visual.duplicate() as ActorVisual
	visual.model_scene = null
	visual.feet_offset = Vector2(3, -2)
	actor.visual = visual
	var sample: Vector2 = Vector2(550, 650)
	var before: Vector2 = actor.sprite.position + (sample - actor.sprite.region_rect.size / 2.0) * actor.sprite.scale
	var crop: Rect2i = Rect2i(200, 100, 700, 850)
	visual.texture = ImageTexture.create_from_image(visual.texture.get_image().get_region(crop))
	visual.ground_anchor -= Vector2(crop.position)
	visual.display_size = Vector2(90, 90)
	actor.visual = visual
	var after: Vector2 = actor.sprite.position + (sample - Vector2(crop.position) - actor.sprite.region_rect.size / 2.0) * actor.sprite.scale
	expect(before.is_equal_approx(after), "Changing canvas bounds and adjusting the anchor preserves every retained pixel's world position")
	expect(actor.sprite.scale.is_equal_approx(Vector2.ONE / 8.0), "HD scale is independent of canvas and health-bar bounds")
	actor.free()


func _capture(viewport: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _check_rendered() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(840, 320)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("49433a")
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	var actors := Node2D.new()
	actors.y_sort_enabled = true
	viewport.add_child(actors)
	var towers: Array[ActorView] = []
	var people: Array[ActorView] = []
	for index: int in range(6):
		var tower: ActorView = _actor(KINDS[index / 2], actors)
		tower.position = Vector2(140 + (index % 3) * 280, 145 + (index / 3) * 155)
		tower.scale = Vector2.ONE * 1.8
		towers.append(tower)
		var person: ActorView = _actor("nathaniel", actors)
		person.apply_state({}, false, false)
		person.position = tower.position + Vector2(5, -14 if index % 2 == 0 else 14)
		person.scale = Vector2.ONE * 1.8
		people.append(person)
	var combined: Image = await _capture(viewport)
	for person: ActorView in people:
		person.hide()
	var tower_image: Image = await _capture(viewport)
	for tower: ActorView in towers:
		tower.hide()
	var background_image: Image = await _capture(viewport)
	for person: ActorView in people:
		person.show()
	var person_image: Image = await _capture(viewport)
	for index: int in range(6):
		var expected: Image = tower_image if index % 2 == 0 else person_image
		var other: Image = person_image if index % 2 == 0 else tower_image
		var area: Rect2i = Rect2i(Vector2i(towers[index].position) - Vector2i(80, 120), Vector2i(160, 140))
		var count: int = _matching_overlap(combined, expected, other, background_image, area)
		expect(count > 30, "%s visibly sorts %s Nathaniel (%d pixels)" % [KINDS[index / 2], "in front of" if index % 2 == 0 else "behind", count])
	viewport.free()


func _matching_overlap(combined: Image, expected: Image, other: Image, background: Image, area: Rect2i) -> int:
	var count: int = 0
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var first: Color = expected.get_pixel(x, y)
			var second: Color = other.get_pixel(x, y)
			var base: Color = background.get_pixel(x, y)
			if _difference(first, base) < 0.12 or _difference(second, base) < 0.12 or _difference(first, second) < 0.12:
				continue
			if _difference(combined.get_pixel(x, y), first) < 0.01:
				count += 1
	return count


func _difference(first: Color, second: Color) -> float:
	return maxf(absf(first.r - second.r), maxf(absf(first.g - second.g), absf(first.b - second.b)))
