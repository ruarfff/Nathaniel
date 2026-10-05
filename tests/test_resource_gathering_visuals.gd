extends SceneTree
## Mechanical cargo ownership, linked arms, and contained intake heat.

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
	var player: ActorView = load("res://scenes/actors/nathaniel.tscn").instantiate()
	var hermes: HermesView = load("res://scenes/actors/hermes.tscn").instantiate()
	root.add_child(player)
	root.add_child(hermes)
	var nathaniel: Dictionary = {"position": Vector2(200, 200), "hp": 100, "resource_capacity": 3, "aim_direction": Vector2.RIGHT, "moving": false}
	var receiver: Dictionary = {"position": Vector2(240, 200), "hp": 100, "anchored": false, "furnace_remaining": 0.0}
	player.apply_state(nathaniel, false, false)
	hermes.apply_state(receiver, false, false)
	if player.model_view == null:
		expect(false, "The gathering test needs imported actor resources")
		player.free()
		hermes.free()
		quit(1)
		return
	var rig: ResourceGatheringView = player.model_view.gathering_view
	expect(rig != null and rig.backpack != null and rig.active_bundle != null, "Nathaniel loads the authored backpack and shell bundle")
	expect(hermes.gathering_model().gathering_view != null, "Mobile Hermes has a live intake")
	if rig == null or hermes.gathering_model().gathering_view == null:
		quit(1)
		return
	var corpse: Dictionary = {"id": 1, "position": Vector2(220, 200), "pickup_position": Vector2(220, 200), "phase": "grab", "phase_elapsed": 0.2, "cargo_slot": 0, "carried": false, "source_kind": "soldier"}
	var cargo: Array = [corpse]
	corpse.phase = "crush"
	corpse.carried = true
	corpse.disarmed = true
	corpse.phase_elapsed = 0.01
	_sync(player, hermes, cargo, nathaniel, receiver)
	expect(rig._contact_material != null and rig._contact_material.albedo_color.a > 0.8, "Successful grip lights an existing clamp contact pad")
	corpse.phase_elapsed = 0.2
	_sync(player, hermes, cargo, nathaniel, receiver)
	expect(rig._contact_material.albedo_color.a == 0.0, "The disarm contact glint ends before loading completes")
	var muzzle: Vector2 = player.weapon_muzzle(Vector2.RIGHT, "rifle")
	for phase: String in ["grab", "crush", "carry", "present", "feed"]:
		corpse.phase = phase
		corpse.phase_elapsed = BattlefieldRules.phase_seconds(phase) * 0.5
		corpse.carried = phase != "grab"
		for index: int in range(8):
			nathaniel.aim_direction = Vector2.from_angle(TAU * index / 8.0)
			player.apply_state(nathaniel, false, false)
			_sync(player, hermes, cargo, nathaniel, receiver)
			expect(player.model_view.z_index == (1 if phase in ["present", "feed"] else 0), "Held matter remains visible above the receiver until intake handoff")
			expect(ResourceGatheringView.ground_visible(corpse) == (phase == "grab"), "Only an ungripped body remains on the ground in " + phase)
			expect(rig.active_bundle.visible == (phase in ["crush", "present", "feed"]), "The held shell has one owner in " + phase)
			_check_links(player.model_view, phase)
			expect(player.weapon_muzzle(Vector2.RIGHT, "rifle").distance_to(muzzle) < 0.0001, "Backpack motion leaves the rifle muzzle unchanged")
			var wrist: Node3D = player.model_view.model_root.find_child("GatherWristLeft", true, false)
			var pose: Transform3D = wrist.global_transform
			player.model_view._process(0.4)
			expect(wrist.global_transform.is_equal_approx(pose), "Pause freezes the handling pose")
	corpse.phase = "feed"
	corpse.phase_elapsed = GameBalance.RESOURCE_FEED_SECONDS * 0.84
	for anchored: bool in [false, true]:
		receiver.anchored = anchored
		hermes.apply_state(receiver, false, true)
		hermes._process(HermesView.DEPLOY_SECONDS)
		hermes.apply_state(receiver, false, false)
		_sync(player, hermes, cargo, nathaniel, receiver)
		var furnace: ResourceGatheringView = hermes.gathering_model().gathering_view
		expect(furnace != null and furnace.intake_bundle != null, "Both Hermes forms have authored intake matter")
		expect(not rig.active_bundle.visible and furnace.intake_bundle.visible, "The intake takes visual ownership after the clamps release")
		receiver.furnace_remaining = GameBalance.RESOURCE_FURNACE_SECONDS * 0.5
		_sync(player, hermes, [], nathaniel, receiver)
		expect(not furnace.intake_bundle.visible, "Accepted matter disappears before the furnace pulse")
		var glow: MeshInstance3D = hermes.gathering_model().model_root.find_child("FurnaceGlow", true, false)
		var material: StandardMaterial3D = glow.material_override
		expect(material.albedo_color.r > 0.8 and material.albedo_color.g > 0.3 and material.albedo_color.b < 0.5, "Furnace heat is a contained amber surface")
		receiver.furnace_remaining = 0.0
		_sync(player, hermes, [], nathaniel, receiver)
		expect(material.albedo_color.r < 0.2, "The intake returns to dark after the pulse")
	for capacity: int in range(1, 4):
		nathaniel.resource_capacity = capacity
		cargo.clear()
		for slot: int in capacity:
			cargo.append({"phase": "carry", "carried": true, "cargo_slot": slot})
		_sync(player, hermes, cargo, nathaniel, receiver)
		for slot: int in range(1, 4):
			var rack: Node3D = player.model_view.model_root.find_child("CargoRack%d" % slot, true, false)
			var bundle: Node3D = player.model_view.model_root.find_child("CargoBundle%d" % slot, true, false)
			expect(rack.visible == (slot <= capacity) and bundle.visible == (slot <= capacity), "Each capacity upgrade exposes one occupied rack slot")
	nathaniel.hp = 0
	hermes.sync_intake([], nathaniel, receiver)
	for model: ActorModelView in [hermes.model_view, hermes.mobile_model_view]:
		expect(not model.gathering_view.intake_bundle.visible, "Death clears received matter in both forms without a Nathaniel view")
	player.free()
	hermes.free()
	_check_self_destruct()
	if "--render" in OS.get_cmdline_user_args():
		await _check_rendered()
		await _check_self_destruct_rendered()
	print("Resource gathering visuals: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_links(model: ActorModelView, phase: String) -> void:
	if phase == "carry":
		return
	for suffix: String in ["Left", "Right"]:
		var upper: Node3D = model.model_root.find_child("GatherUpper" + suffix, true, false)
		var elbow: Node3D = model.model_root.find_child("GatherElbow" + suffix, true, false)
		var forearm: Node3D = model.model_root.find_child("GatherForearm" + suffix, true, false)
		var extension: Node3D = model.model_root.find_child("GatherExtension" + suffix, true, false)
		var wrist: Node3D = model.model_root.find_child("GatherWrist" + suffix, true, false)
		expect(upper.to_global(Vector3.UP * 0.36).distance_to(elbow.global_position) < 0.0001, "Upper rigid link ends at the elbow in " + phase)
		expect(upper.global_basis.y.length() > 0.9999 and upper.global_basis.y.length() < 1.0001, "The upper link keeps its rigid length")
		expect((extension if extension != null else forearm).to_global(Vector3.UP * 0.36).distance_to(wrist.global_position) < 0.0001, "Telescoping link ends at the clamp wrist in " + phase)


func _sync(player: ActorView, hermes: HermesView, cargo: Array, state: Dictionary, receiver: Dictionary) -> void:
	player.sync_gathering(cargo, state, receiver, hermes)
	hermes.sync_intake(cargo, state, receiver)


func _check_rendered() -> void:
	if DisplayServer.get_name() == "headless":
		expect(false, "Gathering image checks need a graphical display")
		return
	DirAccess.make_dir_recursive_absolute("res://test-artifacts")
	var output := SubViewport.new()
	output.size = Vector2i(640, 480)
	output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(output)
	var player: ActorView = load("res://scenes/actors/nathaniel.tscn").instantiate()
	var hermes: HermesView = load("res://scenes/actors/hermes.tscn").instantiate()
	output.add_child(player)
	output.add_child(hermes)
	var state: Dictionary = {"position": Vector2(350, 50), "hp": 100, "resource_capacity": 3, "moving": false}
	var receiver: Dictionary = {"position": Vector2(390, 50), "hp": 100, "anchored": false}
	var cargo: Array = [{"phase": "carry", "carried": true, "cargo_slot": 0}, {"phase": "carry", "carried": true, "cargo_slot": 1}, {"phase": "carry", "carried": true, "cargo_slot": 2}]
	for direction: int in range(8):
		state.aim_direction = Vector2.from_angle(TAU * direction / 8.0)
		player.apply_state(state, false, false)
		hermes.apply_state(receiver, false, false)
		_sync(player, hermes, cargo, state, receiver)
		await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = player.model_view.viewport.get_texture().get_image()
		var used: Rect2i = image.get_used_rect()
		expect(used.has_area() and used.position.x > 0 and used.position.y > 0 and used.end.x < image.get_width() and used.end.y < image.get_height(), "Full capacity fits the render canvas in heading %d" % direction)
		image.save_png("res://test-artifacts/gathering-capacity-heading-%d.png" % direction)
	for phase: String in ["grab", "feed"]:
		for direction: int in range(8):
			var heading: Vector2 = Vector2.from_angle(TAU * direction / 8.0)
			state.aim_direction = heading
			receiver.position = Vector2(state.position) + heading * GameBalance.RESOURCE_DELIVERY_REACH
			var matter: Dictionary = {"phase": phase, "phase_elapsed": BattlefieldRules.phase_seconds(phase) * (0.98 if phase == "grab" else ResourceGatheringView.FEED_HANDOFF - 0.001),
				"carried": phase == "feed", "cargo_slot": 0, "pickup_position": Vector2(state.position) + heading * 76.0}
			player.apply_state(state, false, false)
			hermes.apply_state(receiver, false, false)
			_sync(player, hermes, [matter], state, receiver)
			await process_frame
			await RenderingServer.frame_post_draw
			await process_frame
			await RenderingServer.frame_post_draw
			var image: Image = player.model_view.viewport.get_texture().get_image()
			var used: Rect2i = image.get_used_rect()
			expect(used.has_area() and used.position.x > 0 and used.position.y > 0 and used.end.x < image.get_width() and used.end.y < image.get_height(), "%s at full reach fits the canvas in heading %d" % [phase, direction])
			if phase == "feed":
				var carrier_model: ActorModelView = player.model_view
				var receiver_model: ActorModelView = hermes.gathering_model()
				var held_point: Vector2 = _screen_point(carrier_model, carrier_model.gathering_view.active_bundle.global_position) + player.position
				var intake_point: Vector2 = _screen_point(receiver_model, receiver_model.gathering_view.intake.global_position) + hermes.position
				expect(held_point.distance_to(intake_point) < 0.1, "The held bundle meets the visible intake across actor viewports")
			image.save_png("res://test-artifacts/gathering-%s-heading-%d.png" % [phase, direction])
	var intake_heights: Array[float] = []
	for anchored: bool in [false, true]:
		receiver.anchored = anchored
		hermes.apply_state(receiver, false, true)
		hermes._process(HermesView.DEPLOY_SECONDS)
		hermes.apply_state(receiver, false, false)
		var model: ActorModelView = hermes.gathering_model()
		intake_heights.append(model.gathering_view.intake.global_position.y)
		var images: Array[Image] = []
		for remaining: float in [0.0, GameBalance.RESOURCE_FURNACE_SECONDS * 0.5]:
			receiver.furnace_remaining = remaining
			_sync(player, hermes, [], state, receiver)
			await process_frame
			await RenderingServer.frame_post_draw
			await process_frame
			await RenderingServer.frame_post_draw
			images.append(model.viewport.get_texture().get_image())
		var changed: int = 0
		for y: int in images[0].get_height():
			for x: int in images[0].get_width():
				var before: Color = images[0].get_pixel(x, y)
				var after: Color = images[1].get_pixel(x, y)
				if after.r > before.r + 0.08 and after.g > before.g + 0.02:
					changed += 1
		expect(changed >= 5 and changed < 400, "The %s furnace visibly heats a small contained area" % ("deployed" if anchored else "mobile"))
		images[1].save_png("res://test-artifacts/gathering-furnace-%s.png" % ("deployed" if anchored else "mobile"))
	expect(intake_heights[0] > intake_heights[1] + 0.3, "Deployed delivery follows the lower chest intake")
	output.free()
	await process_frame


func _screen_point(model: ActorModelView, point: Vector3) -> Vector2:
	var canvas: Vector2i = model.model_root.get_meta("logical_canvas")
	var density: float = float(model.viewport.size.x) / canvas.x
	return model.camera.unproject_position(point) / density - Vector2(model.model_root.get_meta("logical_ground_anchor"))


func _effects_game() -> GameSimulation:
	var sim := GameSimulation.new()
	sim.configure({"number": 1, "width": 64, "height": 64, "tile_size": 32, "blocked": [],
		"player_start": Vector2(300, 300), "hermes_start": Vector2(600, 300), "enemies": [], "wave_based": false})
	return sim


func _check_self_destruct() -> void:
	var effects: WorldEffects = load("res://scenes/effects/world_effects.tscn").instantiate()
	var sim: GameSimulation = _effects_game()
	effects.simulation = sim
	effects.fog_enabled = false
	root.add_child(effects)
	effects.set_process(false)
	var corpse: Dictionary = sim.spawn_resource(10, Vector2.ZERO, 3.001)
	expect(effects.corpse_warning_strength(corpse) == 0.0, "The intact body stays quiet before its final three seconds")
	corpse.expiration = 2.875
	expect(effects.corpse_warning_strength(corpse) > 0.99, "The warning peaks after the first soft rise")
	var next: Dictionary = sim.spawn_resource(10, Vector2(100, 100), 2.625, false, "gunSoldier")
	effects.add_events([])
	var sprite: Sprite2D = effects.get_node("Corpse%d" % corpse.id)
	var other: Sprite2D = effects.get_node("Corpse%d" % next.id)
	expect(sprite.texture != other.texture and float(sprite.material.get_shader_parameter("warning")) > 0.99 and float(other.material.get_shader_parameter("warning")) == 0.0, "Each corpse keeps its source art and independent deadline")
	sim.set_paused(true)
	effects._process(0.4)
	expect(float(sprite.material.get_shader_parameter("warning")) > 0.99, "Pause freezes warning brightness")
	corpse.disarmed = true
	corpse.expiration = 0.1
	effects.add_events([])
	expect(float(sprite.material.get_shader_parameter("warning")) == 0.0, "A disarmed loose body never warns, even with an old expiry value")
	sim.set_paused(false)
	next.expiration = 0.1
	sim.step(0.2)
	effects.add_events(sim.take_events())
	expect(sim.corpses.size() == 1 and effects.corpse_dissolves.size() == 1, "Resource loss retains only a presentation dissolve")
	expect(is_equal_approx(float(effects.corpse_dissolves[0].age), 0.1), "The visual tail includes time already simulated after expiry")
	expect(effects.transients.is_empty(), "Self-destruct does not add an explosion ring")
	sim.set_paused(true)
	effects._process(0.4)
	expect(is_equal_approx(float(effects.corpse_dissolves[0].age), 0.1), "Pause freezes dissolution")
	sim.set_paused(false)
	effects._process(0.5)
	expect(effects.corpse_dissolves.is_empty(), "Dissolution ends after six tenths of a second")
	effects.add_events([{"type": "corpse_expired", "corpse_id": 999, "position": Vector2.ZERO, "elapsed_since_expiry": 1.0}])
	expect(effects.corpse_dissolves.is_empty(), "A large simulation step cannot resurrect an old dissolve")
	effects.add_events([{"type": "corpse_expired", "corpse_id": 999, "position": Vector2.ZERO}])
	effects.simulation = _effects_game()
	expect(effects.corpse_dissolves.is_empty() and effects._corpse_sprites.is_empty(), "Loading another simulation clears every old corpse effect")
	effects.free()


func _check_self_destruct_rendered() -> void:
	var output := SubViewport.new()
	output.size = Vector2i(256, 160)
	output.transparent_bg = true
	output.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(output)
	var effects: WorldEffects = load("res://scenes/effects/world_effects.tscn").instantiate()
	effects.simulation = _effects_game()
	effects.fog_enabled = false
	effects.position = Vector2(128, 105)
	output.add_child(effects)
	effects.set_process(false)
	var corpse: Dictionary = effects.simulation.spawn_resource(10, Vector2.ZERO, 4.0)
	var images: Array[Image] = []
	for state: String in ["armed", "warning", "disarmed", "dissolve"]:
		corpse.expiration = 2.875 if state in ["warning", "disarmed"] else 4.0
		corpse.disarmed = state == "disarmed"
		if state == "dissolve":
			effects.simulation.corpses.clear()
			effects.add_events([{"type": "corpse_expired", "corpse_id": corpse.id, "position": corpse.position, "elapsed_since_expiry": 0.4}])
		effects._process(0.0)
		await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = output.get_texture().get_image()
		images.append(image)
		image.save_png("res://test-artifacts/corpse-self-destruct-%s.png" % state)
	effects.simulation.corpses.append(corpse)
	corpse.disarmed = false
	corpse.expiration = 4.0
	effects.corpse_dissolves.clear()
	effects._process(0.0)
	var sprite: Sprite2D = effects.get_node("Corpse%d" % corpse.id)
	sprite.material = null
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var authored: Image = output.get_texture().get_image()
	var brightened: int = 0
	var dissolved: int = 0
	var silhouette_changed: int = 0
	var armed_changed: int = 0
	for y: int in output.size.y:
		for x: int in output.size.x:
			var armed: Color = images[0].get_pixel(x, y)
			var warning: Color = images[1].get_pixel(x, y)
			var disarmed: Color = images[2].get_pixel(x, y)
			var dissolved_color: Color = images[3].get_pixel(x, y)
			var raw: Color = authored.get_pixel(x, y)
			if absf(armed.r - raw.r) > 0.01 or absf(armed.g - raw.g) > 0.01 or absf(armed.b - raw.b) > 0.01 or absf(armed.a - raw.a) > 0.01:
				armed_changed += 1
			if armed.a > 0.5 and warning.g > armed.g + 0.05 and warning.g > disarmed.g + 0.05:
				brightened += 1
			if absf(armed.a - warning.a) > 0.01:
				silhouette_changed += 1
			if armed.a > 0.5 and dissolved_color.a < 0.1:
				dissolved += 1
	expect(armed_changed == 0, "The armed shader preserves the authored corpse texture and opacity")
	expect(brightened > 100 and silhouette_changed == 0, "Warning brightens shell and seams without blinking away the silhouette")
	expect(dissolved > 100 and dissolved < 2000, "Dissolution removes coarse portions of the body before its final fade")
	output.free()
	await process_frame
