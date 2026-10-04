extends SceneTree
## Native content, controls, saves and shot routing. OS input is checked separately.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _key(app: GameApp, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	app.game_input._input(event)


func _run() -> void:
	for number: int in range(6):
		var level: GameLevel = load("res://levels/level_%d.tscn" % number).instantiate()
		var sim := GameSimulation.new()
		sim.configure(level.data())
		expect(sim.weapon_pickups.size() == 1, "Level %d has one authored pickup" % number)
		var pickup: Dictionary = sim.weapon_pickups[0]
		expect(pickup.weapon_id == "heavy_rifle", "Level %d offers the alternate rifle" % number)
		expect(Vector2(sim.nathaniel.position).distance_to(pickup.position) > GameBalance.WEAPON_PICKUP_RADIUS, "Level %d does not collect at spawn" % number)
		expect(not sim.navigation.route(sim.nathaniel.position, pickup.position, sim.nathaniel.radius).is_empty(), "Level %d pickup is reachable from the authored spawn" % number)
		expect(sim.navigation.walkable(pickup.position, sim.nathaniel.radius), "Level %d pickup artwork has no blocking footprint" % number)
		level.free()
	var app: GameApp = load("res://scenes/main.tscn").instantiate()
	app.storage_root = "/private/tmp/nathaniel-weapon-controls-%d/" % Time.get_ticks_usec()
	root.add_child(app)
	app.set_physics_process(false)
	app.load_level(0)
	app._physics_process(0.0)
	await process_frame
	expect(app.ui.buttons.rifle.button_pressed and app.ui.buttons.heavy_rifle.disabled, "HUD starts with rifle selected and the alternate locked")
	_key(app, KEY_2)
	expect(app.sim.nathaniel.equipped_weapon_id == "rifle", "Locked shortcut cannot equip a missing weapon")
	var pickup: Dictionary = app.sim.weapon_pickups[0]
	var crate: WeaponPickupView = app.pickup_views[int(pickup.id)]
	expect(crate.get_parent() == app.get_node("World/Actors") and crate.position == IsoProjection.project(pickup.position), "Pickup shares actor ground anchors and Y sorting")
	app.sim.fog.fill(1)
	app._sync_views()
	expect(not crate.visible, "Fog hides an unseen pickup")
	app.fog.enabled = false
	app._sync_views()
	expect(crate.visible, "Disabling fog shows pickup artwork")
	app.sim.move_to(pickup.position)
	for frame: int in range(120):
		app._physics_process(1.0 / 60.0)
		if app.sim.weapon_pickups.is_empty():
			break
	expect(app.sim.weapon_pickups.is_empty() and "heavy_rifle" in app.sim.nathaniel.owned_weapon_ids, "Walking to the real level pickup unlocks the heavy rifle")
	expect(app.pickup_views.is_empty(), "Collected pickup removes its view")
	expect(app.sim.nathaniel.equipped_weapon_id == "rifle" and not app.ui.buttons.heavy_rifle.disabled, "Collection enables slot 2 without changing the gun")
	app.command("build")
	app.ui.build_kind = "gun_tower"
	var destination: Variant = app.sim.nathaniel.destination
	var focus: String = app.sim.focused_character
	_key(app, KEY_2)
	expect(app.sim.nathaniel.equipped_weapon_id == "heavy_rifle" and app.sim.nathaniel.equip_ready_remaining > 0.0, "Key 2 starts the equip delay")
	expect(app.sim.nathaniel.destination == destination and app.sim.focused_character == focus and app.ui.build_kind == "gun_tower", "Weapon shortcut leaves movement, camera and build choice intact")
	expect(app.ui.buttons.heavy_rifle.button_pressed and String(app.ui.get_node("Bottom/Rows/Weapons/WeaponStatus").text).contains("Equipping"), "HUD shows equipped slot and switch status")
	app.command("pause")
	_key(app, KEY_1)
	expect(app.sim.nathaniel.equipped_weapon_id == "heavy_rifle", "Weapon shortcuts cannot act through a modal")
	app.command("resume")
	app.ui.buttons.rifle.pressed.emit()
	expect(app.sim.nathaniel.equipped_weapon_id == "rifle", "Named touch button uses the same equip command")
	app.command("focus")
	app.sim.stop_player()
	app.sim.nathaniel.equip_ready_remaining = 0.0
	app.sim.nathaniel.cooldown = 100.0
	var direction := Vector2(0.31, 0.83).normalized()
	app.sim.nathaniel.aim_direction = direction
	app.sim.take_events()
	expect(CombatRules.shoot(app.sim, app.sim.nathaniel, app.sim.nathaniel.position + direction * 250.0), "Rifle emits a shot through the combat contract")
	app._physics_process(0.0)
	var shot: Dictionary = app.sim.projectiles.back()
	var actor: ActorView = app.views[int(app.sim.nathaniel.id)]
	var offset: Vector2 = actor.weapon_muzzle(direction, "rifle")
	var launch: Vector2 = IsoProjection.project(shot.position) + offset
	expect(offset.is_finite() and app.effects.projectile_position(shot).distance_to(launch) < 0.001, "Application launches Nathaniel's rifle bullet at its barrel")
	expect(app.effects.muzzle_flashes.size() == 1 and Vector2(app.effects.muzzle_flashes[0].position).distance_to(launch) < 0.001, "Nathaniel's flash and bullet start at the same point")
	_key(app, KEY_2)
	app._sync_views()
	expect(shot.weapon_id == "rifle" and app.effects.projectile_position(shot).distance_to(launch) < 0.001, "Swapping guns leaves an existing bullet at its rifle muzzle offset")
	app.command("save_slot", 1)
	app.command("load_slot", 1)
	var restored: Dictionary = app.sim.projectiles.back()
	expect(app.sim.nathaniel.equipped_weapon_id == "heavy_rifle" and app.sim.weapon_pickups.is_empty(), "Application save/load keeps loadout and consumed pickups")
	expect(restored.weapon_id == "rifle" and app.effects.projectile_position(restored).distance_to(IsoProjection.project(restored.position) + offset) < 0.001, "Loading while holding heavy rifle restores old rifle bullet's muzzle")
	app.ui.size = Vector2(960, 540)
	app.ui.build_open = true
	app.ui.update_game(app.sim, false)
	await process_frame
	await process_frame
	app.ui._fit_hud()
	await process_frame
	var panel: Control = app.ui.get_node("Bottom")
	for id: String in app.ui.buttons:
		var button: Button = app.ui.buttons[id]
		if button.is_visible_in_tree():
			expect(panel.get_global_rect().encloses(button.get_global_rect()), "Wrapped HUD contains %s button" % id)
	app.load_level(0)
	expect(app.sim.nathaniel.owned_weapon_ids == ["rifle"] and app.sim.weapon_pickups.size() == 1, "Fresh level resets the loadout and restores its authored pickup")
	app.show_main()
	expect(app.pickup_views.is_empty(), "Returning to menu clears pickup views")
	app.queue_free()
	await process_frame
	print("Weapon controls: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
