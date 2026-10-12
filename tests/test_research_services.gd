extends SceneTree
## Real JSON round trips use isolated storage and the normal slot validator.

var checks: int = 0
var failures: Array[String] = []
var directory: String

func _initialize() -> void:
	directory = "/private/tmp/nathaniel-research-services-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_test_round_trip()
	_test_invalid_state()
	_test_legacy()
	var store := GameSaveStore.new(directory)
	for slot: int in range(1, 4):
		store.delete_slot(slot)
	if DirAccess.dir_exists_absolute(directory):
		DirAccess.remove_absolute(directory)
	for failure: String in failures:
		push_error(failure)
	print("Research services: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _fixture() -> GameSimulation:
	var sim := GameSimulation.new()
	sim.configure({"number": 0, "width": 32, "height": 32, "tile_size": 32,
		"blocked": [], "player_start": Vector2(200, 320), "hermes_start": Vector2(400, 320),
		"enemies": [], "towers": [], "wave_based": false, "starting_resources": 100})
	return sim

func _drop(sim: GameSimulation, kind: String, position: Vector2) -> void:
	var enemy: Dictionary = sim.spawn_enemy(kind, position)
	sim.damage_entity(enemy.id, enemy.hp, sim.nathaniel.id)

func _advance(sim: GameSimulation, seconds: float) -> void:
	for frame: int in ceili(seconds * 60.0):
		sim.step(1.0 / 60.0)

func _test_round_trip() -> void:
	var sim := _fixture()
	var store := GameSaveStore.new(directory)
	_drop(sim, "grunt", Vector2(210, 320))
	sim.step(1.0 / 60.0)
	_check(not sim.tech_pickups.is_empty(), "Pickup is present before acceptance")
	_check(store.save_slot(1, sim.snapshot(), "Research collection").success, "In-progress tech collection saves")
	var loaded: Dictionary = store.load_slot(1)
	_check(loaded.success, "In-progress tech collection loads through JSON")
	if not loaded.success:
		return
	var restored := GameSimulation.new()
	_check(restored.restore(loaded.state), "In-progress tech collection restores")
	_advance(restored, 1.0)
	_check(restored.tech == 1 and restored.tech_pickups.is_empty(), "Restored collection credits exactly once")
	_check(store.save_slot(1, restored.snapshot()).success, "Accepted pickup saves")
	_check(restored.restore(store.load_slot(1).state), "Accepted pickup restores")
	_advance(restored, 1.0)
	_check(restored.tech == 1 and restored.tech_pickups.is_empty(), "Accepted pickup cannot reappear after reload")

	_drop(restored, "spawner", Vector2(720, 720))
	restored.tech = 100
	_check(restored.place_tower("researchCenter", Vector2(512, 320)), "Center builds for save fixture")
	var center: Dictionary = restored.research_center()
	if center.is_empty():
		return
	_check(restored.begin_research(center.id), "Research session opens before save")
	for track: String in ["capacity", "reach", "cooling", "plating"]:
		_check(restored.purchase_research(track, 0, restored.research_session_id), "Research buys " + track)
	var expected: Dictionary = restored.snapshot()
	_check(store.save_slot(2, expected, "Research ranks").success, "Open research session saves gameplay state")
	loaded = store.load_slot(2)
	_check(loaded.success and restored.restore(loaded.state), "Research wallet, ranks, and center restore")
	_check(restored.tech == expected.tech, "Wallet survives JSON round trip")
	for track: String in expected.research_ranks:
		_check(int(restored.research_ranks[track]) == int(expected.research_ranks[track]), "Learned rank survives JSON round trip: " + track)
	_check(restored.tech_pickups.size() == 1 and restored.tech_pickups[0].amount == 8, "Uncollected core quantity survives")
	_check(not restored.paused and restored.research_session_id == 0, "Restore drops transient menu pause and authorization")
	_check(not restored.purchase_research("capacity", 1), "Restored state has no authorized purchase session")
	var delay: float = restored.hermes.delay
	for repeat: int in 3:
		_check(restored.restore(restored.snapshot()), "Repeated restore remains valid")
	_check(is_equal_approx(restored.hermes.delay, delay), "Repeated restore does not compound cooling")
	_check(restored.nathaniel.resource_capacity == 2 and restored.nathaniel.resource_reach == 60.0, "Backpack effects do not compound on restore")

func _test_invalid_state() -> void:
	var sim := _fixture()
	_drop(sim, "grunt", Vector2(720, 720))
	var baseline: Dictionary = sim.snapshot()
	var store := GameSaveStore.new(directory)
	_check(store.save_slot(3, baseline).success, "Valid slot exists before invalid writes")
	for value: Variant in [-1, 0.5, "2", true, null]:
		var invalid: Dictionary = baseline.duplicate(true)
		invalid.tech = value
		_reject(sim, invalid, baseline, "Invalid tech wallet " + str(value))
	for field: String in ["amount", "id"]:
		for value: Variant in [0, -1, 1.5, "2", true, null]:
			var invalid: Dictionary = baseline.duplicate(true)
			invalid.tech_pickups[0][field] = value
			_reject(sim, invalid, baseline, "Invalid tech " + field + " " + str(value))
	for patch: Dictionary in [{"kind": "corpse"}, {"phase": "feed"}, {"owner_id": 9999}, {"position": {"x": "bad", "y": 1}}]:
		var invalid: Dictionary = baseline.duplicate(true)
		invalid.tech_pickups[0].merge(patch, true)
		_reject(sim, invalid, baseline, "Invalid tech drop " + str(patch.keys()))
	for rank: Variant in [-1, 3, 0.5, "1", true]:
		var invalid: Dictionary = baseline.duplicate(true)
		invalid.research_ranks.capacity = rank
		_reject(sim, invalid, baseline, "Invalid research rank " + str(rank))
	var duplicate: Dictionary = baseline.duplicate(true)
	duplicate.tech_pickups.append(duplicate.tech_pickups[0].duplicate(true))
	_reject(sim, duplicate, baseline, "Duplicate drop identity")
	duplicate = baseline.duplicate(true)
	duplicate.tech_pickups[0].id = duplicate.entities[0].id
	_reject(sim, duplicate, baseline, "Drop collides with entity identity")
	_check(not store.save_slot(3, duplicate).success, "Invalid research write is refused")
	_check(store.load_slot(3).state == JSON.parse_string(JSON.stringify(baseline)), "Invalid write preserves the previous slot")

	_check(sim.place_tower("researchCenter", Vector2(512, 320)), "Center builds for singleton validation")
	baseline = sim.snapshot()
	duplicate = baseline.duplicate(true)
	for entity: Dictionary in baseline.entities:
		if entity.kind == "researchCenter":
			var second: Dictionary = entity.duplicate(true)
			second.id = 9000
			second.position = {"x": 640.0, "y": 320.0}
			duplicate.entities.append(second)
	_reject(sim, duplicate, baseline, "Duplicate research center")

func _test_legacy() -> void:
	var sim := _fixture()
	sim.nathaniel.resource_capacity = 2
	sim.nathaniel.resource_reach = 60.0
	var legacy: Dictionary = sim.snapshot()
	for key: String in ["tech", "tech_pickups", "research_ranks", "tech_target_id"]:
		legacy.erase(key)
	var store := GameSaveStore.new(directory)
	_check(store.save_slot(1, legacy, "Old backpack save").success, "Old snapshot without research fields remains valid")
	var loaded: Dictionary = store.load_slot(1)
	_check(loaded.success and sim.restore(loaded.state), "Old backpack save restores")
	_check(sim.tech == 0 and sim.tech_pickups.is_empty(), "Old save gains no tech or drops")
	_check(sim.research_ranks.capacity == 1 and sim.research_ranks.reach == 1, "Old purchased backpack ranks migrate")
	_check(sim.nathaniel.resource_capacity == 2 and sim.nathaniel.resource_reach == 60.0, "Old saved actor values are not upgraded twice")
	_check(sim.place_tower("researchCenter", Vector2(512, 320)), "Migrated run can build a center")
	sim.tech = 20
	_check(sim.begin_research(sim.research_center().id), "Migrated run opens research")
	_check(sim.purchase_research("capacity", 1, sim.research_session_id) and sim.tech == 0, "Migrated rank pays only the second-rank cost")

func _reject(sim: GameSimulation, invalid: Dictionary, baseline: Dictionary, label: String) -> void:
	_check(not GameSaveStore.validate_state(invalid).is_empty(), label + " rejected by save store")
	_check(not sim.restore(invalid), label + " rejected by direct restore")
	_check(sim.snapshot() == baseline, label + " preserves the active run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
