extends SceneTree
## Native clip playback and the generated character resource contract.

const KINDS: Array[String] = ["nathaniel", "hermes", "grunt", "soldier", "boss"]

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
	await _check_playback()
	if "--unit" not in OS.get_cmdline_user_args():
		var kinds: Array[String] = KINDS
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--asset="):
				kinds = [argument.trim_prefix("--asset=")]
		for kind: String in kinds:
			_check_resource(kind)
		if "--render" in OS.get_cmdline_user_args():
			if DisplayServer.get_name() == "headless":
				expect(false, "Rendered animation checks need a graphical display")
			else:
				await _check_rendered()
	print("Animated art checks: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _fixture() -> ActorView:
	var visual := ActorVisual.new()
	visual.pixels_per_world_pixel = 8.0
	visual.ground_anchor = Vector2(16, 24)
	visual.animations = SpriteFrames.new()
	visual.animations.remove_animation(&"default")
	for direction: int in range(8):
		for mode: String in ["idle", "walk", "fire"]:
			var clip: StringName = StringName("%s_%d" % [mode, direction])
			visual.animations.add_animation(clip)
			visual.animations.set_animation_speed(clip, 20.0)
			visual.animations.set_animation_loop(clip, mode != "fire")
			for frame: int in range(4 if mode == "walk" else 2):
				var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
				image.fill(Color.from_hsv(float(direction) / 8.0, 0.8, 0.4 + float(frame) * 0.15))
				visual.animations.add_frame(clip, ImageTexture.create_from_image(image), 2.0 if mode == "walk" and frame == 1 else 1.0)
	var actor := ActorView.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	actor.add_child(sprite)
	actor.visual = visual
	root.add_child(actor)
	return actor


func _check_playback() -> void:
	var actor: ActorView = _fixture()
	expect(actor.animation_sprite != null and actor.animation_sprite.visible and not actor.sprite.visible, "An animation-only resource uses Godot playback without an old PNG")
	for direction: int in range(8):
		var heading: Vector2 = Vector2.RIGHT.rotated(float(direction) * PI / 4.0)
		actor.apply_state({"facing": heading, "moving": true}, false, false)
		expect(actor.animation_sprite.animation == StringName("walk_%d" % direction), "Logical heading %d selects its walk clip" % direction)
		actor.apply_state({"facing": heading, "moving": false}, false, false)
		expect(actor.animation_sprite.animation == StringName("idle_%d" % direction), "Logical heading %d selects its idle clip" % direction)
		var contact: Vector2 = actor.animation_sprite.position + (actor.visual.ground_anchor - Vector2(16, 16)) * actor.animation_sprite.scale
		expect(contact.is_zero_approx(), "Direction changes preserve the source ground anchor")
	actor.apply_state({"position": Vector2.ZERO, "moving": false}, false, false)
	actor.apply_state({"position": Vector2(0, 10)}, false, false)
	expect(actor.animation_sprite.animation == &"walk_2", "Motion without an explicit facing uses logical world direction")
	await process_frame
	await process_frame
	actor.animation_sprite.stop()
	actor.apply_state({"facing": Vector2.RIGHT, "moving": true}, false, true)
	await create_timer(0.075).timeout
	expect(actor.animation_sprite.frame == 1, "Native playback advances to the second walk frame (frame %d, progress %.3f)" % [actor.animation_sprite.frame, actor.animation_sprite.frame_progress])
	await create_timer(0.04).timeout
	expect(actor.animation_sprite.frame == 1, "SpriteFrames frame duration controls the held walk frame (frame %d, progress %.3f)" % [actor.animation_sprite.frame, actor.animation_sprite.frame_progress])
	var walk_frame: int = actor.animation_sprite.frame
	var walk_progress: float = actor.animation_sprite.frame_progress
	actor.apply_state({"facing": Vector2.DOWN, "moving": true}, false, true)
	expect(actor.animation_sprite.animation == &"walk_2" and actor.animation_sprite.frame == walk_frame and is_equal_approx(actor.animation_sprite.frame_progress, walk_progress), "Turning preserves the gait phase")
	actor.apply_state({"facing": Vector2.RIGHT, "moving": true}, false, true)
	actor.notify_attack()
	actor.apply_state({"facing": Vector2.RIGHT, "moving": true}, false, true)
	expect(actor.animation_sprite.animation == &"fire_0", "A shot has presentation priority over movement")
	actor.animation_sprite.set_frame_and_progress(1, 0.5)
	actor.apply_state({"facing": Vector2.DOWN, "moving": true}, false, true)
	expect(actor.animation_sprite.animation == &"fire_2" and actor.animation_sprite.frame == 1 and is_equal_approx(actor.animation_sprite.frame_progress, 0.5), "Turning does not restart or extend a shot")
	actor.apply_state({"facing": Vector2.RIGHT, "moving": true}, false, true)
	actor.notify_attack()
	expect(actor.animation_sprite.frame == 0 and is_zero_approx(actor.animation_sprite.frame_progress), "A repeated shot restarts the fire clip")
	await create_timer(0.14).timeout
	expect(actor.animation_sprite.animation == &"walk_0", "One-shot completion restores the current movement clip")
	actor.visual.animations.set_animation_loop(&"fire_0", true)
	actor.notify_attack()
	await create_timer(0.14).timeout
	expect(actor.animation_sprite.animation == &"walk_0", "A manual looping fire clip still recovers after one attack cycle")
	actor.visual.animations.set_animation_loop(&"fire_0", false)
	actor.notify_attack()
	actor.notify_respawn()
	expect(actor.animation_sprite.animation == &"idle_0", "Respawn clears an attack that started before death")
	actor.apply_state({"facing": Vector2.UP, "moving": false, "firing": true}, false, true)
	await create_timer(0.24).timeout
	expect(actor.animation_sprite.animation == &"fire_6" and actor.animation_sprite.is_playing(), "Continuous firing repeats its native fire clip")
	actor.apply_state({"facing": Vector2.UP, "moving": false, "firing": false}, false, true)
	expect(actor.animation_sprite.animation == &"idle_6", "A completed beam returns to idle")
	actor.notify_attack()
	actor.apply_state({"facing": Vector2.UP, "moving": false}, false, false)
	var frozen_frame: int = actor.animation_sprite.frame
	var frozen_progress: float = actor.animation_sprite.frame_progress
	await create_timer(0.14).timeout
	expect(actor.animation_sprite.frame == frozen_frame and is_equal_approx(actor.animation_sprite.frame_progress, frozen_progress), "Paused presentation freezes frame and progress")
	actor.apply_state({"facing": Vector2.UP, "moving": false}, false, true)
	await create_timer(0.14).timeout
	expect(actor.animation_sprite.animation == &"idle_6", "Resume completes the paused attack")
	actor.visual.animations.remove_animation(&"walk_7")
	actor.apply_state({"facing": Vector2(1, -1), "moving": true}, false, false)
	expect(actor.animation_sprite.animation == &"idle_7", "A missing movement clip falls back to the same direction idle")
	actor.visual.animations.remove_animation(&"idle_7")
	actor.apply_state({"facing": Vector2(1, -1), "moving": true}, false, false)
	expect(actor.animation_sprite.animation == &"idle_0", "An incomplete resource falls back to its default idle")
	actor.visual.animations.set_meta("ground_anchor", Vector2(11, 29))
	actor.visual.animations.set_meta("pixels_per_world_pixel", 4.0)
	actor.apply_state({"moving": false}, false, false)
	expect(actor.animation_sprite.scale == Vector2.ONE / 4.0, "Regenerated SpriteFrames metadata overrides stale visual density")
	var contact: Vector2 = actor.animation_sprite.position + (Vector2(11, 29) - Vector2(16, 16)) * actor.animation_sprite.scale
	expect(contact.is_zero_approx(), "A changed export crop preserves ground contact without editing ActorVisual")
	actor.visual.animations.remove_meta("ground_anchor")
	actor.visual.animations.remove_meta("pixels_per_world_pixel")
	actor.apply_state({"moving": false}, false, false)
	expect(actor.animation_sprite.scale == Vector2.ONE / 8.0 and actor.visual.frame_ground_anchor() == Vector2(16, 24), "Manual SpriteFrames without metadata use the visual's explicit scale and anchor")
	var legacy := ActorVisual.new()
	legacy.texture = load("res://assets/Sprites/Characters/nathanielspritesheet.png")
	legacy.columns = 8
	legacy.rows = 2
	actor.visual = legacy
	actor.apply_state({"facing": Vector2.RIGHT, "moving": true}, false, false)
	expect(actor.sprite.visible and not actor.animation_sprite.visible, "Replacing the visual with a legacy PNG disables animated rendering")
	expect((actor.sprite.region_rect.size * actor.sprite.scale).is_equal_approx(legacy.display_size), "Legacy sizing survives animated-to-static replacement")
	actor.free()


func _actor(kind: String, parent: Node) -> ActorView:
	var actor: ActorView = load("res://scenes/actors/%s.tscn" % kind).instantiate() as ActorView
	parent.add_child(actor)
	actor.apply_state({"moving": false}, false, false)
	return actor


func _check_resource(kind: String) -> void:
	var actor: ActorView = _actor(kind, root)
	if actor.visual != null and actor.visual.model_scene != null:
		# Keep checking the retained PNG clips as an explicit fallback. Live model
		# aiming and gait have their own checks in test_nathaniel_weapons.gd.
		var fallback: ActorVisual = actor.visual.duplicate() as ActorVisual
		fallback.model_scene = null
		actor.visual = fallback
	expect(actor.visual != null, kind + " visual resource loads")
	if actor.visual == null:
		actor.free()
		return
	var frames: SpriteFrames = actor.visual.animations
	expect(frames != null, kind + " uses its generated SpriteFrames")
	if frames == null:
		actor.free()
		return
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/%s.json" % kind))
	var canvas: Vector2 = Vector2(metadata.canvas[0], metadata.canvas[1])
	expect(actor.visual.frame_ground_anchor() == Vector2(metadata.anchor[0], metadata.anchor[1]), kind + " uses the exported common anchor")
	expect(actor.visual.frame_pixel_density() == 8.0 and metadata.render_density == 8, kind + " retains 8 pixels per world pixel")
	expect(actor.animation_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, kind + " uses smooth mipmap sampling")
	for direction: int in range(8):
		for mode: String in ["idle", "walk", "fire"]:
			var clip: StringName = StringName("%s_%d" % [mode, direction])
			expect(frames.has_animation(clip), kind + " includes " + clip)
			if not frames.has_animation(clip):
				continue
			expect(frames.get_frame_count(clip) >= (4 if mode == "walk" else 2 if mode == "fire" else 1), kind + " has sampled frames for " + clip)
			expect(frames.get_animation_loop(clip) == (mode != "fire"), kind + " has the correct loop mode for " + clip)
			for frame: int in range(frames.get_frame_count(clip)):
				var texture: Texture2D = frames.get_frame_texture(clip, frame)
				expect(texture != null and texture.get_size() == canvas, kind + " frames share one cropped canvas")
				if texture is AtlasTexture:
					expect(texture.atlas.get_width() <= 4096 and texture.atlas.get_height() <= 4096, kind + " atlas pages stay within 4096 pixels")
			actor.apply_state({"facing": Vector2.RIGHT.rotated(float(direction) * PI / 4.0), "moving": mode == "walk", "firing": mode == "fire"}, false, false)
			var contact: Vector2 = actor.animation_sprite.position + (actor.visual.frame_ground_anchor() - canvas / 2.0) * actor.animation_sprite.scale
			expect(contact.is_equal_approx(actor.visual.feet_offset), kind + " anchors remain fixed across directions and actions")
	actor.free()


func _capture(viewport: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _check_rendered() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1200, 650)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("4b463c")
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	var actors := Node2D.new()
	actors.y_sort_enabled = true
	viewport.add_child(actors)
	var towers: Array[ActorView] = []
	var people: Array[ActorView] = []
	for index: int in range(10):
		var tower: ActorView = _actor("gun_tower", actors)
		tower.position = Vector2(120 + (index % 5) * 240, 280 + (index / 5) * 310)
		tower.scale = Vector2.ONE * 2.0
		towers.append(tower)
		var person: ActorView = _actor(KINDS[index % 5], actors)
		person.position = tower.position + Vector2(3, -12 if index < 5 else 12)
		person.scale = Vector2.ONE * 2.0
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
	for index: int in range(10):
		var expected: Image = tower_image if index < 5 else person_image
		var other: Image = person_image if index < 5 else tower_image
		var area: Rect2i = Rect2i(Vector2i(towers[index].position) - Vector2i(95, 180), Vector2i(190, 210))
		var count: int = _matching_overlap(combined, expected, other, background_image, area)
		expect(count > 30, "%s visibly sorts %s its tower (%d pixels)" % [KINDS[index % 5], "behind" if index < 5 else "in front of", count])
	viewport.free()


func _matching_overlap(combined: Image, expected: Image, other: Image, background: Image, area: Rect2i) -> int:
	var count: int = 0
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var first: Color = expected.get_pixel(x, y)
			var second: Color = other.get_pixel(x, y)
			var base: Color = background.get_pixel(x, y)
			if _difference(first, base) < 0.08 or _difference(second, base) < 0.08 or _difference(first, second) < 0.08:
				continue
			if _difference(combined.get_pixel(x, y), first) < 0.01:
				count += 1
	return count


func _difference(first: Color, second: Color) -> float:
	return maxf(absf(first.r - second.r), maxf(absf(first.g - second.g), absf(first.b - second.b)))
