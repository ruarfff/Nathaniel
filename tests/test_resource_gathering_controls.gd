extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func advance(app: GameApp, seconds: float) -> void:
	for frame: int in range(int(ceil(seconds * 60.0))):
		app._physics_process(1.0 / 60.0)


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var app: GameApp = load("res://scenes/main.tscn").instantiate()
	app.storage_root = "/private/tmp/nathaniel-gathering-controls-%d/" % Time.get_ticks_usec()
	root.add_child(app)
	app.set_physics_process(false)
	# Campaign saves retain this synthetic open-ground control fixture.
	app.load_level(1)
	app.sim.configure({"number": 1, "width": 64, "height": 64, "tile_size": 32,
		"blocked": [], "player_start": Vector2(640, 640), "hermes_start": Vector2(900, 640),
		"enemies": [], "wave_based": false, "starting_resources": 100})
	app.fog.enabled = false
	app.sim.set_hermes_mode("stopped")
	app._physics_process(0.0)
	await process_frame
	expect(not app.sim.nathaniel.has_corpse, "Empty backpack disables delivery")
	expect(app.ui.get_node("%Nathaniel").status == "Cargo 0/1", "HUD separates cargo capacity from spendable resources")
	expect(not app.ui.buttons.upgrade_capacity.is_visible_in_tree(), "Backpack upgrades share the closed Build tray")
	app.command("build")
	expect(app.ui.buttons.upgrade_capacity.is_visible_in_tree(), "Build exposes backpack upgrades")
	app.ui.buttons.upgrade_capacity.pressed.emit()
	expect(app.sim.nathaniel.resource_capacity == 2 and app.sim.resources == 80, "Cargo button buys one slot for its displayed cost")
	app.ui.buttons.upgrade_reach.pressed.emit()
	expect(app.sim.nathaniel.resource_reach == 60.0 and app.sim.resources == 65, "Reach button extends arms without consuming another slot")
	app.command("pause")
	app.command("upgrade_gathering", "capacity")
	expect(app.sim.nathaniel.resource_capacity == 2 and app.sim.resources == 65, "A modal prevents upgrade input")
	app.command("resume")
	app.sim.spawn_resource(10, app.sim.nathaniel.position, 10.0, false, "gunSoldier")
	advance(app, 0.9)
	expect(app.sim.nathaniel.has_corpse and app.sim.nathaniel.has_corpse, "Completed collection enables delivery")
	expect(app.sim.resources == 65 and app.ui.get_node("%Nathaniel").status == "Cargo 1/2", "Carried matter stays separate from the wallet")
	var gathering: Dictionary = GameDebugBridge.new(app).state().gathering
	expect(gathering.cargoCount == 1 and gathering.capacity == 2 and gathering.reach == 60.0 and gathering.phase == "carry", "Debug state reports cargo and upgrades without crediting delivery")
	app.command("save_slot", 1)
	app.command("load_slot", 1)
	expect(app.sim.nathaniel.resource_capacity == 2 and app.sim.nathaniel.resource_reach == 60.0, "Save/load keeps both purchased upgrades")
	expect(app.sim.corpses.size() == 1 and app.sim.corpses[0].source_kind == "gunSoldier" and app.sim.corpses[0].carried, "Save/load keeps the carried body's identity and ownership")
	app.command("follow")
	app._update_camera(1.0, true)
	var click := app.world_to_screen(app.sim.hermes.position) - Vector2(0, 20 * app.camera_zoom)
	app.world_click(click)
	expect(app.sim.nathaniel.destination != null and app.sim.hermes_mode == "following", "Clicking mobile Hermes returns cargo without deploying him")
	expect(app.sim.focused_character == "nathaniel" and not app.ui.build_open, "Delivery keeps camera on Nathaniel and closes Build")
	advance(app, 4.0)
	expect(app.sim.corpses.is_empty() and app.sim.resources == 75, "Movement and the physical feed sequence credit one delivered bundle")
	expect(not app.sim.nathaniel.has_corpse, "Accepted cargo empties the HUD delivery state")
	app.command("upgrade_gathering", "capacity")
	app.sim.stop_player()
	app.sim.set_hermes_mode("stopped")
	app.sim.nathaniel.position = Vector2(640, 640)
	app.sim.hermes.position = Vector2(1200, 640)
	for slot: int in range(3):
		app.sim.spawn_resource(10, app.sim.nathaniel.position, 10.0, true)
	app.command("follow")
	app.command("deliver")
	advance(app, 12.0)
	expect(app.sim.corpses.is_empty() and app.sim.resources == 65, "One return order delivers three bundles to a distant moving Hermes")
	expect(Vector2(app.sim.nathaniel.position).distance_to(app.sim.hermes.position) <= GameBalance.RESOURCE_DELIVERY_REACH, "Return order stops within intake reach instead of walking past Hermes")
	app.sim.spawn_resource(10, app.sim.nathaniel.position, 10.0, true)
	app.command("deliver")
	app.command("stop")
	expect(not app.sim.nathaniel.returning_cargo, "Stop cancels automatic return tracking")
	app.sim.resources = 0
	app.command("build")
	expect(app.ui.buttons.upgrade_capacity.disabled and app.ui.buttons.upgrade_reach.disabled, "Unaffordable upgrades are disabled")
	app.command("upgrade_gathering", "reach")
	expect(app.sim.nathaniel.resource_reach == 60.0 and app.sim.resources == 0, "Rejected purchase leaves the saved upgrade and wallet intact")
	app.ui.size = Vector2(960, 540)
	app.ui.update_game(app.sim, false)
	await process_frame
	await process_frame
	app.ui._fit_hud()
	await process_frame
	var panel: Control = app.ui.get_node("Bottom")
	for key: String in app.ui.buttons:
		var button: Button = app.ui.buttons[key]
		if button.is_visible_in_tree():
			expect(panel.get_global_rect().encloses(button.get_global_rect()), "Compact HUD contains %s" % key)
	app.load_level(0)
	expect(app.sim.nathaniel.resource_capacity == 1 and app.sim.nathaniel.resource_reach == 44.0, "Fresh levels start with the starter backpack")
	_test_pickup_feedback(app)
	app.queue_free()
	await process_frame
	print("Resource gathering controls: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _pickup_fixture(app: GameApp, blocked: Array = []) -> Dictionary:
	app.load_level(0)
	app.sim.configure({"number": 0, "width": 64, "height": 64, "tile_size": 32,
		"blocked": blocked, "player_start": Vector2(640, 640), "hermes_start": Vector2(1300, 640),
		"enemies": [], "wave_based": false, "starting_resources": 100})
	app.fog.enabled = false
	app.sim.set_hermes_mode("stopped")
	app.ui.size = Vector2(root.size)
	var corpse := app.sim.spawn_resource(10, Vector2(900, 640), 10.0)
	app._physics_process(0.0)
	app._update_camera(1.0, true)
	app.effects._process(0.0)
	return corpse


func _corpse_screen_point(app: GameApp, corpse: Dictionary, opaque: bool = true) -> Vector2:
	var sprite: Sprite2D = app.effects._corpse_sprites[int(corpse.id)]
	var image: Image = sprite.texture.get_image()
	for y: int in image.get_height():
		for x: int in image.get_width():
			var alpha: float = image.get_pixel(x, y).a
			if (opaque and alpha <= 0.5) or (not opaque and alpha > 0.0):
				continue
			var point: Vector2 = sprite.get_global_transform_with_canvas() * (sprite.get_rect().position + Vector2(x + 0.5, y + 0.5))
			if app.world_entity_at(point).is_empty() and not app.ui.blocks_world_input(point):
				return point
	expect(false, "Corpse fixture has a usable %s texture pixel" % ("opaque" if opaque else "transparent"))
	return app.world_to_screen(corpse.position)


func _test_pickup_feedback(app: GameApp) -> void:
	var corpse := _pickup_fixture(app)
	var click := _corpse_screen_point(app, corpse)
	var transparent_click := _corpse_screen_point(app, corpse, false)
	var notice := app.ui.get_node("%Notice") as Label
	expect(app.effects.corpse_at_screen(click).get("id", -1) == corpse.id and app.effects.corpse_at_screen(transparent_click).is_empty(), "Corpse input hits visible body pixels and ignores transparent texture margins")
	app.world_click(transparent_click)
	app.effects._process(0.0)
	expect(app.effects.pickup_target_id == -1 and notice.text == "Moving Nathaniel.", "A transparent corpse margin gives an ordinary movement order")
	app.world_click(click)
	app.effects._process(0.0)
	expect(app.sim.nathaniel.destination is Vector2 and Vector2(app.sim.nathaniel.destination).is_equal_approx(corpse.position), "Clicking corpse artwork moves to the body's exact logical pickup position")
	expect(app.effects.pickup_target_id == corpse.id and notice.text == "Collecting corpse.", "A corpse click identifies the pickup order and confirms collection")
	var sprite: Sprite2D = app.effects._corpse_sprites[int(corpse.id)]
	var material := sprite.material as ShaderMaterial
	expect(material.get_shader_parameter("pickup_color") == app.effects.nathaniel_target_color and is_equal_approx(float(material.get_shader_parameter("pickup_strength")), app.effects.target_tint_strength), "The chosen corpse uses Nathaniel's subtle amber body highlight")
	app.world_click(click)
	app.effects._process(0.0)
	expect(app.effects.pickup_target_id == corpse.id and is_equal_approx(float(material.get_shader_parameter("pickup_strength")), app.effects.target_tint_strength), "Repeated corpse clicks retain a steady pickup highlight")
	app.command("pause")
	app.world_click(transparent_click)
	app.effects._process(0.0)
	expect(app.effects.pickup_target_id == corpse.id and Vector2(app.sim.nathaniel.destination).is_equal_approx(corpse.position), "Pause preserves the collection order and rejects new world clicks")
	app.command("resume")
	app.command("build")
	app.effects._process(0.0)
	expect(app.effects.pickup_target_id == corpse.id, "Opening Build preserves an existing collection order")
	app.world_click(click)
	app.effects._process(0.0)
	expect(not app.ui.build_open and app.effects.pickup_target_id == corpse.id and Vector2(app.sim.nathaniel.destination).is_equal_approx(corpse.position), "A corpse click outside Build closes it without replacing the collection order")
	app.command("stop")
	app.effects._process(0.0)
	expect(app.effects.pickup_target_id == -1 and is_zero_approx(float(material.get_shader_parameter("pickup_strength"))), "Stop clears collection feedback from the corpse body")
	app.command("build")
	app.world_click(click)
	app.effects._process(0.0)
	expect(not app.ui.build_open and app.effects.pickup_target_id == -1 and app.sim.nathaniel.destination == null, "Closing Build on a corpse does not create a pickup order")
	app.world_click(click)
	app.world_click(app.world_to_screen(Vector2(640, 400)))
	app.effects._process(0.0)
	expect(app.effects.pickup_target_id == -1 and Vector2(app.sim.nathaniel.destination).is_equal_approx(Vector2(640, 400)), "A new ground order clears the previous corpse indication")
	app.world_click(click)
	app.sim.stop_player()
	app.effects._process(0.0)
	expect(app.effects.pickup_target_id == -1, "State reconciliation clears feedback when the destination is cancelled")

	corpse = _pickup_fixture(app)
	click = _corpse_screen_point(app, corpse)
	var enemy := app.sim.spawn_enemy("soldier", Vector2(640, 900))
	app._sync_views()
	app.sim.fog.fill(2)
	app.world_click(click)
	app.world_click(app.world_to_screen(enemy.position) - Vector2(0, 20 * app.camera_zoom))
	app.effects._process(0.0)
	expect(app.sim.nathaniel.manual_target_id == enemy.id and app.effects.pickup_target_id == corpse.id and Vector2(app.sim.nathaniel.destination).is_equal_approx(corpse.position), "Targeting an enemy preserves walking to collect a corpse")
	app.sim.nathaniel.position = corpse.position
	corpse.expiration = GameBalance.RESOURCE_WARNING_SECONDS - 0.125
	app.effects._process(0.0)
	material = (app.effects._corpse_sprites[int(corpse.id)] as Sprite2D).material as ShaderMaterial
	expect(float(material.get_shader_parameter("warning")) > 0.9 and float(material.get_shader_parameter("pickup_strength")) > 0.0, "Expiry warning and pickup highlight remain active together")
	BattlefieldRules.update_corpses(app.sim, 0.0)
	app.effects._process(0.0)
	expect(corpse.phase == "grab" and app.effects.pickup_target_id == corpse.id, "Pickup feedback stays through the ground grab")
	BattlefieldRules.update_corpses(app.sim, GameBalance.RESOURCE_GRAB_SECONDS)
	app.effects._process(0.0)
	expect(corpse.phase == "crush" and corpse.carried and app.effects.pickup_target_id == -1, "Gripping and crushing a body ends its ground pickup indication")
	BattlefieldRules.update_corpses(app.sim, GameBalance.RESOURCE_CRUSH_SECONDS)
	expect(corpse.phase == "carry" and app.effects.pickup_target_id == -1, "Carried cargo does not retain a ground pickup indication")

	corpse = _pickup_fixture(app)
	click = _corpse_screen_point(app, corpse)
	app.sim.spawn_resource(10, app.sim.nathaniel.position, 10.0, true)
	app.world_click(click)
	app.effects._process(0.0)
	expect(app.effects.pickup_target_id == -1 and notice.text == "Cargo full. Deliver to Hermes first." and Vector2(app.sim.nathaniel.destination).is_equal_approx(corpse.position), "A full backpack gives a delivery notice and movement without promising pickup")

	corpse = _pickup_fixture(app)
	click = _corpse_screen_point(app, corpse)
	app.world_click(click)
	app.sim.spawn_resource(10, app.sim.nathaniel.position, 10.0, true)
	app.effects._process(0.0)
	expect(app.effects.pickup_target_id == -1, "Filling cargo while walking clears an unavailable pickup indication")
	app.world_click(click)
	app.command("deliver")
	app.effects._process(0.0)
	expect(app.sim.nathaniel.returning_cargo and app.effects.pickup_target_id == -1, "Delivery has no stale corpse pickup indication")

	corpse = _pickup_fixture(app)
	click = _corpse_screen_point(app, corpse)
	app.world_click(click)
	app.sim.nathaniel.resource_capacity = 2
	app.sim.spawn_resource(10, app.sim.nathaniel.position, 10.0, true)
	app.command("deliver")
	app.effects._process(0.0)
	expect(app.sim.nathaniel.returning_cargo and app.effects.pickup_target_id == -1, "Delivery replaces an active corpse order when cargo space remains")

	corpse = _pickup_fixture(app)
	click = _corpse_screen_point(app, corpse)
	app.fog.enabled = true
	app.sim.fog.fill(0)
	app._sync_views()
	app.effects._process(0.0)
	expect(app.effects.corpse_at_screen(click).is_empty(), "Hidden corpse artwork is not clickable")
	app.world_click(click)
	app.effects._process(0.0)
	expect(app.effects.pickup_target_id == -1 and notice.text == "Moving Nathaniel.", "A hidden corpse click gives no collection confirmation")

	corpse = _pickup_fixture(app)
	click = _corpse_screen_point(app, corpse)
	app.world_click(click)
	corpse.expiration = 0.01
	BattlefieldRules.update_corpses(app.sim, 0.02)
	app.effects.add_events(app.sim.take_events(), app.views)
	app.effects._process(0.0)
	expect(app.effects.pickup_target_id == -1 and app.sim.corpses.is_empty() and not app.effects.corpse_dissolves.is_empty(), "Expiry clears the pickup indication while the body dissolves")
	material = (app.effects._corpse_sprites[int(corpse.id)] as Sprite2D).material as ShaderMaterial
	expect(is_zero_approx(float(material.get_shader_parameter("pickup_strength"))) and app.effects.corpse_at_screen(click).is_empty(), "A dissolving body has no pickup tint and cannot be clicked for collection")

	corpse = _pickup_fixture(app)
	click = _corpse_screen_point(app, corpse)
	app.world_click(click)
	app.sim.nathaniel.hp = 0
	app.effects._process(0.0)
	expect(app.effects.pickup_target_id == -1, "Nathaniel's death clears the collection indication")

	corpse = _pickup_fixture(app, [Vector2i(28, 20)])
	click = _corpse_screen_point(app, corpse)
	app.world_click(click)
	app.effects._process(0.0)
	expect(app.sim.nathaniel.direct_movement and app.effects.pickup_target_id == corpse.id and notice.text.contains("No clear route to the corpse."), "A blocked corpse route identifies the body and explains partial movement")
	app.load_level(0)
	expect(app.effects.pickup_target_id == -1, "Changing the simulation clears old corpse pickup feedback")
