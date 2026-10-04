extends SceneTree
## Continuous character aim, independent gait, and reusable weapon appearance.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _actor(parent: Node = null) -> ActorView:
	var actor: ActorView = load("res://scenes/actors/nathaniel.tscn").instantiate()
	(root if parent == null else parent).add_child(actor)
	actor.model_view.set_process(false)
	actor.apply_state({"position": Vector2(200, 200), "aim_direction": Vector2.RIGHT,
		"equipped_weapon_id": "rifle", "moving": false}, false, true)
	return actor


func _run() -> void:
	_check_aim_and_switch()
	_check_movement_and_pause()
	_check_fallback()
	if "--render" in OS.get_cmdline_user_args():
		if DisplayServer.get_name() == "headless":
			expect(false, "Rendered character checks require a graphical display")
		else:
			await _check_rendered()
	print("Nathaniel weapon art: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_aim_and_switch() -> void:
	var actor: ActorView = _actor()
	var model: ActorModelView = actor.model_view
	expect(model != null and model.visible and not actor.sprite.visible, "Nathaniel selects the live character model")
	expect(model.weapon_id == "rifle", "The character defaults to the service rifle")
	expect(model.viewport.find_children("*", "Camera3D", true, false).size() == 1, "Character and attached weapon share one camera and render target")
	var anchor: Vector2 = model.model_root.get_meta("logical_ground_anchor")
	var origin: Vector2 = model.camera.unproject_position(Vector3.ZERO)
	expect(origin.distance_to(anchor) < 0.0001, "Live character preserves the authored ground anchor")
	expect((model.camera.unproject_position(Vector3(0, 0, -1)) - origin).distance_to(Vector2(32, 16)) < 0.0001, "Character uses the same 64x32 world projection")
	for id: String in ["rifle", "heavy_rifle"]:
		for direction: Vector2 in [Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN, Vector2(0.71, -0.29)]:
			actor.apply_state({"position": Vector2(200, 200), "facing": Vector2.LEFT,
				"aim_direction": direction, "equipped_weapon_id": id}, false, true)
			var barrel: Vector3 = model.muzzle.global_basis.x.normalized()
			var projected: Vector2 = model.camera.unproject_position(model.muzzle.global_position + barrel) - model.camera.unproject_position(model.muzzle.global_position)
			expect(projected.normalized().dot(IsoProjection.project(direction).normalized()) > 0.99999, id + " barrel uses authoritative aim rather than movement facing")
			var actual: Vector2 = model.camera.unproject_position(model.muzzle.global_position) - anchor
			expect(actor.weapon_muzzle(direction, id).distance_to(actual) < 0.0001, id + " muzzle query reaches the visible barrel opening")
	var direction := Vector2(0.83, 0.37).normalized()
	var rifle: Vector2 = actor.weapon_muzzle(direction, "rifle")
	var heavy: Vector2 = actor.weapon_muzzle(direction, "heavy_rifle")
	expect(rifle.distance_to(heavy) > 2.0, "Different barrel lengths produce different muzzle offsets")
	actor.notify_attack(direction, "heavy_rifle")
	model._process(0.025)
	var aim_before: Transform3D = model.aim_pivot.transform
	var recoil_before: Transform3D = model.recoil.transform
	expect(actor.weapon_muzzle(direction, "rifle").distance_to(rifle) < 0.0001, "A rifle shot retains its launch muzzle after switching to the heavy rifle")
	expect(model.weapon_id == "heavy_rifle" and model.aim_pivot.transform == aim_before and model.recoil.transform == recoil_before, "Old-shot muzzle queries do not change current equipment, aim, or recoil")
	actor.notify_attack(Vector2.LEFT, "rifle")
	expect(model.aim_pivot.transform == aim_before and model.recoil.transform == recoil_before, "A delayed old-weapon firing event cannot recoil or steer the equipped weapon")
	expect(not actor.weapon_muzzle(direction, "missing_weapon").is_finite(), "Unknown weapon art reports an unavailable muzzle")
	expect(not model.equip_weapon("missing_weapon") and model.weapon_id == "heavy_rifle", "Unknown equipment leaves the current model intact")
	var other: ActorView = _actor()
	expect(other.model_view.weapon_id == "rifle" and other.model_view.viewport.find_world_3d() != model.viewport.find_world_3d(), "Equipment state and 3D worlds are per actor")
	expect(other.visual == actor.visual and actor.visual.default_weapon_id == "rifle", "Switching leaves the shared authoring resource unchanged")
	other.free()
	actor.free()


func _check_movement_and_pause() -> void:
	var actor: ActorView = _actor()
	var model: ActorModelView = actor.model_view
	expect(model.locomotion_pivot != null and model.animation_player != null, "Character provides separate locomotion and authored gait")
	var hip: Node3D = model.model_root.find_child("LeftHip", true, false)
	var idle: Transform3D = hip.transform
	var upper: Vector3 = model.aim_pivot.global_position
	var muzzle: Vector2 = actor.weapon_muzzle(Vector2.RIGHT, "rifle")
	actor.apply_state({"position": Vector2(200, 205), "moving": true,
		"aim_direction": Vector2.RIGHT, "equipped_weapon_id": "rifle"}, false, true)
	model._process(0.125)
	expect(not hip.transform.is_equal_approx(idle), "Authored leg motion plays while moving across the aim direction")
	expect(model.aim_pivot.global_position.distance_to(upper) < 0.0001 and actor.weapon_muzzle(Vector2.RIGHT, "rifle").distance_to(muzzle) < 0.0001, "Walking leaves the upper-body height and firing anchor stable")
	var body_forward: Vector3 = model.locomotion_pivot.basis.x
	var body_yaw: float = atan2(-body_forward.z, body_forward.x)
	expect(absf(wrapf(body_yaw - PI / 2.0, -PI, PI)) <= PI / 3.0 + 0.0001, "Strafing keeps the lower body within sixty degrees of the aim")
	actor.notify_attack(Vector2.RIGHT, "rifle")
	model._process(0.025)
	var hands: Node3D = model.model_root.find_child("WeaponHands", true, false)
	expect(absf(hands.position.x + 0.025) < 0.0001, "Both gripping hands follow the rifle recoil")
	actor.apply_state({"position": Vector2(200, 205), "moving": true, "aim_direction": Vector2.RIGHT}, false, false)
	var paused_hip: Transform3D = hip.transform
	var paused_recoil: Transform3D = model.recoil.transform
	model._process(0.5)
	expect(hip.transform.is_equal_approx(paused_hip) and model.recoil.transform.is_equal_approx(paused_recoil), "Pause freezes gait and weapon recoil")
	actor.apply_state({"position": Vector2(200, 205), "moving": true, "aim_direction": Vector2.RIGHT}, false, true)
	model._process(0.2)
	expect(hands.position.length() < 0.0001, "Recoil finishes before the next rifle shot")
	actor.notify_attack(Vector2.RIGHT, "rifle")
	model._process(0.025)
	actor.apply_state({"position": Vector2(200, 205), "moving": true,
		"aim_direction": Vector2.RIGHT, "equipped_weapon_id": "heavy_rifle"}, false, true)
	expect(hands.position.length() < 0.0001 and model.weapon_id == "heavy_rifle", "Switching weapons clears the previous recoil while keeping the shared grip")
	for phase: int in range(4):
		model.set_aim(Vector2.from_angle(float(phase) * 0.8))
		model._process(0.125)
		expect(actor.weapon_muzzle(Vector2.RIGHT, "rifle").distance_to(muzzle) < 0.0001, "Saved rifle shot keeps its launch point through changed aim, weapon, and gait phase %d" % phase)
	actor.notify_respawn()
	expect(hip.transform.is_equal_approx(idle) and hands.position.length() < 0.0001, "Respawn resets gait and recoil without changing equipped art")
	actor.free()


func _check_fallback() -> void:
	var actor: ActorView = _actor()
	var source: ActorVisual = actor.visual
	var fallback: ActorVisual = source.duplicate()
	fallback.model_scene = null
	actor.visual = fallback
	actor.apply_state({"moving": true, "facing": Vector2.RIGHT}, false, false)
	expect(actor.animation_sprite != null and actor.animation_sprite.visible and not actor.model_view.visible, "Existing Nathaniel PNG frames remain a usable fallback")
	expect(source.model_scene != null and source.animations != null, "Fallback selection does not alter the shared live character resource")
	actor.free()


func _check_rendered() -> void:
	DirAccess.make_dir_recursive_absolute("res://test-artifacts")
	var output := SubViewport.new()
	output.size = Vector2i(3840, 2160)
	output.size_2d_override = Vector2i(1280, 720)
	output.size_2d_override_stretch = true
	output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(output)
	var actor: ActorView = _actor(output)
	actor.position = Vector2(640, 500)
	actor.scale = Vector2.ONE * 2.0
	actor.model_view.set_process(true)
	var model: ActorModelView = actor.model_view
	for id: String in ["rifle", "heavy_rifle"]:
		model.equip_weapon(id)
		for direction: Vector2 in [Vector2(0.83, 0.37), Vector2(-0.83, -0.37)]:
			model.set_aim(direction)
			await process_frame
			await RenderingServer.frame_post_draw
			await process_frame
			await RenderingServer.frame_post_draw
			var image: Image = model.viewport.get_texture().get_image()
			var used: Rect2i = image.get_used_rect()
			expect(used.has_area() and used.position.x > 0 and used.position.y > 0 and used.end.x < image.get_width() and used.end.y < image.get_height(), id + " fits the live canvas from front and rear")
			expect(image.get_pixel(0, 0).a == 0.0, id + " retains transparent viewport borders")
			image.save_png("res://test-artifacts/nathaniel-%s-%s.png" % [id, "front" if direction.x > 0.0 else "rear"])
	var canvas: Vector2i = model.model_root.get_meta("logical_canvas")
	expect(model.viewport.size == canvas * 6, "A real 4K output with close zoom renders the character at six pixels per logical point")
	expect(output.get_texture().get_image().get_size() == Vector2i(3840, 2160), "The graphical character check uses a true 4K render target")
	output.free()
	await _capture_gait()


func _capture_gait() -> void:
	var output := SubViewport.new()
	output.size = Vector2i(3840, 2160)
	output.size_2d_override = Vector2i(1280, 720)
	output.size_2d_override_stretch = true
	output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(output)
	var background := ColorRect.new()
	background.color = Color("49433a")
	background.size = Vector2(1280, 720)
	output.add_child(background)
	var aim := Vector2(0.83, 0.37).normalized()
	var labels: Array[String] = ["Forward", "Strafe", "Backpedal"]
	var headings: Array[Vector2] = [aim, aim.orthogonal(), -aim]
	for row: int in range(3):
		var label := Label.new()
		label.text = labels[row] + " - four gait phases; fixed aim"
		label.position = Vector2(30, 10 + row * 235)
		label.add_theme_font_size_override("font_size", 20)
		output.add_child(label)
		for phase: int in range(4):
			var actor: ActorView = _actor(output)
			actor.position = Vector2(170 + phase * 305, 220 + row * 235)
			actor.scale = Vector2.ONE * 2.0
			actor.model_view.set_aim(aim)
			actor.model_view.set_movement(headings[row], 70.0)
			actor.model_view._process(float(phase) * 0.125)
	await process_frame
	await RenderingServer.frame_post_draw
	output.get_texture().get_image().save_png("res://test-artifacts/nathaniel-gait-4k.png")
	output.free()
