extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var actor: HermesView = load("res://scenes/actors/hermes.tscn").instantiate() as HermesView
	root.add_child(actor)
	var state := {"position": Vector2(160, 160), "facing": Vector2.RIGHT, "anchored": false}
	actor.apply_state(state)
	check(actor.mobile_model_view.visible and not actor.model_view.visible and not actor.animation_sprite.visible, "Mobile Hermes uses one live walking model")
	check(not actor.weapon_muzzle(Vector2.RIGHT).is_finite(), "Mobile Hermes has no deployed cannon muzzle")
	_check_mobile_laser(actor, state)
	if "--render" in OS.get_cmdline_user_args():
		await _capture_mobile(actor)
		await _capture_angles(actor)
	state.anchored = true
	actor.apply_state(state)
	check(not actor.laser_muzzle().is_finite(), "Deployment disables the shoulder emitter immediately")
	actor._process(HermesView.DEPLOY_SECONDS * 0.5)
	check(actor.model_view.visible and actor.mobile_model_view.visible, "Deployment blends the walking silhouette into the folded body")
	var body: Node3D = actor.model_view.model_root.find_child("DeployBody", true, false) as Node3D
	var halfway: Transform3D = body.transform
	var amount: float = actor._deployment_amount
	actor.apply_state(state, false, false)
	actor._process(1.0)
	check(actor._deployment_amount == amount and body.transform == halfway, "Pause freezes the folding pose")
	actor.apply_state(state)
	actor._process(HermesView.DEPLOY_SECONDS)
	check(actor.model_view.visible and not actor.mobile_model_view.visible and actor._deployment_amount == 1.0, "Anchored Hermes has one deployed silhouette")
	var deployed_body: Transform3D = body.transform
	check(deployed_body.origin.y < halfway.origin.y, "The torso lowers as Hermes anchors")
	for part_name: String in HermesView.ANCHOR_NAMES:
		var anchor: Node3D = actor.model_view.model_root.find_child(part_name, true, false) as Node3D
		check(anchor != null and anchor.scale.is_equal_approx(Vector3.ONE), "Stabilizer opens at ground contact: " + part_name)
	var model: ActorModelView = actor.model_view
	for direction: Vector2 in [Vector2.RIGHT, Vector2.UP, Vector2(-0.8, 0.3)]:
		state.facing = direction
		actor.apply_state(state)
		var marker: Vector2 = model.camera.unproject_position(model.muzzle.global_position) - Vector2(64, 96)
		check(actor.weapon_muzzle(direction).is_equal_approx(marker), "Hermes fires from his actual cannon muzzle")
		check(body.transform == deployed_body, "The cannon turns independently of the planted body")
	actor.notify_attack(Vector2.UP)
	model._process(0.025)
	check(not model.recoil.transform.is_equal_approx(model._recoil_rest), "The deployed cannon recoils")
	if "--render" in OS.get_cmdline_user_args():
		await _capture(actor)
	state.anchored = false
	actor.apply_state(state)
	actor._process(HermesView.DEPLOY_SECONDS)
	check(actor.mobile_model_view.visible and not model.visible and actor.laser_muzzle().is_finite(), "Following folds the base back into mobile Hermes and restores the shoulder emitter")
	state.hp = 0
	actor.apply_state(state)
	check(not actor.laser_muzzle().is_finite(), "Dead Hermes has no active laser emitter")
	actor.free()
	var paused_mobile: HermesView = load("res://scenes/actors/hermes.tscn").instantiate() as HermesView
	root.add_child(paused_mobile)
	paused_mobile.apply_state({"position": Vector2(80, 80), "facing": Vector2.UP, "moving": false, "anchored": false}, false, false)
	var body_forward: Vector3 = (paused_mobile.mobile_model_view.locomotion_pivot.global_basis * Vector3.FORWARD).normalized()
	check(body_forward.dot(Vector3.LEFT) > 0.99999, "A stationary paused load applies its body facing before any render process")
	paused_mobile.free()
	var restored: HermesView = load("res://scenes/actors/hermes.tscn").instantiate() as HermesView
	root.add_child(restored)
	state.anchored = true
	state.hp = 1
	restored.apply_state(state, false, false)
	check(restored._deployment_amount == 1.0 and restored.model_view.visible and not restored.mobile_model_view.visible, "Loading an anchored state restores the complete base without replaying deployment")
	restored.free()
	print("Hermes actor checks: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_mobile_laser(actor: HermesView, state: Dictionary) -> void:
	var model: ActorModelView = actor.mobile_model_view
	check(model.pitch_pivot != null and model.locomotion_pivot != null and model.animation_player != null, "The mobile rig has independent aiming and authored walking controls")
	var initial_cannon: Transform3D = actor.model_view.recoil.transform
	var initial_recoil: Transform3D = model.recoil.transform
	var head: MeshInstance3D
	for part: Node in model.model_root.find_children("*", "MeshInstance3D", true, false):
		if String(part.name).to_lower().replace("_", " ") == "square sensor head":
			head = part as MeshInstance3D
	check(head != null, "Hermes retains his original sensor head geometry")
	for body_index: int in 8:
		var body_direction := Vector2.from_angle(body_index * PI / 4.0)
		model.set_movement(body_direction, 70.0)
		model._process(0.04)
		var walking_body: Transform3D = model.locomotion_pivot.transform
		for target_index: int in 8:
			for distance: float in [60.0, 90.0, 180.0]:
				var offset := Vector2.from_angle(target_index * PI / 4.0) * distance
				actor.aim_laser(offset, 24.0)
				var target: Vector3 = model.model_root.to_global(Vector3(offset.y, 24.0, -offset.x) / 32.0)
				var forward: Vector3 = model.muzzle.global_basis.x.normalized()
				check(forward.dot(model.muzzle.global_position.direction_to(target)) > 0.99999, "Shoulder aperture points at contact for body %d, target %d, distance %.0f" % [body_index, target_index, distance])
				check(model.locomotion_pivot.transform.is_equal_approx(walking_body), "Aiming keeps the walking body direction for body %d and target %d" % [body_index, target_index])
				var projected: Vector2 = model.camera.unproject_position(model.muzzle.global_position) / model._density - model._anchor + actor.visual.feet_offset
				check(actor.laser_muzzle().is_equal_approx(projected), "The laser origin uses the live aperture for body %d and target %d" % [body_index, target_index])
				var contact: Vector2 = model.camera.unproject_position(target) / model._density - model._anchor
				check(contact.distance_to(IsoProjection.project(offset) - Vector2(0.0, 24.0 * sqrt(1.5))) < 0.001, "The target height uses the world projection")
				if head != null:
					var head_hit: Variant = head.get_aabb().intersects_segment(head.to_local(model.muzzle.global_position), head.to_local(target))
					check(head_hit == null, "The beam clears Hermes's head for body %d, target %d, distance %.0f" % [body_index, target_index, distance])
		var fixed_target := Vector2(160.0, 60.0)
		actor.aim_laser(fixed_target, 24.0)
		for frame: int in 5:
			model._process(0.055)
			var target := Vector3(fixed_target.y, 24.0, -fixed_target.x) / 32.0
			check(model.muzzle.global_basis.x.normalized().dot(model.muzzle.global_position.direction_to(model.model_root.to_global(target))) > 0.99999, "The aperture keeps contact through walk frame %d" % frame)
	actor.notify_attack(Vector2.LEFT)
	check(actor.model_view.recoil.transform == initial_cannon and model.recoil.transform == initial_recoil, "The mobile laser does not recoil either cannon or pod")
	state.moving = true
	actor.apply_state(state, false, false)
	var paused_muzzle: Transform3D = model.muzzle.global_transform
	var paused_time: float = model._walk_time
	actor.apply_state(state, false, false)
	model._process(0.5)
	check(model._walk_time == paused_time and model.muzzle.global_transform.is_equal_approx(paused_muzzle), "Repeated paused state updates freeze the mobile walk and shoulder pose")
	state.moving = false
	actor.apply_state(state)
	actor.aim_laser(Vector2(180, 20), 24.0)
	check(actor.laser_muzzle().is_finite(), "Following Hermes keeps his shoulder laser while standing still")
	var logical_muzzle: Vector2 = actor.laser_muzzle()
	for density: float in [1.0, 2.0, 4.0, 8.0]:
		model._resize(density)
		check(actor.laser_muzzle().distance_to(logical_muzzle) < 0.001, "Changing model resolution preserves the logical muzzle at density %.0f" % density)
		var target: Vector3 = model.model_root.to_global(Vector3(20.0, 24.0, -180.0) / 32.0)
		var contact: Vector2 = model.camera.unproject_position(target) / density - model._anchor
		check(contact.distance_to(IsoProjection.project(Vector2(180, 20)) - Vector2(0, 24.0 * sqrt(1.5))) < 0.001, "Target projection stays aligned at density %.0f" % density)
	model._resize(1.0)


func _capture_mobile(actor: HermesView) -> void:
	actor.scale = Vector2.ONE * 5.0
	actor.position = Vector2(640, 520)
	actor.mobile_model_view.set_movement(Vector2.RIGHT, 0.0)
	actor.aim_laser(Vector2(180, 20), 24.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var output: Image = actor.mobile_model_view.viewport.get_texture().get_image()
	check(output != null and output.get_used_rect().has_area(), "The mobile Hermes model renders visible pixels")
	if output != null:
		var bounds: Rect2i = output.get_used_rect()
		check(bounds.position.x > 0 and bounds.position.y > 0 and bounds.end.x < output.get_width() and bounds.end.y < output.get_height(), "The shoulder pod fits inside the model canvas")
		DirAccess.make_dir_recursive_absolute("res://test-artifacts")
		output.save_png("res://test-artifacts/hermes-mobile.png")


func _capture_angles(actor: HermesView) -> void:
	actor.scale = Vector2.ONE * 3.0
	var model: ActorModelView = actor.mobile_model_view
	var sheet: Image
	for index: int in 8:
		var heading: float = index * PI / 4.0
		model.set_movement(Vector2.from_angle(heading), 70.0)
		actor.aim_laser(Vector2.from_angle(heading + PI / 3.0) * 180.0, 24.0)
		model._process(0.055)
		await process_frame
		await RenderingServer.frame_post_draw
		var frame: Image = model.viewport.get_texture().get_image()
		check(frame != null and frame.get_used_rect().has_area(), "The shoulder pod renders at body heading %d" % index)
		if frame == null:
			continue
		var bounds: Rect2i = frame.get_used_rect()
		check(bounds.position.x > 0 and bounds.position.y > 0 and bounds.end.x < frame.get_width() and bounds.end.y < frame.get_height(), "The full walking model stays inside the canvas at heading %d" % index)
		if sheet == null:
			sheet = Image.create(frame.get_width() * 4, frame.get_height() * 2, false, frame.get_format())
			sheet.fill(Color("ddd4be"))
		sheet.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i(index % 4, index / 4) * frame.get_size())
	if sheet != null:
		sheet.save_png("res://test-artifacts/hermes-shoulder-angles.png")


func _capture(actor: HermesView) -> void:
	actor.scale = Vector2.ONE * 5.0
	actor.position = Vector2(640, 520)
	actor.model_view.reset_pose()
	actor.model_view.set_aim(Vector2.RIGHT)
	await process_frame
	await RenderingServer.frame_post_draw
	var output: Image = actor.model_view.viewport.get_texture().get_image()
	check(output != null and output.get_used_rect().has_area(), "The deployed Hermes model renders visible pixels")
	if output != null:
		var bounds: Rect2i = output.get_used_rect()
		check(bounds.position.x > 0 and bounds.position.y > 0 and bounds.end.x < output.get_width() and bounds.end.y < output.get_height(), "Hermes fits inside the model canvas")
		DirAccess.make_dir_recursive_absolute("res://test-artifacts")
		output.save_png("res://test-artifacts/hermes-anchor.png")
