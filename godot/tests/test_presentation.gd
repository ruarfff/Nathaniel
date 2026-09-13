extends SceneTree
## Integration checks use native scenes and isolated saves. These are not OS input tests.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
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
		check(app.sim.lives == (0 if number == 0 else 3), "Level lives preserve source")
		check(app.level.get_node("Ground") is TileMapLayer, "Native terrain remains editable")
		check(app.views.size() >= 2, "Player scene views instantiate")
		var world := Vector2(240, 450)
		check(app.screen_to_world(app.world_to_screen(world)).distance_to(world) < 0.001, "Input reverses camera plus projection")
	app.load_level(0)
	await process_frame
	app.set_physics_process(false)
	app.command("focus", "hermes")
	check(app.sim.focused_character == "hermes" and app.sim.hermes_mode == "building", "Focus never changes Hermes mode")
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
	_test_slot_menu_paths(app, path.path_join("native-slot-menus"))
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
	check(app.ui.build_kind.is_empty() and not app.ui.build_open and app.game_input.drag_kind.is_empty(), "Opening a modal cancels placement and pointer drag")
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
	app.audio.play_music("menuMusic")
	app.settings.music_enabled = true
	app.audio.apply_settings(app.settings)
	await process_frame
	check(app.audio.music.playing and not app.audio.music.stream_paused, "Enabled music starts its requested stream")
	app.settings.music_enabled = false
	app.audio.apply_settings(app.settings)
	await process_frame
	check(app.audio.music.stream_paused, "Disabling music pauses the active stream")
	app.settings.music_enabled = true
	app.audio.apply_settings(app.settings)
	await process_frame
	check(app.audio.music.playing and not app.audio.music.stream_paused, "Re-enabling music resumes an already-playing paused stream")
	app.settings.music_enabled = false
	app.audio.apply_settings(app.settings)
	app.audio.play_music("gameMusic2")
	await process_frame
	check(app.audio.requested_track == "gameMusic2" and app.audio.music.stream.resource_path.ends_with("gameMusic2.mp3"), "Track changes while disabled preserve the requested level music")
	app.settings.music_enabled = true
	app.audio.apply_settings(app.settings)
	await process_frame
	check(app.audio.music.playing and not app.audio.music.stream_paused and app.audio.music.stream.resource_path.ends_with("gameMusic2.mp3"), "Re-enabling starts the latest requested track")
	# The audio mixer runs independently of headless frames; let the last play
	# reach it before the caller stops and frees the player.
	await create_timer(0.05).timeout


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
