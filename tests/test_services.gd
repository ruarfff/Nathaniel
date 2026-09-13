extends SceneTree

const SaveStore = preload("res://scripts/infrastructure/save_store.gd")
const LegacyImport = preload("res://scripts/infrastructure/swift_save_import.gd")
const Settings = preload("res://scripts/infrastructure/settings_store.gd")
const Progress = preload("res://scripts/infrastructure/progress_store.gd")
const DebugServer = preload("res://scripts/infrastructure/debug_server.gd")
const AtomicJSON = preload("res://scripts/infrastructure/atomic_json.gd")
var failures: int = 0
var checks: int = 0
var directory: String
var last_tap := Vector2.ZERO
var last_action: String = ""


func _initialize() -> void:
	directory = "/tmp/nathaniel-services-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	call_deferred("_run")


func _run() -> void:
	_test_legacy()
	_test_slots()
	_test_simulation_restoration()
	_test_settings_progress()
	_test_http_framing()
	_test_routes()
	await _test_network()
	_remove_fixture_directory()
	print("Services: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _test_legacy() -> void:
	var source := _swift_fixture()
	var result: Dictionary = LegacyImport.convert(source, _level())
	_check(result.success, "Actual Swift Codable shape imports")
	var state: Dictionary = result.state
	_check(state.resources == 30 and state.lives == 3, "Version 2 spare lives and wallet are preserved")
	_check(state.entities[0].destination == {"x": 900, "y": 700}, "Requested route endpoint survives import")
	_check(state.entities[0].facing == {"x": 0.0, "y": -1.0}, "Swift south is negative logical y")
	_check(state.entities[1].destination == null, "Hermes resets movement as Swift load does")
	_check(state.entities[2].target_id == 2, "Hermes enemy target reference is restored")
	_check(state.entities[2].spawn_countdown == 17.25 and state.entities[2].initial_spawns_remaining == 1, "Spawner production timer survives")
	_check(state.entities[3].construction_cost == 19 and state.entities[3].owned, "Actual tower construction cost survives")
	_check(state.entities[3].cooldown == 0, "Swift load resets tower cooldown")
	_check(state.entities[4].construction_cost == 0 and not state.entities[4].owned, "Map tower has no refund cost")
	_check(state.corpses[0].carried and state.corpses[0].expiration == 18.5 and state.corpses[0].amount == 10, "Carried corpse timer and amount survive without wallet credit")
	_check(state.wave_since_last_spawn == 2.75, "Survival wave phase uses elapsed difficulty and remaining countdown")
	_check(SaveStore.validate_state(state).is_empty(), "Imported state passes native validation")
	for patch: Dictionary in [{"projectiles": ["bad"]}, {"fog": [3]}, {"entities": [{"id": 1}]}, {"resources": 0.5}, {"rng_state": {}}]:
		var invalid := state.duplicate(true)
		invalid.merge(patch, true)
		_check(not SaveStore.validate_state(invalid).is_empty(), "Malformed nested snapshot is rejected before restoration")
	source.saveVersion = 1
	source.hermes.mode = "locked"
	source.towers[0].erase("constructionCost")
	source.enemies[0].erase("timeUntilNextSpawn")
	source.enemies[0].erase("initialSpawnsRemaining")
	source.erase("battlefieldResources")
	source.nathaniel.currentHP = 0
	result = LegacyImport.convert(source, _level())
	state = result.state
	_check(state.lives == 2, "Version 1 lives migrate from total lives to spare lives")
	_check(state.hermes_mode == "independent", "Old locked Hermes mode imports as independent")
	_check(state.entities[0].hp == 8000 and state.entities[0].destination == null, "Pending paid respawn restores without spending another life")
	_check(state.entities[0].position == _level().player_start, "Paid respawn returns to level start")
	_check(state.entities[3].construction_cost == 5, "Old owned gun tower gets shipped refund cost")
	_check(state.entities[2].spawn_countdown == 30 and state.entities[2].initial_spawns_remaining == 3, "Old spawner saves get production defaults")
	_check(state.corpses.is_empty(), "Old saves without corpses remain compatible")
	source.hermes.characterState.currentHP = 0
	_check(LegacyImport.convert(source, _level()).state.result == "gameOver", "Dead Hermes imports as defeat")
	source.saveVersion = 99
	_check(not LegacyImport.convert(source, _level()).success, "Future Swift save versions are rejected")
	source = _swift_fixture()
	source.enemies[0].targetIndex = 8
	_check(not LegacyImport.convert(source, _level()).success, "Invalid target reference is rejected")
	_check(not LegacyImport.convert(_swift_fixture(), {"number": 2}).success, "Wrong level is rejected")


func _test_slots() -> void:
	var store := SaveStore.new(directory.path_join("slots"))
	var simulation := GameSimulation.new()
	simulation.configure(_level())
	var state := simulation.snapshot()
	state.level.blocked = [Vector2i(1, 2)]
	state.entities[0].position = Vector2(125, 250)
	_check(store.list_slots().size() == 3, "Exactly three slots exist")
	_check(not store.save_slot(0, state).success and not store.save_slot(4, state).success, "Invalid slots cannot write")
	_check(store.save_slot(1, state, "First").success, "Native save writes atomically")
	state.score = 42
	_check(store.save_slot(2, state, "Second").success, "Second independent slot writes")
	state.score = 99
	_check(store.save_slot(1, state, "Updated").success, "Existing Godot slot can be replaced")
	var reloaded := SaveStore.new(directory.path_join("slots"))
	var loaded := reloaded.load_slot(1)
	_check(loaded.success and loaded.state.score == 99, "Reopened store reads updated snapshot: " + str(loaded.get("error", "")))
	if not loaded.success:
		return
	_check(loaded.state.entities[0].position == Vector2(125, 250), "Vector2 position survives JSON")
	_check(loaded.state.level.blocked[0] == Vector2i(1, 2), "Integer grid vector survives JSON")
	_check(reloaded.load_slot(2).state.score == 42, "Other slot is untouched")
	_check(reloaded.list_slots()[0].display_name == "Updated", "Metadata derives from slot data")
	var previous := FileAccess.get_file_as_bytes(store.slot_path(1))
	state.resources = -1
	_check(not store.save_slot(1, state).success, "Invalid game state cannot replace a save")
	_check(previous == FileAccess.get_file_as_bytes(store.slot_path(1)), "Rejected write preserves previous bytes")
	state.resources = 30
	state.entities[0].hp = NAN
	_check(not store.save_slot(1, state).success, "Non-finite values are rejected")
	_check(reloaded.delete_slot(1).success and not reloaded.load_slot(1).success, "Delete removes only selected slot")
	_check(reloaded.load_slot(2).success, "Delete preserves other slot")
	_check(not reloaded.delete_slot(4).success, "Invalid delete is rejected")
	var corrupt := FileAccess.open(store.slot_path(3), FileAccess.WRITE)
	corrupt.store_string("{invalid JSON")
	corrupt.close()
	_check(not store.load_slot(3).success and not store.list_slots()[2].has_save, "Corrupt data is shown as unavailable")
	var source_path := directory.path_join("legacy.json")
	_check(AtomicJSON.write_file(source_path, _swift_fixture()).success, "Isolated legacy fixture writes")
	var source_bytes := FileAccess.get_file_as_bytes(source_path)
	_check(not store.import_swift_file(source_path, 1, {}).success, "Import requires caller-supplied level data")
	_check(not store.import_swift_file(source_path, 1, {"number": 2}).success, "Import rejects mismatched caller level data")
	_check(not FileAccess.file_exists(store.slot_path(1)), "Rejected level data cannot create a slot")
	_check(store.import_swift_file(source_path, 1, _level()).success, "Explicit file imports into empty slot")
	_check(not store.import_swift_file(source_path, 1, _level()).success, "Import refuses occupied slot")
	_check(not store.import_swift_file(source_path, 3, _level()).success, "Import preserves corrupt occupied slot")
	_check(source_bytes == FileAccess.get_file_as_bytes(source_path), "Import never changes source bytes")


func _test_settings_progress() -> void:
	var settings_path := directory.path_join("settings.json")
	var settings := Settings.new(settings_path)
	_check(not settings.music_enabled and not settings.sound_effects_enabled, "Audio defaults match Swift")
	_check(settings.fog_enabled, "Fog is enabled in fresh settings")
	settings.music_enabled = true
	settings.fog_enabled = false
	_check(settings.save().success and Settings.new(settings_path).music_enabled, "Settings persist independently")
	_check(not Settings.new(settings_path).fog_enabled, "Fog visibility persists across app sessions")
	var corrupt_settings := directory.path_join("invalid-settings.json")
	AtomicJSON.write_file(corrupt_settings, {"music_enabled": "true", "sound_effects_enabled": 1, "fog_enabled": "false"})
	var safe_defaults := Settings.new(corrupt_settings)
	_check(not safe_defaults.music_enabled and not safe_defaults.sound_effects_enabled and safe_defaults.fog_enabled, "Invalid settings types cannot change boolean defaults")
	var progress_path := directory.path_join("progress.json")
	var progress := Progress.new(progress_path)
	_check(progress.continue_level() == 1, "New progress continues at level 1")
	_check(progress.record_completion(1, 100, 50).success, "Completion persists")
	progress.record_completion(1, 90, 40)
	_check(progress.data.level_high_scores["1"] == 100 and progress.data.level_best_times["1"] == 40, "Scores maximize and completion times minimize")
	_check(progress.continue_level() == 2, "Completed level advances continuation")
	for level: int in range(2, 6):
		progress.record_completion(level, level * 100, level * 10)
	var reloaded := Progress.new(progress_path)
	_check(reloaded.data.highest_score == 1500 and reloaded.data.best_completion_time == 180, "Campaign total uses per-level records")
	_check(reloaded.continue_level() == 5 and reloaded.is_level_completed(5), "Completed campaign stays at level 5")
	_check(not reloaded.record_completion(6, 0, 1).success, "Invalid progress cannot write")
	_check(Settings.new(settings_path).music_enabled, "Progress changes preserve settings")


func _test_simulation_restoration() -> void:
	var imported: Dictionary = LegacyImport.convert(_swift_fixture(), _level()).state
	var sim := GameSimulation.new()
	_check(sim.restore(imported), "Converted Swift state restores in actual simulation")
	_check(sim.nathaniel.destination == Vector2(900, 700), "Imported requested route reaches simulation")
	_check(not sim.nathaniel.path.is_empty() and sim.nathaniel.path.back() == Vector2(900, 700), "Imported route is recomputed to requested endpoint")
	_check(not sim.navigation.walkable(Vector2(300, 200)), "Imported towers become dynamic route obstacles")
	_check(sim.entity(3).spawn_countdown == 17.25 and sim.entity(3).target_id == sim.hermes.id, "Imported production and target references reach simulation")
	_check(sim.corpses.size() == 1 and sim.corpses[0].carried and sim.resources == 30, "Imported carried corpse does not double-credit wallet")
	sim.nathaniel.cooldown = 0.35
	sim.nathaniel.pending_damage = 0.4
	var store := SaveStore.new(directory.path_join("integration"))
	_check(store.save_slot(1, sim.snapshot()).success, "Actual native simulation snapshot saves")
	var restored := GameSimulation.new()
	_check(restored.restore(store.load_slot(1).state), "Actual native snapshot restores from disk")
	_check(restored.nathaniel.cooldown == 0.35 and restored.nathaniel.pending_damage == 0.4, "Native weapon phase and fractional damage survive disk round trip")
	_check(restored.random.state == sim.random.state, "Native random sequence survives disk round trip")
	_check(restored.navigation.towers.size() == 2 and restored.nathaniel.destination == Vector2(900, 700), "Disk reload rebuilds towers before routes")
	restored.set_hermes_mode("following")
	_check(restored.resources == 34 and restored.navigation.towers.size() == 1, "Imported 19-resource tower refunds floor 25 percent and keeps map tower")


func _test_http_framing() -> void:
	var body := '{"name":"loadLevel","params":{"level":"1"}}'.to_utf8_buffer()
	var request := ("POST /action HTTP/1.1\r\nContent-Length: %d\r\n\r\n" % body.size()).to_utf8_buffer()
	request.append_array(body)
	for size: int in range(request.size()):
		_check(not DebugServer.parse_http(request.slice(0, size)).get("complete", false), "Fragmented HTTP waits for Content-Length")
	var parsed: Dictionary = DebugServer.parse_http(request)
	_check(parsed.complete and parsed.success and parsed.body == body, "Complete HTTP request preserves body")
	for header: String in ["Content-Length: 0\r\nContent-Length: 0", "Transfer-Encoding: chunked", "Content-Length: -1", "Content-Length: +1", "Content-Length: nope"]:
		var invalid: Dictionary = DebugServer.parse_http(("GET /state HTTP/1.1\r\n%s\r\n\r\n" % header).to_utf8_buffer())
		_check(not invalid.success and invalid.status == 400, "Ambiguous HTTP framing is rejected")
	_check(DebugServer.parse_http("GET /state HTTP/1.1\r\nContent-Length: 16777217\r\n\r\n".to_utf8_buffer()).status == 413, "Large HTTP body is rejected before buffering")
	_check(DebugServer.parse_http("x".repeat(16_385).to_utf8_buffer()).status == 413, "Large HTTP headers are rejected")


func _test_routes() -> void:
	var server := _server_fixture()
	_check(server.route_request("GET", "/health").body.engine == "Godot", "Health identifies engine")
	_check(server.route_request("GET", "/state").body.coordinateSystem.input.contains("top-left"), "State identifies viewport input origin")
	_check(server.route_request("GET", "/actions").body.actions.size() == 9, "Gameplay action discovery matches MCP interface")
	var result: Dictionary = server.route_request("POST", "/tap", '{"node":"testButton"}'.to_utf8_buffer())
	_check(result.body.success and last_tap == Vector2(20, 40), "Node tap uses bounds center")
	result = server.route_request("POST", "/action", '{"name":"pause","params":{}}'.to_utf8_buffer())
	_check(result.body.success and last_action == "pause" and result.body.has("gameState"), "MCP actions include refreshed state")
	_check(server.route_request("POST", "/action", '{"name":"pause","params":{"bad":1}}'.to_utf8_buffer()).status == 400, "Action params must be strings")
	_check(server.route_request("POST", "/tap", '{}'.to_utf8_buffer()).status == 400, "Missing input coordinates fail")
	_check(server.route_request("POST", "/swipe", '{"fromX":1,"fromY":2,"toX":3,"toY":4,"duration":-1}'.to_utf8_buffer()).status == 400, "Negative drag duration fails")
	_check(server.route_request("GET", "/screenshot").body.data == Marshalls.raw_to_base64(PackedByteArray([137, 80, 78, 71])), "Screenshot keeps MCP base64 PNG envelope")
	_check(server.route_request("GET", "/missing").status == 404, "Unknown endpoint returns 404")
	server.free()


func _test_network() -> void:
	var server := _server_fixture()
	root.add_child(server)
	var chosen_port: int = 19000 + OS.get_process_id() % 20000
	var started := server.start_server(chosen_port)
	_check(started.success, "Loopback server binds isolated test port")
	if started.success:
		var request := HTTPRequest.new()
		root.add_child(request)
		request.timeout = 3.0
		_check(request.request("http://127.0.0.1:%d/state" % chosen_port) == OK, "Native HTTP client starts")
		var response: Array = await request.request_completed
		var parsed: Variant = JSON.parse_string(response[3].get_string_from_utf8())
		_check(response[0] == HTTPRequest.RESULT_SUCCESS and response[1] == 200 and parsed is Dictionary and parsed.get("engine") == "Godot", "Real TCP round trip returns valid framed state")
		request.queue_free()
	server.stop_server()
	server.queue_free()


func _server_fixture() -> GameDebugServer:
	var server := DebugServer.new()
	server.configure({"state": func() -> Dictionary: return {"scene": "GameScene", "score": 1}, "nodes": func() -> Array: return [{"name": "testButton", "frame": {"x": 10, "y": 20, "width": 20, "height": 40}}], "tap": func(point: Vector2) -> bool: last_tap = point; return true, "action": func(action: String, _params: Dictionary) -> Dictionary: last_action = action; return {"success": true}, "screenshot": func() -> PackedByteArray: return PackedByteArray([137, 80, 78, 71])})
	return server


func _level() -> Dictionary:
	return {"number": 0, "width": 32, "height": 32, "tile_size": 32, "blocked": [], "player_start": {"x": 100, "y": 200}, "hermes_start": {"x": 200, "y": 200}, "enemies": [], "wave_based": true}


func _swift_fixture() -> Dictionary:
	# Literal fields match SavedGameState/SavedGameState+Extensions, not a native snapshot.
	return {"saveVersion": 2, "savedAt": 800000000, "displayName": "Synthetic regression fixture", "levelNumber": 0, "elapsedTime": 125, "score": 420, "lives": 3, "resources": 30,
		"nathaniel": {"position": {"x": 125, "y": 250}, "currentHP": 7900, "maxHP": 8000, "facingDirection": 0, "destination": {"x": 900, "y": 700}},
		"hermes": {"characterState": {"position": {"x": 150, "y": 250}, "currentHP": 1900, "maxHP": 2000, "facingDirection": 6, "destination": {"x": 100, "y": 300}}, "mode": "independent"},
		"enemies": [{"type": "spawner", "position": {"x": 600, "y": 200}, "currentHP": 1490, "maxHP": 1500, "facingDirection": 3, "destination": {"x": 800, "y": 200}, "targetIndex": 1, "timeUntilNextSpawn": 17.25, "initialSpawnsRemaining": 1}],
		"towers": [{"type": "gunTower", "position": {"x": 300, "y": 200}, "currentHP": 599, "maxHP": 600, "isHermesOwned": true, "cooldownRemaining": 0.4, "constructionCost": 19}, {"type": "healTower", "position": {"x": 400, "y": 200}, "currentHP": 600, "maxHP": 600, "isHermesOwned": false, "cooldownRemaining": 0}],
		"battlefieldResources": [{"position": {"x": 125, "y": 250}, "amount": 10, "timeToExpiration": 18.5, "isCarried": true}], "currentWave": 2, "timeUntilNextWave": 0.25}


func _remove_fixture_directory() -> void:
	# Only paths created by this test instance are eligible for deletion.
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	for child: String in dir.get_directories():
		var nested := DirAccess.open(directory.path_join(child))
		for filename: String in nested.get_files():
			nested.remove(filename)
		dir.remove(child)
	for filename: String in dir.get_files():
		dir.remove(filename)
	DirAccess.remove_absolute(directory)
