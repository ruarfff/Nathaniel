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
	check(app.sim.focused_character == "nathaniel" and app.sim.hermes_mode == "following" and app.ui.ring_character == "hermes", "Hermes focus opens Build without changing the player or his mode")
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
	var hermes_icon := app.ui.get_node("%Hermes") as Button
	_mouse_button(hermes_icon.get_global_rect().get_center(), true)
	_mouse_button(hermes_icon.get_global_rect().get_center(), false)
	check(app.sim.focused_character == "nathaniel" and app.ui.ring_character == "hermes" and app.sim.nathaniel.destination == null, "Hermes icon opens Build while Nathaniel remains the player")
	check(app.ui.get_node("%Nathaniel").button_pressed and hermes_icon.button_pressed and app.ui.buttons.fire.disabled, "Nathaniel stays selected while the Hermes icon shows active Build")
	_mouse_button(hermes_icon.get_global_rect().get_center(), true)
	_mouse_button(hermes_icon.get_global_rect().get_center(), false)
	check(app.ui.ring_character == "hermes" and hermes_icon.button_pressed, "Repeated Hermes icon clicks keep Build open and the selector pressed")
	var away := Vector2(80, app.ui.play_rect().get_center().y)
	_mouse_button(away, true)
	_mouse_button(away, false)
	check(app.ui.ring_character.is_empty() and not app.ui.build_open and app.sim.focused_character == "nathaniel" and app.sim.nathaniel.destination == null, "Clicking away returns to Nathaniel without a world order")
	check(not app.ui.buttons.fire.disabled and not hermes_icon.button_pressed, "Closing Build restores Nathaniel controls and clears the Hermes icon")
	_key_stroke(KEY_SPACE)
	_key_stroke(KEY_B)
	check(app.ui.ring_character == "hermes" and app.sim.hermes_mode == "following", "B opens Hermes ring without deploying")
	_key_stroke(KEY_SPACE)
	check(app.ui.ring_character.is_empty() and app.sim.focused_character == "nathaniel", "Space focuses Nathaniel and clears commands")
	app.open_context_ring()
	app.ui.update_game(app.sim)
	await process_frame
	var tower_button: Button = app.ui.ring_buttons.gun_tower
	var start := tower_button.get_global_rect().get_center()
	var ground := app.world_to_screen(app.sim.hermes.position + Vector2(160, 0))
	var wallet := app.sim.resources
	_mouse_button(start, true)
	check(app.game_input.drag_kind == "gun_tower" and app.ui.build_kind == "gun_tower" and app.ui.ring_character.is_empty(), "Ring button-down arms placement and hides the ring")
	_key_stroke(KEY_ESCAPE)
	_mouse_button(ground, false)
	check(app.sim.resources == wallet and app.ui.build_kind.is_empty() and app.game_input.drag_kind.is_empty() and app.ui.ring_character == "hermes", "Escape returns to Build and cancels a held tower without placement on release")
	_key_stroke(KEY_ESCAPE)
	check(not app.ui.build_open and not app.sim.paused, "The next Escape closes Build and restores Nathaniel control")
	_key_stroke(KEY_ESCAPE)
	check(app.sim.paused, "Escape pauses only after Build has closed")
	app.command("resume")
	app.command("cancel_placement")
	await process_frame
	start = tower_button.get_global_rect().get_center()
	_mouse_button(start, true)
	_mouse_button(hermes_icon.get_global_rect().get_center(), false)
	check(app.sim.resources == wallet and app.ui.build_kind.is_empty(), "Dropping a tower over a character icon cannot place behind it")
	app.command("cancel_placement")
	await process_frame
	start = tower_button.get_global_rect().get_center()
	var blocked_world := app.screen_to_world(ground)
	app.sim.spawn_enemy("grunt", blocked_world)
	_mouse_button(start, true)
	_mouse_button(ground, false)
	check(app.sim.resources == wallet and app.ui.build_kind == "gun_tower" and app.sim.hermes_mode == "following", "Rejected tower drag preserves the preview and following")
	var clear_ground := app.world_to_screen(app.sim.hermes.position + Vector2(0, 160))
	_mouse_button(clear_ground, true)
	_mouse_button(clear_ground, false)
	check(app.sim.resources == wallet - 5 and app.ui.build_kind.is_empty() and app.sim.hermes_mode == "building" and app.ui.ring_character == "hermes" and app.game_input.drag_kind.is_empty(), "Clear-ground retry pays once and returns to Build")
	check(app.ui.ring_buttons.pack.text.contains("+1 matter"), "Pack shows the actual rounded refund")
	app.command("pack")
	check(app.sim.resources == wallet - 4 and app.sim.hermes_mode == "following" and app.sim.focused_character == "nathaniel" and not app.ui.build_open, "Pack refunds once and returns to Nathaniel")
	app.open_context_ring()
	var destination: Variant = app.sim.nathaniel.destination
	_mouse_button(Vector2(1100, 300), true)
	_mouse_button(Vector2(1100, 300), false)
	check(app.ui.ring_character.is_empty() and app.sim.nathaniel.destination == destination, "Outside click dismisses without moving")
	_mouse_button(Vector2(1100, 300), true)
	_key_stroke(KEY_ESCAPE)
	_mouse_button(Vector2(1100, 300), false)
	check(app.sim.nathaniel.destination == destination and app.sim.paused, "Pause cancels a held world tap")
	app.command("resume")
	app.open_context_ring()
	await process_frame
	var bridge := GameDebugBridge.new(app)
	start = tower_button.get_global_rect().get_center()
	check(bridge.tap(start) and app.ui.build_kind == "gun_tower" and app.game_input.drag_kind.is_empty(), "Debug tower tap arms placement without a held pointer")
	clear_ground = app.world_to_screen(app.sim.hermes.position + Vector2(0, 160))
	check(bridge.tap(clear_ground) and app.sim.resources == wallet - 9 and app.ui.build_kind.is_empty() and app.ui.ring_character == "hermes", "Debug ground tap places once and returns to Build")
	await process_frame
	start = tower_button.get_global_rect().get_center()
	check(not bridge.swipe(start, hermes_icon.get_global_rect().get_center(), 0.2), "Debug swipe rejects a HUD destination")
	check(app.ui.ring_character == "hermes" and app.ui.build_kind.is_empty(), "Debug swipe over the HUD restores Build after cancellation")
	var swipe_ground := app.world_to_screen(app.sim.hermes.position - Vector2(160, 0))
	check(bridge.swipe(start, swipe_ground, 0.2), "Debug swipe places from a visible enabled ring slot")
	check(app.ui.ring_character == "hermes" and app.ui.build_kind.is_empty(), "Debug swipe returns to Build without reopening it explicitly")
	app._update_camera(0.28)
	await process_frame
	start = tower_button.get_global_rect().get_center()
	var drag_wallet := app.sim.resources
	var drag_ground := app.world_to_screen(app.sim.hermes.position + Vector2(0, -160))
	_mouse_button(start, true)
	_mouse_button(drag_ground, false)
	check(app.sim.resources == drag_wallet - 5 and app.ui.ring_character == "hermes" and app.ui.build_kind.is_empty() and app.game_input.drag_kind.is_empty(), "Successful viewport mouse drag returns to Build and releases the held tower")
	app.sim.resources = 4
	app.ui.update_game(app.sim)
	check(app.ui.ring_buttons.gun_tower.disabled and not bridge.tap(start), "Disabled ring slots consume debug taps")
	check(not bridge.swipe(start, ground, 0.2), "Disabled ring slots cannot start a debug swipe")
	app.command("pause")
	check(not bridge.tap(start), "Modal menus block ring controls")
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
	var canceled := InputEventScreenTouch.new()
	canceled.canceled = true
	app.game_input._input(canceled)
	check(app.ui.ring_character == "hermes" and app.ui.build_kind.is_empty() and app.game_input.drag_kind.is_empty(), "Canceled touch returns to Build without a hidden placement mode")
	app.game_input.begin_tower_drag("gun_tower")
	app.command("hermes_stop")
	check(app.sim.hermes_mode == "building" and not app.sim.hermes.moving and app.ui.ring_character == "hermes" and app.sim.focused_character == "nathaniel" and app.game_input.drag_kind.is_empty() and app.ui.build_kind.is_empty(), "Stop cancels a held placement and stops Hermes while returning to Build")
	app.ui.update_game(app.sim)
	check(app.ui.get_node("%Hermes").status == "Deployed" and app.sim.hermes.anchored, "HUD names the deployed cannon state")
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
	check(not app.ui.build_open and app.ui.ring_character.is_empty() and app.sim.focused_character == "nathaniel" and app.sim.hermes_mode == "following" and not app.sim.paused, "Old Hermes-focused save loads into Nathaniel control with Build closed")
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
	app._update_camera(1.0, true)
	var wallet := app.sim.resources
	app.sim.spawn_resource(10, app.sim.nathaniel.position, 10.0, true)
	for mode: String in ["following", "building"]:
		app.sim.set_hermes_mode(mode)
		app.command("focus", "nathaniel")
		var click := app.world_to_screen(app.sim.hermes.position) - Vector2(0, 20 * app.camera_zoom)
		app.world_click(click)
		check(app.sim.focused_character == "nathaniel" and app.sim.nathaniel.destination == app.sim.hermes.position, "Immediate delivery keeps Nathaniel selected")
		check(app.effects.delivery_pulse_position == app.sim.hermes.position and app.effects.delivery_pulse_time == app.effects.delivery_pulse_lifetime, "Accepted delivery starts a full pulse")
		check(app.sim.resources == wallet and app.sim.nathaniel.has_corpse, "Delivery order does not credit cargo early")
		app.effects._process(app.effects.delivery_pulse_lifetime + 0.1)
		check(app.effects.delivery_pulse_time == 0, "Delivery pulse expires")
		app.command("stop")
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
	app.fog.enabled = true
	app._sync_views()
	app.ui.update_game(app.sim)
	var nathaniel_target := app.ui.get_node("%Nathaniel") as CharacterControl
	var hermes_target := app.ui.get_node("%Hermes") as CharacterControl
	var soldier_view := app.views[int(soldier.id)] as ActorView
	var grunt_view := app.views[int(grunt.id)] as ActorView
	check(nathaniel_target.target_name.contains("Grunt") and hermes_target.target_name.contains("Grunt"), "Both target HUDs identify automatic combat targets")
	check(soldier_view.target_highlight == Color.WHITE and grunt_view.target_highlight != Color.WHITE, "Only the automatic combat target receives a world tint")
	app.command("focus", "hermes")
	app.world_click(app.world_to_screen(soldier.position) - Vector2(0, 20 * app.camera_zoom))
	app._sync_views()
	check(app.sim.nathaniel.target_id == grunt.id and soldier_view.target_highlight == Color.WHITE and not app.ui.build_open, "Enemy click closes Build without retargeting or highlighting another enemy")
	app.command("focus", "nathaniel")
	var soldier_click := app.world_to_screen(soldier.position) - Vector2(0, 20 * app.camera_zoom)
	var grunt_click := app.world_to_screen(grunt.position) - Vector2(0, 20 * app.camera_zoom)
	app.world_click(soldier_click)
	check(app.sim.nathaniel.target_id == soldier.id and app.sim.nathaniel.manual_target_id == soldier.id and app.sim.hermes.target_id == grunt.id and app.sim.focused_character == "nathaniel", "Enemy click commands selected Nathaniel without changing Hermes's target")
	app._sync_views()
	app.ui.update_game(app.sim)
	check(nathaniel_target.target_name.contains("Soldier") and nathaniel_target.target_texture != null, "Nathaniel target HUD shows the selected enemy portrait")
	check(hermes_target.target_name.contains("Grunt"), "Manual Nathaniel targeting leaves Hermes automatic target HUD unchanged")
	var nathaniel_tint := soldier_view.target_highlight
	var hermes_tint := grunt_view.target_highlight
	check(nathaniel_tint != Color.WHITE and hermes_tint != Color.WHITE and nathaniel_tint != hermes_tint and nathaniel_tint.r > nathaniel_tint.b and hermes_tint.b > hermes_tint.r, "Native target actors have distinct amber and cyan tints")
	var soldier_display: CanvasItem = soldier_view.model_view.display if soldier_view.model_view != null else soldier_view.sprite
	var grunt_display: CanvasItem = grunt_view.animation_sprite if grunt_view.animation_sprite != null else grunt_view.sprite
	var soldier_highlight := soldier_display.material as ShaderMaterial
	var grunt_highlight := grunt_display.material as ShaderMaterial
	check(soldier_view.model_view != null and soldier_view.model_view.visible and soldier_highlight != null and soldier_highlight.get_shader_parameter("highlight_color") == nathaniel_tint and is_equal_approx(float(soldier_highlight.get_shader_parameter("highlight_strength")), app.effects.target_tint_strength) and bool(soldier_highlight.get_shader_parameter("source_premultiplied")), "The live soldier model displays Nathaniel's highlight shader")
	check(grunt_view.animation_sprite != null and grunt_view.animation_sprite.visible and grunt_highlight != null and grunt_highlight.get_shader_parameter("highlight_color") == hermes_tint and is_equal_approx(float(grunt_highlight.get_shader_parameter("highlight_strength")), app.effects.target_tint_strength) and not bool(grunt_highlight.get_shader_parameter("source_premultiplied")), "The animated grunt displays Hermes's highlight shader")
	check(soldier_view.modulate == Color.WHITE and grunt_view.modulate == Color.WHITE, "Target highlights leave actor shadows and health at their normal modulation")
	app.world_click(soldier_click)
	app._sync_views()
	check(soldier_view.target_highlight == nathaniel_tint and grunt_view.target_highlight == hermes_tint, "Repeated enemy clicks leave target highlights steady")
	app.effects._process(1.0)
	app._sync_views()
	check(soldier_view.target_highlight == nathaniel_tint and grunt_view.target_highlight == hermes_tint, "Target highlights remain steady after click feedback would have expired")
	app.world_click(grunt_click)
	app._sync_views()
	check(soldier_view.target_highlight == Color.WHITE and grunt_view.target_highlight != Color.WHITE and grunt_view.target_highlight != nathaniel_tint and grunt_view.target_highlight != hermes_tint, "Retargeting clears the previous actor tint and blends the shared target")
	check(soldier_highlight != null and is_zero_approx(float(soldier_highlight.get_shader_parameter("highlight_strength"))) and grunt_highlight != null and grunt_highlight.get_shader_parameter("highlight_color") == grunt_view.target_highlight, "Retargeting disables the previous model wash and updates the shared sprite wash")
	app.world_click(soldier_click)
	app._sync_views()
	app.command("pause")
	app.world_click(grunt_click)
	app._sync_views()
	check(app.sim.nathaniel.target_id == soldier.id and soldier_view.target_highlight == nathaniel_tint and grunt_view.target_highlight == hermes_tint, "Paused enemy clicks cannot change the target or its highlight")
	app.command("resume")
	app.sim.set_paused(true)
	app.world_click(soldier_click)
	app._sync_views()
	check(soldier_view.target_highlight == nathaniel_tint, "A rejected paused command leaves the current target highlight steady")
	app.sim.set_paused(false)
	var player_hp: int = app.sim.nathaniel.hp
	app.sim.nathaniel.hp = 0
	app.world_click(soldier_click)
	app._sync_views()
	app.ui.update_game(app.sim)
	check(nathaniel_target.target_name.contains("No target") and soldier_view.target_highlight == Color.WHITE and grunt_view.target_highlight == hermes_tint, "A down Nathaniel has no target HUD or highlight while Hermes retains his target")
	app.sim.nathaniel.hp = player_hp
	app.sim.fog.fill(1)
	app.fog.enabled = false
	app.world_click(grunt_click)
	app._sync_views()
	check(app.sim.nathaniel.target_id == soldier.id and soldier_view.target_highlight == nathaniel_tint and grunt_view.target_highlight == hermes_tint, "A command rejected by domain visibility leaves the existing target highlights unchanged")
	app.fog.enabled = true
	app._sync_views()
	app.ui.update_game(app.sim, true)
	check(nathaniel_target.target_name.contains("Out of sight") and not nathaniel_target.target_name.contains("HP") and hermes_target.target_name.contains("Out of sight") and not hermes_target.target_name.contains("HP") and soldier_view.target_highlight == Color.WHITE and grunt_view.target_highlight == Color.WHITE, "Fog hides target health and clears world highlights for both characters")
	app.ui.update_game(app.sim, false)
	app.fog.enabled = false
	app._sync_views()
	check(nathaniel_target.target_texture != null and hermes_target.target_texture != null and soldier_view.target_highlight == nathaniel_tint and grunt_view.target_highlight == hermes_tint, "Disabling fog restores target portraits and native actor highlights")
	soldier.position = Vector2(1200, 640)
	app.sim.damage_entity(soldier.id, 12)
	app.ui.update_game(app.sim, false)
	check(nathaniel_target.target_name == "Soldier" and int(soldier.hp) == 188, "Target HUD retains the correct identity as health and distance change")
	app.sim.hermes.target_id = soldier.id
	app._sync_views()
	var shared_tint := soldier_view.target_highlight
	check(shared_tint != Color.WHITE and shared_tint != nathaniel_tint and shared_tint != hermes_tint and grunt_view.target_highlight == Color.WHITE, "A shared target combines both character colors and clears Hermes's previous target")
	check(soldier_display.modulate == Color("ff8585") and soldier_highlight != null and soldier_highlight.get_shader_parameter("highlight_color") == shared_tint, "Damage flash remains active under the target color wash")
	var hermes_hp: int = app.sim.hermes.hp
	app.sim.hermes.hp = 0
	app._sync_views()
	app.ui.update_game(app.sim, false)
	check(soldier_view.target_highlight == nathaniel_tint and hermes_target.target_name.contains("No target"), "A down Hermes contributes no color or target HUD to a shared target")
	app.sim.hermes.hp = hermes_hp
	app.sim.damage_entity(soldier.id, 1000)
	app._sync_views()
	app.ui.update_game(app.sim, false)
	check(nathaniel_target.target_name.contains("No target") and hermes_target.target_name.contains("No target") and not app.views.has(int(soldier.id)) and grunt_view.target_highlight == Color.WHITE, "A destroyed target disappears from both HUDs and leaves no highlighted actor")
	app.sim.damage_entity(grunt.id, 1000)
	app.sim.step(0)
	app.sim.nathaniel.target_id = soldier.id
	app.sim.hermes.target_id = grunt.id
	app._sync_views()
	app.ui.update_game(app.sim, false)
	check(app.sim.entity(soldier.id).is_empty() and app.sim.entity(grunt.id).is_empty() and nathaniel_target.target_name.contains("No target") and hermes_target.target_name.contains("No target") and not app.views.has(int(soldier.id)) and not app.views.has(int(grunt.id)), "Removed targets cannot leave stale HUD or highlighted actor state")
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
	for character: String in ["nathaniel", "hermes"]:
		var card := app.ui.get_node("%" + character.capitalize()) as CharacterControl
		check(app.ui.safe_rect().encloses(card.get_global_rect()), "Character and target portrait fit in the safe area")
		var point := card.get_global_rect().position + Vector2(165, 88)
		_mouse_button(point, true)
		_mouse_button(point, false)
		check(app.sim.focused_character == "nathaniel" and app.ui.ring_character == ("hermes" if character == "hermes" else ""), "Target portrait returns to Nathaniel or opens Hermes Build without changing the player")
	check(app.sim.nathaniel.destination == null and app.sim.nathaniel.target_id == enemy.id and app.sim.nathaniel.manual_target_id == enemy.id, "Target portrait clicks cannot move or retarget Nathaniel")
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
