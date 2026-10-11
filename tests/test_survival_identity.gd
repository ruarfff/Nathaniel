extends SceneTree
## Synthetic input checks identity; real platform input is checked separately.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	Engine.max_fps = 60
	_run.call_deferred()


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)


func _run() -> void:
	_test_entry_adapter()
	_test_demo_export()
	var app := load("res://scenes/main.tscn").instantiate() as GameApp
	app.storage_root = "/private/tmp/nathaniel-survival-identity-%d/" % Time.get_ticks_usec()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	for map_id: String in SurvivalMapCatalog.NEW_RUN_IDS:
		app.map_selection_override = map_id
		app.command("survival")
		check(app.sim != null and app.sim.survival_map_id == map_id, "Controlled new run selects " + map_id)
		if app.sim == null:
			continue
		check(app.level.scene_file_path == SurvivalMapCatalog.scene_path(map_id), "Scenery resolves from " + map_id)
		check((app.ui.get_node("%Notice") as Label).text == SurvivalMapCatalog.title(map_id) and app.ui.notice_time > 0, "Run start briefly names " + map_id)
		var authored := app.sim.snapshot()
		var combat_rng := app.sim.random.state
		for index: int in range(12):
			SurvivalMapCatalog.choose(app.map_selection_rng)
		check(app.sim.random.state == combat_rng, "Map selection leaves combat randomness unchanged")
		app.map_selection_override = SurvivalMapCatalog.NEW_RUN_IDS[(SurvivalMapCatalog.NEW_RUN_IDS.find(map_id) + 1) % 4]
		app.sim.resources = 987
		app.sim.result = "gameOver"
		app._physics_process(0.0)
		_menu_button(app, "Try again").pressed.emit()
		check(app.sim.survival_map_id == map_id and app.sim.resources == authored.resources and app.sim.snapshot().level == authored.level, "Retry button restores authored state on " + map_id)
		app.sim.resources = 654
		app.sim.result = "gameOver"
		app._physics_process(0.0)
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.pressed = true
		app.game_input._input(key)
		check(app.sim.survival_map_id == map_id and app.sim.resources == authored.resources, "Keyboard retry preserves " + map_id)
		app.sim.resources = 321
		app.sim.random.randi()
		var saved_rng := app.sim.random.state
		app.command("confirm_save", 1)
		app.show_main()
		app.command("load_slot", 1)
		check(app.sim.survival_map_id == map_id and app.sim.resources == 321 and app.sim.random.state == saved_rng, "Save and resume preserve map, state, and combat RNG for " + map_id)
		check(app.level.scene_file_path == SurvivalMapCatalog.scene_path(map_id), "Resume scenery matches saved " + map_id)
		_test_authored_restore(app, map_id)
		await process_frame
		app.set_physics_process(false)
	_test_selection(app)
	_test_debug_survival(app)
	_test_legacy(app)
	_test_unknown(app)
	app.save_store.delete_slot(1)
	app.audio.music.stop()
	app.queue_free()
	await process_frame
	await create_timer(0.05).timeout
	print("Survival identity: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _test_selection(app: GameApp) -> void:
	app.map_selection_override = ""
	var expected_rng := RandomNumberGenerator.new()
	var seen: Dictionary = {}
	for seed_value: int in range(1, 33):
		app.map_selection_rng.seed = seed_value
		expected_rng.seed = seed_value
		var expected := SurvivalMapCatalog.NEW_RUN_IDS[expected_rng.randi_range(0, 3)]
		check(SurvivalMapCatalog.choose(app.map_selection_rng) == expected, "Independent map RNG uses uniform integer selection for seed %d" % seed_value)
		seen[expected] = seed_value
	check(seen.size() == 4, "Fixed selection seeds cover all four maps without a frequency assertion")
	for map_id: String in seen:
		app.map_selection_rng.seed = int(seen[map_id])
		check(app.start_survival_run() and app.sim.survival_map_id == map_id, "New-run boundary consumes independent RNG for " + map_id)
	check(SurvivalMapCatalog.LEGACY_ID not in SurvivalMapCatalog.NEW_RUN_IDS, "The legacy map stays outside the new-run catalog")


func _test_legacy(app: GameApp) -> void:
	app.load_level(0)
	var legacy := app.sim.snapshot()
	var authored: Dictionary = legacy.level.duplicate(true)
	legacy.level.erase("survival_map_id")
	legacy.level.erase("entry_sectors")
	legacy.level.width = 52
	legacy.level.height = 52
	legacy.level.blocked = []
	legacy.resources = 137
	check(app.save_store.save_slot(1, legacy).success, "A legacy survival save without a map ID remains valid")
	app.map_selection_override = "dry_wash"
	app.command("load_slot", 1)
	check(app.sim.survival_map_id == SurvivalMapCatalog.LEGACY_ID and app.sim.config.width == 30 and app.sim.resources == 137, "A legacy save restores its original map and state")
	check(app.level.scene_file_path == "res://levels/level_0.tscn", "A legacy save uses the original scenery")
	check(app.sim.snapshot().level == authored, "Legacy resume takes terrain from its retained native map")
	app.command("confirm_save", 1)
	var resaved := app.save_store.load_slot(1)
	check(resaved.success and resaved.state.level.survival_map_id == SurvivalMapCatalog.LEGACY_ID, "Saving a legacy run adds its stable original-map identity")
	app.sim.result = "gameOver"
	app.command("continue_result")
	check(app.sim.survival_map_id == SurvivalMapCatalog.LEGACY_ID and app.sim.config.width == 30 and app.sim.resources == 30, "Legacy retry preserves the original authored map")


func _test_authored_restore(app: GameApp, map_id: String) -> void:
	var saved := app.sim.snapshot()
	var authored: Dictionary = saved.level.duplicate(true)
	var player_position: Vector2 = app.sim.nathaniel.position
	var rng_state: int = app.sim.random.state
	saved.level.width = 30
	saved.level.height = 30
	saved.level.blocked = []
	saved.level.entry_sectors = []
	saved.level.player_start = {"x": 32, "y": 32}
	saved.level.hermes_start = {"x": 96, "y": 32}
	saved.level.wave_based = false
	saved.level.title = "Stale terrain"
	saved.resources = 271
	saved.score = 88
	saved.elapsed_time = 12.0
	saved.pending_wave_kinds = ["boss", "spawner"]
	saved.spawn_retry_remaining = 0.2
	check(app.save_store.save_slot(1, saved).success, "Stale embedded map fixture remains a compatible save for " + map_id)
	app.command("load_slot", 1)
	check(app.sim.snapshot().level == authored and app.level.scene_file_path == SurvivalMapCatalog.scene_path(map_id), "Resume resolves both simulation terrain and scenery from " + map_id)
	check(app.sim.resources == 271 and app.sim.score == 88 and app.sim.elapsed_time == 12.0 and app.sim.nathaniel.position == player_position and app.sim.random.state == rng_state, "Canonical terrain preserves dynamic run state for " + map_id)
	check(app.sim.pending_wave_kinds == ["boss", "spawner"] and app.sim.spawn_retry_remaining == 0.2, "Canonical terrain preserves deferred wave budgets for " + map_id)


func _test_debug_survival(app: GameApp) -> void:
	var bridge := GameDebugBridge.new(app)
	for sector: Dictionary in app.sim.entry_sectors:
		sector.enabled = false
	BattlefieldRules.update_waves(app.sim, 5.0)
	var state := bridge.state()
	check(state.survival.mapId == app.sim.survival_map_id, "Debug state reports the selected native survival map")
	check(state.survival.pendingSpawns == 1 and state.survival.spawnBlockedReason == "noEnabledEntrySector" and state.survival.spawnRetryRemaining > 0, "Debug state explains a deferred authored-sector wave")
	var spawner := app.sim.spawn_enemy("spawner", app.sim.hermes.position)
	spawner.spawn_countdown = 0.0
	BattlefieldRules.update_spawner(app.sim, spawner, 0.0)
	state = bridge.state()
	var blocked_spawner: Dictionary = {}
	for entity: Dictionary in state.entities:
		if entity.id == spawner.id:
			blocked_spawner = entity
	check(not blocked_spawner.get("spawnBlockedReason", "").is_empty(), "Debug entity state explains a deferred spawner child")
	app.load_level(4)
	check(not bridge.state().has("survival"), "Wave-based campaign debug state does not claim survival mode")


func _test_unknown(app: GameApp) -> void:
	var current := app.sim
	check(not app.load_survival_map("missing_map") and app.sim == current, "Unknown map loading fails without replacing the current run")
	check((app.ui.get_node("%Notice") as Label).text.contains("Unknown survival map identifier"), "Unknown map loading gives a clear error")
	app.map_selection_override = "missing_map"
	check(not app.start_survival_run() and app.sim == current, "Unknown selection override fails without a fallback")
	var invalid := app.sim.snapshot()
	invalid.level.survival_map_id = "missing_map"
	check(GameSaveStore.validate_state(invalid).contains("Unknown survival map"), "Save validation rejects unknown IDs")
	check(not app.sim.restore(invalid), "Domain restore rejects unknown IDs")
	invalid.level.survival_map_id = 1
	check(GameSaveStore.validate_state(invalid).contains("Unknown survival map"), "Save validation rejects a non-string map ID")
	invalid = app.sim.snapshot()
	invalid.pending_wave_kinds = ["invalidEnemy"]
	check(GameSaveStore.validate_state(invalid).contains("Invalid deferred wave"), "Save validation rejects invalid deferred enemies")


func _test_entry_adapter() -> void:
	var level := GameLevel.new()
	level.definition = LevelDefinition.new()
	level.definition.number = 0
	var spawns := Node2D.new()
	spawns.name = "Spawns"
	level.add_child(spawns)
	for index: int in range(3):
		var marker := SpawnMarker.new()
		marker.kind = "enemyEntry"
		marker.label = "north" if index < 2 else "closed"
		marker.position = IsoProjection.project(Vector2(32 + index * 32, 128))
		marker.enabled = index < 2
		spawns.add_child(marker)
	var config := level.data()
	check(config.entry_sectors.size() == 2 and config.entry_sectors[0].positions == [Vector2(32, 128), Vector2(64, 128)], "Native entry markers group by label and convert to logical points")
	check(config.entry_sectors[0].enabled and not config.entry_sectors[1].enabled, "Disabled native sectors remain explicit")
	level.free()


func _test_demo_export() -> void:
	var presets := ConfigFile.new()
	check(presets.load("res://export_presets.cfg") == OK, "Export presets load")
	for section: String in presets.get_sections():
		if presets.get_value(section, "name", "") != "Web Demo":
			continue
		check(presets.get_value(section, "export_filter", "") == "all_resources", "Demo exports all non-excluded native resources")
		var excluded: PackedStringArray = String(presets.get_value(section, "exclude_filter", "")).split(",")
		for map_id: String in SurvivalMapCatalog.MAPS:
			var path := SurvivalMapCatalog.scene_path(map_id).trim_prefix("res://")
			var included := true
			for pattern: String in excluded:
				included = included and not path.match(pattern)
			check(included, "Demo includes survival scene " + map_id)


func _menu_button(app: GameApp, text: String) -> Button:
	for child: Node in app.ui.get_node("%Content").get_children():
		if child is Button and child.text == text:
			return child
	return null
