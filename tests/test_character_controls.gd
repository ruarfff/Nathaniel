extends SceneTree
## Gesture dispatch is synthetic; exported OS input is checked separately.

var checks := 0
var failures := 0
var app: GameApp


func _initialize() -> void:
	_run.call_deferred()


func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func fixture(cargo: bool = false) -> void:
	app.camera_zoom = 1.0
	app.load_level(0)
	app.sim.configure({"number": 0, "width": 64, "height": 64, "tile_size": 32, "blocked": [], "player_start": Vector2(640, 640), "hermes_start": Vector2(780, 640), "enemies": [], "wave_based": false, "starting_resources": 100})
	app.fog.enabled = false
	if cargo:
		app.sim.spawn_resource(10, app.sim.nathaniel.position, 10.0, true)
	app._physics_process(0)
	app._update_camera(1, true)
	app.ui._fit_hud()


func tap(character: String) -> void:
	var actor: Dictionary = app.sim.hermes if character == "hermes" else app.sim.nathaniel
	app.world_click(app.world_to_screen(actor.position) - Vector2(0, 20 * app.camera_zoom))


func _test_camera_focus() -> void:
	fixture()
	app.sim.hermes.position = Vector2(980, 880)
	var start := app.camera.position
	var world_size := Vector2(app.sim.config.width, app.sim.config.height) * float(app.sim.config.tile_size)
	app.command("focus", "hermes")
	var dimensions := app._character_display_size(app.sim.hermes)
	var build_zoom := minf(app.camera_zoom, minf(136.0 / dimensions.y, 156.0 / dimensions.x))
	var destination := IsoProjection.project(app.sim.hermes.position) - Vector2(0, dimensions.y / 2) + (Vector2(root.size) / 2 - app.ui.play_rect().get_center()) / build_zoom
	expect(app.sim.focused_character == "nathaniel" and app.ui.build_open and app.camera.position.is_equal_approx(start), "Build focuses Hermes without changing Nathaniel control or snapping the camera")
	app._update_camera(0.07)
	var early := app.camera.position
	expect(early.distance_to(start) > 1 and early.distance_to(destination) > 1, "Focus moves through intermediate positions")
	app._update_camera(0.07)
	var middle := app.camera.position
	expect(middle.distance_to(early) > early.distance_to(start), "Focus eases into the move")
	app.command("focus", "hermes")
	app._update_camera(0.07)
	var late := app.camera.position
	app._update_camera(0.07)
	expect(app.camera.position.is_equal_approx(destination), "Build focus settles within 280 ms; repeated icon actions do not restart it")
	expect(destination.distance_to(late) < late.distance_to(middle), "Focus slows down as it arrives")
	app.sim.hermes.position += Vector2(24, 0)
	app._update_camera(0.01)
	var following := destination + IsoProjection.project(Vector2(24, 0))
	expect(app.camera.position.distance_to(destination) > 0 and app.camera.position.distance_to(following) > 1, "Normal camera following stays smooth after the focus move ends")
	app.command("focus", "nathaniel")
	app._update_camera(0.07)
	var interrupted := app.camera.position
	app.command("focus", "hermes")
	expect(app.camera.position.is_equal_approx(interrupted), "Reopening Build during a return move preserves camera continuity")
	app.change_zoom(1.1)
	expect(app.camera.position.is_equal_approx(interrupted), "Zoom input during focus does not snap the pan to its destination")
	app.sim.hermes.position += Vector2(24, 0)
	app._update_camera(0.28)
	var body_center := app.world_to_screen(app.sim.hermes.position) - Vector2(0, dimensions.y * app.camera_zoom / 2)
	expect(body_center.distance_to(app.ui.play_rect().get_center()) < 0.01, "Build focus follows Hermes's current position when he moves")
	app.command("focus", "nathaniel")
	app._update_camera(0.28)
	app.change_zoom(2.0)
	start = app.camera.position
	var initial_zoom := app.camera_zoom
	app.open_context_ring()
	expect(app.camera.position.is_equal_approx(start) and app.camera_zoom == initial_zoom, "Opening Hermes's ring does not snap position or zoom")
	app._update_camera(0.07)
	expect(app.camera_zoom < initial_zoom and app.camera_zoom > 136.0 / app._character_display_size(app.sim.hermes).y, "Build framing eases zoom out to fit Hermes inside the ring")
	app._update_camera(0.21)
	body_center = app.world_to_screen(app.sim.hermes.position) - Vector2(0, dimensions.y * app.camera_zoom / 2)
	expect(body_center.distance_to(app.ui.play_rect().get_center()) < 0.01, "The eased build view finishes with Hermes centered inside the ring")
	start = app.camera.position
	app.command("focus", "nathaniel")
	expect(app.sim.focused_character == "nathaniel" and not app.ui.build_open and app.camera.position.is_equal_approx(start), "Closing Build restores Nathaniel control without a camera snap")
	app._update_camera(0.07)
	destination = IsoProjection.clamp_camera(IsoProjection.project(app.sim.nathaniel.position), world_size, root.size, app.camera_zoom)
	expect(app.camera.position.distance_to(start) > 1 and app.camera.position.distance_to(destination) > 1, "Closing Build eases back through intermediate positions")
	app._update_camera(0.21)
	expect(app.camera.position.is_equal_approx(destination), "Closing Build returns the camera to Nathaniel within 280 ms")
	app.open_context_ring()
	app._update_camera(0.07)
	app.load_level(0)
	start = app.camera.position
	app._update_camera(0.07)
	expect(app.camera.position.is_equal_approx(start), "Starting a level clears any previous focus transition")
	fixture()


func _run() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1280, 800)
	app = load("res://scenes/main.tscn").instantiate()
	app.storage_root = "/private/tmp/nathaniel-character-controls-%d/" % Time.get_ticks_usec()
	root.add_child(app)
	app.set_physics_process(false)
	app.game_input.set_process(false)
	await process_frame
	_test_camera_focus()
	for mode: String in ["following", "building"]:
		for build_open: bool in [false, true]:
			for cargo: bool in [false, true]:
				for actor: String in ["nathaniel", "hermes"]:
					fixture(cargo)
					app.sim.set_hermes_mode(mode)
					if build_open:
						app.open_context_ring()
						app._update_camera(0.28)
					for repetition: int in range(2):
						if build_open and actor == "nathaniel" and repetition == 0:
							app.world_click(Vector2(80, app.ui.play_rect().get_center().y))
						else:
							tap(actor)
						var deliver := actor == "hermes" and cargo and (not build_open or repetition > 0)
						expect(app.sim.nathaniel.returning_cargo == deliver, "World Hermes delivers cargo during normal control; closing Build consumes its first tap")
						expect(app.sim.focused_character == "nathaniel" and not app.ui.build_open, "Closing Build restores normal Nathaniel world control")
						expect(app.ui.ring_character.is_empty(), "World character taps never open a ring, including repeated Hermes taps")
	fixture(true)
	var held := InputEventMouseButton.new()
	held.pressed = true
	held.button_index = MOUSE_BUTTON_LEFT
	held.position = app.world_to_screen(app.sim.hermes.position) - Vector2(0, 20)
	app.game_input._unhandled_input(held)
	expect(not app.sim.nathaniel.returning_cargo and app.ui.character_pressed, "Press gives feedback without issuing a release action")
	held.pressed = false
	app.game_input._input(held)
	expect(app.sim.nathaniel.returning_cargo and not app.ui.character_pressed, "Release orders delivery immediately and clears pressed feedback")
	for build_open: bool in [false, true]:
		fixture(true)
		if build_open:
			app.open_context_ring()
			app._update_camera(0.28)
		held.position = app.world_to_screen(app.sim.hermes.position) - Vector2(0, 20)
		held.pressed = true
		app.game_input._unhandled_input(held)
		app.sim.hermes.position += Vector2(200, 0)
		held.pressed = false
		app.game_input._input(held)
		expect(app.sim.nathaniel.destination == null and not app.sim.nathaniel.returning_cargo and app.ui.ring_character == ("hermes" if build_open else "") and not app.ui.character_pressed, "Hermes moving out from under a held tap cancels without changing the active control mode")
	fixture(true)
	held.position = app.world_to_screen(Vector2(900, 650))
	held.pressed = true
	app.game_input._unhandled_input(held)
	app.sim.hermes.position = Vector2(900, 650)
	held.pressed = false
	app.game_input._input(held)
	expect(not app.sim.nathaniel.returning_cargo and app.sim.nathaniel.destination == null, "An actor moving under a ground press cannot change it into delivery")
	for cancellation: String in ["pause", "focus", "zoom", "death", "scene", "drag", "pinch"]:
		fixture(true)
		held.pressed = true
		held.position = app.world_to_screen(app.sim.hermes.position) - Vector2(0, 20)
		app.game_input._unhandled_input(held)
		match cancellation:
			"pause":
				app.command("pause")
				app.command("resume")
			"focus": app.command("focus", "hermes")
			"zoom": app.change_zoom(1.1)
			"death": app.sim.nathaniel.hp = 0
			"scene": fixture()
			"drag":
				var motion := InputEventMouseMotion.new()
				motion.position = held.position + Vector2(100, 0)
				app.game_input._input(motion)
			"pinch":
				for index: int in range(2):
					var touch := InputEventScreenTouch.new()
					touch.index = index
					touch.pressed = true
					touch.position = held.position + Vector2(index * 100, 0)
					app.game_input._input(touch)
		held.pressed = false
		app.game_input._input(held)
		app.game_input.touches.clear()
		app.game_input.pinching = false
		expect(not app.sim.nathaniel.returning_cargo and app.ui.ring_character == ("hermes" if cancellation == "focus" else ""), "%s cancels a held world tap" % cancellation)
	fixture()
	app.sim.nathaniel.destination = Vector2(950, 950)
	var enemy := app.sim.spawn_enemy("grunt", Vector2(950, 800))
	app.sim.fog.fill(2)
	app.open_context_ring()
	var point := Vector2(80, app.ui.play_rect().get_center().y)
	app.game_input.pointer_position = point
	app.command("fire_at_pointer")
	app.command("stop")
	expect(app.sim.focused_character == "nathaniel" and app.sim.nathaniel.destination == Vector2(950, 950) and app.sim.nathaniel.manual_fire_target == null, "Build blocks new Nathaniel fire and stop commands while keeping his existing orders")
	app.command("pause")
	app.command("resume")
	expect(app.sim.focused_character == "nathaniel" and not app.ui.build_open, "Pause and resume close Build and restore Nathaniel control")
	app.open_context_ring()
	app.world_click(point)
	expect(not app.ui.build_open and app.ui.ring_character.is_empty() and app.sim.nathaniel.destination == Vector2(950, 950) and app.sim.nathaniel.manual_target_id == -1, "Outside click closes Build without a movement or target order")
	app._update_camera(0.28)
	app.world_click(app.world_to_screen(app.sim.nathaniel.position) - Vector2(0, 50))
	expect(app.sim.focused_character == "nathaniel" and app.ui.ring_character.is_empty(), "Tapping Nathaniel's visible upper body keeps normal control without a ring")
	point = app.world_to_screen(Vector2(900, 650))
	app.world_click(point)
	expect(app.sim.nathaniel.destination != Vector2(950, 950), "The next ground tap moves Nathaniel after Build closes")
	app.world_click(app.world_to_screen(enemy.position) - Vector2(0, 20))
	expect(app.sim.nathaniel.manual_target_id == enemy.id, "Enemy taps target for Nathaniel after Build closes")
	for character: String in ["hermes", "nathaniel"]:
		fixture(true)
		app.sim.target_enemy(app.sim.spawn_enemy("grunt", Vector2(800, 800)).id)
		var target: int = app.sim.nathaniel.target_id
		var card := app.ui.get_node("%" + character.capitalize()) as CharacterControl
		card.pressed.emit()
		card.pressed.emit()
		expect(app.sim.focused_character == "nathaniel" and app.ui.ring_character == ("hermes" if character == "hermes" else "") and not app.sim.nathaniel.returning_cargo and app.sim.nathaniel.target_id == target, "Hermes icon opens Build; repeated icon taps preserve Nathaniel control, orders, and the open menu")
		app._update_camera(0.28)
		tap(character)
		expect(app.ui.ring_character.is_empty() and app.sim.focused_character == "nathaniel", "World character tap closes the menu and returns to Nathaniel")
		tap(character)
		expect(app.ui.ring_character.is_empty(), "A second world character tap does not reopen Build")
	fixture()
	app.open_context_ring()
	var live_buttons := 0
	for button: Button in app.ui.ring_buttons.values():
		if button.visible:
			live_buttons += 1
	expect(live_buttons == 6, "Hermes has six fixed positions")
	expect(app.ui.ring_buttons.empty.disabled and app.ui.ring_buttons.settings.disabled and app.ui.ring_buttons.pack.disabled, "Empty, Settings and mobile Pack stay inactive")
	app.sim.resources = 0
	app.ui.update_game(app.sim, false)
	expect(app.ui.ring_buttons.gun_tower.disabled and app.ui.ring_buttons.gun_tower.text.contains("Need more matter"), "Unaffordable slot stays visible with a reason")
	app.sim.resources = 100
	app.game_input.begin_tower_drag("gun_tower")
	expect(app.ui.ring_character.is_empty() and app.ui.build_kind == "gun_tower", "Tower selection replaces the ring with placement")
	tap("hermes")
	expect(app.ui.build_kind == "gun_tower" and app.ui.ring_character.is_empty() and app.sim.resources == 100, "World Hermes does not reopen Build during placement")
	app.ui.get_node("%Hermes").pressed.emit()
	expect(app.ui.build_kind.is_empty() and app.ui.ring_character == "hermes" and app.sim.resources == 100, "Hermes icon reopens Build and cancels uncommitted placement")
	app.command("focus", "nathaniel")
	expect(app.ui.build_kind.is_empty() and app.sim.resources == 100, "Icon selection discards uncommitted placement")
	app.open_context_ring()
	app._update_camera(0.28)
	app.game_input.begin_tower_drag("gun_tower")
	var placement_camera := app.camera.position
	var invalid := app.world_to_screen(app.sim.hermes.position + Vector2(app.sim.hermes_build_range() + 80, 0))
	app.world_click(invalid)
	expect(app.sim.resources == 100 and app.ui.build_open and app.ui.ring_character.is_empty() and app.ui.build_kind == "gun_tower" and app.game_input.drag_kind == "gun_tower", "Rejected placement retains the preview and spends no matter")
	var ground := app.world_to_screen(app.sim.hermes.position + Vector2(120, 100))
	app.world_click(ground)
	expect(app.sim.resources == 95 and app.sim.hermes_mode == "building" and app.ui.build_kind.is_empty() and app.game_input.drag_kind.is_empty() and app.ui.ring_character == "hermes" and app.ui.build_open and app.sim.focused_character == "nathaniel", "Valid placement pays once and returns to Build with no held tower")
	expect(app.camera.position.is_equal_approx(placement_camera) and app._camera_focus_elapsed == app.CAMERA_FOCUS_DURATION, "Returning to Build after placement keeps the settled Hermes camera")
	app.game_input.begin_tower_drag("gun_tower")
	ground = app.world_to_screen(app.sim.hermes.position + Vector2(120, -100))
	app.world_click(ground)
	expect(app.sim.resources == 90 and app.ui.ring_character == "hermes" and app.ui.build_kind.is_empty() and app.game_input.drag_kind.is_empty(), "The returned menu can build a second tower and return again")
	app.game_input.begin_tower_drag("gun_tower")
	app.command("escape")
	expect(app.sim.resources == 90 and app.ui.ring_character == "hermes" and app.ui.build_kind.is_empty() and app.game_input.drag_kind.is_empty() and not app.sim.paused, "Escape cancels placement and returns to Build")
	expect(app.ui.ring_buttons.pack.text.contains("Gun 2") and app.ui.ring_buttons.pack.text.contains("+2 matter"), "Pack shows tower kinds, counts and refund without hover")
	app.command("pack")
	expect(app.sim.resources == 92 and app.sim.hermes_mode == "following" and app.sim.focused_character == "nathaniel" and not app.ui.build_open, "Pack reclaims once and resumes normal Nathaniel control")
	app.open_context_ring()
	app.world_click(Vector2(80, app.ui.play_rect().get_center().y))
	expect(app.ui.ring_character.is_empty() and app.sim.nathaniel.destination == null and app.sim.focused_character == "nathaniel" and not app.ui.build_open, "Outside tap dismisses, is consumed, and returns to Nathaniel control")
	_test_visibility()
	for viewport_size: Vector2i in [Vector2i(1280, 800), Vector2i(960, 540), Vector2i(540, 960)]:
		root.size = viewport_size
		root.content_scale_size = viewport_size
		await process_frame
		fixture()
		await process_frame
		app.ui._fit_hud()
		for character: String in ["hermes", "nathaniel"]:
			if "--render" in OS.get_cmdline_user_args():
				_render_fixture()
			if character == "hermes":
				app.open_context_ring()
			else:
				app.command("focus", "nathaniel")
			await process_frame
			app.ui._fit_hud()
			app.change_zoom(4.0)
			app._update_camera(0.28)
			var actor: Dictionary = app.sim.hermes if character == "hermes" else app.sim.nathaniel
			var dimensions := app._character_display_size(actor) * app.camera_zoom
			var body := Rect2(app.world_to_screen(actor.position) - Vector2(dimensions.x / 2, dimensions.y), dimensions)
			for button: Button in app.ui.ring_buttons.values():
				if button.is_visible_in_tree():
					expect(not button.get_global_rect().intersects(body), "Ring controls leave the selected actor visible at maximum zoom")
					expect(app.ui.safe_rect().encloses(button.get_global_rect()), "%s ring fits %s" % [character, viewport_size])
					expect(not button.get_global_rect().intersects(app.ui.get_node("Characters").get_global_rect()), "Ring leaves persistent selectors available")
			if "--render" in OS.get_cmdline_user_args():
				app._physics_process(0)
				app._update_camera(1, true)
				app._update_character_hud()
				await process_frame
				await RenderingServer.frame_post_draw
				var image := root.get_texture().get_image()
				image.save_png("res://test-artifacts/hud-%s-%dx%d.png" % [character, viewport_size.x, viewport_size.y])
	app.queue_free()
	await process_frame
	print("Character controls: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _render_fixture() -> void:
	fixture()
	app.sim.nathaniel.position = Vector2(420, 420)
	app.sim.hermes.position = Vector2(540, 460)
	app.sim.nathaniel.owned_weapon_ids.append("heavy_rifle")
	app.sim.spawn_resource(10, app.sim.nathaniel.position, 10.0, true)
	app.sim.place_tower("gun_tower", app.sim.hermes.position + Vector2(140, -90))
	var grunt := app.sim.spawn_enemy("grunt", Vector2(460, 680))
	var soldier := app.sim.spawn_enemy("soldier", Vector2(700, 620))
	app.sim.nathaniel.target_id = grunt.id
	app.sim.hermes.target_id = soldier.id
	app.camera_zoom = 1.5
	app.camera.zoom = Vector2.ONE * app.camera_zoom
	app._physics_process(0)


func _test_visibility() -> void:
	fixture()
	var grunt := app.sim.spawn_enemy("grunt", Vector2(700, 780))
	var soldier := app.sim.spawn_enemy("soldier", Vector2(780, 700))
	app.sim.nathaniel.target_id = grunt.id
	app.sim.hermes.target_id = soldier.id
	app.ui.update_game(app.sim, false)
	var n: CharacterControl = app.ui.get_node("%Nathaniel")
	var h: CharacterControl = app.ui.get_node("%Hermes")
	expect(n.target_name == "Grunt" and h.target_name == "Soldier" and n.target_texture != h.target_texture, "Portraits follow independent visible targets")
	app.sim.fog.fill(1)
	app.ui.update_game(app.sim, true)
	app.sim.hermes.position += Vector2(2000, 0)
	app._update_character_hud()
	expect(n.target_name == "Out of sight" and h.target_name == "Out of sight" and n.target_texture == null and h.target_texture == null, "Hidden targets reveal no identity or portrait")
	expect(h.offscreen_direction != Vector2.ZERO and n.offscreen_direction == Vector2.ZERO, "Friendly off-screen direction is independent of enemy visibility")
	app.sim.hermes.target_id = -1
	app.ui.update_game(app.sim, true)
	expect(h.target_name == "No target" and h.target_texture == null, "No target uses an empty crosshair")
