extends SceneTree
## Integration checks use native scenes and isolated saves. These are not OS input tests.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	# Match the verified UI timing baseline while the audio mixer runs separately.
	Engine.max_fps = 60
	_run.call_deferred()


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)


func _run() -> void:
	for world: Vector2 in [Vector2.ZERO, Vector2(15.7, 921), Vector2(3800, 959), Vector2(-22, 90)]:
		check(IsoProjection.unproject(IsoProjection.project(world)).is_equal_approx(world), "Projection inverse preserves logical coordinates")
	check(IsoProjection.clamp_camera(Vector2(-9999, 9999), Vector2(300, 300), Vector2(1280, 800), 1.0).is_equal_approx(Vector2(0, 150)), "Small map camera centers when viewport exceeds map")
	var app := load("res://scenes/main.tscn").instantiate() as GameApp
	app.storage_root = "/private/tmp/nathaniel-presentation-start-%d/" % Time.get_ticks_usec()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	check(app.ui.menu == "main", "Application starts at main menu")
	for number in range(6):
		check(app.load_level(number), "Native level %d opens" % number)
		await process_frame
		app.set_physics_process(false)
		check(app.sim.level_number == number, "Configuration matches chosen level")
		check(app.sim.entities.size() >= 2, "Both players instantiate")
		check(app.sim.hermes_mode == "following" and not app.ui.build_open, "Fresh level %d starts with Hermes following and Build closed" % number)
		check(app.sim.lives == (0 if number == 0 else 3), "Level lives preserve source")
		check(app.level.get_node("Ground") is TileMapLayer, "Native terrain remains editable")
		check(app.views.size() >= 2, "Player scene views instantiate")
		var world := Vector2(240, 450)
		check(app.screen_to_world(app.world_to_screen(world)).distance_to(world) < 0.001, "Input reverses camera plus projection")
	app.load_level(0)
	await process_frame
	app.set_physics_process(false)
	app.command("focus", "hermes")
	check(app.sim.focused_character == "nathaniel" and app.sim.hermes_mode == "following" and not app.ui.build_open, "Direct Hermes focus is ignored without changing his mode")
	app.command("follow")
	check(app.sim.hermes_mode == "following", "Follow button changes mode")
	app.ui.build_kind = "gun_tower"
	app.command("follow")
	check(app.ui.build_kind.is_empty(), "Follow cancels armed tower placement")
	app.command("hermes_stop")
	check(app.sim.hermes_mode == "building", "Stationary Hermes returns to building")
	app.command("pause")
	var paused_at := app.sim.elapsed_time
	app.sim.step(1.0)
	check(app.sim.elapsed_time == paused_at, "Pause stops gameplay time")
	app.command("settings")
	check(app.ui.menu == "settings", "Settings opens over pause")
	app.command("back")
	check(app.ui.menu == "pause", "Settings returns to pause")
	app.command("resume")
	check(not app.sim.paused and app.ui.menu.is_empty(), "Resume closes modal and restarts simulation")
	app.command("settings")
	check(app.sim.paused, "Direct settings intent pauses active gameplay")
	app.command("back")
	app.command("resume")
	var zoom_before := app.camera_zoom
	app.change_zoom(1.5)
	check(app.camera_zoom > zoom_before, "Zoom changes world camera")
	check(app.ui.scale == Vector2.ONE, "HUD is outside camera transform")
	var point := Vector2(300, 300)
	check(app.screen_to_world(app.world_to_screen(point)).distance_to(point) < 0.001, "Inverse input remains exact after zoom")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	app.game_input._input(key)
	check(app.sim.focused_character == "nathaniel", "Keyboard focus dispatch reaches simulation")
	app.ui.build_kind = "gun_tower"
	app.command("focus", "nathaniel")
	check(app.ui.build_kind.is_empty(), "Focusing Nathaniel cancels placement")
	app.game_input.drag_kind = "gun_tower"
	var canceled_touch := InputEventScreenTouch.new()
	canceled_touch.canceled = true
	app.game_input._input(canceled_touch)
	check(app.game_input.drag_kind.is_empty(), "Canceled touch cannot place a tower")
	var first_touch := InputEventScreenTouch.new()
	first_touch.index = 0
	first_touch.pressed = true
	first_touch.position = Vector2(100, 100)
	app.game_input._input(first_touch)
	app.game_input.drag_kind = "gun_tower"
	app.ui.build_kind = "gun_tower"
	var second_touch := InputEventScreenTouch.new()
	second_touch.index = 1
	second_touch.pressed = true
	second_touch.position = Vector2(200, 100)
	app.game_input._input(second_touch)
	check(app.game_input.pinching and app.game_input.drag_kind.is_empty() and app.ui.build_kind.is_empty(), "Second touch changes tower drag into camera gesture without accidental placement")
	var pinch := InputEventScreenDrag.new()
	pinch.index = 1
	pinch.position = Vector2(250, 100)
	var pinch_zoom := app.camera_zoom
	app.game_input._input(pinch)
	check(app.camera_zoom > pinch_zoom, "Two-finger gesture scales the game camera")
	first_touch.pressed = false
	app.game_input._input(first_touch)
	check(app.game_input.pinching, "Lifting one pinch finger keeps pointer commands suppressed")
	second_touch.pressed = false
	app.game_input._input(second_touch)
	check(not app.game_input.pinching and app.game_input.touches.is_empty(), "Lifting both fingers ends pinch state")
	app.command("pause")
	app.sim.resources = 123
	var path := "/private/tmp/nathaniel-presentation-%d" % Time.get_ticks_usec()
	app.save_store = GameSaveStore.new(path)
	app.command("save_slot", 1)
	check(app.save_store.load_slot(1).success, "Save menu writes isolated first slot")
	app.load_level(2)
	app.command("pause")
	app.command("load_slot", 1)
	check(app.sim.level_number == 0 and app.level.definition.number == 0, "Loading restores the saved level scene")
	check(app.sim.resources == 123 and not app.sim.paused, "Loading restores resource wallet and resumes")
	app.command("pause")
	app.command("save_slot", 1)
	check(app.ui.menu == "confirm_save", "Existing slots require explicit replacement in UI")
	app.command("main")
	check(app.sim == null and app.level == null, "Main menu discards session and scene")
	app.command("resume")
	check(app.sim == null, "Resume cannot revive discarded session")
	var bridge := GameDebugBridge.new(app)
	check(bridge.state().scene == "MainMenuScene", "Debug state distinguishes menu")
	check(bridge.nodes().size() >= 6, "Debug exposes visible menu buttons")
	app.load_level(1)
	app.sim.result = "victory"
	app.command("settings")
	check(app.sim.result == "victory" and app.ui.menu != "settings", "Terminal result rejects settings intent")
	app.game_input._input(key)
	check(app.sim.level_number == 2, "Any key advances completed campaign level")
	await _test_controls_regressions(app)
	_test_pointer_tracking(app)
	_test_build_mode_commands(app)
	_test_legacy_build_focus(app, path.path_join("legacy-build-focus"))
	_test_delivery_feedback(app)
	_test_target_feedback(app)
	await _test_target_hud_input(app)
	_test_slot_menu_paths(app, path.path_join("native-slot-menus"))
	_test_import_composition(app, path.path_join("legacy-import"))
	_test_modal_regressions(app)
	_test_debug_clipping(app)
	await process_frame
	await _test_small_menu_scrolling(app)
	await _test_audio_settings(app)
	app.audio.music.stop()
	app.queue_free()
	await process_frame
	# Let the audio server release a stopped MP3 playback before engine shutdown.
	await create_timer(0.05).timeout
	print("Presentation integration: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _mouse_button(point: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = point
	event.pressed = pressed
	root.push_input(event, true)


func _key_stroke(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)


func _test_controls_regressions(app: GameApp) -> void:
	var previous_size := root.size
	root.size = Vector2i(1280, 800)
	root.notify_mouse_entered()
	app.load_level(0)
	app.sim.configure({"number": 0, "width": 64, "height": 64, "tile_size": 32,
		"blocked": [], "player_start": Vector2(640, 640),
		"hermes_start": Vector2(480, 640), "enemies": [], "wave_based": false})
	app.fog.enabled = false
	app.camera_zoom = 1.0
	app.camera.zoom = Vector2.ONE
	app._update_camera(1.0, true)
	app.ui.update_game(app.sim)
	await process_frame
	await process_frame
	var hermes_readout := app.ui.get_node("%Hermes") as Label
	_mouse_button(hermes_readout.get_global_rect().get_center(), true)
	_mouse_button(hermes_readout.get_global_rect().get_center(), false)
	check(app.sim.focused_character == "nathaniel" and not app.ui.build_open and app.sim.nathaniel.destination == null, "Hermes HUD reports state without selecting him or moving Nathaniel behind the HUD")
	var build_button: Button = app.ui.buttons.build
	_mouse_button(build_button.get_global_rect().get_center(), true)
	_mouse_button(build_button.get_global_rect().get_center(), false)
	check(app.ui.build_open and app.sim.focused_character == "hermes", "Build HUD opens tower choices and focuses the camera on Hermes")
	_key_stroke(KEY_SPACE)
	check(app.sim.focused_character == "nathaniel" and not app.ui.build_open, "Space press and release closes Build after clicking its HUD button")
	_key_stroke(KEY_SPACE)
	check(app.sim.focused_character == "nathaniel" and not app.ui.build_open, "Repeated Space stays with Nathaniel without a focused HUD button reopening Build")
	_key_stroke(KEY_B)
	app.ui.update_game(app.sim)
	check(app.ui.build_open and build_button.button_pressed and app.sim.focused_character == "hermes", "B opens Build and its HUD selection matches the camera mode")
	_key_stroke(KEY_B)
	check(not app.ui.build_open and app.sim.focused_character == "nathaniel", "B closes Build and returns the camera to Nathaniel")
	var pause_button := app.ui.get_node("%Pause") as Button
	_mouse_button(pause_button.get_global_rect().get_center(), true)
	_mouse_button(pause_button.get_global_rect().get_center(), false)
	_key_stroke(KEY_ESCAPE)
	_key_stroke(KEY_SPACE)
	check(app.ui.menu.is_empty() and app.sim.focused_character == "nathaniel", "Space after Pause and Resume cannot reactivate Pause")
	app.command("follow")
	app.sim.step(0.5)
	var following_before: Dictionary = app.sim.hermes.duplicate(true)
	app.command("build")
	check(app.sim.hermes_mode == "following" and app.sim.hermes == following_before and app.ui.build_open and app.sim.focused_character == "hermes", "Opening Build preserves Hermes follow movement while showing tower choices")
	app.ui.update_game(app.sim)
	await process_frame
	await process_frame
	var tower_button: Button = app.ui.buttons.gun_tower
	var start := tower_button.get_global_rect().get_center()
	app._update_camera(1.0, true)
	var ground := app.world_to_screen(app.sim.hermes.position + Vector2(160, 0))
	var wallet := app.sim.resources
	check(not tower_button.disabled and tower_button.is_visible_in_tree(), "Tower choices are available while Hermes follows")
	_mouse_button(start, true)
	check(app.game_input.drag_kind == "gun_tower" and app.ui.build_kind == "gun_tower", "Tower button press immediately arms placement preview")
	_key_stroke(KEY_ESCAPE)
	_mouse_button(ground, false)
	check(app.sim.resources == wallet and app.ui.build_kind.is_empty() and app.game_input.drag_kind.is_empty() and app.ui.build_open and app.sim.hermes_mode == "following", "Escape cancels a held tower before world release without stopping Hermes or closing Build")
	_mouse_button(start, true)
	_key_stroke(KEY_ESCAPE)
	_mouse_button(start, false)
	check(app.ui.build_kind.is_empty(), "Releasing on the original tower button cannot rearm canceled placement")
	_mouse_button(start, true)
	_mouse_button(hermes_readout.get_global_rect().get_center(), false)
	check(app.sim.resources == wallet and app.ui.build_kind.is_empty(), "Tower drop over top HUD cannot place behind the controls")
	_mouse_button(start, true)
	_mouse_button(Vector2(40, 750), false)
	check(app.sim.resources == wallet and app.ui.build_kind.is_empty(), "Tower drop over bottom HUD cancels placement")
	var blocked_world := app.screen_to_world(ground)
	app.sim.spawn_enemy("grunt", blocked_world)
	_mouse_button(start, true)
	_mouse_button(ground, false)
	check(app.sim.resources == wallet and app.ui.build_kind == "gun_tower" and app.sim.hermes_mode == "following" and app.sim.hermes == following_before, "Rejected tower drag preserves selection and Hermes follow movement for retry")
	var clear_ground := app.world_to_screen(app.sim.hermes.position + Vector2(0, 160))
	_mouse_button(clear_ground, true)
	_mouse_button(clear_ground, false)
	check(app.sim.resources == wallet - 5 and app.ui.build_kind.is_empty() and app.sim.hermes_mode == "building" and not app.sim.hermes.moving and app.sim.hermes.destination == null, "A clear-ground tap retries rejected placement, charges once, and stops Hermes")
	check(app.ui.build_open and app.sim.focused_character == "hermes", "Successful placement keeps Build available for another tower")
	app.ui.update_game(app.sim)
	check(String(app.ui.buttons.follow.text).contains("1"), "Follow displays the rounded refund before dismantling")
	app.command("follow")
	check(app.sim.resources == wallet - 4 and not app.ui.build_open and app.sim.focused_character == "nathaniel" and app.sim.hermes_mode == "following", "Follow dismantles the paid tower, refunds one resource, closes Build, and returns to Nathaniel")
	check(app.ui.get_node("%Notice").text == "Hermes following.", "Follow replaces the old tower-placement notice with Hermes current action")
	app.command("stop")
	_mouse_button(ground, true)
	check(app.sim.nathaniel.destination == null, "Initial touch-compatible press does not issue a movement command")
	var first := InputEventScreenTouch.new()
	first.index = 0
	first.pressed = true
	first.position = ground
	app.game_input._input(first)
	var second := InputEventScreenTouch.new()
	second.index = 1
	second.pressed = true
	second.position = ground + Vector2(80, 0)
	app.game_input._input(second)
	first.pressed = false
	app.game_input._input(first)
	second.pressed = false
	app.game_input._input(second)
	_mouse_button(ground, false)
	check(app.sim.nathaniel.destination == null, "A two-finger gesture cannot leave a terrain movement command")
	app.command("build")
	var destination := app.screen_to_world(Vector2(800, 500))
	_mouse_button(Vector2(800, 500), true)
	_mouse_button(Vector2(800, 500), false)
	check(app.sim.nathaniel.destination is Vector2 and Vector2(app.sim.nathaniel.destination).distance_to(destination) < 0.01 and app.sim.focused_character == "hermes", "Ground tap still moves Nathaniel while Hermes has camera focus")
	_key_stroke(KEY_ESCAPE)
	check(not app.ui.build_open and not app.sim.paused and app.sim.focused_character == "nathaniel", "Escape closes Build before pausing gameplay")
	app.command("stop")
	_mouse_button(Vector2(800, 500), true)
	_key_stroke(KEY_ESCAPE)
	_mouse_button(Vector2(800, 500), false)
	check(app.sim.nathaniel.destination == null and app.sim.paused, "Pause cancels a pending ground tap")
	app.command("resume")
	app.command("hermes_stop")
	app.command("build")
	app.world_click(app.world_to_screen(app.sim.nathaniel.position) - Vector2(0, 20))
	check(app.sim.focused_character == "nathaniel" and not app.ui.build_open, "World character selection closes the build tray like HUD selection")
	app.command("build")
	app.ui.update_game(app.sim)
	await process_frame
	await process_frame
	var bridge := GameDebugBridge.new(app)
	start = tower_button.get_global_rect().get_center()
	var debug_wallet := app.sim.resources
	check(bridge.tap(start) and app.ui.build_kind == "gun_tower" and app.game_input.drag_kind.is_empty(), "Debug tower tap arms click placement without a pointer drag")
	check(bridge.tap(clear_ground) and app.sim.resources == debug_wallet - 5 and app.ui.build_kind.is_empty(), "Debug world tap places the selected tower and charges five resources once")
	check(not bridge.swipe(start, hermes_readout.get_global_rect().get_center(), 0.2) and app.sim.resources == debug_wallet - 5, "Debug tower swipe rejects destinations covered by HUD controls")
	var swipe_ground := app.world_to_screen(app.sim.hermes.position - Vector2(160, 0))
	check(bridge.swipe(start, swipe_ground, 0.2) and app.sim.resources == debug_wallet - 10, "Debug tower swipe inside Hermes range from an enabled visible button still places once")
	app.sim.resources = 4
	app.ui.update_game(app.sim)
	check(app.ui.buttons.gun_tower.disabled and app.ui.buttons.laser_tower.disabled and app.ui.buttons.heal_tower.disabled, "Unaffordable tower choices are disabled")
	app.command("stop")
	check(not bridge.tap(start) and app.ui.build_kind.is_empty() and app.sim.nathaniel.destination == null, "Disabled debug tower tap cannot select a tower or command movement behind the HUD")
	check(not bridge.swipe(start, ground, 0.2) and app.sim.resources == 4 and app.sim.nathaniel.destination == null, "Disabled debug tower swipe cannot fall through to terrain movement")
	app.sim.resources = debug_wallet
	app.ui.update_game(app.sim)
	app.command("build")
	app.ui.update_game(app.sim)
	check(not bridge.swipe(start, ground, 0.2) and app.sim.nathaniel.destination == null, "Hidden debug tower controls cannot start a placement swipe")
	check(bridge.swipe(Vector2(800, 500), Vector2(820, 500), 0.2) and app.sim.nathaniel.destination is Vector2, "Debug swipes starting in the world retain the terrain-tap fallback")
	app.command("pause")
	check(not bridge.tap(start) and app.ui.build_kind.is_empty() and app.sim.resources == debug_wallet, "Paused debug taps cannot activate covered tower controls")
	app.command("main")
	app.fog.enabled = app.settings.fog_enabled
	root.size = previous_size
	root.notify_mouse_exited()
	await process_frame


func _test_pointer_tracking(app: GameApp) -> void:
	app.load_level(0)
	app.sim.configure({"number": 0, "width": 64, "height": 64, "tile_size": 32,
		"blocked": [], "player_start": Vector2(640, 640),
		"hermes_start": Vector2(480, 640), "enemies": [], "wave_based": false})
	app.command("build")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(900, 440)
	app.game_input._input(motion)
	check(app.game_input.pointer_position == motion.position, "Mouse motion updates the cached viewport pointer")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = Vector2(930, 470)
	mouse.pressed = true
	app.game_input._input(mouse)
	check(app.game_input.pointer_position == mouse.position, "Mouse button input updates the pointer without requiring a preceding motion event")
	app.game_input.begin_tower_drag("gun_tower")
	check(app.game_input.drag_start == mouse.position, "Tower drag starts at the event position without querying a native mouse")
	app.game_input.cancel_tower_drag()
	mouse.pressed = false
	app.game_input._input(mouse)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(550, 350)
	touch.pressed = true
	app.game_input._input(touch)
	check(app.game_input.pointer_position == touch.position, "Touch press updates the cached pointer for touch-only platforms")
	app.game_input.begin_tower_drag("gun_tower")
	check(app.game_input.drag_start == touch.position, "A touch-started tower drag uses the current touch position")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(580, 370)
	app.game_input._input(drag)
	check(app.game_input.pointer_position == drag.position, "Touch drag updates the placement pointer")
	app._physics_process(0)
	check(app.effects.placement and app.effects.cursor_world.is_equal_approx(app.screen_to_world(drag.position)), "Tower preview uses the cached touch position in world coordinates")
	app.game_input.cancel_tower_drag()
	touch.pressed = false
	touch.position = Vector2(590, 375)
	app.game_input._input(touch)
	check(app.game_input.pointer_position == touch.position and app.game_input.touches.is_empty(), "Touch release retains the final pointer position and clears the active touch")
	app.command("main")


func _test_build_mode_commands(app: GameApp) -> void:
	app.load_level(0)
	app.sim.configure({"number": 0, "width": 64, "height": 64, "tile_size": 32,
		"blocked": [], "player_start": Vector2(640, 640),
		"hermes_start": Vector2(480, 640), "enemies": [], "wave_based": false})
	app.command("follow")
	app.sim.step(0.5)
	var before: Dictionary = app.sim.snapshot()
	app.command("gun_tower")
	check(app.ui.build_kind.is_empty() and not app.place_at("gun_tower", app.world_to_screen(Vector2(1000, 1000))) and app.sim.snapshot() == before, "Closed Build cannot arm or place a tower or interrupt following")
	app.command("build")
	check(app.effects.build_open, "Opening Build shows the build range before a tower is chosen")
	var placement_before: Dictionary = app.sim.snapshot()
	var outside := app.world_to_screen(app.sim.hermes.position + Vector2(app.sim.hermes_build_range() + 1.0, 0))
	check(not app.place_at("gun_tower", outside) and app.sim.snapshot() == placement_before, "Out-of-range UI placement neither spends resources nor deploys Hermes")
	check(String(app.ui.get_node("%Notice").text).contains("amber ring"), "Out-of-range placement explains the visible boundary")
	app.game_input.begin_tower_drag("gun_tower")
	check(app.game_input.drag_kind == "gun_tower", "A tower drag can start while Hermes follows")
	app.command("hermes_stop")
	check(app.sim.hermes_mode == "building" and not app.sim.hermes.moving and app.ui.build_open and app.sim.focused_character == "hermes" and app.game_input.drag_kind.is_empty() and app.ui.build_kind.is_empty(), "Stop cancels a held placement and stops Hermes while keeping Build open")
	app.ui.update_game(app.sim)
	check(String(app.ui.get_node("%Status").text).contains("Anchored") and app.sim.hermes.anchored, "HUD names the deployed cannon state")
	app.game_input.begin_tower_drag("gun_tower")
	app.command("focus", "nathaniel")
	check(not app.ui.build_open and app.sim.focused_character == "nathaniel" and app.game_input.drag_kind.is_empty() and app.ui.build_kind.is_empty(), "Returning to Nathaniel cancels held placement and closes Build")
	check(not app.effects.build_open and app.sim.hermes.anchored, "Closing Build leaves the deployed base active")
	app.command("toggle_hermes")
	check(app.sim.hermes_mode == "following" and not app.ui.build_open, "Hermes toggle starts following without selecting him")
	app.command("toggle_hermes")
	check(app.sim.hermes_mode == "building" and app.sim.focused_character == "nathaniel", "Hermes toggle stops following without selecting him")
	app.command("main")


func _test_legacy_build_focus(app: GameApp, directory: String) -> void:
	var previous_store := app.save_store
	app.save_store = GameSaveStore.new(directory)
	app.load_level(0)
	app.sim.set_hermes_mode("following")
	app.sim.focused_character = "hermes"
	check(app.save_store.save_slot(1, app.sim.snapshot()).success, "Old Hermes-focus fixture writes only temporary storage")
	app.command("main")
	app.command("load_slot", 1)
	check(app.ui.build_open and app.sim.focused_character == "hermes" and app.sim.hermes_mode == "following" and not app.sim.paused, "An old saved Hermes camera restores as Build view without stopping following")
	app.command("focus")
	check(not app.ui.build_open and app.sim.focused_character == "nathaniel" and app.sim.hermes_mode == "following", "Return command leaves an old Hermes-focused save in normal Nathaniel control")
	app.command("main")
	app.save_store = previous_store


func _test_delivery_feedback(app: GameApp) -> void:
	app.load_level(0)
	app.sim.configure({"number": 0, "width": 64, "height": 64, "tile_size": 32,
		"blocked": [], "player_start": Vector2(640, 640),
		"hermes_start": Vector2(480, 640), "enemies": [], "wave_based": false})
	app.fog.enabled = false
	var hermes_click := app.world_to_screen(app.sim.hermes.position) - Vector2(0, 20 * app.camera_zoom)
	app.world_click(hermes_click)
	check(app.sim.focused_character == "nathaniel" and not app.ui.build_open and app.sim.nathaniel.destination == null and app.effects.delivery_pulse_time == 0, "Clicking Hermes without carried resources cannot select him, open Build, or issue movement")
	app.command("build")
	app.world_click(hermes_click)
	check(app.sim.focused_character == "hermes" and app.ui.build_open and app.sim.nathaniel.destination == null and app.effects.delivery_pulse_time == 0, "Clicking Hermes without resources in Build view leaves the current mode unchanged")
	app.command("focus", "nathaniel")
	var wallet := app.sim.resources
	app.sim.spawn_resource(10, app.sim.nathaniel.position)
	BattlefieldRules.update_corpses(app.sim, 0.7)
	check(app.sim.nathaniel.has_corpse and app.sim.resources == wallet, "Delivery feedback fixture collects a corpse without crediting the wallet")
	app.command("pause")
	app.world_click(hermes_click)
	check(app.effects.delivery_pulse_time == 0 and app.sim.nathaniel.destination == null, "Paused Hermes clicks cannot start a delivery order or pulse")
	app.command("resume")
	app.command("hermes_stop")
	app.sim.set_paused(true)
	app.ui.show_notice("")
	app.world_click(app.world_to_screen(Vector2(1000, 1000)))
	check(app.ui.get_node("%Notice").text.is_empty() and app.sim.nathaniel.destination == null, "Paused world movement cannot acknowledge a rejected command without a modal")
	app.world_click(hermes_click)
	check(app.effects.delivery_pulse_time == 0 and app.ui.get_node("%Notice").text.is_empty(), "Paused delivery cannot pulse or acknowledge a rejected command without a modal")
	app.sim.set_paused(false)
	app.command("follow")
	app.world_click(hermes_click)
	check(app.sim.focused_character == "nathaniel" and not app.ui.build_open and app.effects.delivery_pulse_time > 0 and app.sim.nathaniel.destination == app.sim.hermes.position, "Clicking following Hermes returns cargo without deploying him")
	app.command("hermes_stop")
	app.command("focus", "nathaniel")
	app.world_click(hermes_click)
	check(app.sim.focused_character == "nathaniel" and app.sim.nathaniel.destination == app.sim.hermes.position, "Delivery click keeps Nathaniel selected and commands movement to Hermes")
	check(app.effects.delivery_pulse_position == app.sim.hermes.position and app.effects.delivery_pulse_time == app.effects.delivery_pulse_lifetime, "Delivery order starts a full pulse at Hermes")
	check(app.sim.resources == wallet and app.sim.nathaniel.has_corpse and app.ui.get_node("%Notice").text == "Returning cargo to Hermes.", "Delivery acknowledgement states the pending action without crediting resources early")
	app.effects._process(app.effects.delivery_pulse_lifetime * 0.5)
	check(app.effects.delivery_pulse_time > 0 and app.effects.delivery_pulse_time < app.effects.delivery_pulse_lifetime, "Delivery pulse fades over time")
	app.world_click(hermes_click)
	check(app.effects.delivery_pulse_time == app.effects.delivery_pulse_lifetime, "Repeated delivery clicks restart the pulse")
	app.effects._process(app.effects.delivery_pulse_lifetime + 0.1)
	check(app.effects.delivery_pulse_time == 0 and app.sim.resources == wallet, "Delivery pulse expires without changing the resource wallet")
	app.command("build")
	app.world_click(hermes_click)
	check(app.sim.focused_character == "nathaniel" and not app.ui.build_open and app.sim.nathaniel.destination == app.sim.hermes.position and app.effects.delivery_pulse_time == app.effects.delivery_pulse_lifetime, "Delivery from Build returns the camera to the cargo carrier")
	app.command("main")
	app.fog.enabled = app.settings.fog_enabled


func _test_target_feedback(app: GameApp) -> void:
	app.load_level(0)
	app.sim.configure({"number": 0, "width": 64, "height": 64, "tile_size": 32,
		"blocked": [], "player_start": Vector2(640, 640),
		"hermes_start": Vector2(480, 640), "enemies": [], "wave_based": false})
	var soldier := app.sim.spawn_enemy("soldier", Vector2(640, 800))
	var grunt := app.sim.spawn_enemy("grunt", Vector2(480, 800))
	app.sim.nathaniel.target_id = grunt.id
	app.sim.hermes.target_id = grunt.id
	app.ui.update_game(app.sim)
	var nathaniel_target := app.ui.get_node("%NathanielTarget") as Label
	var hermes_target := app.ui.get_node("%HermesTarget") as Label
	check(nathaniel_target.text.contains("Grunt") and nathaniel_target.text.contains("Auto") and hermes_target.text.contains("Grunt") and hermes_target.text.contains("Auto"), "Both target HUDs identify automatic combat targets")
	app.command("build")
	var soldier_click := app.world_to_screen(soldier.position) - Vector2(0, 20 * app.camera_zoom)
	var grunt_click := app.world_to_screen(grunt.position) - Vector2(0, 20 * app.camera_zoom)
	app.world_click(soldier_click)
	check(app.sim.nathaniel.target_id == soldier.id and app.sim.nathaniel.manual_target_id == soldier.id and app.sim.hermes.target_id == grunt.id and app.sim.focused_character == "hermes", "Enemy click commands Nathaniel without changing Hermes target or camera focus")
	check(app.effects.target_pulse_id == soldier.id and app.effects.target_pulse_time == app.effects.target_pulse_lifetime, "Accepted enemy click starts a target pulse")
	app.ui.update_game(app.sim)
	check(nathaniel_target.text.contains("Soldier") and nathaniel_target.text.contains("200 HP") and nathaniel_target.text.contains("Selected") and nathaniel_target.text.contains("In range"), "Nathaniel target HUD identifies the selected enemy, health, and weapon range")
	check(hermes_target.text.contains("Grunt") and hermes_target.text.contains("Auto"), "Manual Nathaniel targeting leaves Hermes automatic target HUD unchanged")
	app.effects.fog_enabled = true
	var markers := app.effects.target_markers()
	check(markers.size() == 2 and markers[0].target.id == soldier.id and markers[0].label == "N" and markers[1].target.id == grunt.id and markers[1].label == "H", "World markers identify each character's distinct target")
	app.effects._process(app.effects.target_pulse_lifetime * 0.5)
	check(app.effects.target_pulse_time > 0 and app.effects.target_pulse_time < app.effects.target_pulse_lifetime, "Target pulse fades over time")
	app.world_click(soldier_click)
	check(app.effects.target_pulse_time == app.effects.target_pulse_lifetime, "Repeated enemy clicks restart target acknowledgement")
	app.effects._process(app.effects.target_pulse_lifetime + 0.1)
	check(app.effects.target_pulse_time == 0 and app.effects.target_markers().size() == 2, "Pulse expiry retains current target markers")
	app.command("pause")
	app.world_click(grunt_click)
	check(app.effects.target_pulse_time == 0 and app.sim.nathaniel.target_id == soldier.id, "Paused enemy clicks cannot change target or start a pulse")
	app.command("resume")
	app.sim.set_paused(true)
	app.world_click(soldier_click)
	check(app.effects.target_pulse_time == 0, "A rejected paused command cannot acknowledge the already selected enemy")
	app.sim.set_paused(false)
	var player_hp: int = app.sim.nathaniel.hp
	app.sim.nathaniel.hp = 0
	app.world_click(soldier_click)
	app.ui.update_game(app.sim)
	markers = app.effects.target_markers()
	check(app.effects.target_pulse_time == 0 and nathaniel_target.text.contains("None") and markers.size() == 1 and markers[0].label == "H", "A down Nathaniel has no target HUD or marker and cannot acknowledge a target order")
	app.sim.nathaniel.hp = player_hp
	app.sim.fog.fill(1)
	app.fog.enabled = false
	app.world_click(grunt_click)
	check(app.effects.target_pulse_time == 0 and app.sim.nathaniel.target_id == soldier.id, "A command rejected by domain visibility cannot show an accepted target pulse")
	app.ui.update_game(app.sim, true)
	check(nathaniel_target.text.contains("Out of sight") and not nathaniel_target.text.contains("HP") and hermes_target.text.contains("Out of sight") and not hermes_target.text.contains("HP") and app.effects.target_markers().is_empty(), "Fog hides target health and world markers for both characters")
	app.ui.update_game(app.sim, false)
	app.effects.fog_enabled = false
	check(nathaniel_target.text.contains("200 HP") and hermes_target.text.contains("150 HP") and app.effects.target_markers().size() == 2, "Disabling fog restores target information and markers")
	soldier.position = Vector2(1200, 640)
	app.sim.damage_entity(soldier.id, 12)
	app.ui.update_game(app.sim, false)
	check(nathaniel_target.text.contains("188 HP") and nathaniel_target.text.contains("Out of range"), "Target HUD follows current health and distance instead of stale click state")
	app.sim.hermes.target_id = soldier.id
	markers = app.effects.target_markers()
	check(markers.size() == 2 and markers[0].target.id == soldier.id and markers[1].target.id == soldier.id and markers[0].label == "N" and markers[1].label == "H" and markers[0].color != markers[1].color, "A shared target retains distinct Nathaniel and Hermes markers")
	app.sim.damage_entity(soldier.id, 1000)
	app.ui.update_game(app.sim, false)
	check(nathaniel_target.text.contains("None") and hermes_target.text.contains("None") and app.effects.target_markers().is_empty(), "A destroyed target disappears from both HUDs and world markers immediately")
	app.sim.damage_entity(grunt.id, 1000)
	app.sim.step(0)
	app.sim.nathaniel.target_id = soldier.id
	app.sim.hermes.target_id = grunt.id
	app.ui.update_game(app.sim, false)
	check(app.sim.entity(soldier.id).is_empty() and app.sim.entity(grunt.id).is_empty() and nathaniel_target.text.contains("None") and hermes_target.text.contains("None") and app.effects.target_markers().is_empty(), "Removed targets cannot leave stale HUD or marker state")
	app.command("main")
	app.fog.enabled = app.settings.fog_enabled
	app.effects.fog_enabled = app.settings.fog_enabled


func _test_target_hud_input(app: GameApp) -> void:
	var previous_size := root.size
	var previous_scale_size := root.content_scale_size
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	root.notify_mouse_entered()
	app.load_level(0)
	app.sim.configure({"number": 0, "width": 64, "height": 64, "tile_size": 32,
		"blocked": [], "player_start": Vector2(640, 640),
		"hermes_start": Vector2(480, 640), "enemies": [], "wave_based": false})
	var enemy := app.sim.spawn_enemy("spawner", Vector2(640, 800))
	app.sim.target_enemy(enemy.id)
	app.sim.hermes.target_id = enemy.id
	app.ui.update_game(app.sim)
	await process_frame
	await process_frame
	var top: Rect2 = app.ui.get_node("Top").get_global_rect()
	var nathaniel_target := app.ui.get_node("%NathanielTarget") as Label
	var hermes_target := app.ui.get_node("%HermesTarget") as Label
	check(Rect2(Vector2.ZERO, Vector2(960, 540)).encloses(top) and top.encloses(nathaniel_target.get_global_rect()) and top.encloses(hermes_target.get_global_rect()) and top.encloses(app.ui.get_node("%Pause").get_global_rect()), "Target readouts and Pause fit inside the top HUD at 960 by 540")
	check(app.ui.get_node("%Notice").get_global_rect().position.y >= top.end.y, "Target acknowledgement remains below the top HUD at 960 by 540")
	for readout: Label in [nathaniel_target, hermes_target]:
		var point := readout.get_global_rect().get_center()
		_mouse_button(point, true)
		_mouse_button(point, false)
	check(app.sim.nathaniel.destination == null and app.sim.nathaniel.target_id == enemy.id and app.sim.nathaniel.manual_target_id == enemy.id, "Mouse clicks on either target readout cannot move or retarget Nathaniel behind the HUD")
	app.world_click(app.world_to_screen(Vector2(1000, 800)))
	app.ui.update_game(app.sim)
	check(app.sim.nathaniel.destination is Vector2 and app.sim.nathaniel.target_id == enemy.id and app.sim.nathaniel.manual_target_id == -1 and nathaniel_target.text.contains("Auto") and not nathaniel_target.text.contains("Selected"), "A ground movement order changes the retained target from Selected to Auto in the HUD")
	app.command("main")
	root.content_scale_size = previous_scale_size
	root.size = previous_size
	root.notify_mouse_exited()
	await process_frame


func _test_slot_menu_paths(app: GameApp, directory: String) -> void:
	app.save_store = GameSaveStore.new(directory)
	app.load_level(0)
	app.command("pause")
	for slot: int in range(1, 4):
		app.sim.resources = slot * 100
		app.command("save_menu")
		var button := _find_menu_button(app, "Slot %d · Empty" % slot)
		check(button != null and not button.disabled, "Empty save slot %d is visibly available" % slot)
		if button == null:
			return
		button.pressed.emit()
		check(app.ui.menu == "pause" and app.save_store.load_slot(slot).state.resources == slot * 100, "Native save button writes slot %d and returns to Pause" % slot)
	app.command("save_menu")
	check(_slot_buttons(app).size() == 3, "Save selector renders exactly three slots")
	var saved_bytes := FileAccess.get_file_as_bytes(app.save_store.slot_path(2))
	app.sim.resources = 777
	_find_menu_button(app, "Slot 2 · Level 0 · 200 resources").pressed.emit()
	check(app.ui.menu == "confirm_save", "Occupied native slot opens replacement confirmation")
	_find_menu_button(app, "Cancel").pressed.emit()
	check(app.ui.menu == "save" and FileAccess.get_file_as_bytes(app.save_store.slot_path(2)) == saved_bytes, "Cancel returns to slot selector without replacing a save")
	_find_menu_button(app, "Slot 2 · Level 0 · 200 resources").pressed.emit()
	_find_menu_button(app, "Replace slot 2").pressed.emit()
	check(app.ui.menu == "pause" and app.save_store.load_slot(2).state.resources == 777, "Explicit replacement changes only the selected slot")
	check(app.save_store.load_slot(1).state.resources == 100 and app.save_store.load_slot(3).state.resources == 300, "Replacement preserves both other slots")
	app.command("main")
	for slot: int in range(1, 4):
		app.command("load_menu")
		var amount: int = 777 if slot == 2 else slot * 100
		var button := _find_menu_button(app, "Slot %d · Level 0 · %d resources" % [slot, amount])
		check(button != null and not button.disabled, "Existing slot %d has its saved display label" % slot)
		if button == null:
			return
		button.pressed.emit()
		check(app.sim.resources == amount and app.ui.menu.is_empty() and not app.sim.paused, "Native load restores selected slot %d and resumes" % slot)
		app.command("main")
	app.save_store.delete_slot(1)
	var file := FileAccess.open(app.save_store.slot_path(3), FileAccess.WRITE)
	file.store_string("not a save")
	file.close()
	app.command("load_menu")
	var empty := _find_menu_button(app, "Slot 1 · Empty")
	var corrupt := _find_menu_button(app, "Slot 3 · Cannot read save")
	check(empty != null and empty.disabled and corrupt != null and corrupt.disabled, "Load selector identifies and disables empty/corrupt slots")
	check(corrupt != null and not corrupt.tooltip_text.is_empty(), "Corrupt slot includes an error explanation")
	_find_menu_button(app, "Cancel").pressed.emit()
	check(app.ui.menu == "main" and app.sim == null, "Cancel from main-menu Load returns to main menu")
	app.load_level(0)
	app.command("pause")
	app.command("save_menu")
	_find_menu_button(app, "Slot 3 · Cannot read save").pressed.emit()
	check(app.ui.menu == "confirm_save", "Corrupt occupied slots also require replacement confirmation")
	_find_menu_button(app, "Cancel").pressed.emit()
	_find_menu_button(app, "Cancel").pressed.emit()
	check(app.ui.menu == "pause" and app.sim.paused, "Cancel from gameplay Save returns to paused session")


func _test_modal_regressions(app: GameApp) -> void:
	app.command("resume")
	app.ui.build_kind = "gun_tower"
	app.ui.build_open = true
	app.game_input.drag_kind = "gun_tower"
	app.command("pause")
	app.command("settings")
	app.command("escape")
	check(app.ui.menu == "pause", "Escape closes Settings before clearing an old placement")
	check(app.ui.build_kind.is_empty() and not app.ui.build_open and app.game_input.drag_kind.is_empty() and app.sim.focused_character == "nathaniel", "Opening a modal cancels placement and pointer drag and returns the camera to Nathaniel")
	app.command("escape")
	check(app.ui.menu.is_empty() and not app.sim.paused, "Second Escape resumes after Settings closes")
	app.command("pause")
	var saved_sim := app.sim
	_find_menu_button(app, "Main menu").pressed.emit()
	check(app.ui.menu == "confirm_exit" and app.sim == saved_sim and app.sim.paused, "Pause exit confirms before discarding unsaved session")
	if app.ui.menu == "confirm_exit":
		_find_menu_button(app, "Cancel").pressed.emit()
		check(app.ui.menu == "pause" and app.sim == saved_sim, "Exit cancellation preserves paused session")
		_find_menu_button(app, "Main menu").pressed.emit()
		app.command("escape")
		check(app.ui.menu == "pause" and app.sim.paused, "Escape closes exit confirmation without resuming")
		_find_menu_button(app, "Main menu").pressed.emit()
		_find_menu_button(app, "Exit to main menu").pressed.emit()
		check(app.ui.menu == "main" and app.sim == null, "Confirmed exit discards session")
	app.command("settings")
	var original_path := app.settings.path
	# Existing directory as target makes atomic replacement fail without touching real settings.
	app.settings.path = app.save_store.directory
	app.command("setting", {"fog_enabled": not app.settings.fog_enabled})
	var notice: Label = app.ui.get_node("%Notice")
	check(notice.text.begins_with("Could not save settings:"), "Settings persistence failure is visible to the player")
	app.settings.path = original_path
	app.command("back")


func _find_menu_button(app: GameApp, text: String) -> Button:
	for child: Node in app.ui.get_node("%Content").get_children():
		if child is Button and child.text == text:
			return child
	return null


func _slot_buttons(app: GameApp) -> Array[Button]:
	var result: Array[Button] = []
	for child: Node in app.ui.get_node("%Content").get_children():
		if child is Button and child.text.begins_with("Slot "):
			result.append(child)
	return result


func _test_audio_settings(app: GameApp) -> void:
	app.audio.apply_settings(false, true)
	check(not app.audio.music_enabled and app.audio.sound_enabled, "Audio accepts independent boolean preferences without a settings store")
	app.audio.play_music("menuMusic")
	app.settings.music_enabled = true
	app.audio.apply_settings(app.settings.music_enabled, app.settings.sound_effects_enabled)
	await process_frame
	check(app.audio.music.playing and not app.audio.music.stream_paused, "Enabled music starts its requested stream")
	app.settings.music_enabled = false
	app.audio.apply_settings(app.settings.music_enabled, app.settings.sound_effects_enabled)
	await process_frame
	check(app.audio.music.stream_paused, "Disabling music pauses the active stream")
	app.settings.music_enabled = true
	app.audio.apply_settings(app.settings.music_enabled, app.settings.sound_effects_enabled)
	await process_frame
	check(app.audio.music.playing and not app.audio.music.stream_paused, "Re-enabling music resumes an already-playing paused stream")
	app.settings.music_enabled = false
	app.audio.apply_settings(app.settings.music_enabled, app.settings.sound_effects_enabled)
	app.audio.play_music("gameMusic2")
	await process_frame
	check(app.audio.requested_track == "gameMusic2" and app.audio.music.stream.resource_path.ends_with("gameMusic2.mp3"), "Track changes while disabled preserve the requested level music")
	app.settings.music_enabled = true
	app.audio.apply_settings(app.settings.music_enabled, app.settings.sound_effects_enabled)
	await process_frame
	check(app.audio.music.playing and not app.audio.music.stream_paused and app.audio.music.stream.resource_path.ends_with("gameMusic2.mp3"), "Re-enabling starts the latest requested track")
	# The audio mixer runs independently of headless frames; let the last play
	# reach it before the caller stops and frees the player.
	await create_timer(0.05).timeout


func _test_import_composition(app: GameApp, directory: String) -> void:
	app.save_store = GameSaveStore.new(directory.path_join("saves"))
	var character := {"position": {"x": 125, "y": 250}, "currentHP": 100, "maxHP": 100}
	var source := {
		"saveVersion": 2, "levelNumber": 2, "elapsedTime": 10, "score": 42, "lives": 3, "resources": 71,
		"nathaniel": character, "hermes": {"characterState": character, "mode": "following"},
		"enemies": [], "towers": [],
	}
	var source_path := directory.path_join("swift.json")
	check(GameAtomicJSON.write_file(source_path, source).success, "Legacy import fixture writes to isolated storage")
	var source_bytes := FileAccess.get_file_as_bytes(source_path)
	var imported := app.import_swift_save(source_path, 1)
	check(imported.success, "Application resolves the saved level for explicit legacy import")
	check(FileAccess.get_file_as_bytes(source_path) == source_bytes, "Application import never changes the source file")
	if imported.success:
		var scene := load("res://levels/level_2.tscn").instantiate() as GameLevel
		check(imported.state.level.blocked == scene.data().blocked, "Import uses the authored level collision data")
		scene.free()
		app.command("main")
		app.command("load_slot", 1)
		check(app.sim != null and app.sim.level_number == 2 and app.sim.resources == 71, "Imported slot loads its level and saved gameplay through the application")
	var saved_bytes := FileAccess.get_file_as_bytes(app.save_store.slot_path(1))
	check(not app.import_swift_save(source_path, 1).success, "Application import rejects an occupied slot")
	check(FileAccess.get_file_as_bytes(app.save_store.slot_path(1)) == saved_bytes, "Rejected application import preserves slot bytes")
	check(not app.import_swift_save(directory.path_join("missing.json"), 2).success, "Application import returns missing-file failure")
	source.levelNumber = 6
	GameAtomicJSON.write_file(source_path, source)
	check(not app.import_swift_save(source_path, 2).success, "Application import rejects an unavailable saved level")
	GameAtomicJSON.write_file(source_path, {"malformed": true})
	check(not app.import_swift_save(source_path, 2).success, "Application import returns malformed-state failure")
	check(not FileAccess.file_exists(app.save_store.slot_path(2)), "Failed application imports leave the destination empty")


func _test_debug_clipping(app: GameApp) -> void:
	app.command("main")
	var clipped := Control.new()
	clipped.position = Vector2(20, 20)
	clipped.size = Vector2(100, 100)
	clipped.clip_contents = true
	app.ui.get_node("%Modal").add_child(clipped)
	var button := Button.new()
	button.text = "Clipped test control"
	button.position = Vector2(0, 200)
	button.size = Vector2(80, 40)
	clipped.add_child(button)
	var bridge := GameDebugBridge.new(app)
	var hidden_found: bool = false
	for node: Dictionary in bridge.nodes():
		if node.name == button.text:
			hidden_found = true
	check(not hidden_found, "Debug nodes exclude buttons outside a scroll clipping region")
	button.position = Vector2(0, 80)
	var exposed: Dictionary = {}
	for node: Dictionary in bridge.nodes():
		if node.name == button.text:
			exposed = node
	check(not exposed.is_empty() and is_equal_approx(float(exposed.frame.height), 20.0), "Partially visible controls report only their visible bounds")
	check(not bridge.tap(Vector2(30, 130)), "Debug tap cannot activate a clipped portion of a button")
	clipped.queue_free()


func _test_small_menu_scrolling(app: GameApp) -> void:
	app.command("main")
	var original_size := app.ui.size
	app.ui.size = Vector2(640, 360)
	await process_frame
	await process_frame
	var scroll: ScrollContainer = app.ui.get_node("%Scroll")
	check(scroll.size.y <= app.ui.size.y - 70.0 and scroll.get_v_scroll_bar().visible, "Menu scroll viewport fits a short window and exposes its scrollbar")
	var bridge := GameDebugBridge.new(app)
	var before: Array = bridge.nodes()
	check(not before.any(func(node: Dictionary) -> bool: return node.name == "Quit"), "Controls below the menu viewport are not exposed as visible")
	await _test_native_scroll_input(app, scroll)
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await process_frame
	var after: Array = bridge.nodes()
	check(after.any(func(node: Dictionary) -> bool: return node.name == "Quit"), "Scrolling reveals the final menu control")
	check(not after.any(func(node: Dictionary) -> bool: return node.name == "New campaign"), "Scrolled-away controls no longer appear in debug nodes")
	app.ui.size = original_size
	app.command("main")
	await process_frame


func _test_native_scroll_input(app: GameApp, scroll: ScrollContainer) -> void:
	# The native touchscreen scroll path uses emulated mouse events. Enable the
	# touchscreen hint on the headless display and send that sequence via Viewport.
	var was_emulating_touch := Input.emulate_touch_from_mouse
	Input.emulate_touch_from_mouse = true
	root.notify_mouse_entered()
	app.ui.command.disconnect(app.command)
	var commands: Array[String] = []
	var record_command := func(action: String, _value: Variant) -> void: commands.append(action)
	app.ui.command.connect(record_command)
	var starts: Array[bool] = []
	var record_start := func() -> void: starts.append(true)
	scroll.scroll_started.connect(record_start)
	var button := _find_menu_button(app, "New campaign")
	var start := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = start
	root.push_input(motion, true)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	press.position = start
	root.push_input(press, true)
	motion.position = start - Vector2(0, 12)
	motion.relative = Vector2(0, -12)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	press.pressed = false
	press.button_mask = 0
	press.position = motion.position
	root.push_input(press, true)
	await process_frame
	check(not starts.is_empty() and scroll.scroll_vertical > 0, "Dragging on a native menu button reaches ScrollContainer and starts scrolling")
	check(commands.is_empty(), "A native scroll gesture cancels menu button activation")
	scroll.scroll_vertical = 0
	await process_frame
	start = button.get_global_rect().get_center()
	motion.position = start
	motion.relative = Vector2.ZERO
	motion.button_mask = 0
	root.push_input(motion, true)
	press.position = start
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(press, true)
	press.pressed = false
	press.button_mask = 0
	root.push_input(press, true)
	check(commands == ["level"], "An ordinary native tap still activates a menu button once")
	app.ui.command.disconnect(record_command)
	app.ui.command.connect(app.command)
	scroll.scroll_started.disconnect(record_start)
	root.notify_mouse_exited()
	Input.emulate_touch_from_mouse = was_emulating_touch
	check(app.ui.buttons.fire.mouse_filter == Control.MOUSE_FILTER_STOP, "HUD controls retain pointer capture outside the scroll menu")
