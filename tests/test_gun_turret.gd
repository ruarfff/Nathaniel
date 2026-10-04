extends SceneTree
## Live turret aiming, authored marker projection, and retained viewport rendering.

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
	var actor: ActorView = load("res://scenes/actors/gun_tower.tscn").instantiate() as ActorView
	(root if parent == null else parent).add_child(actor)
	actor.position = Vector2(180, 180)
	return actor


func _run() -> void:
	_check_projection_and_aim()
	_check_playback()
	_check_density_and_visibility()
	_check_legacy_and_resource_change()
	if "--render" in OS.get_cmdline_user_args():
		if DisplayServer.get_name() == "headless":
			expect(false, "Rendered turret checks require a graphical display")
		else:
			await _check_rendered()
			await _check_4k_viewport()
	print("Gun turret checks: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_projection_and_aim() -> void:
	var actor: ActorView = _actor()
	var model: ActorModelView = actor.model_view
	expect(model != null and not actor.sprite.visible, "The gun tower uses its live model")
	expect(model.viewport.own_world_3d, "Each turret has an independent lighting and depth world")
	var origin: Vector2 = model.camera.unproject_position(Vector3.ZERO)
	expect(origin.is_equal_approx(Vector2(64, 96)), "The generated camera keeps the original ground anchor")
	expect((model.camera.unproject_position(Vector3(0, 0, -1)) - origin).is_equal_approx(IsoProjection.project(Vector2(32, 0))), "The camera projects logical +X onto the 64x32 grid")
	expect((model.camera.unproject_position(Vector3(1, 0, 0)) - origin).is_equal_approx(IsoProjection.project(Vector2(0, 32))), "The camera projects logical +Y onto the 64x32 grid")
	var base_transforms: Dictionary[Node3D, Transform3D] = {}
	for child: Node in model.aim_pivot.get_parent().get_children():
		if child is Node3D and child != model.aim_pivot:
			base_transforms[child as Node3D] = child.transform
	for heading: Vector2 in [Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN, Vector2(1, 0.37), Vector2(-0.23, -1), Vector2(-0.9, 0.63)]:
		actor.apply_state({"position": Vector2.ZERO, "facing": heading})
		var barrel: Vector3 = model.aim_pivot.global_basis.x.normalized()
		var projected: Vector2 = model.camera.unproject_position(model.muzzle.global_position + barrel) - model.camera.unproject_position(model.muzzle.global_position)
		expect(projected.normalized().dot(IsoProjection.project(heading).normalized()) > 0.99999, "The actual barrel points along arbitrary logical heading " + str(heading))
		var marker: Vector2 = model.camera.unproject_position(model.muzzle.global_position) - origin
		expect(actor.weapon_muzzle(heading).distance_to(marker) < 0.0001, "A shot starts at the authored barrel marker for " + str(heading))
	for base: Node3D in base_transforms:
		expect(base.transform.is_equal_approx(base_transforms[base]), "Aiming preserves base transform " + base.name)
	var displayed: Transform3D = model.aim_pivot.transform
	var muzzle_a: Vector2 = actor.weapon_muzzle(Vector2.RIGHT)
	var muzzle_b: Vector2 = actor.weapon_muzzle(Vector2.UP)
	expect(muzzle_a.distance_to(muzzle_b) > 10.0, "Each launch heading has a different projected muzzle")
	expect(model.aim_pivot.transform.is_equal_approx(displayed), "Queries for old projectiles preserve the displayed aim")
	actor.free()


func _check_playback() -> void:
	var actor: ActorView = _actor()
	var model: ActorModelView = actor.model_view
	var rest: Transform3D = model.recoil.transform
	actor.notify_attack(Vector2(0.33, -1))
	expect(model.recoil.transform.is_equal_approx(rest), "The barrel starts at the emission point before recoil")
	model._process(0.025)
	expect(not model.recoil.transform.is_equal_approx(rest), "A firing event moves the barrel for recoil")
	var launch: Vector2 = actor.weapon_muzzle(Vector2(0.33, -1))
	actor.apply_state({"position": Vector2(180, 180), "facing": Vector2(0.33, -1)}, false, false)
	var paused: Transform3D = model.recoil.transform
	model._process(0.1)
	expect(model.recoil.transform.is_equal_approx(paused), "Pause freezes recoil")
	expect(actor.weapon_muzzle(Vector2(0.33, -1)).is_equal_approx(launch), "The launch marker excludes later barrel recoil")
	actor.apply_state({"position": Vector2(180, 180)}, false, true)
	model._process(0.2)
	expect(model.recoil.transform.is_equal_approx(rest), "Recoil returns to the authored pose")
	actor.notify_attack(Vector2.LEFT)
	actor.notify_respawn()
	expect(model.recoil.transform.is_equal_approx(rest), "Respawn resets an interrupted recoil")
	actor.free()


func _check_density_and_visibility() -> void:
	# Headless root windows can have a different stretch scale. An explicit
	# render target keeps this actor-scale check independent of the display.
	var output := SubViewport.new()
	output.size = Vector2i(1280, 800)
	root.add_child(output)
	var actor: ActorView = _actor(output)
	var model: ActorModelView = actor.model_view
	actor.scale = Vector2.ONE * 5.4
	model._process(0.0)
	expect(model.viewport.size == Vector2i(768, 768), "4K with close zoom has six source pixels per logical point")
	var origin: Vector2 = model.camera.unproject_position(Vector3.ZERO) * model.display.scale + model.display.position - Vector2(model.viewport.size) * model.display.scale / 2.0
	expect(origin.length() < 0.0001, "Changing render density preserves ground contact")
	actor.scale = Vector2.ONE * 20.0
	model._process(0.0)
	expect(model.viewport.size == Vector2i(1024, 1024), "Per-actor texture size is capped at eight pixels per logical point")
	actor.hide()
	model._process(0.0)
	expect(model.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Hidden actors do not render their 3D viewport")
	actor.show()
	actor.position = Vector2(-100000, -100000)
	model._process(0.0)
	expect(model.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Off-screen actors do not render their 3D viewport")
	output.free()


func _check_legacy_and_resource_change() -> void:
	var actor: ActorView = _actor()
	var original: ActorVisual = actor.visual
	var png: ActorVisual = original.duplicate() as ActorVisual
	png.model_scene = null
	actor.visual = png
	expect(actor.sprite.visible and not actor.model_view.visible, "PNG-only resources remain usable")
	expect(not actor.weapon_muzzle(Vector2.RIGHT).is_finite(), "PNG-only art reports that it has no authored muzzle")
	actor.visual = original
	expect(actor.model_view.visible and not actor.sprite.visible, "Restoring the model resource restores the model view")
	actor.free()


func _check_rendered() -> void:
	var actor: ActorView = _actor()
	var model: ActorModelView = actor.model_view
	actor.scale = Vector2.ONE * 3.0
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = model.viewport.get_texture().get_image()
	expect(image != null and image.get_used_rect().has_area(), "The live 3D model produces visible pixels")
	expect(image.get_pixel(0, 0).a == 0.0, "The viewport background is transparent")
	var bounds: Rect2i = image.get_used_rect()
	expect(bounds.position.x > 0 and bounds.position.y > 0 and bounds.end.x < image.get_width() and bounds.end.y < image.get_height(), "The authored model stays inside its transparent canvas")
	await process_frame
	await RenderingServer.frame_post_draw
	expect(model.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "An idle turret retains its texture without rerendering")
	var before: PackedByteArray = image.get_data()
	actor.notify_attack(Vector2.LEFT)
	await process_frame
	await RenderingServer.frame_post_draw
	image = model.viewport.get_texture().get_image()
	expect(image.get_data() != before, "Turning the turret updates the rendered pixels")
	actor.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	expect(model.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Hidden recoil does not keep the viewport active")
	actor.free()


func _check_4k_viewport() -> void:
	var output := SubViewport.new()
	output.size = Vector2i(3840, 2160)
	output.size_2d_override = Vector2i(1280, 720)
	output.size_2d_override_stretch = true
	output.gui_embed_subwindows = true
	output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(output)
	var camera := Camera2D.new()
	camera.position = Vector2(180, 180)
	camera.zoom = Vector2.ONE * 2.0
	output.add_child(camera)
	camera.make_current()
	camera.force_update_scroll()
	var actor: ActorView = _actor(output)
	var muzzle: Vector2 = actor.weapon_muzzle(Vector2(0.83, 0.37))
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	expect(output.get_texture().get_image().get_size() == Vector2i(3840, 2160), "The 4K check renders into a real 3840x2160 target without desktop window limits")
	expect(actor.model_view.viewport.size == Vector2i(768, 768), "4K viewport stretch and 2x camera zoom select six source pixels per logical point")
	expect(actor.weapon_muzzle(Vector2(0.83, 0.37)).distance_to(muzzle) < 0.0001, "4K stretch and camera zoom preserve the local muzzle anchor")
	var projected: Transform2D = output.get_final_transform() * actor.get_global_transform_with_canvas()
	expect((projected * Vector2.ZERO).distance_to(Vector2(1920, 1080)) < 0.001, "The actor ground origin stays at the 4K camera center")
	output.size = Vector2i(1920, 1080)
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	expect(actor.model_view.viewport.size == Vector2i(384, 384), "Changing the output resolution updates model density without changing camera zoom")
	expect(actor.weapon_muzzle(Vector2(0.83, 0.37)).distance_to(muzzle) < 0.0001, "Resizing the output preserves the muzzle anchor")
	output.free()
