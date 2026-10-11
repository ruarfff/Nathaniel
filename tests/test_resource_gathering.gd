extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	_test_capacity_reach_and_expiry()
	_test_acceptance_and_interruption()
	_test_death_ownership()
	_test_upgrades_and_sequences()
	_test_spawn_invariants()
	_test_return_to_hermes()
	_test_save_phases_and_validation()
	_test_movement_and_weapon()
	_test_self_destruct_deadlines()
	_test_disarm_interruption_and_pause()
	_test_self_destruct_saves()
	_test_recovery_eligibility_and_kinds()
	_test_recovery_order_and_routes()
	_test_recovery_claim_priority()
	_test_recovery_contact_and_credit()
	_test_recovery_shared_intake()
	_test_recovery_interruption_and_modes()
	_test_recovery_save_continuity()
	if failures.is_empty():
		print("PASS resource gathering: %d assertions" % checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("FAIL resource gathering: %d / %d assertions" % [failures.size(), checks])
		quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _game() -> GameSimulation:
	var sim := GameSimulation.new()
	sim.configure({"number": 1, "width": 64, "height": 64, "tile_size": 32,
		"blocked": [], "player_start": Vector2(300, 300),
		"hermes_start": Vector2(600, 300), "enemies": [], "wave_based": false})
	sim.set_hermes_mode("building")
	return sim

func _advance(sim: GameSimulation, seconds: float, fps: int = 60) -> void:
	for index: int in roundi(seconds * fps):
		sim.step(1.0 / fps)

func _test_capacity_reach_and_expiry() -> void:
	var sim: GameSimulation = _game()
	var corpse: Dictionary = sim.spawn_resource(10, sim.nathaniel.position + Vector2(45, 0), 10, false, "gunSoldier")
	sim.step(0)
	_check(corpse.phase == "loose" and not sim.nathaniel.has_corpse, "Starter arms do not reach beyond 44 points")
	corpse.position.x -= 1
	sim.step(0.1)
	_check(corpse.phase == "grab" and not corpse.carried and sim.resources == 30, "Grab begins at reach boundary without resource credit")
	sim.nathaniel.position.x -= 2
	sim.step(0)
	_check(corpse.phase == "loose" and corpse.cargo_slot == -1, "Moving beyond arm reach cancels an ungripped body")
	sim.nathaniel.position = corpse.position
	sim.step(GameBalance.RESOURCE_GRAB_SECONDS)
	_check(corpse.phase == "crush" and corpse.carried, "Grip transfers ground ownership to the arms")
	sim.step(GameBalance.RESOURCE_CRUSH_SECONDS)
	_check(corpse.phase == "carry" and corpse.source_kind == "gunSoldier" and corpse.amount == 10, "Crush stores one bundle with unchanged source and value")
	var next: Dictionary = sim.spawn_resource(10, sim.nathaniel.position)
	sim.step(9.9)
	_check(next.phase == "loose" and sim.carried_resource_count() == 1, "Full starter rack leaves another body on the ground")
	sim.step(0.1)
	_check(not sim.corpses.has(next), "Loose body expires at ten seconds")
	sim.step(20)
	_check(sim.corpses.size() == 1 and corpse.carried, "Held bundle never expires")
	corpse.expiration = 0
	sim.step(0)
	_check(sim.corpses.has(corpse), "An old zero-expiry carried bundle is preserved")

func _test_acceptance_and_interruption() -> void:
	for mode: String in ["following", "building"]:
		var sim: GameSimulation = _game()
		sim.set_hermes_mode(mode)
		sim.spawn_resource(10, sim.hermes.position)
		sim.step(0)
		_check(sim.resources == 30 and sim.corpses.size() == 1, "Living Hermes does not credit loose matter in " + mode)
		sim.nathaniel.position = sim.hermes.position + Vector2(44, 0)
		sim.step(0.6)
		_check(sim.resources == 30 and sim.carried_resource_count() == 1, "Collection itself creates no wallet resources in " + mode)
		sim.step(0.22)
		_check(sim.corpses[0].phase == "feed" and sim.resources == 30, "Presentation opens the intake before acceptance in " + mode)
		sim.nathaniel.position = sim.hermes.position + Vector2(49, 0)
		sim.step(0.1)
		_check(sim.corpses[0].phase == "carry" and sim.resources == 30, "Leaving intake reach cancels feed without credit in " + mode)
		sim.nathaniel.position = sim.hermes.position + Vector2(48, 0)
		sim.step(0.59)
		_check(sim.resources == 30 and sim.corpses.size() == 1, "Bundle remains owned until feed completion in " + mode)
		sim.step(0.01)
		_check(sim.resources == 40 and sim.corpses.is_empty() and not sim.nathaniel.has_corpse, "Accepted delivery transfers one bundle once in " + mode)
		_check(is_equal_approx(float(sim.hermes.furnace_remaining), GameBalance.RESOURCE_FURNACE_SECONDS), "Furnace pulse starts at accepted delivery in " + mode)
		sim.step(1)
		var deliveries: int = 0
		for event: Dictionary in sim.take_events():
			if event.type == "delivery":
				deliveries += 1
		_check(deliveries == 1 and sim.resources == 40 and sim.hermes.furnace_remaining == 0, "No repeated credit or furnace event in " + mode)
	for fps: int in [30, 60, 120]:
		var sim: GameSimulation = _game()
		sim.hermes.position = sim.nathaniel.position + Vector2(40, 0)
		sim.spawn_resource(10, sim.nathaniel.position)
		_advance(sim, 1.2, fps)
		_check(sim.resources == 40 and sim.corpses.is_empty(), "Gathering finishes after 1.2 seconds at %d FPS" % fps)

func _test_death_ownership() -> void:
	for time: float in [0.1, 0.4, 0.6, 0.8, 1.1]:
		var sim: GameSimulation = _game()
		sim.hermes.position = sim.nathaniel.position + Vector2(40, 0)
		var corpse: Dictionary = sim.spawn_resource(10, sim.nathaniel.position)
		sim.step(time)
		var location: Vector2 = sim.nathaniel.position
		sim.damage_entity(int(sim.nathaniel.id), 8000)
		_check(sim.corpses.size() == 1 and not corpse.carried and corpse.phase == "loose" and corpse.position == location and sim.resources == 30, "Death preserves one uncredited body at %.1fs" % time)
		_check(not sim.nathaniel.has_corpse and corpse.cargo_slot == -1, "Death releases cargo ownership at %.1fs" % time)
		if time >= GameBalance.RESOURCE_GRAB_SECONDS:
			_check(corpse.disarmed and corpse.expiration == 0.0, "Dropped held matter remains disarmed at %.1fs" % time)
		else:
			_check(not corpse.disarmed and is_equal_approx(float(corpse.expiration), 10.0 - time), "Death before grip preserves the armed deadline at %.1fs" % time)
	var sim: GameSimulation = _game()
	sim.hermes.position = sim.nathaniel.position + Vector2(40, 0)
	sim.spawn_resource(10, sim.nathaniel.position)
	sim.step(1.1)
	sim.damage_entity(int(sim.hermes.id), int(sim.hermes.hp))
	_check(sim.resources == 30 and sim.corpses[0].phase == "carry" and sim.corpses[0].carried, "Hermes death cancels an unaccepted feed and preserves cargo")

func _test_upgrades_and_sequences() -> void:
	var sim: GameSimulation = _game()
	sim.resources = 200
	_check(sim.gathering_upgrade_cost("capacity") == 20 and sim.gathering_upgrade_cost("reach") == 15, "Starter upgrades expose separate prices")
	sim.spawn_resource(10, sim.nathaniel.position)
	sim.step(0.1)
	_check(sim.upgrade_gathering("capacity") and sim.nathaniel.resource_capacity == 2 and sim.nathaniel.resource_reach == 44, "Capacity can increase during grab without changing reach")
	_check(sim.upgrade_gathering("capacity") and sim.upgrade_gathering("reach") and sim.upgrade_gathering("reach"), "Both upgrade paths reach their supported maximum")
	_check(sim.nathaniel.resource_capacity == 3 and sim.nathaniel.resource_reach == 76 and sim.resources == 95, "Upgrade prices are charged exactly once")
	_check(sim.gathering_upgrade_cost("capacity") == -1 and not sim.upgrade_gathering("capacity") and not sim.upgrade_gathering("other"), "Invalid and completed upgrade paths cannot charge resources")
	sim.spawn_resource(10, sim.nathaniel.position + Vector2(76, 0))
	sim.spawn_resource(20, sim.nathaniel.position + Vector2(74, 0), 10, false, "gunSoldier")
	sim.step(1.7)
	_check(sim.carried_resource_count() == 3 and sim.corpses[0].cargo_slot == 0 and sim.corpses[1].cargo_slot != sim.corpses[2].cargo_slot, "One arm pair fills each upgraded slot in sequence")
	sim.hermes.position = sim.nathaniel.position + Vector2(40, 0)
	sim.step(0.6)
	_check(sim.resources == 105 and sim.carried_resource_count() == 2, "First accepted bundle empties only one rack slot")
	sim.step(0.54)
	_check(sim.resources == 105 and sim.carried_resource_count() == 2, "Furnace completion separates accepted transfers")
	sim.step(2)
	_check(sim.resources == 135 and sim.corpses.is_empty(), "Larger rack feeds every distinct bundle once")
	var restored := GameSimulation.new()
	_check(restored.restore(sim.snapshot()) and restored.nathaniel.resource_capacity == 3 and restored.nathaniel.resource_reach == 76, "Upgrade values persist in native saves")
	sim.damage_entity(int(sim.nathaniel.id), 8000)
	_check(sim.nathaniel.resource_capacity == 3 and sim.nathaniel.resource_reach == 76, "A spare-life respawn preserves upgrades")
	sim.configure(sim.level)
	_check(sim.nathaniel.resource_capacity == 1 and sim.nathaniel.resource_reach == 44, "A fresh level resets the starter backpack")
	sim.resources = 0
	_check(not sim.upgrade_gathering("capacity"), "An unaffordable upgrade is rejected")
	sim.resources = 100
	sim.paused = true
	_check(not sim.upgrade_gathering("reach"), "Pause rejects upgrade mutations")

func _test_save_phases_and_validation() -> void:
	for time: float in [0.1, 0.4, 0.65, 0.9, 1.3]:
		var sim: GameSimulation = _game()
		sim.hermes.position = sim.nathaniel.position + Vector2(40, 0)
		sim.spawn_resource(10, sim.nathaniel.position, 10, false, "gunSoldier")
		sim.step(time)
		var restored := GameSimulation.new()
		var saved: Dictionary = JSON.parse_string(JSON.stringify(sim.snapshot()))
		_check(restored.restore(saved), "JSON restores in-flight gathering at %.2fs" % time)
		_check(restored.take_events().is_empty(), "Restore emits no delivery effect at %.2fs" % time)
		sim.step(2)
		restored.step(2)
		_check(restored.resources == 40 and restored.resources == sim.resources and restored.corpses.is_empty(), "Restored action completes with one credit at %.2fs" % time)
	var sim: GameSimulation = _game()
	sim.spawn_resource(10, sim.nathaniel.position, 10, true, "gunSoldier")
	var legacy: Dictionary = sim.snapshot()
	legacy.entities[0].erase("resource_capacity")
	legacy.entities[0].erase("resource_reach")
	legacy.entities[1].erase("furnace_remaining")
	for key: String in ["phase", "phase_elapsed", "cargo_slot", "pickup_position", "disarmed"]:
		legacy.corpses[0].erase(key)
	var extra: Dictionary = legacy.corpses[0].duplicate(true)
	extra.id = 99
	legacy.corpses.append(extra)
	var restored := GameSimulation.new()
	_check(restored.restore(legacy) and restored.carried_resource_count() == 1 and restored.corpses.size() == 2, "Legacy excess cargo drops without loss or credit")
	_check(restored.corpses[1].phase == "loose" and restored.corpses[1].disarmed and restored.corpses[1].expiration == 0 and restored.corpses[0].source_kind == "gunSoldier", "Legacy cargo migration preserves source type and leaves dropped matter safe")
	for field: String in ["phase", "phase_elapsed", "cargo_slot", "amount", "carried"]:
		var broken: Dictionary = sim.snapshot()
		match field:
			"phase": broken.corpses[0].phase = "magic"
			"phase_elapsed": broken.corpses[0].phase_elapsed = -1
			"cargo_slot": broken.corpses[0].cargo_slot = 9
			"amount": broken.corpses[0].amount = 0.5
			"carried": broken.corpses[0].carried = false
		var before: Dictionary = restored.snapshot()
		_check(not restored.restore(broken) and restored.snapshot() == before, "Invalid %s rejects restore without changing the running game" % field)
	var duplicate: Dictionary = sim.snapshot()
	duplicate.entities[0].resource_capacity = 2
	extra = duplicate.corpses[0].duplicate(true)
	extra.id = 99
	duplicate.corpses.append(extra)
	_check(not restored.restore(duplicate), "Two bundles cannot own one cargo slot")
	for field: String in ["resource_capacity", "resource_reach", "furnace_remaining", "missing_phase", "multiple_actions"]:
		var broken: Dictionary = sim.snapshot()
		match field:
			"resource_capacity": broken.entities[0].resource_capacity = 1.5
			"resource_reach": broken.entities[0].resource_reach = 0
			"furnace_remaining": broken.entities[1].furnace_remaining = 1.0
			"missing_phase": broken.corpses[0].erase("phase")
			"multiple_actions":
				broken.entities[0].resource_capacity = 2
				broken.corpses[0].phase = "feed"
				extra = broken.corpses[0].duplicate(true)
				extra.id = 99
				extra.cargo_slot = 1
				broken.corpses.append(extra)
		_check(not restored.restore(broken), "Invalid gathering %s fails state validation" % field)

func _test_spawn_invariants() -> void:
	var sim: GameSimulation = _game()
	sim.resources = 100
	sim.upgrade_gathering("capacity")
	sim.spawn_resource(10, sim.nathaniel.position, 10, true)
	var second: Dictionary = sim.spawn_resource(20, sim.nathaniel.position, 10, true)
	sim.hermes.position = sim.nathaniel.position + Vector2(40, 0)
	sim.step(0.6)
	var replacement: Dictionary = sim.spawn_resource(30, sim.nathaniel.position, 10, true)
	_check(second.cargo_slot == 1 and replacement.cargo_slot == 0, "Explicit carried setup fills the vacant slot after a delivery")
	var overflow: Dictionary = sim.spawn_resource(10, Vector2.ZERO, 0, true)
	_check(not overflow.carried and overflow.phase == "loose" and overflow.disarmed and overflow.expiration == 0 and overflow.position == sim.nathaniel.position, "Explicit carried overflow drops safely at Nathaniel without loss")
	var restored := GameSimulation.new()
	_check(restored.restore(sim.snapshot()), "Explicit resource setup always produces valid cargo ownership")
	var before: Dictionary = sim.snapshot()
	_check(sim.spawn_resource(0, sim.nathaniel.position).is_empty() and sim.spawn_resource(10, Vector2(INF, 0)).is_empty() and sim.spawn_resource(10, Vector2.ZERO, INF).is_empty() and sim.spawn_resource(10, Vector2.ZERO, 10, false, "unknown").is_empty() and sim.snapshot() == before, "Invalid resource setup leaves the allocator and game unchanged")
	sim.hermes.hp = 0
	_check(not sim.upgrade_gathering("reach"), "A dead Hermes cannot build a backpack upgrade")

func _test_movement_and_weapon() -> void:
	var sim: GameSimulation = _game()
	var corpse: Dictionary = sim.spawn_resource(10, sim.nathaniel.position)
	sim.step(0.1)
	sim.move_to(sim.nathaniel.position + Vector2(20, 0))
	sim.nathaniel.cooldown = 10
	_check(sim.fire_at(sim.nathaniel.position + Vector2(0, -100)), "Rifle accepts fire during a grab")
	var start: Vector2 = sim.nathaniel.position
	sim.step(0.1)
	_check(sim.nathaniel.position != start and corpse.phase == "grab" and not sim.projectiles.is_empty(), "Movement and rifle fire continue during backpack handling")

func _test_return_to_hermes() -> void:
	for mode: String in ["following", "building"]:
		var sim: GameSimulation = _game()
		sim.hermes.position = Vector2(1800, 300)
		sim.set_hermes_mode(mode)
		sim.resources = 200
		sim.upgrade_gathering("capacity")
		sim.upgrade_gathering("capacity")
		for index: int in 3:
			sim.spawn_resource(10, sim.nathaniel.position, 10, true)
		_check(sim.return_to_hermes() and sim.nathaniel.returning_cargo, "Return accepts a full rack while Hermes is " + mode)
		sim.step(0.1)
		sim.nathaniel.cooldown = 10
		_check(sim.fire_at(sim.nathaniel.position + Vector2(0, -100)) and sim.nathaniel.returning_cargo, "Manual fire preserves cargo return while Hermes is " + mode)
		var restored := GameSimulation.new()
		_check(restored.restore(sim.snapshot()) and restored.nathaniel.returning_cargo, "Save/load preserves cargo return while Hermes is " + mode)
		_advance(restored, 30)
		_check(restored.resources == 170 and restored.corpses.is_empty() and not restored.nathaniel.returning_cargo, "Long return feeds all three bundles while Hermes is " + mode)
		_check(Vector2(restored.nathaniel.position).distance_to(restored.hermes.position) <= GameBalance.RESOURCE_RETURN_DISTANCE and not restored.nathaniel.moving, "Return stops at the intake without walking past Hermes in " + mode)
	var sim: GameSimulation = _game()
	_check(not sim.return_to_hermes(), "An empty rack cannot start cargo return")
	sim.spawn_resource(10, sim.nathaniel.position, 10, true)
	sim.return_to_hermes()
	sim.stop_player()
	sim.step(0.1)
	_check(not sim.nathaniel.returning_cargo and not sim.nathaniel.moving, "Stop cancels cargo return without resuming it next frame")
	sim.return_to_hermes()
	var destination: Vector2 = sim.nathaniel.position + Vector2(0, 100)
	sim.move_to(destination)
	sim.step(0.1)
	_check(not sim.nathaniel.returning_cargo and sim.nathaniel.destination == destination, "Manual movement replaces cargo return")
	sim.return_to_hermes()
	sim.damage_entity(int(sim.nathaniel.id), 8000)
	_check(not sim.nathaniel.returning_cargo, "Death cancels cargo return before spare-life respawn")
	sim.spawn_resource(10, sim.nathaniel.position, 10, true)
	sim.return_to_hermes()
	sim.damage_entity(int(sim.hermes.id), int(sim.hermes.hp))
	_check(not sim.nathaniel.returning_cargo and not sim.nathaniel.moving, "Hermes death cancels cargo return immediately")
	var invalid: Dictionary = sim.snapshot()
	invalid.entities[0].returning_cargo = 1
	_check(not GameSimulation.gathering_state_error(invalid).is_empty(), "Saved cargo return must be a boolean")

func _test_self_destruct_deadlines() -> void:
	var sim: GameSimulation = _game()
	var corpse: Dictionary = sim.spawn_resource(10, Vector2(900, 900))
	sim.step(7)
	_check(not corpse.disarmed and corpse.expiration == GameBalance.RESOURCE_WARNING_SECONDS, "Warning begins inside the existing ten-second deadline")
	sim.nathaniel.position = corpse.position
	sim.step(GameBalance.RESOURCE_GRAB_SECONDS)
	_check(corpse.disarmed and corpse.carried and corpse.cargo_slot == 0 and corpse.expiration == 0, "Grip during warning atomically disarms and assigns a cargo slot")
	_check(sim.resources == 30, "Disarming a warning body does not credit resources")
	for lifetime: float in [0.1, GameBalance.RESOURCE_GRAB_SECONDS - 0.000000001, GameBalance.RESOURCE_GRAB_SECONDS]:
		sim = _game()
		corpse = sim.spawn_resource(10, sim.nathaniel.position, lifetime)
		sim.step(GameBalance.RESOURCE_GRAB_SECONDS)
		_check(sim.corpses.is_empty() and not sim.nathaniel.has_corpse and sim.resources == 30, "Expiry during grab or at grip boundary loses matter at %.10fs" % lifetime)
		var expired_count: int = 0
		for event: Dictionary in sim.take_events():
			if event.type == "corpse_expired":
				expired_count += 1
				_check(event.corpse_id == corpse.id and event.source_kind == corpse.source_kind and event.position == corpse.position, "Expiry event retains body identity and source for dissolution")
		_check(expired_count == 1, "Each expired body starts one dissolution")
		sim.step(1)
		_check(sim.take_events().is_empty(), "Expired matter cannot repeat effects or delivery")
	for lifetime: float in [GameBalance.RESOURCE_GRAB_SECONDS + 0.000000001, 0.29]:
		sim = _game()
		corpse = sim.spawn_resource(10, sim.nathaniel.position, lifetime)
		sim.step(GameBalance.RESOURCE_GRAB_SECONDS)
		_check(corpse.disarmed and corpse.carried and sim.corpses.size() == 1, "Grip just before expiry succeeds at %.10fs" % lifetime)
	for steps: Array in [[0.27, 0.01], [0.1, 0.1, 0.08], [1.0 / 60, 1.0 / 60, 1.0 / 60, 0.23]]:
		sim = _game()
		sim.spawn_resource(10, sim.nathaniel.position, GameBalance.RESOURCE_GRAB_SECONDS)
		for delta: float in steps:
			sim.step(delta)
		_check(sim.corpses.is_empty() and sim.resources == 30, "Expiry wins a split-step grip boundary: %s" % str(steps))
	sim = _game()
	corpse = sim.spawn_resource(10, Vector2(900, 900))
	sim.step(9.7)
	sim.step(0.02)
	sim.nathaniel.position = corpse.position
	sim.step(0.28)
	_check(sim.corpses.is_empty(), "Floating-point residue cannot rescue a body at its exact ten-second deadline")
	sim = _game()
	corpse = sim.spawn_resource(10, Vector2(900, 900), 0.1, false, "gunSoldier")
	var later: Dictionary = sim.spawn_resource(10, Vector2(950, 900), 0.4)
	sim.step(0.35)
	_check(sim.corpses.size() == 1 and sim.corpses[0] == later and is_equal_approx(float(later.expiration), 0.05), "Nearby bodies retain independent self-destruct deadlines")
	var expiry: Dictionary = {}
	for event: Dictionary in sim.take_events():
		if event.type == "corpse_expired":
			expiry = event
	_check(not expiry.is_empty() and expiry.corpse_id == corpse.id and is_equal_approx(float(expiry.elapsed_since_expiry), 0.25), "Dissolution starts with the elapsed part of a large step")
	_check(sim.nathaniel.hp == sim.nathaniel.max_hp and sim.hermes.hp == sim.hermes.max_hp and sim.resources == 30, "Internal breakdown causes no damage or resource reward")

func _test_disarm_interruption_and_pause() -> void:
	var sim: GameSimulation = _game()
	var corpse: Dictionary = sim.spawn_resource(10, sim.nathaniel.position, 1)
	sim.step(0.1)
	_check(corpse.cargo_slot == -1 and not corpse.disarmed, "Starting a grab reserves no slot and leaves the countdown armed")
	sim.nathaniel.position += Vector2(100, 0)
	sim.step(0)
	_check(corpse.phase == "loose" and is_equal_approx(float(corpse.expiration), 0.9), "Leaving reach before grip preserves the deadline")
	sim.paused = true
	sim.step(20)
	_check(is_equal_approx(float(corpse.expiration), 0.9) and sim.corpses.size() == 1, "Pause freezes armed self-destruct time")
	sim.paused = false
	sim.nathaniel.position = corpse.position
	sim.step(0.1)
	var elapsed: float = corpse.phase_elapsed
	sim.paused = true
	sim.step(20)
	_check(corpse.phase_elapsed == elapsed and not corpse.disarmed and is_equal_approx(float(corpse.expiration), 0.8), "Pause freezes a grab and its armed warning countdown")
	sim.paused = false
	sim.step(0.18)
	_check(corpse.disarmed and corpse.carried, "Resuming completes the remaining grip time")
	sim.damage_entity(int(sim.nathaniel.id), int(sim.nathaniel.max_hp))
	sim.nathaniel.position = Vector2(900, 900)
	sim.step(20)
	_check(sim.corpses.size() == 1 and corpse.disarmed and not corpse.carried and corpse.expiration == 0, "A death drop remains safe beyond the former lifetime")
	sim.nathaniel.position = corpse.position
	sim.step(0.6)
	_check(corpse.disarmed and corpse.carried and sim.resources == 30, "Safe dropped cargo can be collected again without credit")
	sim = _game()
	corpse = sim.spawn_resource(10, sim.nathaniel.position, 1)
	sim.step(0.1)
	var occupied: Dictionary = sim.spawn_resource(10, sim.nathaniel.position, 10, true)
	sim.step(0.18)
	_check(corpse.phase == "loose" and not corpse.disarmed and not corpse.carried and occupied.cargo_slot == 0, "Grip rechecks a slot occupied after the grab began")
	sim.step(0.72)
	_check(sim.corpses.size() == 1 and sim.corpses[0] == occupied, "Full cargo capacity cannot disarm nearby armed matter")

func _test_self_destruct_saves() -> void:
	for remaining: float in [7.5, 2.5]:
		var sim: GameSimulation = _game()
		sim.spawn_resource(10, Vector2(900, 900), remaining)
		var restored := GameSimulation.new()
		_check(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))), "Armed or warning state restores with %.1fs remaining" % remaining)
		_check(not restored.corpses[0].disarmed and restored.corpses[0].expiration == remaining, "Loading preserves the armed deadline with %.1fs remaining" % remaining)
		restored.step(remaining)
		_check(restored.corpses.is_empty() and restored.resources == 30, "Restored armed matter expires without reward")
		var after_expiry := GameSimulation.new()
		_check(after_expiry.restore(restored.snapshot()) and after_expiry.corpses.is_empty() and after_expiry.take_events().is_empty(), "Saving during dissolution cannot restore lost matter or repeat expiry")
	var sim: GameSimulation = _game()
	var corpse: Dictionary = sim.spawn_resource(10, sim.nathaniel.position, 10, true)
	sim.damage_entity(int(sim.nathaniel.id), int(sim.nathaniel.max_hp))
	var restored := GameSimulation.new()
	_check(restored.restore(sim.snapshot()) and restored.corpses[0].disarmed and not restored.corpses[0].carried, "Safe loose death drops retain permanent disarm through save/load")
	restored.nathaniel.position = Vector2(900, 900)
	restored.step(20)
	_check(restored.corpses.size() == 1, "Loaded safe loose matter never expires")
	sim = _game()
	corpse = sim.spawn_resource(10, Vector2(900, 900), 2.5)
	var legacy: Dictionary = sim.snapshot()
	legacy.corpses[0].erase("disarmed")
	_check(restored.restore(legacy) and not restored.corpses[0].disarmed and restored.corpses[0].expiration == 2.5, "Legacy loose matter keeps its remaining armed lifetime")
	legacy.corpses[0].expiration = 0
	_check(restored.restore(legacy) and restored.corpses.is_empty(), "A legacy expired body cannot return as collectible matter")
	legacy.corpses[0].expiration = 2.5
	legacy.corpses[0].phase = "grab"
	legacy.corpses[0].cargo_slot = 0
	legacy.corpses[0].phase_elapsed = 0.1
	_check(restored.restore(legacy) and not restored.corpses[0].disarmed and restored.corpses[0].cargo_slot == -1, "Legacy grab keeps its timer and defers slot assignment until grip")
	for invalid_value: Variant in [0, "false", null]:
		var broken: Dictionary = sim.snapshot()
		broken.corpses[0].disarmed = invalid_value
		var before: Dictionary = restored.snapshot()
		_check(not restored.restore(broken) and restored.snapshot() == before, "Invalid disarm values reject restoration without mutation")
	sim = _game()
	sim.spawn_resource(10, sim.nathaniel.position, 10, true)
	var broken: Dictionary = sim.snapshot()
	broken.corpses[0].disarmed = false
	_check(not restored.restore(broken), "Current held cargo cannot restore an armed mechanism")

func _recovery_game(number: int = 0) -> GameSimulation:
	var sim: GameSimulation = _game()
	sim.level.number = number
	sim.level_number = number
	sim.lives = 0 if number == 0 else 3
	sim.hermes.position = Vector2(600, 600)
	sim.nathaniel.position = Vector2(1100, 1100)
	BattlefieldRules.update_fog(sim)
	return sim

func _kill_resource(sim: GameSimulation, offset: Vector2, kind: String = "soldier", attacker_id: int = -1) -> Dictionary:
	var before: int = sim.corpses.size()
	var enemy: Dictionary = sim.spawn_enemy(kind, Vector2(sim.hermes.position) + offset)
	sim.damage_entity(int(enemy.id), int(enemy.hp), attacker_id)
	return sim.corpses.back() if sim.corpses.size() > before else {}

func _test_recovery_eligibility_and_kinds() -> void:
	var sim: GameSimulation = _recovery_game()
	sim.set_hermes_mode("following")
	var old: Dictionary = _kill_resource(sim, Vector2(180, 0))
	sim.set_hermes_mode("building")
	var boundary: Dictionary = _kill_resource(sim, Vector2(sim.hermes_build_range(), 0))
	var outside: Dictionary = _kill_resource(sim, Vector2(sim.hermes_build_range() + 0.001, 0))
	_check(not old.recovery_eligible and boundary.recovery_eligible and not outside.recovery_eligible, "Death-time eligibility includes the build boundary and excludes mobile and outside deaths")
	sim.step(0)
	_check(int(sim.hermes.recovery_corpse_id) == int(boundary.id) and old.phase == "loose" and outside.phase == "loose", "Deployment does not sweep older or outside bodies")
	sim.set_hermes_mode("following")
	_check(not boundary.recovery_eligible and boundary.phase == "loose", "Packing up clears the current deployment's pending eligibility")
	sim.set_hermes_mode("building")
	sim.step(0)
	_check(sim.recovery_state().is_empty(), "A later deployment cannot reclaim the cleared list")
	for kind: String in ["soldier", "gunSoldier", "boss"]:
		sim = _recovery_game()
		var corpse: Dictionary = _kill_resource(sim, Vector2(200, 0), kind, int(sim.nathaniel.id))
		_check(corpse.recovery_eligible and corpse.source_kind == kind and corpse.amount == GameBalance.RESOURCE_VALUES[kind], "A %s death records its existing matter value and recovery eligibility" % kind)
		sim.step(2)
		_check(sim.resources == 30 + int(corpse.amount) and sim.corpses.is_empty(), "Recovery accepts one %s body in survival" % kind)
	for kind: String in ["grunt", "spawner"]:
		sim = _recovery_game()
		_check(_kill_resource(sim, Vector2(200, 0), kind).is_empty() and sim.corpses.is_empty() and sim.resources == 30, "%s deaths leave no recoverable matter" % kind)
	sim = _recovery_game()
	sim.hermes.hp = 0
	var corpse: Dictionary = _kill_resource(sim, Vector2(180, 0))
	_check(not corpse.recovery_eligible, "An enemy death cannot enter a dead Hermes's recovery list")

func _test_recovery_order_and_routes() -> void:
	var sim: GameSimulation = _recovery_game()
	var safe: Dictionary = _kill_resource(sim, Vector2(100, 0))
	safe.disarmed = true
	safe.expiration = 0.0
	var later: Dictionary = _kill_resource(sim, Vector2(130, 0))
	later.expiration = 4.0
	var first: Dictionary = _kill_resource(sim, Vector2(200, 0))
	first.expiration = 2.0
	sim.step(0)
	_check(int(sim.hermes.recovery_corpse_id) == int(first.id) and not safe.carried and later.phase == "loose", "Armed nearest-expiry bodies precede nearer safe and longer-lived bodies")
	sim = _recovery_game()
	var far: Dictionary = _kill_resource(sim, Vector2(200, 0))
	var near: Dictionary = _kill_resource(sim, Vector2(140, 0))
	var tied: Dictionary = _kill_resource(sim, Vector2(-140, 0))
	sim.step(0)
	_check(int(sim.hermes.recovery_corpse_id) == int(near.id) and far.phase == "loose" and tied.phase == "loose", "Equal deadlines use distance, then stable body ID")
	for offset: Vector2 in [Vector2(200, 0), Vector2(-200, 0), Vector2(0, 200), Vector2(0, -200), Vector2(140, 140), Vector2(-140, 140), Vector2(140, -140), Vector2(-140, -140)]:
		sim = _recovery_game()
		var corpse: Dictionary = _kill_resource(sim, offset, "boss")
		sim.step(2)
		_check(sim.corpses.is_empty() and sim.resources == 40, "G1 guides a boss from every tested approach: %s" % offset)
	for obstacle: String in ["terrain", "body_width", "tower", "spawner"]:
		sim = _recovery_game()
		var corpse: Dictionary = _kill_resource(sim, Vector2(200, 0))
		match obstacle:
			"terrain": sim.navigation.blocked[Vector2i(22, 18)] = true
			"body_width": sim.navigation.blocked[Vector2i(22, 19)] = true
			"tower": sim.place_map_tower("gunTower", Vector2(720, 600))
			"spawner":
				var blocker: Dictionary = sim.spawn_enemy("spawner", Vector2(720, 600))
				blocker.damage = 0
		sim.step(0)
		_check(corpse.phase == "loose" and sim.recovery_state().is_empty(), "A %s obstruction blocks recovery with body clearance" % obstacle)
	sim = _recovery_game()
	var hidden: Dictionary = _kill_resource(sim, Vector2(200, 0))
	sim.fog.fill(0)
	sim.step(0)
	_check(hidden.phase == "loose" and sim.recovery_state().is_empty(), "A hidden body cannot start a hook or expose activity")
	BattlefieldRules.update_fog(sim)
	sim.step(0)
	_check(int(sim.hermes.recovery_corpse_id) == int(hidden.id), "A still-eligible body is retried when visibility returns")
	sim = _recovery_game()
	var corpse: Dictionary = _kill_resource(sim, Vector2(200, 0))
	var live: Dictionary = sim.spawn_enemy("soldier", Vector2(720, 600))
	live.speed = 0
	live.damage = 0
	sim.step(0)
	_check(int(sim.hermes.recovery_corpse_id) == int(corpse.id), "A live unit on the ground route does not block the winch")
	sim = _recovery_game()
	corpse = _kill_resource(sim, Vector2(200, 0), "boss")
	sim.place_map_tower("gunTower", Vector2(sim.hermes.position) + Vector2(44, 43))
	sim.step(2)
	_check(sim.resources == 40 and not sim.corpses.has(corpse), "The boss's shrinking bundle clearance fits the authored compression leg beside a tower")

func _test_recovery_claim_priority() -> void:
	var sim: GameSimulation = _recovery_game()
	var corpse: Dictionary = _kill_resource(sim, Vector2(200, 0))
	sim.nathaniel.position = corpse.position
	sim.hermes.recovery_cooldown = GameBalance.HERMES_WINCH_RESET_SECONDS
	sim.step(0.1)
	_check(corpse.phase == "grab" and not corpse.disarmed, "A busy winch lets Nathaniel start a grab")
	sim.hermes.recovery_cooldown = 0.0
	sim.step(GameBalance.RESOURCE_GRAB_SECONDS - 0.1)
	_check(corpse.phase == "winch_launch" and not corpse.disarmed and not corpse.carried and corpse.cargo_slot == -1, "An available Hermes claim wins against same-step backpack grip completion")
	_check(sim.gathering_state().phase == "idle" and not sim.nathaniel.has_corpse, "A superseded grab leaves no backpack phase, ownership, or slot")
	sim.step(0)
	_check(corpse.phase == "winch_launch" and sim.gathering_state().phase == "idle", "Nathaniel cannot restart a stale grab after hook reservation")
	sim = _recovery_game()
	corpse = _kill_resource(sim, Vector2(200, 0))
	sim.nathaniel.position = corpse.position
	sim.navigation.blocked[Vector2i(22, 18)] = true
	sim.step(GameBalance.RESOURCE_GRAB_SECONDS)
	sim.navigation.blocked.clear()
	sim.step(0)
	_check(corpse.carried and corpse.disarmed and sim.recovery_state().is_empty(), "Earlier successful backpack ownership remains protected from Hermes")
	sim = _recovery_game()
	var first: Dictionary = _kill_resource(sim, Vector2(200, 0))
	sim.step(0)
	corpse = _kill_resource(sim, Vector2(0, 180))
	sim.nathaniel.position = corpse.position
	sim.step(GameBalance.RESOURCE_GRAB_SECONDS)
	_check(corpse.carried and int(sim.hermes.recovery_corpse_id) == int(first.id), "One active hook does not reserve a waiting body against backpack collection")
	sim = _recovery_game()
	corpse = _kill_resource(sim, Vector2(200, 0))
	sim.nathaniel.position = corpse.position
	sim.nathaniel.speed = 0.0
	var held: Dictionary = sim.spawn_resource(17, sim.nathaniel.position, 10, true)
	var destination: Vector2 = sim.nathaniel.position + Vector2(0, 200)
	sim.move_to(destination)
	sim.step(0)
	_check(int(sim.hermes.recovery_corpse_id) == int(corpse.id) and held.carried and held.amount == 17 and sim.nathaniel.destination == destination, "A hook claim preserves unrelated held cargo and movement orders")
	for expires: bool in [false, true]:
		sim = _recovery_game()
		first = _kill_resource(sim, Vector2(200, 0))
		sim.step(1.22)
		corpse = _kill_resource(sim, Vector2(0, 180))
		sim.nathaniel.position = corpse.position
		if expires:
			corpse.expiration = GameBalance.RESOURCE_GRAB_SECONDS
		sim.step(GameBalance.RESOURCE_GRAB_SECONDS)
		if expires:
			_check(not sim.corpses.has(corpse) and sim.recovery_state().is_empty() and sim.resources == 40, "Expiry wins when the empty hook's reset and backpack grip finish together")
		else:
			_check(corpse.phase == "winch_launch" and not corpse.disarmed and not corpse.carried and sim.resources == 40, "A naturally completed reset claims before same-boundary backpack grip")
			corpse.expiration = 0.1
			sim.step(0.1)
			_check(not sim.corpses.has(corpse) and sim.resources == 40, "Superseding a nearly complete grip adds no grace period before hook contact")

func _test_recovery_contact_and_credit() -> void:
	var contact: float = GameBalance.HERMES_WINCH_LAUNCH_SECONDS + GameBalance.HERMES_WINCH_CLAMP_SECONDS
	for lifetime: float in [contact - 0.000000001, contact, contact + 0.000000001]:
		var sim: GameSimulation = _recovery_game()
		var corpse: Dictionary = _kill_resource(sim, Vector2(200, 0))
		corpse.expiration = lifetime
		sim.step(contact)
		if lifetime <= contact:
			_check(sim.corpses.is_empty() and sim.recovery_state().is_empty() and sim.resources == 30, "Expiry wins at or before clamp contact: %.10f" % lifetime)
		else:
			_check(corpse.disarmed and corpse.expiration == 0 and corpse.phase == "winch_reel" and sim.resources == 30, "Contact just before expiry disarms without credit")
	var sim: GameSimulation = _recovery_game()
	var corpse: Dictionary = _kill_resource(sim, Vector2(200, 0))
	corpse.amount = 17
	sim.step(contact - 0.01)
	_check(not corpse.disarmed and is_equal_approx(float(corpse.expiration), 10.0 - contact + 0.01) and sim.resources == 30, "A reserved body stays armed and uncredited during launch")
	sim.step(0.01)
	_check(corpse.disarmed and corpse.expiration == 0 and not corpse.carried and corpse.cargo_slot == -1, "Clamp contact assigns exclusive winch ownership without a backpack slot")
	sim.step(GameBalance.HERMES_WINCH_REEL_SECONDS / 2)
	_check(corpse.position != corpse.pickup_position and corpse.phase == "winch_reel" and sim.resources == 30, "The secured shell moves over the ground before acceptance")
	sim.step(2)
	var deliveries: int = 0
	for event: Dictionary in sim.take_events():
		if event.type == "delivery" and int(event.corpse_id) == int(corpse.id):
			deliveries += 1
	_check(sim.resources == 47 and sim.corpses.is_empty() and deliveries == 1, "One intake acceptance credits the body's stored value once")
	sim.step(3)
	_check(sim.resources == 47 and sim.recovery_state().is_empty(), "A reset winch cannot repeat the accepted reward")
	sim = _recovery_game()
	_kill_resource(sim, Vector2(200, 0))
	var target: Dictionary = sim.spawn_enemy("soldier", Vector2(sim.hermes.position) + Vector2(0, 280))
	target.max_hp = 100000
	target.hp = 100000
	target.speed = 0
	target.damage = 0
	sim.take_events()
	_advance(sim, float(sim.hermes.delay))
	var shots: int = 0
	for event: Dictionary in sim.take_events():
		if event.type == "shot" and int(event.owner_id) == int(sim.hermes.id):
			shots += 1
	_check(shots == 1 and int(sim.hermes.target_id) == int(target.id) and not sim.recovery_state().is_empty(), "Cannon timing and combat target remain independent while reeling")

func _test_recovery_shared_intake() -> void:
	var sim: GameSimulation = _recovery_game()
	var first: Dictionary = _kill_resource(sim, Vector2(200, 0))
	sim.step(0.4)
	var second: Dictionary = _kill_resource(sim, Vector2(0, 180))
	var held: Dictionary = sim.spawn_resource(17, sim.nathaniel.position, 10, true)
	sim.nathaniel.position = Vector2(sim.hermes.position) + Vector2(40, 0)
	sim.return_to_hermes()
	sim.step(0.89)
	_check(held.phase == "carry" and held.carried and sim.resources == 30, "Manual cargo waits in the rack while the current pull finishes")
	sim.step(0.01)
	_check(sim.resources == 40 and not sim.corpses.has(first) and held.carried, "The in-flight automatic body takes the current intake turn")
	sim.take_events()
	sim.step(1.2)
	var delivered: bool = false
	for event: Dictionary in sim.take_events():
		if event.type == "delivery" and int(event.corpse_id) == int(held.id):
			delivered = true
		if event.type == "gathering_phase" and event.phase == "winch_launch" and int(event.corpse_id) == int(second.id):
			_check(delivered, "A new hook starts only after the waiting manual delivery receipt")
	_check(sim.resources == 57 and not sim.corpses.has(held) and delivered, "Waiting manual cargo receives the next intake turn before a new hook")
	sim.step(3)
	_check(sim.resources == 67 and sim.corpses.is_empty(), "Automatic recovery resumes after manual delivery without duplicate rewards")
	sim = _recovery_game()
	held = sim.spawn_resource(17, sim.nathaniel.position, 10, true)
	sim.return_to_hermes()
	var corpse: Dictionary = _kill_resource(sim, Vector2(200, 0))
	sim.step(0)
	_check(corpse.phase == "winch_launch" and held.carried, "A distant delivery order does not reserve the intake")
	sim = _recovery_game()
	sim.nathaniel.position = Vector2(sim.hermes.position) + Vector2(40, 0)
	held = sim.spawn_resource(17, sim.nathaniel.position, 10, true)
	sim.step(0.1)
	corpse = _kill_resource(sim, Vector2(200, 0))
	sim.step(0)
	_check(held.phase == "present" and corpse.phase == "loose", "A manual transfer already in progress prevents a new launch")
	sim.move_to(Vector2(sim.hermes.position) + Vector2(0, 200))
	sim.step(0.5)
	_check(held.phase == "carry" and held.carried and int(sim.hermes.recovery_corpse_id) == int(corpse.id), "Moving out of intake reach cancels the wait and permits a hook")

func _test_recovery_interruption_and_modes() -> void:
	for action: String in ["pack", "death"]:
		for time: float in [0.1, 0.4, 1.05, 1.2, 1.31]:
			var sim: GameSimulation = _recovery_game()
			var corpse: Dictionary = _kill_resource(sim, Vector2(200, 0))
			sim.step(time)
			var accepted: bool = not sim.corpses.has(corpse)
			var disarmed: bool = corpse.disarmed
			var before_position: Vector2 = corpse.position
			if action == "pack":
				sim.set_hermes_mode("following")
			else:
				sim.damage_entity(int(sim.hermes.id), int(sim.hermes.hp))
			if accepted:
				_check(sim.resources == 40 and sim.corpses.is_empty(), "%s after acceptance retains only the completed credit" % action)
			else:
				_check(corpse.phase == "loose" and not corpse.carried and sim.resources == 30, "%s releases one uncredited body at %.2fs" % [action, time])
				if disarmed:
					_check(Vector2(corpse.position).distance_to(sim.hermes.position) >= GameBalance.HERMES_WINCH_BASE_CLEARANCE + 12.0 and sim.navigation.swept_terrain_clear(corpse.position, corpse.position, 12.0), "%s drops the secured shell outside Hermes's footprint at %.2fs" % [action, time])
				else:
					_check(corpse.position == before_position, "%s before contact preserves the body's original ground position" % action)
				_check(corpse.disarmed == disarmed and (corpse.expiration == 0 if disarmed else is_equal_approx(float(corpse.expiration), 10.0 - time)), "%s preserves expiry or permanent disarm at %.2fs" % [action, time])
			_check(sim.recovery_state().is_empty() and int(sim.hermes.recovery_corpse_id) == 0, "%s clears the active hook at %.2fs" % [action, time])
			if action == "death":
				_check(sim.result == "gameOver", "Hermes death still ends the run")
	for kind: String in ["gunSoldier", "boss"]:
		var radius: float = 22.0 if kind == "boss" else 12.0
		for time: float in [1.05, 1.2]:
			var sim: GameSimulation = _recovery_game()
			var body: Dictionary = _kill_resource(sim, Vector2(200, 0), kind)
			sim.step(time)
			sim.set_hermes_mode("following")
			_check(body.phase == "loose" and body.disarmed and body.expiration == 0 and not body.carried and sim.resources == 30 and Vector2(body.position).distance_to(sim.hermes.position) >= GameBalance.HERMES_WINCH_BASE_CLEARANCE + radius and sim.navigation.swept_terrain_clear(body.position, body.position, radius), "Packing up during compression or feed drops the full %s shell clear of Hermes at %.2fs" % [kind, time])
		var sim: GameSimulation = _recovery_game()
		var body: Dictionary = _kill_resource(sim, Vector2(GameBalance.HERMES_WINCH_BASE_CLEARANCE + radius - 0.001, 0), kind)
		sim.step(0)
		_check(body.phase == "loose" and not body.disarmed and sim.recovery_state().is_empty(), "The winch skips a %s shell which overlaps its base footprint" % kind)
		sim.nathaniel.position = body.position
		sim.step(GameBalance.RESOURCE_GRAB_SECONDS)
		_check(body.carried and body.disarmed and sim.recovery_state().is_empty() and sim.resources == 30, "Nathaniel can manually secure the skipped %s shell" % kind)
	var sim: GameSimulation = _recovery_game()
	var corpse: Dictionary = _kill_resource(sim, Vector2(220, 0))
	sim.step(0.4)
	sim.place_map_tower("gunTower", Vector2(sim.hermes.position) + Vector2(130, 0))
	sim.step(0)
	_check(corpse.phase == "loose" and corpse.disarmed and corpse.expiration == 0 and sim.resources == 30, "A newly blocked pull drops its secured body safely without credit")
	for time: float in [0.1, 0.4, 1.05, 1.2]:
		sim = _recovery_game()
		corpse = _kill_resource(sim, Vector2(200, 0))
		sim.step(time)
		var before: Dictionary = sim.snapshot()
		sim.paused = true
		sim.step(20)
		var after: Dictionary = sim.snapshot()
		_check(after == before, "Pause freezes recovery motion, progress, expiry, and wallet at %.2fs" % time)
		sim.paused = false
		sim.step(2)
		_check(sim.resources == 40 and sim.corpses.is_empty(), "Resume finishes the same recovery once at %.2fs" % time)
	sim = _recovery_game(1)
	corpse = _kill_resource(sim, Vector2(200, 0))
	sim.step(0.4)
	sim.damage_entity(int(sim.nathaniel.id), int(sim.nathaniel.hp))
	_check(corpse.phase == "winch_reel" and corpse.disarmed, "Nathaniel's spare-life death does not release the winch's body")
	sim.configure(sim.level)
	_check(sim.corpses.is_empty() and sim.recovery_state().is_empty() and int(sim.hermes.recovery_corpse_id) == 0 and float(sim.hermes.recovery_cooldown) == 0, "A fresh run clears pending recovery and its reset timer")
	sim = _recovery_game(1)
	corpse = _kill_resource(sim, Vector2(200, 0), "boss")
	sim.step(2)
	_check(sim.result == "victory" and sim.resources == 30 and sim.corpses.has(corpse) and sim.recovery_state().is_empty(), "Campaign boss victory remains immediate without an automatic payout window")
	for cause: String in ["survival_death", "campaign_victory"]:
		sim = _recovery_game(0 if cause == "survival_death" else 1)
		corpse = _kill_resource(sim, Vector2(200, 0))
		sim.step(0.4)
		if cause == "survival_death":
			sim.damage_entity(int(sim.nathaniel.id), int(sim.nathaniel.hp))
		else:
			_kill_resource(sim, Vector2(0, 180), "boss")
		_check(sim.result == ("gameOver" if cause == "survival_death" else "victory") and corpse.phase == "loose" and corpse.disarmed and not corpse.recovery_eligible and sim.recovery_state().is_empty() and sim.resources == 30, "%s immediately drops and clears an active pull without credit" % cause)

func _test_recovery_save_continuity() -> void:
	for time: float in [0.0, 0.1, 0.4, 1.05, 1.2, 1.31]:
		var sim: GameSimulation = _recovery_game()
		var corpse: Dictionary = _kill_resource(sim, Vector2(200, 0), "gunSoldier")
		sim.step(time)
		var restored := GameSimulation.new()
		_check(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))), "JSON restores recovery at %.2fs" % time)
		_check(restored.take_events().is_empty(), "Restoring recovery emits no replayed receipt at %.2fs" % time)
		if sim.corpses.has(corpse):
			_check(restored.corpses[0].recovery_eligible and restored.corpses[0].phase == corpse.phase and is_equal_approx(float(restored.corpses[0].phase_elapsed), float(corpse.phase_elapsed)) and restored.corpses[0].disarmed == corpse.disarmed and is_equal_approx(float(restored.corpses[0].expiration), float(corpse.expiration)), "Load preserves exclusive ownership, progress, and decay at %.2fs" % time)
		restored.step(3)
		_check(restored.resources == 40 and restored.corpses.is_empty(), "Saved recovery completes with exactly one credit at %.2fs" % time)
	var sim: GameSimulation = _recovery_game()
	var corpse: Dictionary = _kill_resource(sim, Vector2(200, 0))
	var pending: Dictionary = _kill_resource(sim, Vector2(0, 180))
	sim.step(0.1)
	var restored := GameSimulation.new()
	_check(restored.restore(sim.snapshot()) and restored.corpses[1].recovery_eligible, "Unclaimed eligibility survives save/load for the current deployment")
	restored.step(4)
	_check(restored.resources == 50 and restored.corpses.is_empty(), "The restored pending list consumes distinct bodies once")
	var legacy: Dictionary = sim.snapshot()
	for item: Dictionary in legacy.entities:
		item.erase("recovery_corpse_id")
		item.erase("recovery_cooldown")
	for item: Dictionary in legacy.corpses:
		item.erase("recovery_eligible")
		item.erase("recovery_route")
		item.erase("recovery_drop_position")
		item.phase = "loose"
		item.phase_elapsed = 0.0
	_check(restored.restore(legacy) and not restored.corpses[0].recovery_eligible and restored.recovery_state().is_empty(), "Older saves receive no inferred recovery eligibility or active job")
	for field: String in ["eligibility", "backpack_owner", "orphan", "multiple_jobs"]:
		var broken: Dictionary = sim.snapshot()
		match field:
			"eligibility": broken.corpses[0].recovery_eligible = 1
			"backpack_owner": broken.corpses[0].carried = true
			"orphan": broken.entities[1].recovery_corpse_id = 99999
			"multiple_jobs":
				broken.corpses[1].phase = "winch_launch"
				broken.corpses[1].phase_elapsed = 0.0
				broken.corpses[1].recovery_route = broken.corpses[0].recovery_route.duplicate(true)
				broken.corpses[1].recovery_drop_position = broken.corpses[0].recovery_drop_position
		var before: Dictionary = restored.snapshot()
		_check(not restored.restore(broken) and restored.snapshot() == before, "Invalid recovery %s rejects restore without mutation" % field)
	for time: float in [0.1, 0.4]:
		sim = _recovery_game()
		corpse = _kill_resource(sim, Vector2(200, 0))
		sim.step(time)
		var saved: Dictionary = sim.snapshot()
		saved.hermes_mode = "following"
		_check(restored.restore(saved) and restored.recovery_state().is_empty() and restored.corpses[0].phase == "loose" and restored.corpses[0].disarmed == corpse.disarmed and not restored.corpses[0].recovery_eligible, "An unavailable restored owner releases or safely drops its body at %.2fs" % time)
