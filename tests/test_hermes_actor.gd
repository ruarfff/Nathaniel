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
	check(actor.animation_sprite.visible and not actor.model_view.visible, "Mobile Hermes uses his walking art")
	check(not actor.weapon_muzzle(Vector2.RIGHT).is_finite(), "Mobile Hermes has no deployed cannon muzzle")
	state.anchored = true
	actor.apply_state(state)
	actor._process(HermesView.DEPLOY_SECONDS * 0.5)
	check(actor.model_view.visible and actor.animation_sprite.visible, "Deployment blends the walking silhouette into the folded body")
	var body: Node3D = actor.model_view.model_root.find_child("DeployBody", true, false) as Node3D
	var halfway: Transform3D = body.transform
	var amount: float = actor._deployment_amount
	actor.apply_state(state, false, false)
	actor._process(1.0)
	check(actor._deployment_amount == amount and body.transform == halfway, "Pause freezes the folding pose")
	actor.apply_state(state)
	actor._process(HermesView.DEPLOY_SECONDS)
	check(actor.model_view.visible and not actor.animation_sprite.visible and actor._deployment_amount == 1.0, "Anchored Hermes has one deployed silhouette")
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
	check(actor.animation_sprite.visible and not model.visible, "Following folds the base back into mobile Hermes")
	actor.free()
	var restored: HermesView = load("res://scenes/actors/hermes.tscn").instantiate() as HermesView
	root.add_child(restored)
	state.anchored = true
	restored.apply_state(state, false, false)
	check(restored._deployment_amount == 1.0 and restored.model_view.visible and not restored.animation_sprite.visible, "Loading an anchored state restores the complete base without replaying deployment")
	restored.free()
	print("Hermes actor checks: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


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
