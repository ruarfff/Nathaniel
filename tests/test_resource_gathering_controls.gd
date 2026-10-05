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
	app.load_level(0)
	app.sim.configure({"number": 0, "width": 64, "height": 64, "tile_size": 32,
		"blocked": [], "player_start": Vector2(640, 640), "hermes_start": Vector2(900, 640),
		"enemies": [], "wave_based": false, "starting_resources": 100})
	app.fog.enabled = false
	app.sim.set_hermes_mode("stopped")
	app._physics_process(0.0)
	await process_frame
	expect(app.ui.buttons.deliver.disabled, "Empty backpack disables delivery")
	expect(String(app.ui.get_node("%Stats").text).contains("Cargo 0 / 1"), "HUD separates cargo capacity from spendable resources")
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
	expect(app.sim.nathaniel.has_corpse and not app.ui.buttons.deliver.disabled, "Completed collection enables delivery")
	expect(app.sim.resources == 65 and String(app.ui.get_node("%Stats").text).contains("Cargo 1 / 2"), "Carried matter stays separate from the wallet")
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
	expect(app.ui.buttons.deliver.disabled, "Accepted cargo empties the HUD delivery state")
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
	app.queue_free()
	await process_frame
	print("Resource gathering controls: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
